#!/usr/bin/perl
#
use Net::IP::LPM;
 
use strict; # Load strict module for increased syntax checking
use DBI; # Load the DBI module for connection to mysql database (or others)
use Time::localtime; # Load Time::localtime module used to convert dates and times
use NetAddr::IP; # Load NetAddr::IP module used to work with and convert ip addresses
use Getopt::Long; # Load GetOpt::Std to parse command line arguments

my $hostname;
my $username;
my $password;
my $database_name;
my $error_log;
if(@ARGV > 0) {
	GetOptions('h|hostname=s' => \$hostname,
		'u|user=s' => \$username,
		'p|password=s' => \$password,
		'db|database_name=s' => \$database_name,
		'e|error_log=s' => \$error_log
	);
}

#defaults
if(! defined $hostname) {
	$hostname = "proton.netsec.colostate.edu";
}
if(! defined $username) {
	$username = "root";
}
if(! defined $password) {    
	$password = "n3ts3cm5q1";
}
if(! defined $database_name) {    
	$database_name = "bgpdata";
}
if(! defined $error_log) {
	`touch /tmp/error_log`;
	$error_log = "/tmp/error_log";
}

print "making connection to database named $database_name on $hostname with user: $username and password: $password\n" ;

#connect to mysql database
my $dbh = DBI->connect( "dbi:mysql:$database_name:$hostname", $username, $password, {
		PrintError => 1,
		RaiseError => 0
	} ) or die "Can't connect to the database: $DBI::errstr\n";

### Prepare SQL statements ###

my $sth_getLookupTable = $dbh->prepare_cached("SELECT * FROM LookupTable") or die "Can't prepare SQL statement: $DBI::errstr\n"; ### ? --> '?'

$sth_getLookupTable->execute();

my $lpm = Net::IP::LPM->new();
$lpm->add('0.0.0.0/0', 'default');
while ( my ($PrefixID, $IP, $PrefixMask) = $sth_getLookupTable->fetchrow_array()) {
	my $slash_noted_prefix=$IP."/".$PrefixMask;
 $lpm->add($slash_noted_prefix,$slash_noted_prefix);
}
print $lpm->lookup('1.1.0.0'),"\n";
