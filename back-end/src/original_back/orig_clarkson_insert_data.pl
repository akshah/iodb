#!/usr/local/bin/perl  
#Last Modified: 7/28/03
#Author: Todd Deshane

# process_files
# gunzips (`gunzip`), extracts information and puts in database from
# bgp*.gz files then gzips them (`gzip`) #### what about recv and other files? 
# USAGE: insert_data.pl [-u username] [-p password] [other options (see below)]

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
    $hostname = "localhost";
}
if(! defined $username) {
    $username = "inserter";
}
if(! defined $password) {    
    $password = "meinsert";
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

### DataSet table --> information about the file being imported (DataSetID,FromFile,Descr,ImportDate,CollectDate)
my $sth_DataSet = $dbh->prepare_cached("INSERT INTO DataSet VALUES(NULL,?,?,now(),?,1)" ) or die "Can't prepare SQL statement: $DBI::errstr\n";

### Message table --> information about the BGP message (MsgID,DataSetID,BGPVersion,MsgType,MsgType,MsgTime,PeerIP,PeerAS,Prefix,PrefixMask,Origin,NextHop,LocalPref,Med,CommunityID,AggregateID,AggregateIP)
my $sth_Message = $dbh->prepare_cached("INSERT INTO Message VALUES(NULL,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)" )  or die "Can't prepare SQL statement: $DBI::errstr\n";

### MsgPath table --> information about the AS Paths of the BGP message (id,MsgPathID,PathOrder,ASN,Alternative) i.e. (1,1,0,3421,0)
my $sth_MsgPath = $dbh->prepare_cached("INSERT INTO MsgPath VALUES(NULL,?,?,?,?)" )      or die "Can't prepare SQL statement: $DBI::errstr\n";

### IPTable table --> information about the IP addresses found in the BGP messages (id,ipval,ip) i.e (1,291516556,17.96.48.140)
my $sth_IPTable = $dbh->prepare_cached("INSERT INTO IPTable VALUES(NULL,?,?)" ) or die "Can't prepare SQL statement: $DBI::errstr\n";
my $sth_IPID = $dbh->prepare_cached("SELECT id FROM IPTable WHERE ip = ?") or die "Can't prepare SQL statement: $DBI::errstr\n"; ### ? --> '?'

### Community table --> information about the Community and the LocalPref (id,CommunityID,PathOrder,Community,LocalPref) i.e. (1,1,0,3150,100)
my $sth_Community = $dbh->prepare_cached("INSERT INTO Community VALUES(NULL,?,?,?,?)" ) or die "Can't prepare SQL statement: $DBI::errstr\n";

#initialize global variables
my $MsgID_insert = -1; #used to store MsgID inserted into Message table
my $DataSetID_insert = -1; #used to store DataSetID inserted into DataSet table
my $count = 0; #count number of files processed
my $numMessages = 0; #count number of messages processed
my $pointer_PeerIP = 0;
my @IP_cache_PeerIP; #cache most recently used ip addressed 
my @ID_cache_PeerIP; #cache most recently used id's associated with ip's
my $pointer_NextHop = 0;
my @IP_cache_NextHop; #cache most recently used ip addressed 
my @ID_cache_NextHop; #cache most recently used id's associated with ip's
my $pointer_AggregateIP = 0;
my @IP_cache_AggregateIP; #cache most recently used ip addressed 
my @ID_cache_AggregateIP; #cache most recently used id's associated with ip's

my $sth_LockTables = $dbh->prepare("LOCK TABLES Message READ") or die "Can't prepare SQL statement: $DBI::errstr\n";
my $sth_UnlockTables = $dbh->prepare("UNLOCK TABLES") or die "Can't prepare SQL statement: $DBI::errstr\n";
my $sth_GetMaxMsgID = $dbh->prepare("SELECT MAX(MsgID) FROM Message WHERE MsgType = 'A'" ) or die "Can't prepare SQL statement: $DBI::errstr\n";

my $sth_CountMessages = $dbh->prepare("SELECT COUNT(*) FROM Message" ) or die "Can't prepare SQL statement: $DBI::errstr\n";

### get maximum values for MsgPathID and Community values 
my $sth_GetMaxMsgPathID = $dbh->prepare("SELECT max(MsgPathID) FROM MsgPath" ) or die "Can't prepare SQL statement: $DBI::errstr\n";
my $sth_GetMaxCommunityID = $dbh->prepare("SELECT max(CommunityID) FROM Community" ) or die "Can't prepare SQL statement: $DBI::errstr\n";

my $MsgPathID = 0; #MsgPath table id to put in message table
my $CommunityID = 0; #Community table id to put in message table

$sth_CountMessages->execute;
my @count_result = $sth_CountMessages->fetchrow_array;
my $message_count = $count_result[0];

print "current message count: $message_count\n";

### set MsgPathID and CommunityID 
if($message_count != 0) {
    $sth_GetMaxMsgPathID->execute;
    my @MsgPathID_max_result = $sth_GetMaxMsgPathID->fetchrow_array;
    $MsgPathID = $MsgPathID_max_result[0];

    $sth_GetMaxCommunityID->execute;
    my @CommunityID_max_result = $sth_GetMaxCommunityID->fetchrow_array;
    $CommunityID = $CommunityID_max_result[0];
}

my $MSG_TYPE_ERROR = 0;
my $AS_PATH_ERROR = 0;
my $MSG_TIME_ERROR = 0;
my $PEER_IP_ERROR = 0;
my $PEER_AS_ERROR = 0;
my $PREFIX_ERROR = 0;
my $PREFIXMASK_ERROR = 0;
my $NEXTHOP_ERROR = 0;
my $MED_ERROR = 0;
my $AGGREGATE_IP_ERROR = 0;

for(my $index = 0; $index < 5; $index++) {
    $IP_cache_PeerIP[$index] = "-1";
    $ID_cache_PeerIP[$index] = "-1";
    $IP_cache_NextHop[$index] = "-1";
    $ID_cache_NextHop[$index] = "-1";
    $IP_cache_AggregateIP[$index] = "-1";
    $ID_cache_AggregateIP[$index] = "-1";
}
my $date = `date`;
my $pwd = `pwd`;
chomp($pwd);
$pwd =~ s/\//-/g; #replace / with _
chomp($date); #takes off trailing newline if necessary
#open error log file
open (ERROR_LOG, ">$error_log\_starting_dir-$pwd\_$date") or die("can't open $error_log\_$pwd\_$date: $!");

### process the data (insert into database)
open FILES, "ls |";

while (<FILES>) {
	chomp($_); #remove whitespace characters at end of filename
	$_ =~ s/\s+/\\ /g; #escape space for the shell
	`gunzip $_`; #extract file to be processed
	
	#store filename with and without .gz extension
	my $originalFilename = $_;
	my $newFilename = $originalFilename;
	$newFilename =~ s/\.gz$//;

	#obtain DataSet info
	my $Descr = "this is a file download from ftp.merit.edu/statistics/ipma/data/";
	my $CollectDate = $newFilename;
	$CollectDate =~ s/bgp\.//;
	if($CollectDate =~ /:0$/) {#ends with :0 
	    $CollectDate .= "0"; #add trailing zero for DATETIME format
	}

	### insert DataSet info
	$sth_DataSet->execute($originalFilename,$Descr,$CollectDate);
	#get the auto-incremented DataSetID that was inserted (for message table) 
	$DataSetID_insert = $dbh->{mysql_insertid};

	#process machine-readable (-m) output of route_btoa
	my $lineNum = 1;
	open BGP_DATA_FILE, "route_btoa -m $newFilename|" or 
	    die "cannot pipe from route_btoa: $!";
	while(<BGP_DATA_FILE>) {
	    my $announce_flag = 0; #flag
	    my $community_flag = 0; #flag
	    #split line into variables seperated by a '|'
	    (my $BGPVersion,my $MsgTime,my $MsgType,my $PeerIP,my $PeerAS,my $prefix_combo,my $asPath,my $Origin,my $NextHop,my $LocalPref,my $Med,my $Community,my $AggregateID,my $AggregateIP)
		= split(/\|/,$_); 

### data from merit LocalPref always 0 so far #################################
	    if(defined $LocalPref) {
		if($LocalPref != 0) { 
		    print ERROR_LOG "LocalPref not 0, in $newFilename on line $lineNum LocalPref: $LocalPref\n";
		}
	    }
### determine BGP Protocol version and store id ###############################
	    my $BGPVersionID; #id to store in message table
	    if($BGPVersion eq "BGP"){
		$BGPVersionID = 1;
	    }
	    elsif($BGPVersion eq "BGP4") {
		$BGPVersionID = 2;
	    }
	    elsif($BGPVersion eq "BGP4MP") {
		$BGPVersionID = 3;
	    }
	    else { #BGPVersion is not BGP,BGP4 nor BGP4MP
		$BGPVersionID = 4; #error
	    }
### convert seconds since epoch (jan 1 1970) to DATETIME ######################
	    #format MsgTime to DATETIME format for insertion into the mysql database
	    my $tm = localtime($MsgTime);
	    $MsgTime = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $tm->year+1900 , $tm->mon+1,$tm->mday,$tm->hour,$tm->min,$tm->sec);

### breakup Prefix i.e. 128.153.0.0/16 into IP and PrefixMask #################
	    #split Prefix/PrefixMask pair
	    (my $Prefix,my $PrefixMask) = split(/\//,$prefix_combo);

### Prefix ####################################################################
	    ###check database (IPTable) for prefix i.e (128.153.0.0)
	    my $PrefixID;
	    if($Prefix) { #if Prefix has a value
		$sth_IPID->execute($Prefix); #check database for id
		my @result  = $sth_IPID->fetchrow_array;
		if($result[0]) { #found id in database
		    $PrefixID = $result[0];
		}
		else { #ip wasn't already there
		    #convert Prefix to unsigned int and insert
		    my $Prefix_ipval = new NetAddr::IP($Prefix);
		    $Prefix_ipval = $Prefix_ipval->numeric();
		    ###insert IP into IPTable
		    $sth_IPTable->execute($Prefix_ipval,$Prefix);
		    $PrefixID = $dbh->{mysql_insertid};
		}
		#PrefixID (int id) now set for Message table
	    }
### PeerIP ####################################################################
	    ###check database (IPTable) for PeerIP 
	    my $PeerIPID; #variable to store PeerIP id for message table
	    if($PeerIP) { #if PeerIP has a value
		#check to see if IP (for PeerIP) already exists
		#check in cache first
		my $i = 0;
		while($PeerIP ne $IP_cache_PeerIP[$i] && $i < 5) {
		    $i++;
		}
		if($i < 5) { #found ip in cache
		    $PeerIPID = $ID_cache_PeerIP[$i];
		}
		else { #not found in cache
		    #didn't find it in cache, check database
		    $sth_IPID->execute($PeerIP);
		    my @result = $sth_IPID->fetchrow_array;
		    if($result[0]) { #found id in database
			$PeerIPID = $result[0];
			$ID_cache_PeerIP[$pointer_PeerIP] = $PeerIPID; #cache id
			$IP_cache_PeerIP[$pointer_PeerIP] = $PeerIP; #cache ip 
		    }		
		    else { #id not found in database
			#convert PeerIP to unsigned int and insert
			my $PeerIP_ipval = new NetAddr::IP($PeerIP);
			$PeerIP_ipval = $PeerIP_ipval->numeric();
			$sth_IPTable->execute($PeerIP_ipval,$PeerIP);
			$PeerIPID = $dbh->{mysql_insertid};
			$ID_cache_PeerIP[$pointer_PeerIP] = $PeerIPID; #cache id
			$IP_cache_PeerIP[$pointer_PeerIP] = $PeerIP; #cache IP
		    }
		    if($pointer_PeerIP < 4) {
			$pointer_PeerIP++;
		    }
		    else { #pointer_PeerIP = 4
			$pointer_PeerIP = 0;
		    }
		}
		# PeerIPID (int id) now set for Message table
	    }

	    ###variables used for announcements
	    my @asPathFields;
	    my @communityFields;
	    my $OriginID; #variable to store Origin id for message table
	    my $NextHopID; #variable to store NextHop id for message table
	    my $AggregateIPID; #variable to store AggregateIP id for message table
	    my $AggregateID; #variable to store AggregateID id for message table
### announcement messages ####################################################
	    if($MsgType eq "A") { #announcement --> path announced
		$MsgPathID++;
		$announce_flag = 1; #set annouce flag
		if($asPath) { #if asPath has a value
		    @asPathFields = split(/\s+/,$asPath); #break up asPath by spaces
		}
		else { 
		    print ERROR_LOG "error with aspath file: $newFilename on $lineNum\n";
		}
### deal with Origin #########################################################
		if($Origin) { #if Origin has a value
		    if($Origin eq "IGP") {
			$OriginID = 1;
		    }
		    elsif($Origin eq "INCOMPLETE") {
			$OriginID = 2;
		    }
		    elsif($Origin eq "EGP") {
			$OriginID = 3;
		    }
		    else #Origin not equal to "IGP","INCOMPLETE", nor "EGP"
		    {
			$OriginID = 4; #ERROR (ERR in OriginTable)
		    } 
		}
### deal with atomic aggregate ##############################################
		if($AggregateID) { #if AggregateID has a value
		    if($AggregateID eq "NAG") {
			$AggregateID = 1;
		    }
		    elsif($AggregateID eq "AG") {
			$AggregateID = 2;
		    }
		    else #AggregateID not equal to "NAG" nor "AG"
		    {
			$AggregateID = 3; #ERROR (ERR in AggrTable)
		    }
		}
### deal with NextHop #######################################################
		if($NextHop) { #if NextHop has a value
		    #check to see if IP (for NextHop) already exists
		    #check in cache first
		    my $i = 0;
		    while($NextHop ne $IP_cache_NextHop[$i] && $i < 5) {
			$i++;
		    }
		    if($i < 5) { #found ip in cache
			$NextHopID = $ID_cache_NextHop[$i];
		    }
		    else { #not found in cache
			#didn't find it in cache, check database
			$sth_IPID->execute($NextHop);
			my @result = $sth_IPID->fetchrow_array;
			if($result[0]) { #found id in database
			    $NextHopID = $result[0];
			    $ID_cache_NextHop[$pointer_NextHop] = $NextHopID; #cache id
			    $IP_cache_NextHop[$pointer_NextHop] = $NextHop; #cache ip 
			}		
			else { #id not found in database
			    #convert NextHop to unsigned int and insert
			    my $NextHop_ipval = new NetAddr::IP($NextHop);
			    $NextHop_ipval = $NextHop_ipval->numeric();
			    $sth_IPTable->execute($NextHop_ipval,$NextHop);
			    $NextHopID = $dbh->{mysql_insertid};
			    $ID_cache_NextHop[$pointer_NextHop] = $NextHopID; #cache id
			    $IP_cache_NextHop[$pointer_NextHop] = $NextHop; #cache IP
			}
			if($pointer_NextHop < 4) {
			    $pointer_NextHop++;
			}
			else { #pointer_NextHop = 4
			    $pointer_NextHop = 0;
			}
		    }
		    #NextHopID (int id) now set for Message table
		}
### deal with aggregate IP ###################################################
		if($AggregateIP) { #if AggregateIP has a value
		    #check to see if IP (for AggregateIP) already exists
		    #check in cache first
		    my $i = 0;
		    while($AggregateIP ne $IP_cache_AggregateIP[$i] && $i < 5) {
			$i++;
		    }
		    if($i < 5) { #found ip in cache
			$AggregateIPID = $ID_cache_AggregateIP[$i];
		    }
		    else { #not found in cache
			#didn't find it in cache, check database
			$sth_IPID->execute($AggregateIP);
			my @result = $sth_IPID->fetchrow_array;
			if($result[0]) { #found id in database
			    $AggregateIPID = $result[0];
			    $ID_cache_AggregateIP[$pointer_AggregateIP] = $AggregateIPID; #cache id
			    $IP_cache_AggregateIP[$pointer_AggregateIP] = $AggregateIP; #cache ip 

			}		
			else { #id not found in database
			    #convert AggregateIP to unsigned int and insert
			    my $AggregateIP_ipval = new NetAddr::IP($AggregateIP);
			    $AggregateIP_ipval = $AggregateIP_ipval->numeric();
			    $sth_IPTable->execute($AggregateIP_ipval,$AggregateIP);
			    $AggregateIPID = $dbh->{mysql_insertid};
			    $ID_cache_AggregateIP[$pointer_AggregateIP] = $AggregateIPID; #cache id
			    $IP_cache_AggregateIP[$pointer_AggregateIP] = $AggregateIP; #cache IP
			}
			if($pointer_AggregateIP < 4) {
			    $pointer_AggregateIP++;
			}
			else { #pointer_AggregateIP = 4
			    $pointer_AggregateIP = 0;
			}
		    }
		    #AggregateIPID (int id) now set for Message table
		}
### set Community flag if exists ##############################################
		if($Community) { #Community has a value
		    ###break up Communities into fields separated by space(s) 
		    @communityFields = split(/\s+/,$Community);
		    $community_flag = 1; # set community flag
		    $CommunityID++;
		    #print "$Community\n";
 		    ###insert Message info in Message table for this announcement
		    $sth_Message->execute($DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,$MsgPathID,$OriginID,$NextHopID,$Med,$CommunityID,$AggregateID,$AggregateIPID);
		}
		else { #Community has no value
		    ###insert Message info in Message table for this announcement
		    $sth_Message->execute($DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,$MsgPathID,$OriginID,$NextHopID,$Med,"NULL",$AggregateID,$AggregateIPID);
		}
	    }
### withdrawal message ########################################################
	    elsif($MsgType eq "W") #withdrawl message
	    {
		$asPath = "NULL";
		$Origin = "NULL";
		$NextHop = "NULL";
		$LocalPref = "NULL";
		$Med = "NULL";
		$AggregateID = "NULL";
		$AggregateIP = "NULL";
		###insert Message info in Message table
		$sth_Message->execute($DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,0,$OriginID,$NextHopID,$Med,0,$AggregateID,$AggregateIPID);
	    }
### state message #############################################################
	    elsif($MsgType eq "STATE") #state message
	    {
		$asPath = "NULL";
		$Origin = "NULL";
		$NextHop = "NULL";
		$LocalPref = "NULL";
		$Med = "NULL";
		$AggregateID = "NULL";
		$AggregateIP = "NULL";
		$MsgType = "S";
		###insert Message info in Message table
		$sth_Message->execute($DataSetID_insert,$BGPVersionID,$MsgType,$MsgTime,$PeerIPID,$PeerAS,$PrefixID,$PrefixMask,0,$OriginID,$NextHopID,$Med,0,$AggregateID,$AggregateIPID);
	    }
	    else { #MsgType not a withdrawal, announcement nor state
		$MSG_TYPE_ERROR++;
	    }
	    #missing peices in files (keep count of errors) 
	    if(! defined $MsgTime) {$MSG_TIME_ERROR++;} 
	    if(! defined $PeerAS) {$PEER_AS_ERROR++;}
	    if(! defined $Prefix) {$PREFIX_ERROR++;}
	    if( (! defined $PrefixMask) && ($MsgType ne "S") ) {$PREFIXMASK_ERROR++;}
	    if(! defined $NextHop) {$NEXTHOP_ERROR++;}
	    if(! defined $Med) {$MED_ERROR++;}
	    if(! defined $AggregateIP) {$AGGREGATE_IP_ERROR++;}

### Deal with ASPATH ##########################################################
	    
	    if($announce_flag) {
		#initialize PathOrder and Alternative bit 
		###(PathOrder,Alternative) => (position of AS in ASPATH, alternative flag--is the path alternative?)
		my $PathOrder = 0;
		my $Alternative = 0; 
		foreach my $ASN (@asPathFields) {
		    if($ASN =~ /^[0-9]+$/) { #regular path
			#insert path entry
			$sth_MsgPath->execute($MsgPathID,$PathOrder,$ASN,$Alternative);		    
		    }
		    elsif($ASN =~ /^\[/) { # starts with [ --> start of an alternative path
			$Alternative = 1;
			$PathOrder = 0;
			$ASN =~ s/\[//; #remove leading bracket
			#insert path entry
			$sth_MsgPath->execute($MsgPathID,$PathOrder,$ASN,$Alternative);		    
		    }  
		    elsif($Alternative && $ASN =~ /\]$/ ) { # ends with ] --> end of alternative path
			$ASN =~ s/\]//; #remove trailing bracket 
			#insert path entry
			$sth_MsgPath->execute($MsgPathID,$PathOrder,$ASN,$Alternative);		    
			$Alternative = 0;
			$PathOrder = 0;
		    }
		    else { #error in path
			$AS_PATH_ERROR++;
		    }
		    $PathOrder++; #increment PathOrder
		}
	    }
### Deal with Community entries ###############################################

	    if($community_flag) {
		#initialize PathOrder (for Community table) 
		###PathOrder => (position of AS:LocalPref pair in Community field of BGP message
		my $PathOrder_Community = 0;
		foreach my $Pair (@communityFields) {
		    (my $AS,my $LocalPref) = split(/\:/,$Pair);
		    if(defined $AS) {
		    $sth_Community->execute($CommunityID,$PathOrder_Community,$AS,$LocalPref);
		    }
		    $PathOrder_Community++; #increment PathOrder
		}
	    }
### Done with one row of machine-readable output ##############################

	    $lineNum++;
	    $numMessages++;
	} #end while (<BGP_DATA_FILE>)

    	#increment counter (number of files processed)
	$count++;	
	# close and zip file back to its originalFilename
	close BGP_DATA_FILE;
	`gzip $newFilename`;
	 
	#print errors when number of errors reach N
	if($count % 100 == 0) { #every 100 files print count of errors
	print ERROR_LOG
	    "$count files processed\n" .
	    "$numMessages messages proceessed\n" .
	    "Number of MSG_TYPE_ERROR: $MSG_TYPE_ERROR\n" . 
	    "Number of AS_PATH_ERROR: $AS_PATH_ERROR\n" . 
	    "Number of MSG_TIME_ERROR: $MSG_TIME_ERROR\n" .
	    "Number of PEER_IP_ERROR: $PEER_IP_ERROR\n" .
	    "Number of PEER_AS_ERROR: $PEER_AS_ERROR\n" .
	    "Number of PREFIX_ERROR: $PREFIX_ERROR\n" .
	    "Number of PREFIXMASK_ERROR: $PREFIXMASK_ERROR\n" .
	    "Number of NEXTHOP_ERROR: $NEXTHOP_ERROR\n" .
	    "Number of MED_ERROR: $MED_ERROR\n" .
	    "Number of AGGREGATE_IP_ERROR: $AGGREGATE_IP_ERROR\n\n";
    }
} #end while(<FILES>) -- processed all files

### Disconnect from the database
$sth_DataSet->finish;
$sth_Message->finish;
$sth_MsgPath->finish;
$sth_IPTable->finish;
$sth_IPID->finish;  
$sth_GetMaxMsgPathID->finish;
$sth_GetMaxCommunityID->finish;
$sth_CountMessages->finish;
$dbh->disconnect
      or warn "Error disconnecting: $DBI::errstr\n";

print "\n\n $count files processed\n\n";    
