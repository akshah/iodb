#!/usr/bin/perl  
#Author: Anant Shah, Colorado State University
#akshah@rams.colostate.edu

#Insert Ping data from ISI into database

use strict;   # Load strict module for increased syntax checking
use DBI;      # Load the DBI module for connection to mysql database (or others)
#use Time::gmtime;  
use Time::Local;
use POSIX qw/strftime/;
use NetAddr::IP
  ;    # Load NetAddr::IP module used to work with and convert ip addresses
use Getopt::Long;    # Load GetOpt::Std to parse command line arguments
use Net::IP::LPM;
use Data::Validate::IP qw(is_ipv4);
use Geo::IP;

my $gi =
  Geo::IP->open( "/usr/local/share/GeoIP/GeoIPCity.dat", GEOIP_STANDARD );


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


my $start_epoch;
sub to_timestamp {
    my ($round)     = @_;
    my $time        = $start_epoch + ( 663 * $round );
    return $time;
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

### DataSet table --> information about the file being imported (DataSetID,FromFile,Descr,ImportDate,CollectDate)

my $dbq_DataSet =
  $dbh->prepare_cached("INSERT INTO DataSet VALUES(NULL,?,?,UTC_TIMESTAMP(),?)")
  or die "Can't prepare SQL statement: $DBI::errstr\n";
my $dbq_GeoID =
  $dbh->prepare_cached("SELECT GeoID FROM GeoInfo WHERE IP = ?")
  or die "Can't prepare SQL statement: $DBI::errstr\n";    
my $dbq_DataSetID =
  $dbh->prepare_cached("SELECT ID FROM DataSet WHERE FromFile = ?")
  or die "Can't prepare SQL statement: $DBI::errstr\n";    
my $dbq_GeoInfo =
  $dbh->prepare_cached("INSERT INTO GeoInfo VALUES(NULL,?,?,?,?,?,?)")
  or die "Can't prepare SQL statement: $DBI::errstr\n";
my $dbq_PingOutage =
  $dbh->prepare_cached("INSERT INTO PingOutage VALUES(NULL,?,?,?,?,?,?,?)")
  or die "Can't prepare SQL statement: $DBI::errstr\n";
my $dbq_CheckDataSet = $dbh->prepare_cached(
"SELECT ID FROM DataSet where FromFile = ?"
) or die "Can't prepare SQL statement: $DBI::errstr\n";

my $lpm_block = Net::IP::LPM->new();
$lpm_block->add( '0.0.0.0/0', 'default' );

#initialize global variables

my $DataSetID_insert = -1;  #used to store DataSetID inserted into DataSet table
my $count            = 0;   #count number of $FILES processed

my $date = `date`;
my $pwd  = `pwd`;
chomp($pwd);
$pwd =~ s/\//-/g;           #replace / with _
chomp($date);               #takes off trailing newline if necessary

my @currfiles = glob("pings.*");

### process the data (insert into database)
#open my $FILES, "ls |";
#while (<$FILES>) {
foreach my $thisfile (@currfiles) {
    chomp($thisfile);              #remove whitespace characters at end of filename
    $thisfile =~ s/\s+/\\ /g;      #escape space for the shell

    my $originalFilename = $thisfile;
    #File name must of format: pings.isi-ant.X.YYYY.MM.DD.hh.mm.ss
    #Where X is either w,j,c
    #obtain DataSet info
    my $Descr = "ISI-ANT Ping Data";

    my @split_name  = split( '\.', $originalFilename );
    
    my $SourceName  = $split_name[1];
    my $vantage = uc($split_name[2]);
    my $year = $split_name[3];
    my $month= $split_name[4];
    my $day= $split_name[5];
    my $hour= $split_name[6];
    my $min= $split_name[7];
    my $sec= $split_name[8];
    
    $start_epoch = timegm($sec,$min,$hour,$day,$month-1,$year);
    my $CollectDate = $split_name[3].$split_name[4].$split_name[5];
    if ( $CollectDate =~ /:0$/ ) {    #ends with :0
        $CollectDate .= "0";          #add trailing zero for DATETIME format
    }

    ### insert DataSet info
    $dbq_CheckDataSet->execute($originalFilename);
    my @res_for_dataset_check=$dbq_CheckDataSet->fetchrow_array;
    if($res_for_dataset_check[0]){
        print("$originalFilename already exists\n");
        next; #This dataset already exists in the database
    }else{
        $dbq_DataSet->execute( $originalFilename, $Descr, $CollectDate );    
    }
 

    #get the auto-incremented DataSetID that was inserted 
    $dbq_DataSetID->execute($originalFilename);
    my @res_ds_id=$dbq_DataSetID->fetchrow_array;
    $DataSetID_insert=$res_ds_id[0];
    my $lineNum = 1;
    my $PING_DATA_FILE;
    open $PING_DATA_FILE, "cat $originalFilename|" or die "cannot pipe from cat: $!";

    #To read all blocks first
    my @blockaddresses;

    #	print "Creating BlockAddr Trie\n";
    while (<$PING_DATA_FILE>) {
        chomp($_);

        #split line into variables seperated by a '|'
        (
            my $Block, 
            my $NumRounds,
            my $Density,
            my $Outage
        ) = split( /\|/, $_ );
        my $bprefix = NetAddr::IP->new( $Block . '/24' );
        push( @blockaddresses, $bprefix );

    }    #end while (<$PING_DATA_FILE>)
    print "Compacting\n";
    my @compacted = NetAddr::IP::compact(@blockaddresses);
    foreach my $in (@compacted) {
        $lpm_block->add( $in, $in );
    }
    close $PING_DATA_FILE;

    open $PING_DATA_FILE, "cat $originalFilename|" or die "cannot pipe from cat: $!";

    print "Creating Data to Feed in\n";

    my $lpm;
    my $o_st_yr = '1999-10-24';    #Some initial value that will not match
    while (<$PING_DATA_FILE>) {

        #print "In loop of while\n";
        chomp($_);

        #split line into variables seperated by a '|'
        (
            my $Block,
            my $NumRounds,
            my $Density,
            my $Outage
        ) = split( /\|/, $_ );

        #GeoInfo of this IPBlock   
        $dbq_GeoID->execute($Block);    #check database for geoid
        my @result = $dbq_GeoID->fetchrow_array;
        if ( !$result[0] ) {             #not found id in database
           my $record = $gi->record_by_addr($Block);
            if ( defined $record ) {
                $dbq_GeoInfo->execute( $Block, $record->country_code,
                    $record->region, $record->city, $record->latitude,
                    $record->longitude );
            }
        }
        
        my @Outage_array = split( ";", $Outage );

        #print "Looping for each outage for a block\n";
        foreach my $rds (@Outage_array) {
            my ( $st, $ed ) = split( "-", $rds );
            my $start = to_timestamp($st);
            my $end   = to_timestamp($ed);

            #format to DATETIME format for insertion into the mysql database
            #my $tm = gmtime($start);
            #$start = sprintf(
            #    "%04d-%02d-%02d %02d:%02d:%02d",
            #    $tm->year + 1900,
            #    $tm->mon + 1,
            #    $tm->mday, $tm->hour, $tm->min, $tm->sec
            #);

my @c_time = gmtime($start);

my $Y  = scalar strftime( "%Y", @c_time );
my $M = scalar strftime( "%m", @c_time );
my $h = scalar strftime( "%H", @c_time );
my $m = scalar strftime( "%M", @c_time );
my $D = scalar strftime( "%d", @c_time );
my $s = scalar strftime( "%S", @c_time );
$start = sprintf(
                "%04d-%02d-%02d %02d:%02d:%02d",
                $Y,
                $M,
                $D, $h, $m, $s
            );



            #my $tm = gmtime($end);
            #$end = sprintf(
            #    "%04d-%02d-%02d %02d:%02d:%02d",
            #    $tm->year + 1900,
             #   $tm->mon + 1,
              #  $tm->mday, $tm->hour, $tm->min, $tm->sec
            #);

@c_time = gmtime($end);

 $Y  = scalar strftime( "%Y", @c_time );
 $M = scalar strftime( "%m", @c_time );
 $h = scalar strftime( "%H", @c_time );
 $m = scalar strftime( "%M", @c_time );
 $D = scalar strftime( "%d", @c_time );
 $s = scalar strftime( "%S", @c_time );
$end = sprintf(
                "%04d-%02d-%02d %02d:%02d:%02d",
                $Y,
                $M,
                $D, $h, $m, $s
            );



            my $BlockAggr = $lpm_block->lookup($Block);

            $dbq_PingOutage->execute( $DataSetID_insert,$vantage,$Block . '/24', $Density, $BlockAggr, $start,
                $end );
        }
      
        $lineNum++;
    }    #end while (<$PING_DATA_FILE>)

    #increment counter (number of $FILES processed)
    $count++;

    # close and zip file back to its originalFilename
    close $PING_DATA_FILE;

    
} #processed all $FILES
#close $FILES;


### Disconnect from the database
$dbq_DataSet->finish;
$dbq_CheckDataSet->finish;
$dbq_DataSetID->finish;
$dbq_GeoInfo->finish;
$dbq_PingOutage->finish;

$dbh->disconnect
  or warn "Error disconnecting: $DBI::errstr\n";

email("InsertPings: $count files processed\n\n");
