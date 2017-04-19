<?php

if(isset($_GET['prefix'])) {

	//Set our variables
	//$format = "xml";
	$prefix = $_GET['prefix'];

	//Connect to the Database
	$con = mysql_connect('proton.netsec.colostate.edu', 'root', 'n3ts3cm5q1') or die ('MySQL Error.');
	mysql_select_db('test_outage', $con) or die('MySQL Error.');

	//Run our query
	$o_id=mysql_query('SELECT OutageID FROM OutageInfo where PeerIP="109.233.176.2" and BGP_LPM="'.$prefix.'" limit 1000');
	//if($format == 'xml') {

		header('Content-type: text/xml');
		$output  = "<?xml version=\"1.0\"?>\n";		
		$output .= "<iodb>\n";
		$output .= "<prefix val= '".$prefix."' > \n";
		for($j = 0 ; $j < mysql_num_rows($o_id) ; $j++){
			$outage_id=mysql_fetch_assoc($o_id);
			$result = mysql_query('SELECT OutageStart,OutageEnd FROM PingOutage where OutageID ="'.$outage_id["OutageID"].'" limit 1000 ') or die('MySQL Error.');



			for($i = 0 ; $i < mysql_num_rows($result) ; $i++){

				$row = mysql_fetch_assoc($result);
		
				$output .= "<outage_start>" . $row['OutageStart'] . "</outage_start>"."<outage_end>" . $row['OutageEnd'] . "</outage_end> \n";
			}
		}

				$output .= "</prefix> \n";
			$output .= "</iodb>";
	//} else {
	//	die('Improper format was requested. Choose XML.');
	//}

	//Output the output.
	echo $output;

}else{
die('Please provide the Prefix.');
}

?>
