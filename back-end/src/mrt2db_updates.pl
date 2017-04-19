#!/usr/bin/perl
#Author: Anant Shah, Colorado State University
#Original Author: Todd Deshane, Clarkson University

use strict;   # Load strict module for increased syntax checking
use DBI;      # Load the DBI module for connection to mysql database (or others)
use Time::gmtime;    # Load Time::gmtime module used to convert dates and times
use NetAddr::IP
  ;    # Load NetAddr::IP module used to work with and convert ip addresses
use Getopt::Long;    # Load GetOpt::Std to parse command line arguments
use Email::MIME;
use Data::Validate::IP qw(is_ipv4);
use Email::Sender::Simple qw(sendmail);

my $hostname;
my $username;
my $password;
my $database_name;
my $error_log;
my $current_file;

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
    $error_log = "/tmp/error_log";
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

#my $dbq_Message = $dbh->prepare_cached(
#    "INSERT INTO Message VALUES(NULL,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)")
#  or die "Can't prepare SQL statement: $DBI::errstr\n";


my $dbq_ASPath = $dbh->prepare_cached("INSERT INTO ASPath VALUES(NULL,?)")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_getCommunityID =
  $dbh->prepare_cached("SELECT CommunityID FROM Community WHERE Community = ?")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_MsgPath =
  $dbh->prepare_cached("INSERT INTO MsgPath VALUES(NULL,?,?,?,?)")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_IPTable = $dbh->prepare_cached("INSERT INTO IPTable VALUES(NULL,?,?)")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_IPID = $dbh->prepare_cached("SELECT id FROM IPTable WHERE ip = ?")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_getMsgPathID =
  $dbh->prepare_cached("SELECT ASPathID FROM ASPath WHERE ASPath = ?")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_Community = $dbh->prepare_cached("INSERT INTO Community VALUES(NULL,?)")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_CheckDataSet =
  $dbh->prepare_cached( "SELECT ID FROM DataSet where FromFile = ?" )
  or die "Can't prepare SQL statement: $DBI::errstr\n";


#initialize global variables
my $MsgID_insert     = -1;  #used to store MsgID inserted into Message table
my $DataSetID_insert = -1;  #used to store DataSetID inserted into DataSet table
my $count            = 0;   #count number of $FILES processed
my $numMessages      = 0;   #count number of messages processed
my $pointer_PeerIP   = 0;
my @IP_cache_PeerIP;        #cache most recently used ip addressed
my @ID_cache_PeerIP;        #cache most recently used id's associated with ip's
my $pointer_NextHop = 0;
my @IP_cache_NextHop;       #cache most recently used ip addressed
my @ID_cache_NextHop;       #cache most recently used id's associated with ip's
my $pointer_AggregateIP = 0;
my @IP_cache_AggregateIP;    #cache most recently used ip addressed
my @ID_cache_AggregateIP;    #cache most recently used id's associated with ip's

my $dbq_LockTables = $dbh->prepare("LOCK TABLES Message READ")
  or die "Can't prepare SQL statement: $DBI::errstr\n";
my $dbq_UnlockTables = $dbh->prepare("UNLOCK TABLES")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

#my $dbq_GetMaxMsgID =
#  $dbh->prepare("SELECT MAX(MsgID) FROM Message WHERE MsgType = 'A'")
#  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $dbq_CountMessages = $dbh->prepare("SELECT COUNT(*) FROM Message")
  or die "Can't prepare SQL statement: $DBI::errstr\n";

my $MsgPathID   = 0;    #MsgPath table id to put in message table
my $CommunityID = 0;    #Community table id to put in message table

$dbq_CountMessages->execute;
my @count_result  = $dbq_CountMessages->fetchrow_array;
my $message_count = $count_result[0];

print "current message count: $message_count\n";

my $MSG_TYPE_ERROR     = 0;
my $AS_PATH_ERROR      = 0;
my $MSG_TIME_ERROR     = 0;
my $PEER_IP_ERROR      = 0;
my $PEER_AS_ERROR      = 0;
my $PREFIX_ERROR       = 0;
my $PREFIXMASK_ERROR   = 0;
my $NEXTHOP_ERROR      = 0;
my $MED_ERROR          = 0;
my $AGGREGATE_IP_ERROR = 0;

for ( my $index = 0 ; $index < 5 ; $index++ ) {
    $IP_cache_PeerIP[$index]      = "-1";
    $ID_cache_PeerIP[$index]      = "-1";
    $IP_cache_NextHop[$index]     = "-1";
    $ID_cache_NextHop[$index]     = "-1";
    $IP_cache_AggregateIP[$index] = "-1";
    $ID_cache_AggregateIP[$index] = "-1";
}
my $date = `date`;
my $pwd  = `pwd`;
chomp($pwd);
$pwd =~ s/\//-/g;    #replace / with _
chomp($date);        #takes off trailing newline if necessary

#open error log file
open( my $ERROR_LOG, ">$error_log\_starting_dir-$pwd\_$date" )
  or die("can't open $error_log\_$pwd\_$date: $!");

my @mrtfiles = glob("*.bz2");

#opendir (my $DIR, '.') or die $!;
### process the data (insert into database)
#open my $FILES, "ls |" or die("can't list files - ls");

#while (<$FILES>) {
#while (my $thisfile = readdir($DIR)) {
#     #my $thisfile=$_;
#     if($thisfile == "."){
#         next;
#     }

foreach my $thisfile (@mrtfiles) {

    chomp($thisfile);    #remove whitespace characters at end of filename

    $thisfile =~ s/\s+/\\ /g;    #escape space for the shell

    #store filename with and without .gz extension
    my $originalFilename = $thisfile;
    $current_file = $originalFilename;
    my $newFilename = $originalFilename;
    $newFilename =~ s/\.bz2$//;
    
    #obtain DataSet info
    my $Descr = "RouteViews Data UPDATES";

    my @split_name  = split( '\.', $newFilename );
    my $CollectDate = $split_name[2];
    my $SourceName  = $split_name[1];

    if ( $CollectDate =~ /:0$/ ) {    #ends with :0
        $CollectDate .= "0";          #add trailing zero for DATETIME format
    }

    ### insert DataSet info
    $dbq_CheckDataSet->execute($originalFilename);
    my @res_for_dataset_check = $dbq_CheckDataSet->fetchrow_array;
    if ( $res_for_dataset_check[0] ) {

        #print("$originalFilename already exists\n");
        next;    #This dataset already exists in the database
    }
    else {
        $dbq_DataSet->execute( $originalFilename, $Descr, $CollectDate );

       #email("Inserting $originalFilename");
       #get the auto-incremented DataSetID that was inserted (for message table)
        $DataSetID_insert = $dbh->{mysql_insertid};
    }
    
    my $bucket_file_name = $newFilename . "_BUCKET";
    open( my $BUCKET, ">>", $bucket_file_name )
      or die("can't open $bucket_file_name: $!");
    
    
    #Start transaction
    #$dbh->do("BEGIN");
    

    #process machine-readable (-m) output of bgpdump
    my $lineNum = 1;
    open my $BGP_DATA_FILE,
      "sudo nice -n -20 /usr/local/bin/bgpdump -m $originalFilename |"
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

      #Check all fields that are supposed to be not null or if peer is v6 ignore
        if (
               $MsgTime == ""
            or $PeerIP == ""
            or $prefix_combo =~ /:/    #Skip v6 prefix
            or $prefix_combo == ""
          )
        {
            next;
        }

        #Check if PeerIP is v4, if not then skip this v6 address
        if ( !is_ipv4($PeerIP) ) {
            next;
        }

### data from merit LocalPref always 0 so far #################################
        if ( defined $LocalPref ) {
            if ( $LocalPref != 0 ) {
                print $ERROR_LOG
"LocalPref not 0, in $newFilename on line $lineNum LocalPref: $LocalPref\n";
            }
        }
### determine BGP Protocol version and store id ###############################
        my $BGPVersionID;    #id to store in message table
        if ( $BGPVersion eq "BGP" ) {
            $BGPVersionID = 1;
        }
        elsif ( $BGPVersion eq "BGP4" ) {
            $BGPVersionID = 2;
        }
        elsif ( $BGPVersion eq "BGP4MP" ) {
            $BGPVersionID = 3;
        }
        else {               #BGPVersion is not BGP,BGP4 nor BGP4MP
            $BGPVersionID = 4;    #error
        }
### convert seconds since epoch (jan 1 1970) to DATETIME ######################
        #format MsgTime to DATETIME format for insertion into the mysql database
        my $tm = gmtime($MsgTime);
        $MsgTime = sprintf(
            "%04d-%02d-%02d %02d:%02d:%02d",
            $tm->year + 1900,
            $tm->mon + 1,
            $tm->mday, $tm->hour, $tm->min, $tm->sec
        );

### breakup Prefix i.e. 128.153.0.0/16 into IP and PrefixMask #################
        #split Prefix/PrefixMask pair
        ( my $Prefix, my $PrefixMask ) = split( /\//, $prefix_combo );

### Prefix ####################################################################
        ###check database (IPTable) for prefix i.e (128.153.0.0)
        my $PrefixID;
        if ($Prefix) {    #if Prefix has a value
            $dbq_IPID->execute($Prefix);    #check database for id
            my @result = $dbq_IPID->fetchrow_array;
            if ( $result[0] ) {             #found id in database
                $PrefixID = $result[0];
            }
            else {                          #ip wasn't already there
                    #convert Prefix to unsigned int and insert
                my $Prefix_ipval = new NetAddr::IP($Prefix);
                $Prefix_ipval = $Prefix_ipval->numeric();
                ###insert IP into IPTable
                $dbq_IPTable->execute( $Prefix_ipval, $Prefix );
                $PrefixID = $dbh->{mysql_insertid};
            }

            #PrefixID (int id) now set for Message table
        }
### PeerIP ####################################################################
        ###check database (IPTable) for PeerIP
        my $PeerIPID;    #variable to store PeerIP id for message table
        if ($PeerIP) {   #if PeerIP has a value
                         #check to see if IP (for PeerIP) already exists
                         #check in cache first
            my $i = 0;
            while ( $PeerIP ne $IP_cache_PeerIP[$i] && $i < 5 ) {
                $i++;
            }
            if ( $i < 5 ) {    #found ip in cache
                $PeerIPID = $ID_cache_PeerIP[$i];
            }
            else {             #not found in cache
                               #didn't find it in cache, check database
                $dbq_IPID->execute($PeerIP);
                my @result = $dbq_IPID->fetchrow_array;
                if ( $result[0] ) {    #found id in database
                    $PeerIPID                         = $result[0];
                    $ID_cache_PeerIP[$pointer_PeerIP] = $PeerIPID;    #cache id
                    $IP_cache_PeerIP[$pointer_PeerIP] = $PeerIP;      #cache ip
                }
                else {    #id not found in database
                          #convert PeerIP to unsigned int and insert
                    my $PeerIP_ipval = new NetAddr::IP($PeerIP);
                    $PeerIP_ipval = $PeerIP_ipval->numeric();
                    $dbq_IPTable->execute( $PeerIP_ipval, $PeerIP );
                    $PeerIPID = $dbh->{mysql_insertid};
                    $ID_cache_PeerIP[$pointer_PeerIP] = $PeerIPID;    #cache id
                    $IP_cache_PeerIP[$pointer_PeerIP] = $PeerIP;      #cache IP
                }
                if ( $pointer_PeerIP < 4 ) {
                    $pointer_PeerIP++;
                }
                else {    #pointer_PeerIP = 4
                    $pointer_PeerIP = 0;
                }
            }

            # PeerIPID (int id) now set for Message table
        }

        ###variables used for announcements
        my @asPathFields;
        my $new_path_flag = 1;
        my @communityFields;
        my $OriginID;        #variable to store Origin id for message table
        my $NextHopID;       #variable to store NextHop id for message table
        my $AggregateIPID;   #variable to store AggregateIP id for message table
        my $AggregateID;     #variable to store AggregateID id for message table
### announcement messages ####################################################
        if ( $MsgType eq "A" ) {    #announcement --> path announced
            $dbq_getMsgPathID->execute($asPath);
            my @as_res_id = $dbq_getMsgPathID->fetchrow_array;

            #print("$as_res_id[0]\n");
            if ( $as_res_id[0] ) {
                $MsgPathID     = $as_res_id[0];
                $new_path_flag = 0;
            }
            else {
                $dbq_ASPath->execute($asPath);
                $dbq_getMsgPathID->execute($asPath);
                @as_res_id = $dbq_getMsgPathID->fetchrow_array;
                $MsgPathID = $as_res_id[0];
            }

            $announce_flag = 1;    #set annouce flag
            if ($asPath) {         #if asPath has a value
                @asPathFields =
                  split( /\s+/, $asPath );    #break up asPath by spaces
            }
            else {
                print $ERROR_LOG
                  "error with aspath file: $newFilename on $lineNum\n";
            }
### deal with Origin #########################################################
            if ($Origin) {                    #if Origin has a value
                if ( $Origin eq "IGP" ) {
                    $OriginID = 1;
                }
                elsif ( $Origin eq "INCOMPLETE" ) {
                    $OriginID = 2;
                }
                elsif ( $Origin eq "EGP" ) {
                    $OriginID = 3;
                }
                else    #Origin not equal to "IGP","INCOMPLETE", nor "EGP"
                {
                    $OriginID = 4;    #ERROR (ERR in OriginTable)
                }
            }
### deal with atomic aggregate ##############################################
            if ($AggregateID) {       #if AggregateID has a value
                if ( $AggregateID eq "NAG" ) {
                    $AggregateID = 1;
                }
                elsif ( $AggregateID eq "AG" ) {
                    $AggregateID = 2;
                }
                else                  #AggregateID not equal to "NAG" nor "AG"
                {
                    $AggregateID = 3;    #ERROR (ERR in AggrTable)
                }
            }
### deal with NextHop #######################################################
            if ($NextHop) {              #if NextHop has a value
                    #check to see if IP (for NextHop) already exists
                    #check in cache first
                my $i = 0;
                while ( $NextHop ne $IP_cache_NextHop[$i] && $i < 5 ) {
                    $i++;
                }
                if ( $i < 5 ) {    #found ip in cache
                    $NextHopID = $ID_cache_NextHop[$i];
                }
                else {             #not found in cache
                                   #didn't find it in cache, check database
                    $dbq_IPID->execute($NextHop);
                    my @result = $dbq_IPID->fetchrow_array;
                    if ( $result[0] ) {    #found id in database
                        $NextHopID = $result[0];
                        $ID_cache_NextHop[$pointer_NextHop] =
                          $NextHopID;      #cache id
                        $IP_cache_NextHop[$pointer_NextHop] =
                          $NextHop;        #cache ip
                    }
                    else {                 #id not found in database
                            #convert NextHop to unsigned int and insert
                        my $NextHop_ipval = new NetAddr::IP($NextHop);
                        $NextHop_ipval = $NextHop_ipval->numeric();
                        $dbq_IPTable->execute( $NextHop_ipval, $NextHop );
                        $NextHopID = $dbh->{mysql_insertid};
                        $ID_cache_NextHop[$pointer_NextHop] =
                          $NextHopID;    #cache id
                        $IP_cache_NextHop[$pointer_NextHop] =
                          $NextHop;      #cache IP
                    }
                    if ( $pointer_NextHop < 4 ) {
                        $pointer_NextHop++;
                    }
                    else {               #pointer_NextHop = 4
                        $pointer_NextHop = 0;
                    }
                }

                #NextHopID (int id) now set for Message table
            }
### deal with aggregate IP ###################################################
            if ($AggregateIP) {          #if AggregateIP has a value
                    #check to see if IP (for AggregateIP) already exists
                    #check in cache first
                my ( $AggASN, $AggIP ) = split( ' ', $AggregateIP );
                $AggregateIP = $AggIP;
                my $i = 0;
                while ( $AggregateIP ne $IP_cache_AggregateIP[$i] && $i < 5 ) {
                    $i++;
                }
                if ( $i < 5 ) {    #found ip in cache
                    $AggregateIPID = $ID_cache_AggregateIP[$i];
                }
                else {             #not found in cache
                                   #didn't find it in cache, check database
                    $dbq_IPID->execute($AggregateIP);
                    my @result = $dbq_IPID->fetchrow_array;
                    if ( $result[0] ) {    #found id in database
                        $AggregateIPID = $result[0];
                        $ID_cache_AggregateIP[$pointer_AggregateIP] =
                          $AggregateIPID;    #cache id
                        $IP_cache_AggregateIP[$pointer_AggregateIP] =
                          $AggregateIP;      #cache ip

                    }
                    else {                   #id not found in database
                            #convert AggregateIP to unsigned int and insert
                        my $AggregateIP_ipval = new NetAddr::IP($AggregateIP);
                        $AggregateIP_ipval = $AggregateIP_ipval->numeric();
                        $dbq_IPTable->execute( $AggregateIP_ipval,
                            $AggregateIP );
                        $AggregateIPID = $dbh->{mysql_insertid};
                        $ID_cache_AggregateIP[$pointer_AggregateIP] =
                          $AggregateIPID;    #cache id
                        $IP_cache_AggregateIP[$pointer_AggregateIP] =
                          $AggregateIP;      #cache IP
                    }
                    if ( $pointer_AggregateIP < 4 ) {
                        $pointer_AggregateIP++;
                    }
                    else {                   #pointer_AggregateIP = 4
                        $pointer_AggregateIP = 0;
                    }
                }

                #AggregateIPID (int id) now set for Message table
            }
### set Community flag if exists ##############################################
            if ($Community) {                #Community has a value
                ###break up Communities into fields separated by space(s)
                #@communityFields = split( /\s+/, $Community );

                $community_flag = 1;    # set community flag
                $dbq_getCommunityID->execute($Community);
                my @comm_id = $dbq_getCommunityID->fetchrow_array;
                if ( $as_res_id[0] ) {
                    $CommunityID = $comm_id[0];

                }
                else {
                    $dbq_Community->execute($Community);
                    $dbq_getCommunityID->execute($Community);
                    @comm_id     = $dbq_getCommunityID->fetchrow_array;
                    $CommunityID = $comm_id[0];
                }

                ###insert Message info in Message table for this announcement
                chomp(
                    $DataSetID_insert, $BGPVersionID, $MsgType,
                    $MsgTime,          $PeerIPID,     $PeerAS,
                    $PrefixID,         $PrefixMask,   $MsgPathID,
                    $OriginID,         $NextHopID,    $Med,
                    $CommunityID,      $AggregateID,  $AggregateIPID
                );

                print $BUCKET "$DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,$MsgPathID,$OriginID,$NextHopID,$Med,$CommunityID,$AggregateID,$AggregateIPID\n";
                #$dbq_Message->execute($DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,$MsgPathID,$OriginID,$NextHopID,$Med,$CommunityID,$AggregateID,$AggregateIPID);
            }
            else {    #Community has no value
                ###insert Message info in Message table for this announcement
                chomp($DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,$MsgPathID,$OriginID,$NextHopID,$Med,$AggregateID,$AggregateIPID);
                print $BUCKET "$DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,$MsgPathID,$OriginID,$NextHopID,$Med,'NULL',$AggregateID,$AggregateIPID\n";
                #$dbq_Message->execute($DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,$MsgPathID,$OriginID,$NextHopID,$Med,'NULL',$AggregateID,$AggregateIPID);
            }
        }
### withdrawal message ########################################################
        elsif ( $MsgType eq "W" )    #withdrawl message
        {
            $asPath      = "NULL";
            $Origin      = "NULL";
            $NextHop     = "NULL";
            $LocalPref   = "NULL";
            $Med         = "NULL";
            $AggregateID = "NULL";
            $AggregateIP = "NULL";
            ###insert Message info in Message table
            
            chomp($DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,$OriginID,$NextHopID,$Med,$AggregateID,$AggregateIPID);
            print $BUCKET "$DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,0,$OriginID,$NextHopID,$Med,0,$AggregateID,$AggregateIPID\n";
            #$dbq_Message->execute($DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,0,$OriginID,$NextHopID,$Med,0,$AggregateID,$AggregateIPID);
        }
### state message #############################################################
        elsif ( $MsgType eq "STATE" )    #state message
        {
            $asPath      = "NULL";
            $Origin      = "NULL";
            $NextHop     = "NULL";
            $LocalPref   = "NULL";
            $Med         = "NULL";
            $AggregateID = "NULL";
            $AggregateIP = "NULL";
            $MsgType     = "S";
            ###insert Message info in Message table
            
            chomp($DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,$OriginID,$NextHopID,$Med,$AggregateID,$AggregateIPID);
            print $BUCKET "$DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,0,$OriginID,$NextHopID,$Med,0,$AggregateID,$AggregateIPID\n";
            #$dbq_Message->execute($DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,0,$OriginID,$NextHopID,$Med,0,$AggregateID,$AggregateIPID);
        }
        else {    #MsgType not a withdrawal, announcement nor state
            $MSG_TYPE_ERROR++;
        }

        #missing peices in $FILES (keep count of errors)
        if ( !defined $MsgTime ) { $MSG_TIME_ERROR++; }
        if ( !defined $PeerAS )  { $PEER_AS_ERROR++; }
        if ( !defined $Prefix )  { $PREFIX_ERROR++; }
        if ( ( !defined $PrefixMask ) && ( $MsgType ne "S" ) ) {
            $PREFIXMASK_ERROR++;
        }
        if ( !defined $NextHop )     { $NEXTHOP_ERROR++; }
        if ( !defined $Med )         { $MED_ERROR++; }
        if ( !defined $AggregateIP ) { $AGGREGATE_IP_ERROR++; }

### Deal with ASPATH ##########################################################

        if ($announce_flag) {
            if ($new_path_flag) {

                #initialize PathOrder and Alternative bit
                ###(PathOrder,Alternative) => (position of AS in ASPATH, alternative flag--is the path alternative?)
                my $PathOrder   = 0;
                my $Alternative = 0;
                foreach my $ASN (@asPathFields) {
                    if ( $ASN =~ /^[0-9]+$/ ) {    #regular path
                                                   #insert path entry
                        $dbq_MsgPath->execute( $MsgPathID, $PathOrder, $ASN,
                            $Alternative );
                    }
                    elsif ( $ASN =~ /^\[/ )
                    {    # starts with [ --> start of an alternative path
                        $Alternative = 1;
                        $PathOrder   = 0;
                        $ASN =~ s/\[//;    #remove leading bracket
                                           #insert path entry
                        $dbq_MsgPath->execute( $MsgPathID, $PathOrder, $ASN,
                            $Alternative );
                    }
                    elsif ( $Alternative && $ASN =~ /\]$/ )
                    {    # ends with ] --> end of alternative path
                        $ASN =~ s/\]//;    #remove trailing bracket
                                           #insert path entry
                        $dbq_MsgPath->execute( $MsgPathID, $PathOrder, $ASN,
                            $Alternative );
                        $Alternative = 0;
                        $PathOrder   = 0;
                    }
                    else {                 #error in path
                        $AS_PATH_ERROR++;
                    }
                    $PathOrder++;          #increment PathOrder
                }
            }
        }

        $lineNum++;
        $numMessages++;
    }

    #number of $FILES processed
    $count++;

    close $BGP_DATA_FILE;
    close $BUCKET;

    #Commit
    #$dbh->do("COMMIT");
    
    my $bucket_file_path=`pwd`;
    chomp($bucket_file_path);
    my $bucket_file_pathname=$bucket_file_path."/".$bucket_file_name;
    `chmod a+r $bucket_file_pathname`;
    my $dbq_Message = $dbh->prepare_cached(
    "LOAD DATA INFILE '$bucket_file_pathname' INTO TABLE Message FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' (DataSetID,BGPVersionID,MsgType,MsgTime,PeerIPID,PeerAS,PrefixID,PrefixMask,MsgPathID,OriginID,NextHopID,Med,CommunityID,AggregateID,AggregateIPID)")
  or die "Can't prepare SQL statement: $DBI::errstr\n";
    $dbq_Message->execute();
    $dbq_Message->finish;  
    
    unlink($bucket_file_name);

    #print errors when number of errors reach N
    if ( $count % 100 == 0 ) {    #every 100 $FILES print count of errors
        print $ERROR_LOG "$count files processed\n"
          . "$numMessages messages proceessed\n"
          . "Number of MSG_TYPE_ERROR: $MSG_TYPE_ERROR\n"
          . "Number of AS_PATH_ERROR: $AS_PATH_ERROR\n"
          . "Number of MSG_TIME_ERROR: $MSG_TIME_ERROR\n"
          . "Number of PEER_IP_ERROR: $PEER_IP_ERROR\n"
          . "Number of PEER_AS_ERROR: $PEER_AS_ERROR\n"
          . "Number of PREFIX_ERROR: $PREFIX_ERROR\n"
          . "Number of PREFIXMASK_ERROR: $PREFIXMASK_ERROR\n"
          . "Number of NEXTHOP_ERROR: $NEXTHOP_ERROR\n"
          . "Number of MED_ERROR: $MED_ERROR\n"
          . "Number of AGGREGATE_IP_ERROR: $AGGREGATE_IP_ERROR\n\n";
    }
}    #processed all $FILES

#close $FILES;
#closedir $DIR;
close $ERROR_LOG;

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
#$dbq_Message->finish;
$dbq_MsgPath->finish;
$dbq_IPTable->finish;
$dbq_IPID->finish;
$dbq_getMsgPathID->finish;
$dbq_CountMessages->finish;
$dbh->disconnect
  or warn "Error disconnecting: $DBI::errstr\n";

email("Last file $current_file, $count files processed\n");
