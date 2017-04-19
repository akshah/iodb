<?php
		//Google+ signin code
		include_once('config/config.php');
		//  start session
		if (session_status() == PHP_SESSION_NONE) {
		    session_start();
		    $_SESSION['clientid'] = $client_id;
		}

		// CSRF Counter-measure
		$token = md5(uniqid(rand(), TRUE));
		$_SESSION['state'] = $token;
		//signin code end
?>
<!DOCTYPE html>
<html lang="en">
  <head>
	<title>Outage Tracker</title>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Outage Tracker">
    <meta name="author" content="iyro@CSU">

    <link href="//maxcdn.bootstrapcdn.com/bootstrap/3.3.1/css/bootstrap.min.css" rel="stylesheet">
    	<script src="//code.jquery.com/jquery-1.10.2.js"></script>
	<script src="//code.jquery.com/ui/1.11.2/jquery-ui.js"></script>
	<link href="jquery.ui.theme.css" rel="stylesheet">
	<script src="//maxcdn.bootstrapcdn.com/bootstrap/3.3.1/js/bootstrap.min.js"></script>
	
	<!--Google+ signin code-->
	<script type="text/javascript">
	  	window.___gcfg = {lang: 'en'};
		(function() {
	    		var po = document.createElement('script'); po.type = 'text/javascript'; po.async = true;
	    		po.src = 'https://apis.google.com/js/platform.js';
	    		var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(po, s);
		})();
	</script>

	<?php
	if (!isset($_SESSION['logout'])) {
		$gScript = 'po.src = \'https://plus.google.com/js/client:plusone.js?onload=render\';';
	} else {
		$gScript = 'po.src = \'https://plus.google.com/js/client:plusone.js\';';
	}
	echo '		<script type="text/javascript">
    		(function () {
      			var po = document.createElement(\'script\');
      			po.type = \'text/javascript\';
      			po.async = true;
      			' . $gScript . '
				var s = document.getElementsByTagName(\'script\')[0];
      			s.parentNode.insertBefore(po, s);
    		})();
      	</script>
      	<script type="text/javascript">
			function render() {
		    	gapi.signin.render(\'customBtn\', {
		      		\'callback\': \'signinCallback\',
		      		\'clientid\': \'' . $_SESSION['clientid'] . '\',
		      		\'cookiepolicy\': \'single_host_origin\',
		      		\'requestvisibleactions\': \'http://schemas.google.com/AddActivity\',
		      		\'scope\': \'https://www.googleapis.com/auth/plus.login email\'
		    	});
		  	}
      	</script>
      	<script type="text/javascript">
			function signinCallback(authResult) {
				if (authResult[\'code\']) {
						$.post( "/ajx/plus.php?storeToken", { code: authResult[\'code\'], state: "' . $_SESSION['state'] . '"},
							function( data ) {
								$(\'#gPlus\').empty().append( data );
				      		}
						);
		  		}
			};
		</script>
		<script type="text/javascript">
			function revokeAccess() {
				$.post("/ajx/plus.php?revoke", {state: "' . $_SESSION['state'] . '"},
					function( data ) {
						$(\'#gPlus\').empty().append( data );
					}
				);
	  		};
		</script>
		<script type="text/javascript">
			function gvnSignOut() {
				$.post( "/ajx/plus.php?logout", {state: "' . $_SESSION['state'] . '"},
				function( data ) {
					$(\'#gPlus\').empty().append( data );
				});
				gapi.auth.signOut();
			};
		</script>
		<style type="text/css">
			#customBtn {cursor: pointer;}
			#customBtn:hover {text-decoration: underline; cursor: hand;}
		</style>
';
	$gPlusWhenLogout = '		<div id="gSignInWrapper">
				<div id="customBtn">
					<a onclick="gapi.auth.signIn({\'clientid\' : \'' . $_SESSION['clientid'] . '\',\'cookiepolicy\' : \'single_host_origin\',
\'callback\' : \'signinCallback\',\'requestvisibleactions\' : \'http://schemas.google.com/AddActivity\',\'scope\' : \'https://www.googleapis.com/auth/plus.login email\'}); $(\'#customBtn\').hide();"><button class="btn-primary btn-sm">Sign in</button></a>
				</div>
			</div>';
	
	if (isset($_SESSION['access_token'])) {
		if (isset($_SESSION['logout'])) {
			$gPlus = $gPlusWhenLogout;
		} else {
			if (isset($_SESSION['givenName']))
				$gPlus = '		<div id="gPlusNav">
				<a href="https://plus.google.com/u/0/">+' . $_SESSION['givenName']  . '</a>&nbsp;&nbsp;&nbsp;
				<a href="' . $_SESSION['profileURL'] . '" class="dropdown-toggle" data-toggle="dropdown"><img src="' . $_SESSION['photo'] . '" class="img-circle"></a>&nbsp;&nbsp;&nbsp;
				<a onclick="gvnSignOut(); return false;" href="#">Disconnect me</a>&nbsp;&nbsp;&nbsp;
				<a onclick="revokeAccess(); return false;" href="#">Remove my consent</a>
			</div>';
		}
	} else {
		if (isset($_SESSION['logout'])) {
			$gPlus = $gPlusWhenLogout;
		} else {
			$gPlus = '		<div id="gSignInWrapper">
				<div id="customBtn" class="customGPlusSignIn">
					<a>+Sign In</a>
				</div>
			</div>';
		}
	}
?>
	<!--Google+ signin code ends-->



	<script>
	<?php
		$servername = "proton.netsec.colostate.edu";
		$username = "iyerro";
		$password = "rohit533";
		
		$conn = new mysqli($servername, $username, $password, "iodb");

		if (!$conn) {
			//TODO : Add Error Message
		}
		
		$sql = "SELECT cast(min(OutageStart) as date) as min, cast(max(OutageEnd) as date) as max from PingOutage";
		
		$result = mysqli_query($conn,$sql);
		
		if (!$result) {
			//TODO : Add Error Message
		}

		if (mysqli_num_rows($result) == 0) {
			//TODO : Add Error Message
		}
		
		$row = mysqli_fetch_assoc($result);
		
		echo "var minD = '" . $row["min"] . "';";
		echo "var maxD = '" . $row["max"] . "';";
		if (isset($_GET["from"]) && isset($_GET["to"])) {
			echo "var setMin = '" . $_GET["from"] . "';";
			echo "var setMax = '" . $_GET["to"] . "';";
		}
		
		$sql = "SELECT DISTINCT Country FROM GeoInfo";
		$result = mysqli_query($conn,$sql);
		$i = 0;
		echo "var countries = [";
		while ($row = mysqli_fetch_assoc($result)) {
			if ($i != 0)
				echo ",";
			$i++;
			echo "'" . $row["Country"] . "'";
		}
		echo "];";
		mysqli_free_result($result);
		$conn->close();
	?>
		
		$(function() {
			$( "#from" ).datepicker({
				changeMonth: true,
				changeYear: true,
				dateFormat: "yy-mm-dd",
				minDate: minD,
				maxDate: maxD,
				defaultDate: minD,
				onSelect: function( selectedDate ) {
					$( "#to" ).datepicker( "option", "minDate", selectedDate );
					$("#set").val("1");
					$("#submit").val("Submit");
					$("#submit").prop("disabled",false);
					$("#totalPages").html("");
				}
			});
			$( "#to" ).datepicker({
				changeMonth: true,
				changeYear: true,
				dateFormat: "yy-mm-dd",
				minDate: minD,
				maxDate: maxD,
				defaultDate: maxD,
				onSelect: function( selectedDate ) {
					$( "#from" ).datepicker( "option", "maxDate", selectedDate );
					$("#set").val("1");
					$("#submit").val("Submit");
					$("#submit").prop("disabled",false);
					$("#totalPages").html("");
				}
			});
			$( "#from" ).datepicker( "setDate", setMin );
			$( "#to" ).datepicker( "setDate", setMax );
			$('#ui-datepicker-div').css('display','none');
		});
	</script>
	
	<script type="text/javascript" src="https://maps.googleapis.com/maps/api/js?sensor=true"></script>
	<script type="text/javascript">
		function initialize() {
			for (i=0 ; i < countries.length; i++) {
			if (countries[i] == <?php if (isset($_GET["country"])) { echo "'" . $_GET["country"] . "'";} else { echo "'US'"; } ?>) {
				$("#countrySelect").append("<option selected='selected'>" + countries[i] + "</option>");
			}
			else {
				$("#countrySelect").append("<option>" + countries[i] + "</option>");
			}
			}
			var map;
			var bounds;
			var mapProp = {
				mapTypeId: google.maps.MapTypeId.ROADMAP
			}
			
			map=new google.maps.Map(document.getElementById("map_canvas"),mapProp);
			
			bounds = new google.maps.LatLngBounds();
			
			<?php
				$servername = "proton.netsec.colostate.edu";
				$username = "iyerro";
				$password = "rohit533";
				
				if (isset($_GET["from"]) && isset($_GET["to"]) && isset($_GET["set"])) {
					echo "var gettoisset = 1;";
					echo "var pageno = " . $_GET["set"] . ";";
					$conn = new mysqli($servername, $username, $password, "iodb");

					if (!$conn) {
						//TODO : Add Error Message
					}
					
					$start = ($_GET["set"] - 1) * 50;
					$SD = urldecode($_GET["from"]) . " 00:00:00";
					$ED = urldecode($_GET["to"]) . " 23:59:59";
					if (isset($_GET["BGP"]) && urldecode($_GET["BGP"]) != "None") {
						$BGP = urldecode($_GET["BGP"]);
						$sqlcount = "SELECT (count(*)/50) + 1 as totalpages
								FROM (
									SELECT OutageInfo.BGP_LPM, PingOutage.IPBlock, PingOutage.OutageStart, PingOutage.OutageEnd
									FROM PingOutage, OutageInfo 
									WHERE PingOutage.OutageID = OutageInfo.OutageID 
									AND OutageInfo.PeerIP = '12.0.1.63'
									AND OutageInfo.BGP_LPM != 'default'
									AND ('" . $SD . "' <= PingOutage.OutageStart AND '" . $ED . "' >= PingOutage.OutageEnd)
									AND ('" . $BGP . "' = BGP_LPM)
								) O 
								JOIN GeoInfo
								ON GeoInfo.IP=substring(O.IPBlock,1,char_length(O.IPBlock)-3) AND 
								GeoInfo.Country = '" . $_GET["country"] . "'";
								
						$sql = "SELECT O.BGP_LPM, O.IPBlock, GeoInfo.Country, GeoInfo.City, GeoInfo.Lattitude, GeoInfo.Longitude, O.OutageStart, O.OutageEnd
								FROM (
									SELECT OutageInfo.BGP_LPM, PingOutage.IPBlock, PingOutage.OutageStart, PingOutage.OutageEnd
									FROM PingOutage, OutageInfo 
									WHERE PingOutage.OutageID = OutageInfo.OutageID 
									AND OutageInfo.PeerIP = '12.0.1.63'
									AND OutageInfo.BGP_LPM != 'default'
									AND ('" . $SD . "' <= PingOutage.OutageStart AND '" . $ED . "' >= PingOutage.OutageEnd)
									AND ('" . $BGP . "' = BGP_LPM)
								) O 
								JOIN GeoInfo
								ON GeoInfo.IP=substring(O.IPBlock,1,char_length(O.IPBlock)-3) AND
								GeoInfo.Country = '" . $_GET["country"] . "'
								limit " . $start . ", 50";
					}
					else {
						$sqlcount = "SELECT (count(*)/50) + 1 as totalpages
								FROM (
									SELECT distinct OutageInfo.BGP_LPM, PingOutage.IPBlock
									FROM PingOutage, OutageInfo 
									WHERE PingOutage.OutageID = OutageInfo.OutageID 
									AND OutageInfo.PeerIP = '12.0.1.63'
									AND OutageInfo.BGP_LPM != 'default'
									AND ('" . $SD . "' <= PingOutage.OutageStart AND '" . $ED . "' >= PingOutage.OutageEnd)
								) O 
								JOIN GeoInfo
								ON GeoInfo.IP=substring(O.IPBlock,1,char_length(O.IPBlock)-3) AND
								GeoInfo.Country = '" . $_GET["country"] . "'";
						
						$sql = "SELECT O.BGP_LPM, O.IPBlock, GeoInfo.Country, GeoInfo.City, GeoInfo.Lattitude, GeoInfo.Longitude
								FROM (
									SELECT distinct OutageInfo.BGP_LPM, PingOutage.IPBlock
									FROM PingOutage, OutageInfo 
									WHERE PingOutage.OutageID = OutageInfo.OutageID 
									AND OutageInfo.PeerIP = '12.0.1.63'
									AND OutageInfo.BGP_LPM != 'default'
									AND ('" . $SD . "' <= PingOutage.OutageStart AND '" . $ED . "' >= PingOutage.OutageEnd)
								) O 
								JOIN GeoInfo
								ON GeoInfo.IP=substring(O.IPBlock,1,char_length(O.IPBlock)-3) AND 
								GeoInfo.Country = '" . $_GET["country"] . "'
								limit " . $start . ", 50";
					}
					$result = mysqli_query($conn,$sql);
					
					$resultcount = mysqli_query($conn,$sqlcount);

					if (!$result) {
						//TODO : Add Error Message
					}

					if (mysqli_num_rows($result) == 0) {
						echo "var locations = [];";
					}
					
					else {
						$countrow = mysqli_fetch_assoc($resultcount);
						echo "var totalpages = " . $countrow["totalpages"] . ";";
						
						echo "var locations = [";
						$i = 0;
						if (mysqli_num_fields($result) == 6) {
							while ($row = mysqli_fetch_assoc($result)) {
								if ($i != 0)
									echo ",";
								$i++;
								echo "[";
								echo "'" . $row["IPBlock"] . "'" . "," . "'" . $row["Country"] . "'" . "," . "'" . $row["City"] . "'" .  ","  . $row["Lattitude"] . "," . $row["Longitude"] . ",'" . $row["BGP_LPM"] . "'";
								echo "]";
							}
						}
						else {
							while ($row = mysqli_fetch_assoc($result)) {
								if ($i != 0)
									echo ",";
								$i++;
								echo "[";
								echo "'" . $row["IPBlock"] . "'" . "," . "'" . $row["Country"] . "'" . "," . "'" . $row["City"] . "'" .  ","  . $row["Lattitude"] . "," . $row["Longitude"] . ",'" . $row["BGP_LPM"] . "','" . $row["OutageStart"] . "','" . $row["OutageEnd"] . "'";
								echo "]";
							}
						}
						echo "];";
						if (isset($_GET["BGP"]) && urldecode($_GET["BGP"]) != "None") {
							echo "var bgpisset = 1;";
						}
						else {
							echo "var bgpisset = 0;";
						}
					}
					mysqli_free_result($result);
					$conn->close();
				}
				else {
					echo "var gettoisset = 0;";
					echo "var bgpisset = 0;";
				}
			?>
			
			if (gettoisset == 1 && locations.length != 0) {
				if (pageno + 1 > Math.floor( totalpages ))
				{
					$("#set").val(pageno);
					$("#submit").val("No More Pages");
					$("#submit").prop("disabled",true);
				}
				else {
					$("#set").val(pageno + 1);
					$("#submit").val("Get Next Page");
				}
				$("#totalPages").html("Current Page : "+pageno+"<br/>Total Pages : "+Math.floor( totalpages )+"<br/>");
				var infowindow = new google.maps.InfoWindow();
				
				var marker, i;
				$("#BGPSelect").show();
				$("#BGPSelect").append("<option>None</option>");
				for (i = 0; i < locations.length; i++) {
					marker = new google.maps.Marker({
					position: new google.maps.LatLng(locations[i][3], locations[i][4]),
					map: map
					});

					google.maps.event.addListener(marker, 'mouseover', (function(marker, i) {
						return function() {
							  var html = "<b>IP Block</b> : " + locations[i][0] + "<br/><b>Country</b> : " + locations[i][1] + "<br/><b>City</b> : " + locations[i][2];
							  infowindow.setContent(html);
							  infowindow.open(map, marker);
						}
					})(marker, i));
					
					bounds.extend(marker.getPosition());
					
					if (bgpisset == 0 & locations[i][5] != '-') {
						$("#BGPSelect").append("<option>" + locations[i][5] + "</option>");
					}
				}
				
				if (bgpisset == 1) {				
					$("#BGPSelect").append("<option>" + locations[0][5] + "</option>");
					
					var tablehead = document.getElementById("BGPTable").getElementsByTagName('thead')[0];
					var row = tablehead.insertRow(0);
					var cell1 = row.insertCell(0);
					var cell2 = row.insertCell(1);
					var cell3 = row.insertCell(2);
					cell1.innerHTML = "<h3>IP Block</h3>";
					cell2.innerHTML = "<h3>Outage Start</h3>";
					cell3.innerHTML = "<h3>Outage End</h3>";
					var table = document.getElementById("BGPTable").getElementsByTagName('tbody')[0];
					
					for (i=0 ; i < locations.length; i++) {
						var row = table.insertRow(i);
						var cell1 = row.insertCell(0);
						var cell2 = row.insertCell(1);
						var cell3 = row.insertCell(2);
						cell1.innerHTML = locations[i][0];
						cell2.innerHTML = locations[i][6];
						cell3.innerHTML = locations[i][7];
					}
				}
			}
			else {
				$("#BGPSelect").append("<option>None</option>");
				$( "#from" ).val(minD);
				$( "#to" ).val(maxD);
				bounds.extend(new google.maps.LatLng(40.573436, -105.0865473));
			}
			map.fitBounds (bounds);
		}
		
		function refreshpage() {
			$("#set").val("1");
			$("#submit").val("Submit");
			$("#submit").prop("disabled",false);
			$("#totalPages").html("");
			$("#BGP").val($("#BGPSelect option:selected").val());
		}
		
		function BGPClick() {
			if($("#BGPCheck").is(':checked')) {
				$("#BGPDiv").show();
			}
			else {
				$("#BGP").val("None");
				$("#BGPDiv").hide();
			}
			refreshpage();
		}
	</script>
  </head>

  <body onload="initialize()">

    <nav class="navbar navbar-inverse" role="navigation">
      <div class="container-fluid">
        <div class="navbar-header">
          <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target="#navbar" aria-expanded="false" aria-controls="navbar">
            <span class="sr-only">Toggle navigation</span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="outagetracker.php">Outage Tracker</a>
        </div>
        <div id="navbar" class="navbar-collapse collapse" style="line-height: 50px;">
		<ul class="nav navbar-nav navbar-right">
			<li><?php 
echo "		<div id = \"gPlus\">
	$gPlus
		</div>
";		
?></li>
		</ul>
        </div>
      </div>
    </nav>

      <div class="container-fluid" style="height:800px">
		  <div class="row">
			  <div class="col-md-2">
				  <form name="input" action="outagetracker.php" method="get">
						<h4>
						<label for="from">From Date : <br/></label>
						<input type="text" id="from" name="from" placeholder="From Date" class="form-control"><br/>
						
						<label for="to">To Date : <br/></label>
						<input type="text" id="to" name="to" placeholder="To Date" class="form-control"><br/>
						
						<label for="countrySelect">Country : <br/></label>
						<select id="countrySelect" name="country" class="form-control" onchange="refreshpage()">
						</select><br/>
						
						<input type="number" name="set" id="set" value="1" style="display:none"></h3>
						
						<label onclick="BGPClick()">
							<input id="BGPCheck" type="checkbox" style="text-align:right"> Enter BGP Prefix manually?
						</label>
						
						<br/>       
						
						<select id="BGPSelect" onchange="refreshpage()" class="form-control" style="display:none">
						</select><br/>
						
						<div id="BGPDiv" style="display:none">
						<label for="BGP">BGP Prefix : <br/></label>
						<input type="text" name="BGP" id="BGP" value="None" class="form-control"><br/>
						</div>
						
						<input id="submit" type="submit" value="Submit" class="btn btn-primary"> <a href="outagetracker.php" style="text-align:right;">Reset</a>
						</h4>
					</form>
					<br/>
					<div id="totalPages" class="text-center"></div>
				</div>
				<div class="col-md-10">
					<div id="map_canvas" style="height:800px"></div>
				</div>
			</div>
      </div>

    <div class="container-fluid">
		<div class="col-md-2">
		</div>
		<div class="col-md-10">
 		<table id="BGPTable" class="table">
		<thead>
		</thead>
		<tbody></tbody>
		</table>
		</div>
	</div>
	<hr>
	<div class="container-fluid">

      <footer class="text-right">
        <p>Designed by Rohit Iyer @ CSU.</p>
      </footer>
    </div> 
  </body>
</html>
