#!/usr/bin/perl  
#Author: Anant Shah, Colorado State University

#Insert data in OutageInfo Table
#ID,OutageID,PeerIPID,BGP_LPM

#For each peer each day create trie then for each outage ID for that day perform lookup and insert value

use strict;    # Load strict module for increased syntax checking
use warnings;
use DBI;    # Load the DBI module for connection to mysql database (or others)
use Time::gmtime;  # Load Time::localtime module used to convert dates and times
use NetAddr::IP
  ;    # Load NetAddr::IP module used to work with and convert ip addresses
use Getopt::Long;    # Load GetOpt::Std to parse command line arguments
use Net::IP::LPM;
use Data::Validate::IP;
use Email::MIME;
use Parallel::ForkManager;
use Email::Sender::Simple qw(sendmail);

my $process_count = 10;

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

my $hostname;
my $username;
my $password;
my $database_name;


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

#my $dbq_getLookupTablePeers =
#  $dbh->prepare("SELECT PeerIP FROM LookupTable where RIB_Time = ?")
#  or die "Can't prepare SQL statement: $DBI::errstr\n";
my @all_peers;

my $dbq_getOutageDays =
  $dbh->prepare_cached(
    "select DATE_FORMAT(OutageStart,'%Y-%m-%d') as day from PingOutage;")
  or die "Can't prepare SQL statement: $DBI::errstr\n";
my @all_days;

#print("Pulling Days\n");
$dbq_getOutageDays->execute();
while ( my ($Day) = $dbq_getOutageDays->fetchrow_array ) {
	if(!($Day ~~ @all_days)){
	    push( @all_days, $Day );
	}

    #print("Pulling Peers\n");
}

@all_days = sort @all_days;

open( my $FH, '<','uniq_peer_list' )
  or die("can't open 'uniq_peer_list': $!");

while ( my $PeerIP = <$FH> ) {
      chomp $PeerIP;
      if ( !( $PeerIP ~~ @all_peers ) ) {
          push( @all_peers, $PeerIP );

          #print( $PeerIP, "\n" );
      }
}
close $FH;

sub create_trie_and_push {

      ##This will be part of child process so creating separate handles

      #connect to mysql database
      my $dbh_C = DBI->connect(
          "dbi:mysql:$database_name:$hostname",
          $username,
          $password,
          {
              PrintError => 1,
              RaiseError => 0
          }
      ) or die "Can't connect to the database: $DBI::errstr\n";

      my $dbq_OutageInfo =
        $dbh_C->prepare_cached("INSERT INTO OutageInfo VALUES(NULL,?,?,?)")
        or die "Can't prepare SQL statement: $DBI::errstr\n";

      my $dbq_getPingOutage = $dbh_C->prepare_cached(
"SELECT OutageID,IPBlock,OutageStart FROM PingOutage where OutageStart like ?"
      ) or die "Can't prepare SQL statement: $DBI::errstr\n";

      my $dbq_getLookupTable = $dbh_C->prepare_cached(
          "SELECT Prefix FROM LookupTable WHERE PeerIP = ? and RIB_Time = ?")
        or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_OutageInfoCheck =
  $dbh_C->prepare_cached(
    "Select InfoID FROM OutageInfo where OutageID = ? and PeerIP = ?")
  or die "Can't prepare SQL statement: $DBI::errstr\n";
  
      my $Day    = $_[0];
      my $PeerIP = $_[1];

      email("OutageInfo: Processing Day $Day and Peer $PeerIP\n");
      print("OutageInfo: Processing Day $Day and Peer $PeerIP\n");

      print("OutageInfo: Creating Trie\n");
      my $lpm = Net::IP::LPM->new();
      $lpm->add( '0.0.0.0/0', 'default' );
      $dbq_getLookupTable->execute( $PeerIP, $Day );

      print("OutageInfo: getLookupTable executed\n");
      while ( my ($Prefix) = $dbq_getLookupTable->fetchrow_array ) {
          if ( defined($Prefix) ) {

              #print("$Prefix\n");
              my ( $ipVal, $Mlen ) = split( "/", $Prefix );
              if ( is_ipv4($ipVal) && defined($Mlen) && $Mlen <= 32 ) {
                  $lpm->add( $Prefix, $Prefix );
              }
          }
      }

      print("OutageInfo: Looking up prefixes\n");
      $dbq_getPingOutage->execute( $Day . '%' );
      while ( my ( $OutageID, $IPBlock, $OutageStart ) =
          $dbq_getPingOutage->fetchrow_array )
      {
          $dbq_OutageInfoCheck->execute( $OutageID, $PeerIP );
          my ($isPresent) = $dbq_OutageInfoCheck->fetchrow_array;

          if ( !$isPresent ) {

          #print("$OutageStart\n");
          my ( $Block, $mask ) = split( "/", $IPBlock );

          my $lookup = $lpm->lookup($Block);
          if ( defined $lookup ) {
              $dbq_OutageInfo->execute( $OutageID, $PeerIP, $lookup );
          }

          }
      }
      print("OutageInfo: Finished Day $Day and Peer $PeerIP\n");
      email("OutageInfo: Finished Day $Day and Peer $PeerIP\n");
      $dbq_getPingOutage->finish;
      $dbq_OutageInfoCheck->finish;
      $dbq_getLookupTable->finish;
      $dbq_OutageInfo->finish;

      $dbh_C->disconnect
        or warn "Error disconnecting: $DBI::errstr\n";
        
      return 0;

}

sub run {
      my $args = shift;
      my ( $D, $P ) = split( '\|', $args );

      create_trie_and_push( $D, $P );
      return 0;
}

foreach my $Day (@all_days) {
      my @dayANDpeer;
      foreach my $PeerIP (@all_peers) {
          push( @dayANDpeer, $Day . '|' . $PeerIP );
      }

      my $pm = Parallel::ForkManager->new($process_count);

      foreach my $dp (@dayANDpeer) {
          my $pid = $pm->start and next;
          run($dp);
          $pm->finish;
      }
      $pm->wait_all_children;
      undef $pm;
      print("OutageInfo: Lookup for $Day Complete\n");
}

#$dbq_getLookupTablePeers->finish;
$dbq_getOutageDays->finish;

#$dbq_OutageInfoCheck->finish;
#$dbq_OutageInfo->finish;
#$dbq_getPingOutage->finish;
#$dbq_getLookupTable->finish;

$dbh->disconnect
  or warn "Error disconnecting: $DBI::errstr\n";

email("OutageInfo: Finished pushing OutageInfo\n");
