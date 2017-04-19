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
    $database_name = "iodb2";
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

my $dbq_getPingOutage =
  $dbh->prepare_cached(
"SELECT unix_timestamp(OutageStart),unix_timestamp(OutageEnd) from PingOutage"
  ) or die "Can't prepare SQL statement: $DBI::errstr\n";


my $numentries=0;
$dbq_getPingOutage->execute();
while ( my @row = $dbq_getPingOutage->fetchrow_array ) { 

    #Basic OutageInfo
    #print("Got OutageInfo\n");
    my $OutageStart = $row[0];
    my $OutageEnd   = $row[1];
   
    #print("Got PingOutages\n");
    #Calculate duration of the outage
    my $Duration = $OutageEnd - $OutageStart;
    print("$Duration\n");

}


$dbq_getPingOutage->finish;

$dbh->disconnect
  or warn "Error disconnecting: $DBI::errstr\n";

