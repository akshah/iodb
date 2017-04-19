#!/usr/bin/perl
#Generic script
#Script to Download Routeviews update files from various collectors
#Reads year month day hour from command line and downloads it from all collectors in @collectors

#Anant Shah

use strict;
use warnings;

use LWP::Simple;
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
use constant TRUE  => 1;

# Global config variables.
#Defaults

my $collector = "route-views2";
my $year      = "2014";
my $month     = "02";
my $day       = "01";
my $hour      = "0000";
my $type      = "RIBS";
my $r_url     = RV_RIB_URL;
my $u_url     = RV_UPDATE_URL;
my $verbose;
my $curr_dir_path = "";

# List of all routeviews collectors.
# Only collectors with v4
my @collectors = qw(route-views2 route-views4
  route-views.isc route-views.kixp route-views.jinx
  route-views.linx route-views.telxatl
  route-views.wide route-views.sydney route-views.saopaulo);

#Test
#my @collectors = qw(route-views2);

my %collectorsabbvr;
$collectorsabbvr{'route-views2'}         = 'rv2';
$collectorsabbvr{'route-views4'}         = 'rv4';
$collectorsabbvr{'route-views6'}         = 'rv6';
$collectorsabbvr{'route-views.isc'}      = 'isc';
$collectorsabbvr{'route-views.eqix'}     = 'eqix';
$collectorsabbvr{'route-views.kixp'}     = 'kixp';
$collectorsabbvr{'route-views.jinx'}     = 'jinx';
$collectorsabbvr{'route-views.linx'}     = 'linx';
$collectorsabbvr{'route-views.telxatl'}  = 'telxatl';
$collectorsabbvr{'route-views.wide'}     = 'wide';
$collectorsabbvr{'route-views.sydney'}   = 'sydney';
$collectorsabbvr{'route-views.saopaulo'} = 'saopaulo';

#---- MAIN ----

parse_command_line();
$type=uc($type);
foreach $collector (@collectors) {

    my $r_url = RV_RIB_URL;
    my $u_url = RV_UPDATE_URL;

    # The URL for route-views2 does not have the collector name in the URL.
    # For every other collector, set the right name in the URL.
    if ( $collector eq 'route-views2' ) {
        $r_url =~ s/COLLECTOR//;
        $u_url =~ s/COLLECTOR//;
    }
    else {
        $r_url =~ s/COLLECTOR/$collector/g;
        $u_url =~ s/COLLECTOR/$collector/g;
    }

    $r_url =~ s/YEAR/$year/;
    $r_url =~ s/MONTH/$month/;
    $u_url =~ s/YEAR/$year/;
    $u_url =~ s/MONTH/$month/;

    my $url="";
    if ( $type eq "RIBS" ) {
        $url = $r_url;
    }
    elsif ( $type eq "UPDATES" ) {
        $url = $u_url;
    }
    else {
        usage();
    }

    # Download the index file for the updates.
    print "Collector: ", $collector, "\n";
    my $this_index_file =
      "$collectorsabbvr{$collector}.$year.$month.$day.$hour.index.html";
    if ( download_file( $url, $this_index_file ) == FALSE ) {
        print STDERR "Error downloading index file from $url.\n";
        exit(0);
    }
    my @r_index_lines = read_file($this_index_file);

    # Download Files
    foreach my $line ( reverse @r_index_lines ) {
        if ( $line =~ /a href="(.*?bz2)"/ ) {
            my $file = $1;

            #Filter on date
            if ( $file =~ /$year$month$day.$hour/ ) {
                my $new_name = $file;
                print "FILE: $url/$file\n";
                if($type eq "RIBS"){
                    $new_name =~ s/rib/rib.$collectorsabbvr{$collector}/g;    
                }else{
                    $new_name =~ s/updates/updates.$collectorsabbvr{$collector}/g;    
                }
                if ( download_file( "$url/$file", "$new_name" ) == FALSE ) {
                    print STDERR "Error downloading file $url/$file.\n";
                    next;
                }
            }
        }
    }
    unlink($this_index_file);
}

#---- END MAIN ----

#---- SUBROUTINES ----

sub usage {
    print "USAGE: \nperl $0 -year YYYY -month MM -day DD -hour HH -type RIBS/UPDATES\n";
    exit(0);
}

sub parse_command_line {
    my $result = GetOptions(
        "year=s"  => \$year,
        "month=s" => \$month,
        "day=s"   => \$day,
        "hour=s"  => \$hour,
        "type=s"  => \$type,
        "help"    => \&usage,
        "v"       => \$verbose
    );
    unless ($result) {
        usage();
    }

}

sub download_file {
    my ( $d_url, $loc ) = @_;
    my $retval = LWP::Simple::getstore( $d_url, $loc );
    if ( LWP::Simple::is_error($retval) ) {
        return FALSE;
    }
    return TRUE;
}
