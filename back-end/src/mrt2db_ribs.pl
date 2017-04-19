#!/usr/bin/perl  
#Author: Anant Shah, Colorado State University

use strict;   # Load strict module for increased syntax checking
use DBI;      # Load the DBI module for connection to mysql database (or others)
use Time::gmtime;    # Load Time::gmtime module used to convert dates and times
use NetAddr::IP
  ;    # Load NetAddr::IP module used to work with and convert ip addresses
use Getopt::Long;    # Load GetOpt::Std to parse command line arguments
use Data::Validate::IP qw(is_ipv4);
use Geo::IP;
use Email::MIME;
use Email::Sender::Simple qw(sendmail);

my $gi =
  Geo::IP->open( "/usr/local/share/GeoIP/GeoIPCity.dat", GEOIP_STANDARD );

my $hostname;
my $username;
my $password;
my $database_name;
my $current_file;
if ( @ARGV > 0 ) {
    GetOptions(
        'h|hostname=s'       => \$hostname,
        'u|user=s'           => \$username,
        'p|password=s'       => \$password,
        'db|database_name=s' => \$database_name
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
    $database_name = "iodb2";
}


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

print("Connected to $database_name on $hostname\n");

### Prepare SQL statements ###

my $dbq_DataSet =
  $dbh->prepare_cached("INSERT INTO DataSet VALUES(NULL,?,?,UTC_TIMESTAMP(),?)")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_insertLookupTable =
  $dbh->prepare_cached("INSERT INTO LookupTable VALUES(NULL,?,?,?)")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_GeoID =
  $dbh->prepare_cached("SELECT GeoID FROM GeoInfo WHERE IP = ?")
  or die "Can't prepare SQL statement: $DBI::errstr\n";   
my $dbq_GeoInfo =
  $dbh->prepare_cached("INSERT INTO GeoInfo VALUES(NULL,?,?,?,?,?,?)")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_CheckDataSet = $dbh->prepare_cached(
"SELECT ID FROM DataSet where FromFile = ?"
) or die "Can't prepare SQL statement: $DBI::errstr\n";


my $count = 0;
my $date  = `date`;
my $pwd   = `pwd`;
chomp($pwd);
$pwd =~ s/\//-/g;    #replace / with _
chomp($date);        #takes off trailing newline if necessary


my @mrtfiles = glob("*.bz2");

#opendir (my $DIR, '.') or die $!;
### process the data (insert into database)
#open my $FILES, "ls |";
#while (<$FILES>) {
#while (my $thisfile = readdir($DIR)) {
foreach my $thisfile (@mrtfiles) {
    chomp($thisfile);            #remove whitespace characters at end of filename
    
    #$thisfile =~ s/\s+/\\ /g;    #escape space for the shell
                          #`bzip2 -d $_`; #extract file to be processed

    #store filename with and without .gz extension
    my $originalFilename = $thisfile;
    $current_file      = $originalFilename;
    my $newFilename      = $originalFilename;
    $newFilename =~ s/\.bz2$//;

    #obtain DataSet info
    my $Descr       = "RouteViews Data RIBS";
    my @split_name  = split( '\.', $newFilename );
    my $CollectDate = $split_name[2];

    #print $newFilename,"\n";
    #$CollectDate =~ s/rib\.//;
    if ( $CollectDate =~ /:0$/ ) {    #ends with :0
        $CollectDate .= "0";          #add trailing zero for DATETIME format
    }

    
    ### insert DataSet info
    #print($originalFilename,"\n",$Descr,"\n",$CollectDate,"\n",$CollectedFrom);
    $dbq_CheckDataSet->execute($originalFilename);
    my @res_for_dataset_check=$dbq_CheckDataSet->fetchrow_array;
    if($res_for_dataset_check[0]){
        print("$originalFilename already exists\n");
        next; #This dataset already exists in the database
    }else{
        $dbq_DataSet->execute( $originalFilename, $Descr, $CollectDate );
        email("Inserting $originalFilename");    
    }
    

    #process machine-readable (-m) output of bgpdump
    my $lineNum = 1;
    open my $BGP_DATA_FILE, "sudo nice -n -20 /usr/local/bin/bgpdump -m $originalFilename |"
      or die "cannot pipe from bgpdump: $!";
    while (<$BGP_DATA_FILE>) {

        my $announce_flag  = 0;    #flag
        my $community_flag = 0;    #flag
                                   #split line into variables seperated by a '|'
        (
            my $BGPVersion,
            my $MsgTime,
            my $MsgType,
            my $PeerIP,
            my $PeerAS,
            my $prefix_combo,
            my $asPath,
            my $Origin,
            my $NextHop,
            my $LocalPref,
            my $Med,
            my $Community,
            my $AggregateID,
            my $AggregateIP
        ) = split( /\|/, $_ );

        #Check all fields that are supposed to be not null
        if (   $MsgTime == ""
            or $PeerIP == ""
            or $prefix_combo == ""
            or $prefix_combo =~ /:/ )    #Skip v6 prefixes
        {
            next;
        }

        #Check if PeerIP is v4, if not then skip this v6 address
        if ( !is_ipv4($PeerIP) ) {
            next;
        }

### convert seconds since epoch (jan 1 1970) to DATETIME ######################
        #format MsgTime to DATETIME format for insertion into the mysql database
        my $tm = gmtime($MsgTime);       #to UTC
          #$MsgTime = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $tm->year+1900 , $tm->mon+1,$tm->mday,$tm->hour,$tm->min,$tm->sec);
        $MsgTime = sprintf( "%04d-%02d-%02d", $tm->year + 1900, $tm->mon + 1,
            $tm->mday );

        $dbq_insertLookupTable->execute( $MsgTime, $PeerIP, $prefix_combo );

        #GeoInfo of this peer
        $dbq_GeoID->execute($PeerIP);    #check database for geoid
        my @result = $dbq_GeoID->fetchrow_array;
        if ( !$result[0] ) {             #not found id in database
         my $record = $gi->record_by_addr($PeerIP);
            if ( defined $record ) {
                $dbq_GeoInfo->execute( $PeerIP, $record->country_code,
                    $record->region, $record->city, $record->latitude,
                    $record->longitude );
            }
        }

        $lineNum++;

    }   

    #number of $FILES processed
    $count++;
    
   
    close $BGP_DATA_FILE;

}#processed all $FILES

#close $FILES;
#closedir $DIR;

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

### Disconnect from the database

$dbq_DataSet->finish;
$dbq_CheckDataSet->finish;
$dbq_GeoID->finish;
$dbq_GeoInfo->finish;
$dbq_insertLookupTable->finish;

$dbh->disconnect
  or warn "Error disconnecting: $DBI::errstr\n";

email("Last file $current_file, $count files processed\n");
