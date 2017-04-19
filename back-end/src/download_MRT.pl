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

use constant RV_RIB_URL =>
  "http://archive.routeviews.org/COLLECTOR/bgpdata/YEAR.MONTH/RIBS";
use constant RV_UPDATE_URL =>
  "http://archive.routeviews.org/COLLECTOR/bgpdata/YEAR.MONTH/UPDATES";
use constant FALSE => 0;
use constant TRUE  => 1;

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

sub download_file {
    my ( $d_url, $loc ) = @_;
    my $retval = LWP::Simple::getstore( $d_url, $loc );
    if ( LWP::Simple::is_error($retval) ) {
        return FALSE;
    }
    return TRUE;
}

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

#Dont even download the files that are already in the database
my $dbq_getDatasetFileNames =
  $dbh->prepare_cached("SELECT FromFile FROM DataSet;")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

$dbq_getDatasetFileNames->execute();
my @files_already_in_db = $dbq_getDatasetFileNames->fetchrow_array;

#============================================

sub to_time {
    my $epoch  = $_[0];
    my @c_time = gmtime($epoch);

    my $by = scalar strftime( "%Y", @c_time );
    my $bm = scalar strftime( "%m", @c_time );
    my $bh = scalar strftime( "%H", @c_time );
    my $bd = scalar strftime( "%d", @c_time );

    my $time = sprintf( "%04d-%02d-%02d-%02d", $by, $bm, $bd, $bh );
    return $time;

}

my $dbq_getOutage = $dbh->prepare(
"SELECT DATE_FORMAT(OutageStart,'%Y:%m:%d:%H'),DATE_FORMAT(OutageEnd,'%Y:%m:%d:%H') from PingOutage;"
) or die "Can't prepare SQL statement: $DBI::errstr\n";
$dbq_getOutage->{"mysql_use_result"} = 1;
email("Resolving outage times");
$dbq_getOutage->execute();
my $num_dates = 0;
while ( my @uniq_dates = $dbq_getOutage->fetchrow_array ) {
    
    my ( $sy, $sm, $sd, $sh ) = split( ':', $uniq_dates[0] );
    my ( $ey, $em, $ed, $eh ) = split( ':', $uniq_dates[1] );

    my $start = sprintf( "%04d-%02d-%02d-%02d", $sy, $sm, $sd, $sh );
    my $end   = sprintf( "%04d-%02d-%02d-%02d", $ey, $em, $ed, $eh );

    my $start_epoch = timegm( 0, 0, $sh, $sd, $sm - 1, $sy );
    my $end_epoch   = timegm( 0, 0, $eh, $ed, $em - 1, $ey );

    my $before_epoch = $start_epoch - ( 3600 * 2 );
    my $after_epoch = $end_epoch + ( 3600 * 2 );

    #print("$before_epoch $start_epoch $after_epoch\n");
    #print("$start to $end:  ");
    my $download_epoch = $before_epoch;
    while ( $download_epoch <= $after_epoch ) {
        my $tmp_time = to_time($download_epoch);
        get_ttime_file($tmp_time);
        print($tmp_time,"\n");
        $download_epoch = $download_epoch + 3600;    #Increament by an hour
    }

}

#Download UPDATES +/- 2 hours
#Download RIBS 1 per day

sub get_ttime_file {
    my $t_time = shift;

    #for my $t_time (@update_file_to_be_downloaded) {
    ( $year, $month, $day, $hour ) = split( '-', $t_time );

    #  my $tr_time = $year . '-' . $month . '-' . $day;
    dMRT( $year, $month, $day, $hour, 'UPDATES' );

    #  if ( !( $tr_time ~~ @rib_file_to_be_downloaded ) ) {
    #     push( @rib_file_to_be_downloaded, $tr_time );
    #    ( $year, $month, $day ) = split( '-', $tr_time );
    dMRT( $year, $month, $day, '00', 'RIBS' );

    #}

}

sub dMRT {
    my $year  = $_[0];
    my $month = $_[1];
    my $day   = $_[2];
    my $hour  = $_[3];
    my $type  = $_[4];

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

        my $url = "";
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

            #print STDERR "Error downloading index file from $url.\n";
            #exit(0);
            next;
        }
        my @r_index_lines = read_file($this_index_file);

        # Download Files
        foreach my $line ( reverse @r_index_lines ) {
            if ( $line =~ /a href="(.*?bz2)"/ ) {
                my $file = $1;

                #Filter on date
                if ( $file =~ /$year$month$day.$hour/ ) {
                    my $new_name =
                      $type . '/' . $collectorsabbvr{$collector} . '/' . $file;

                    #Check if this file was downloaded before.
                    if ( -e $new_name ) {
                        next;    #Skip this file
                    }
                    print "FILE: $url/$file\n";
                    if ( $type eq "RIBS" ) {
                        $new_name =~ s/rib/rib.$collectorsabbvr{$collector}/g;
                    }
                    else {
                        $new_name =~
                          s/updates/updates.$collectorsabbvr{$collector}/g;
                    }
                    if ( $new_name ~~ @files_already_in_db ) {

                        #Repeated dataset, don't download
                    }
                    else {
                        if ( download_file( "$url/$file", "$new_name" ) ==
                            FALSE )
                        {
                           #print STDERR "Error downloading file $url/$file.\n";
                            next;
                        }
                    }

                }
            }
        }
        unlink($this_index_file);
    }

}

$dbq_getOutage->finish;
$dbq_getDatasetFileNames->finish;
$dbh->disconnect
  or warn "Error disconnecting: $DBI::errstr\n";
email("Finished Downloading MRT files");
