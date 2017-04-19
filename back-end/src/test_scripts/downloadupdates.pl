#!/usr/bin/perl
#Script to Download Routeviews update files from various collectors
#Modified from Kautubh's routeviews2xml script

use strict;
use warnings;
use LWP::Simple;
use IO::Uncompress::Bunzip2 qw(bunzip2 $Bunzip2Error);
use Getopt::Long;
use File::Slurp qw/read_file/;
use File::Basename;
use File::Copy qw/move/;
use File::Path qw/make_path/;


use constant RV_RIB_URL =>
"http://archive.routeviews.org/COLLECTOR/bgpdata/YEAR.MONTH/RIBS";
use constant RV_UPDATE_URL =>
"http://archive.routeviews.org/COLLECTOR/bgpdata/YEAR.MONTH/UPDATES";
use constant FALSE => 0;
use constant TRUE => 1;

# Global config variables.
my $peer_out_dir = "peers/";
my $date_out_dir = "date/";
my $collector = "route-views2";
my $year = "2014";
my $month = "09";
my $day = "01";
my $r_url = RV_RIB_URL;
my $u_url = RV_UPDATE_URL;
my $verbose;
my $curr_dir_path = "";


# List of all routeviews collectors.
# Only collectors with v4
#my @collectors = qw(route-views2 route-views4
#route-views.isc route-views.kixp route-views.jinx
#route-views.linx route-views.telxatl
#route-views.wide route-views.sydney route-views.saopaulo);

my @collectors = qw(route-views4
route-views.isc route-views.kixp route-views.jinx
route-views.linx route-views.telxatl
route-views.wide route-views.sydney route-views.saopaulo);


my %collectorsabbvr;
$collectorsabbvr{'route-views2'}='rv2';
$collectorsabbvr{'route-views4'}='rv4';
$collectorsabbvr{'route-views.isc'}='isc';
$collectorsabbvr{'route-views.kixp'}='kixp';
$collectorsabbvr{'route-views.jinx'}='jinx';
$collectorsabbvr{'route-views.linx'}='linx';
$collectorsabbvr{'route-views.telxatl'}='telxatl';
$collectorsabbvr{'route-views.wide'}='wide';
$collectorsabbvr{'route-views.sydney'}='sydney';
$collectorsabbvr{'route-views.saopaulo'}='saopaulo';




#---- MAIN ----

parse_command_line();


foreach $collector (@collectors){

my $r_url = RV_RIB_URL;
my $u_url = RV_UPDATE_URL;

# The URL for route-views2 does not have the collector name in the URL.
# For every other collector, set the right name in the URL.
	if ($collector eq 'route-views2') {
		$r_url =~ s/COLLECTOR//;
		$u_url =~ s/COLLECTOR//;
	} else {
		$r_url =~ s/COLLECTOR/$collector/g;
		$u_url =~ s/COLLECTOR/$collector/g;
	}

	$r_url =~ s/YEAR/$year/;
	$r_url =~ s/MONTH/$month/;
	$u_url =~ s/YEAR/$year/;
	$u_url =~ s/MONTH/$month/;

# Download the index file for the updates.
	print "Collector: ",$collector,"\n";
	if (download_file($u_url, "$collectorsabbvr{$collector}.$day.index.html") == FALSE) {
		print STDERR "Error downloading index file from $u_url.\n";
		exit(0);
	}
	my @u_index_lines = read_file("$collectorsabbvr{$collector}.$day.index.html");

# Download Files
	foreach my $line (reverse @u_index_lines) {
		if ($line =~ /a href="(.*?bz2)"/) {
			my $file = $1;
			#Filter on date
			if($file =~ /$year$month$day/){
				my $new_name=$file;
				print "FILE: $u_url$file\n";
				$new_name=~s/updates/updates.$collectorsabbvr{$collector}/g;
				if (download_file("$u_url/$file", "$new_name") == FALSE) {
					print STDERR "Error downloading file $u_url/$file.\n";
					next;
				}
			}
#        process_file("/tmp/$file", 0);
		}
	}
	unlink("$collectorsabbvr{$collector}.$day.index.html");
}
#---- END MAIN ----

#---- SUBROUTINES ----

# Print a usage message.
# Input: None
# Output: Usage message
# Kaustubh Gadkari Apr 2014
sub usage {
	print "This script downloads a routeviews archive for a given YYYY.MM.\n";
	print "Usage: $0 [-year YYYY] [-month MM]
	[-peer_out_dir /path/to/peer/files] [-date_out_dir /path/to/date/files]
	[-help] [-v]\n";
	exit(0);
}

# Parse the command line and set the appropriate options.
# Input: None
# Output: None
# Kaustubh Gadkari Apr 2014
sub parse_command_line {
	my $result = GetOptions("year=s" => \$year,
		"month=s" => \$month,
		"day=s" => \$day,
		"help" => \&usage,
		"peer_out_dir=s" => \$peer_out_dir,
		"date_out_dir=s" => \$date_out_dir, 
		"v" => \$verbose);
	unless ($result) {
		usage();
	}

}
sub download_file {
	my ($url, $loc) = @_;
	my $retval = LWP::Simple::getstore($url, $loc);
	if (LWP::Simple::is_error($retval)) {
		return FALSE;
	}
	return TRUE;
}
