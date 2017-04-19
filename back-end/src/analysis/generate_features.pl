use strict;   # Load strict module for increased syntax checking
use DBI;      # Load the DBI module for connection to mysql database (or others)

use NetAddr::IP;

# Load NetAddr::IP module used to work with and convert ip addresses
use Getopt::Long;    # Load GetOpt::Std to parse command line arguments
use Data::Validate::IP qw(is_ipv4);
use Geo::IP;
use Email::MIME;
use Email::Sender::Simple qw(sendmail);
use Time::Local;
use POSIX qw(strftime);

use Email::MIME;
use Email::Sender::Simple qw(sendmail);

use LWP::Simple;
use File::Slurp qw/read_file/;
use File::Basename;
use File::Copy qw/move/;
use File::Path qw/make_path/;

my $hostname;
my $username;
my $password;
my $database_name;
my $error_log;
if ( @ARGV > 0 ) {
    GetOptions(
        'h|hostname=s'       => \$hostname,
        'u|user=s'           => \$username,
        'p|password=s'       => \$password,
        'db|database_name=s' => \$database_name,
        'e|error_log=s'      => \$error_log
    );
}

#defaults
if ( !defined $hostname ) {
    $hostname = "proton.netsec.colostate.edu";
}
if ( !defined $username ) {
    $username = "root";
}
if ( !defined $password ) {
    $password = "n3ts3cm5q1";
}
if ( !defined $database_name ) {
    $database_name = "iodb";
}
if ( !defined $error_log ) {
    `touch /tmp/error_log`;
    $error_log = "/tmp/error_log2";
}

print
"making connection to database named $database_name on $hostname with user: $username and password: $password\n";

#connect to mysql database
my $dbh = DBI->connect(
    "dbi:mysql:$database_name:$hostname",
    $username,
    $password,
    {
        PrintError => 1,
        RaiseError => 0
    }
) or die "Can't connect to the database: $DBI::errstr\n";

sub email {

    my $time    = scalar localtime();
    my $string  = $_[0] . "\n" . $time;
    my $message = Email::MIME->create(
        header_str => [
            From    => 'mybot@rams.colostate.edu',
            To      => 'akshah@rams.colostate.edu',
            Subject => 'Outage DB update',
        ],
        attributes => {
            encoding => 'quoted-printable',
            charset  => 'ISO-8859-1',
        },
        body_str => "$string\n",
    );

    sendmail($message);

}

my $dbq_getOutageInfo = $dbh->prepare_cached(
"SELECT OutageID,PeerIP,BGP_LPM FROM OutageInfo where BGP_LPM != 'default' order by OutageID"
) or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_getPingOutage =
  $dbh->prepare_cached(
"SELECT IPBlock,RspDensity,unix_timestamp(OutageStart),unix_timestamp(OutageEnd) from PingOutage where OutageID = ?"
  ) or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_getIPID = $dbh->prepare_cached("SELECT ID from IPTable where IP = ?")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_getIP = $dbh->prepare_cached("SELECT IP from IPTable where ID = ?")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_getMessageFields = $dbh->prepare_cached(
"SELECT PeerAS,NextHopID,MsgPathID,MED FROM Message where PeerIPID = ? and PrefixID= ? and PrefixMask = ?"
) or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_getMessageCounts = $dbh->prepare_cached(
"SELECT count(*) FROM Message where PeerIPID = ? and PrefixID= ? and PrefixMask = ? and PeerAS = ? and NextHopID = ? MsgPathID =? MED = ? and MsgType = ?"
) or die "Can't prepare SQL statement: $DBI::errstr\n";


my $dbq_getOriginAS = $dbh->prepare_cached(
    "select ASN from MsgPath where MsgPathID= ? order by PathOrder desc limit 1"
) or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_getLenAS = $dbh->prepare_cached(
"select PathOrder from MsgPath where MsgPathID= ? order by PathOrder desc limit 1"
) or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_getNextOutageTime = $dbh->prepare_cached(
"select unix_timestamp(OutageStart) from PingOutage where IPBlock= ? and unix_timestamp(OutageStart) > ? limit 1"
) or die "Can't prepare SQL statement: $DBI::errstr\n";

print(
"IPBlock,PeerIP,PeerAS,BGP_LPM,OriginAS,NextHop,MED,LenAS,OutageStart,Duration,Density,TimetoNextOutage\n"
);

my $numentries = 0;
$dbq_getOutageInfo->execute();
while ( my @row = $dbq_getOutageInfo->fetchrow_array ) {
    if ( $numentries == 30 ) {
        last;
    }

    #Basic OutageInfo
    #print("Got OutageInfo\n");
    my $OutageID = $row[0];
    my $PeerIP   = $row[1];
    my $BGP_LPM  = $row[2];

    #Get /24 IPBlock
    $dbq_getPingOutage->execute($OutageID);
    my ( $IPBlock, $Density, $OutageStart, $OutageEnd ) =
      $dbq_getPingOutage->fetchrow_array;

    #print("Got PingOutages\n");
    #Calculate duration of the outage
    my $Duration = $OutageEnd - $OutageStart;

    #Get ID of the PeerIP
    $dbq_getIPID->execute($PeerIP);
    my $PeerIPID = $dbq_getIPID->fetchrow_array;

    #Get PrefixID and Mask to use in filtering messages
    my ( $Prefix, $Mask ) = split( '/', $BGP_LPM );
    $dbq_getIPID->execute($Prefix);
    my $PrefixID = $dbq_getIPID->fetchrow_array;

    #Calculate Time to next Outage
    $dbq_getNextOutageTime->execute( $IPBlock, $OutageEnd );
    my $NextOutageTime = $dbq_getNextOutageTime->fetchrow_array;
    my $TimetoNextOutage;
    if ( $NextOutageTime == "" ) {
        $TimetoNextOutage = 'Inf';
    }
    else {
        $TimetoNextOutage = ( $NextOutageTime - $OutageEnd );
    }

    #print("Fetching Msg Fields\n");
    my @messages;

    #Get PeerAS,NextHop,Number of updates
    $dbq_getMessageFields->execute( $PeerIPID, $PrefixID, $Mask );
    while ( my @msgrows = $dbq_getMessageFields->fetchrow_array ) {

        #Num,MsgType,PeerAS,NextHopID
        #my $NumMsgs = $msgrows[0];
        #my $MsgType = $msgrows[1];
        my $PeerAS    = $msgrows[0];
        my $NextHopID = $msgrows[1];
        my $MsgPathID = $msgrows[2];
        my $MED       = $msgrows[3];

        my $tuple=$PeerAS.'|'.$NextHopID.'|'.$MsgPathID.'|'.$MED;
        #print($tuple);
        if ( !( $tuple ~~ @messages ) ) {
            push( @messages, $tuple );
        }
    }

    #We will push a new row for each uniq tuple <peeras,nexthop,msgpath,med>
    foreach my $entry (@messages) {
        my @messagefields = split( '|', $entry );
        my $PeerAS    = $messagefields[0];
        my $NextHopID = $messagefields[1];
        my $MsgPathID = $messagefields[2];
        my $MED       = $messagefields[3];

        #my $CountofAs;
        #my $CountofWs;
        
        $dbq_getMessageCounts->execute($PeerIPID, $PrefixID, $Mask,$PeerAS, $NextHopID, $MsgPathID, $MED,'A');
        my $CountofAs=$dbq_getMessageCounts->fetchrow_array;
        $dbq_getMessageCounts->execute($PeerIPID, $PrefixID, $Mask,$PeerAS, $NextHopID, $MsgPathID, $MED,'W');
        my $CountofWs=$dbq_getMessageCounts->fetchrow_array;
        
        #print($PeerAS, $NextHopID, $MsgPathID, $MED);
        
        #Get IP of Next Hop
        $dbq_getIP->execute($NextHopID);
        my $NextHopIP = $dbq_getIP->fetchrow_array;

        #Get Origin AS using MsgPathID
        $dbq_getOriginAS->execute($MsgPathID);
        my $OriginAS = $dbq_getOriginAS->fetchrow_array;
        
        #Get length of AS
        $dbq_getLenAS->execute($MsgPathID);
        my $LenAS = $dbq_getLenAS->fetchrow_array;
        if (   $Duration > 0
            && $TimetoNextOutage != "Inf"
            && $TimetoNextOutage > 0
            )
        {
            $numentries++;
            print(
"$IPBlock,$PeerIP,$PeerAS,$BGP_LPM,$OriginAS,$NextHopIP,$MED,$LenAS,$OutageStart,$Duration,$Density,$TimetoNextOutage,$CountofAs,$CountofWs\n"
            );
        }

    }

    #print("Finished\n");
    #$numentries++;
}

$dbq_getOutageInfo->finish;
$dbq_getPingOutage->finish;
$dbq_getMessageFields->finish;
$dbq_getIPID->finish;
$dbq_getIP->finish;
$dbq_getOriginAS->finish;
$dbq_getLenAS->finish;
$dbq_getNextOutageTime->finish;

$dbh->disconnect
  or warn "Error disconnecting: $DBI::errstr\n";

