<?php
require_once 'app/init.php';

$db = new DB ();
$googleClient = new Google_Client ();
$auth = new GoogleAuth ( $db, $googleClient );

if ($auth->checkRedirectCode ()) {
	header ( 'Location: index.php' );
}

?>

<!DOCTYPE html>
<html lang="en">
<head>
<title>Internet Outage Database</title>
<meta charset="utf-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="Outage Tracker">
<meta name="author" content="iyro@CSU">

<link href="//maxcdn.bootstrapcdn.com/bootstrap/3.3.1/css/bootstrap.min.css" rel="stylesheet">
<script src="//code.jquery.com/jquery-1.10.2.js"></script>
<script src="//code.jquery.com/ui/1.11.2/jquery-ui.js"></script>
<link href="jquery.ui.theme.css" rel="stylesheet">
<script	src="//maxcdn.bootstrapcdn.com/bootstrap/3.3.1/js/bootstrap.min.js"></script>

<script>
	<?php
	$sql = "SELECT cast(min(OutageStart) as date) as min, cast(max(OutageEnd) as date) as max from FrontendData";
	$result = $db->query ( $sql );
	
/*	if (! $result) {
		// TODO : Add Error Message
	}
	
	if (mysqli_num_rows ( $result ) == 0) {
		// TODO : Add Error Message
	}*/
	
	$row = mysqli_fetch_assoc ( $result );
	
	echo "var minD = '" . $row["min"] . "';";
	echo "var maxD = '" . $row["max"] . "';";
	
	if (isset ( $_GET ["from"] ) && isset ( $_GET ["to"] )) {
		echo "var setMin = '" . $_GET ["from"] . "';";
		echo "var setMax = '" . $_GET ["to"] . "';";
	}
	
	mysqli_free_result ( $result );
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
			<?php
				$sql = "SELECT DISTINCT Country	FROM FrontendData WHERE Country != 'A2' AND Country != 'A1' AND Country != 'O1' ORDER BY Country";
				$resultCountries = $db->query ( $sql );
				
				echo "$(\"#countrySelect\").append(\"<option selected='selected'>All</option>\");\n";
				while ( $row = mysqli_fetch_assoc ( $resultCountries ) ) {
					if (isset($_GET["country"]) && ($row ["Country"] == $_GET["country"])) {
						echo "$(\"#countrySelect\").append(\"<option selected='selected'>" . $row ["Country"] . "</option>\");\n";
					}
					else {
						echo "$(\"#countrySelect\").append(\"<option>" .  $row ["Country"] . "</option>\");\n";
					}
				}
				mysqli_free_result ( $resultCountries );
			?>
			var map;
			var bounds;
			var mapProp = {
				mapTypeId: google.maps.MapTypeId.ROADMAP
			}
			
			map=new google.maps.Map(document.getElementById("map_canvas"),mapProp);
			
			bounds = new google.maps.LatLngBounds();

			google.maps.event.addListenerOnce(map, 'bounds_changed', function() {
			if (map.getZoom() > 5) {
				map.setZoom(5);
			}
			});
			
			<?php
			if (isset ( $_GET ["from"] ) && isset ( $_GET ["to"] ) && isset ( $_GET ["set"] )) {
				echo "var gettoisset = 1;";
				echo "var pageno = " . $_GET ["set"] . ";";
				
				$start = ($_GET ["set"] - 1) * 50;
				$SD = urldecode ( $_GET ["from"] ) . " 00:00:00";
				$ED = urldecode ( $_GET ["to"] ) . " 23:59:59";
				if (isset ( $_GET ["BGP"] ) && urldecode ( $_GET ["BGP"] ) != "") {
					$BGP = urldecode ( $_GET ["BGP"] );
					if (isset ( $_GET ["country"] ) && urldecode ( $_GET ["country"] ) != "All") {
						$sqlcount = "SELECT (count(*)/50) + 1 as totalpages
														FROM (
															SELECT FrontendDataID, BGP_LPM, IPBlock, Country, City, Lattitude, Longitude, OutageStart, OutageEnd
															FROM
															FrontendData
															WHERE (OutageStart >= '" . $SD . "' AND OutageEnd <= '" . $ED . "')
															AND (BGP_LPM = '" . $BGP . "')
															AND (Country = '" . $_GET ["country"] . "')) x";
						$sql = "SELECT FrontendDataID, BGP_LPM, IPBlock, Country, City, Lattitude, Longitude, OutageStart, OutageEnd, count(Comments.CommentID) as Comments
															FROM
															FrontendData
															LEFT JOIN Comments ON FrontendData.FrontendDataID = Comments.FrontenDataID
															WHERE (OutageStart >= '" . $SD . "' AND OutageEnd <= '" . $ED . "')
															AND (BGP_LPM = '" . $BGP . "')
															AND (Country = '" . $_GET ["country"] . "') GROUP BY FrontendDataID limit " . $start . ", 50";
					} else {
						$sqlcount = "SELECT (count(*)/50) + 1 as totalpages
														FROM (
															SELECT FrontendDataID, BGP_LPM, IPBlock, Country, City, Lattitude, Longitude, OutageStart, OutageEnd
															FROM
															FrontendData
															WHERE (OutageStart >= '" . $SD . "' AND OutageEnd <= '" . $ED . "')
															AND (BGP_LPM = '" . $BGP . "')) x";
						$sql = "SELECT FrontendDataID, BGP_LPM, IPBlock, Country, City, Lattitude, Longitude, OutageStart, OutageEnd, count(Comments.CommentID) as Comments
															FROM
															FrontendData
															LEFT JOIN Comments ON FrontendData.FrontendDataID = Comments.FrontenDataID
															WHERE (OutageStart >= '" . $SD . "' AND OutageEnd <= '" . $ED . "')
															AND (BGP_LPM = '" . $BGP . "') GROUP BY FrontendDataID limit " . $start . ", 50";
					}
				} else {
					if (isset ( $_GET ["country"] ) && urldecode ( $_GET ["country"] ) != "All") {
						$sqlcount = "SELECT (count(*)/50) + 1 as totalpages
														FROM (
															SELECT distinct BGP_LPM, IPBlock, Country, City, Lattitude, Longitude
															FROM
															FrontendData
															WHERE (OutageStart >= '" . $SD . "' AND OutageEnd <= '" . $ED . "')
															AND (Country = '" . $_GET ["country"] . "')) x";
						$sql = "SELECT distinct BGP_LPM, IPBlock, Country, City, Lattitude, Longitude
															FROM
															FrontendData
															WHERE (OutageStart >= '" . $SD . "' AND OutageEnd <= '" . $ED . "')
															AND (Country = '" . $_GET ["country"] . "') limit " . $start . ", 50";
					} else {
						$sqlcount = "SELECT (count(*)/50) + 1 as totalpages
														FROM (
															SELECT distinct BGP_LPM, IPBlock, Country, City, Lattitude, Longitude
															FROM
															FrontendData
															WHERE (OutageStart >= '" . $SD . "' AND OutageEnd <= '" . $ED . "')) x";
						$sql = "SELECT distinct BGP_LPM, IPBlock, Country, City, Lattitude, Longitude
															FROM
															FrontendData
															WHERE (OutageStart >= '" . $SD . "' AND OutageEnd <= '" . $ED . "') limit " . $start . ", 50";
					}
				}
				$result = $db->query ( $sql );
				
				$resultcount = $db->query ( $sqlcount );
				
				if ((!$result) || (mysqli_num_rows ( $result ) == 0)) {
					echo "var locations = [];";
					// TODO : Add Error Message
				}
				else {
					$countrow = mysqli_fetch_assoc ( $resultcount );
					echo "var totalpages = " . $countrow ["totalpages"] . ";";
					
					echo "var locations = [";
					$i = 0;
					/*
					 * if (mysqli_num_fields($result) == 7) {
					 * while ($row = mysqli_fetch_assoc($result)) {
					 * if ($i != 0)
					 * echo ",";
					 * $i++;
					 * echo "[";
					 * echo "'" . $row["IPBlock"] . "'" . "," . "'" . $row["Country"] . "'" . "," . "'" . $row["City"] . "'" . "," . $row["Lattitude"] . "," . $row["Longitude"] . ",'" . $row["BGP_LPM"] . "','" . $row["comment"] . "'";
					 * echo "]";
					 * }
					 * }
					 */
					if (mysqli_num_fields ( $result ) == 6) {
						while ( $row = mysqli_fetch_assoc ( $result ) ) {
							if ($i != 0)
								echo ",";
							$i ++;
							echo "[";
							echo "'" . $row ["IPBlock"] . "'" . "," . "'" . $row ["Country"] . "'" . "," . "'" . $row ["City"] . "'" . "," . $row ["Lattitude"] . "," . $row ["Longitude"] . ",'" . $row ["BGP_LPM"] . "'";
							echo "]";
						}
					} else {
						while ( $row = mysqli_fetch_assoc ( $result ) ) {
							if ($i != 0)
								echo ",";
							$i ++;
							echo "[";
							echo "'" . $row ["IPBlock"] . "'" . "," . "'" . $row ["Country"] . "'" . "," . "'" . $row ["City"] . "'" . "," . $row ["Lattitude"] . "," . $row ["Longitude"] . ",'" . $row ["BGP_LPM"] . "','" . $row ["OutageStart"] . "','" . $row ["OutageEnd"] . "'," . $row ["FrontendDataID"] . "," . $row ["Comments"];
							echo "]";
						}
					}
					echo "];";
					if (isset ( $_GET ["BGP"] ) && urldecode ( $_GET ["BGP"] ) != "") {
						echo "var bgpisset = 1;";
					} else {
						echo "var bgpisset = 0;";
					}
				}
				mysqli_free_result ( $result );
			} else {
				echo "var gettoisset = 0;";
				echo "var bgpisset = 0;";
				echo "var locations = [];";
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

				if (bgpisset == 1) {				
					$("#BGPSelect").append("<option selected='selected'>" + locations[0][5] + "</option>");
					
					var tablehead = document.getElementById("BGPTable").getElementsByTagName('thead')[0];
					var row = tablehead.insertRow(0);
					var cell1 = row.insertCell(0);
					var cell2 = row.insertCell(1);
					var cell3 = row.insertCell(2);
					var cell4 = row.insertCell(3);
					cell1.innerHTML = "<h3>IP Block</h3>";
					cell2.innerHTML = "<h3>Outage Start</h3>";
					cell3.innerHTML = "<h3>Outage End</h3>";
					cell4.innerHTML = "<h3>Comments</h3>";
					var table = document.getElementById("BGPTable").getElementsByTagName('tbody')[0];
				}

				
				var posLatList = [];
				var posLongList = [];
				for (i = 0; i < locations.length; i++) {
					found = 0;
					for (var r = 0; r<posLatList.length; r++) {
						if (posLatList[r] == locations[i][3] && posLongList[r] == locations[i][4]) {
							found = 1;
						}
					}
					if (found == 0) {
						posLatList.push(locations[i][3]);
						posLongList.push(locations[i][4]);
						var pos = new google.maps.LatLng(locations[i][3], locations[i][4]);
						marker = new google.maps.Marker({
							position: pos,
							map: map
						});
						
						google.maps.event.addListener(marker, 'mouseover', (function(marker, i) {
							return function() {
								var html = "";
								var ipList = [];
								for (j=0; j<locations.length; j++) {
									if (locations[i][3] == locations[j][3] && locations[i][4] == locations[j][4]) {
										found = 0;
										for (var q = 0; q<ipList.length; q++) {
											if (ipList[q] == locations[j][0]) {
												found = 1;					
											}
										}
										if (found == 0) {
											ipList.push(locations[j][0]);
											html = html + "<b>IP Block</b> : " + locations[j][0] + "<br/><b>Country</b> : " + locations[j][1] + "<br/><b>City</b> : " + locations[j][2] + "<br/><br/>";
										}
									}
								}
								infowindow.setContent(html);
								infowindow.open(map, marker);
							}
						})(marker, i));
						bounds.extend(marker.getPosition());
					}
					
					if (bgpisset == 0 & locations[i][5] != '-') {
						$("#BGPSelect").append("<option>" + locations[i][5] + "</option>");
					}

					if (bgpisset == 1) {
						var row = table.insertRow(i);
						var cell1 = row.insertCell(0);
						var cell2 = row.insertCell(1);
						var cell3 = row.insertCell(2);
						var cell4 = row.insertCell(3);
						cell1.innerHTML = locations[i][0];
						cell2.innerHTML = locations[i][6];
						cell3.innerHTML = locations[i][7];
						<?php if($auth->isLoggedIn()): ?>
						<?php echo "cell4.innerHTML = \"<button type=\\\"button\\\" class=\\\"btn btn-success btn-xs\\\" data-toggle=\\\"modal\\\" data-target=\\\"#AddComment\\\" data-title=\"+locations[i][8]+\" data-ipb=\"+locations[i][0]+\" data-os=\"+locations[i][6]+\" data-oe=\"+locations[i][7]+\">Add Comment</button>&nbsp&nbsp&nbsp<button type=\\\"button\\\" class=\\\"btn btn-primary btn-xs\\\" data-toggle=\\\"modal\\\" data-target=\\\"#Comments\\\" data-title=\"+locations[i][8]+\" data-ipb=\"+locations[i][0]+\" data-os=\"+locations[i][6]+\" data-oe=\"+locations[i][7]+\">View Comments (\"+locations[i][9]+\")</button>\";"?>
						<?php else: ?>
						<?php echo "cell4.innerHTML = \"<button type=\\\"button\\\" class=\\\"btn btn-primary btn-xs\\\" data-toggle=\\\"modal\\\" data-target=\\\"#Comments\\\" data-title=\"+locations[i][8]+\" data-ipb=\"+locations[i][0]+\" data-os=\"+locations[i][6]+\" data-oe=\"+locations[i][7]+\">View Comments (\"+locations[i][9]+\")</button>\";"?>
						<?php endif; ?>
						
					}
				}

			}
			else {
				if (locations.length == 0 && gettoisset == 1) {
				$("#totalPages").html("No Outages for that duration!");
			}
				$("#BGPSelect").append("<option>None</option>");
				$( "#from" ).val(minD);
				$( "#to" ).val(maxD);
				bounds.extend(new google.maps.LatLng(48.987386, -62.361014));
				bounds.extend(new google.maps.LatLng(18.005611, -124.626080));
			}

			map.fitBounds (bounds); 

			$("#Comments").on('show.bs.modal', function(event){
		        var button = $(event.relatedTarget);  // Button that triggered the modal
		        var titleData = button.data('title'); // Extract value from data-* attributes
		        var ipb = button.data('ipb');
		        var os = button.data('os');
		        var oe = button.data('oe');
		        $("#Comments").find(".modal-title").html("<b>Comments</b><br/><b>Block</b> : "+ipb+"<br/><b>Outage</b> : "+os+" - "+oe);
		        $.post("getComments.php",{fid:titleData}, function(data, status) {
		        	$("#CmntsTable").html(data);
		        });
		    });

			$("#AddComment").on('show.bs.modal', function(event){
		        var button = $(event.relatedTarget);  // Button that triggered the modal
		        var titleData = button.data('title'); // Extract value from data-* attributes
		        var ipb = button.data('ipb');
		        var os = button.data('os');
		        var oe = button.data('oe');
		        $("#AddComment").find(".modal-title").html("<b>Add Comment</b><br/><b>Block</b> : "+ipb+"<br/><b>Outage</b> : "+os+" - "+oe);
		        $("#AddCmntBtn").prop('value', titleData);
		    });

			$("#AddCmntBtn").click(function(){
				var me = $(this);
				var txt = $("#CmntTxt").val();
			    $.post("addComment.php", {fid:me.val(), comment: txt}, function(data, status) {$("#CmntTxt").val('');$("#AddComment").modal('hide');});
		    });
		}
		
		function refreshpage() {
			$("#set").val("1");
			$("#submit").val("Submit");
			$("#submit").prop("disabled",false);
			$("#totalPages").html("");
			if ($("#BGPSelect option:selected").val() == "None") {
				$("#BGP").val("");
			} else {
				$("#BGP").val($("#BGPSelect option:selected").val());
			}
		}
		
		function BGPClick() {
			if($("#BGPCheck").is(':checked')) {
				$("#BGPDiv").show();
				$('#BGPSelect :nth-child(1)').prop('selected', true);
			}
			else {
				$("#BGPDiv").hide();
			}
			$("#BGP").val("");
			refreshpage();
		}

		function DelComment(cid){
		    $.post("delComment.php", {cid:cid}, function(data, status) {$("#CmntsTable").html(data);});		    
	    }

	</script>
	<script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+'://platform.twitter.com/widgets.js';fjs.parentNode.insertBefore(js,fjs);}}(document, 'script', 'twitter-wjs');</script>
	

</head>
<body onload="initialize()">
	<nav class="navbar navbar-inverse" role="navigation">
		<div class="container-fluid">
			<div class="navbar-header">
				<button type="button" class="navbar-toggle collapsed"
					data-toggle="collapse" data-target="#navbar" aria-expanded="false"
					aria-controls="navbar">
					<span class="sr-only">Toggle navigation</span> <span
						class="icon-bar"></span> <span class="icon-bar"></span> <span
						class="icon-bar"></span>
				</button>
				<a class="navbar-brand" href="index.php">Internet Outage Database</a>
			</div>
			<div id="navbar" class="navbar-collapse collapse"
				style="line-height: 50px;">
				<ul class="nav navbar-nav navbar-right">
					<li>	<?php if(!$auth->isLoggedIn()): ?>
					<a href="<?php echo $auth->getAuthUrl(); ?>">Sign In with Google</a>
				<?php else: ?>
					<a href="logout.php">Signout (<?php echo $_SESSION['email']; ?>)</a>
				<?php endif; ?>
			</li>
				</ul>
			</div>
		</div>
	</nav>

	<div class="container-fluid" style="height: 800px">
		<div class="row">
			<div class="col-md-2">
				<form name="input" action="index.php" method="get">
					<h4>
						<label for="from">From Date : <br /></label> <input type="text" autocomplete="off"
							id="from" name="from" placeholder="From Date"
							class="form-control"><br /> <label for="to">To Date : <br /></label>
						<input type="text" autocomplete="off" id="to" name="to" placeholder="To Date"
							class="form-control"><br /> <label for="countrySelect">Country :
							<br />
						</label> <select id="countrySelect" name="country"
							class="form-control" onchange="refreshpage()">
						</select><br /> <input type="number" name="set" id="set" value="1"
							style="display: none">

						<label onclick="BGPClick()"> <input id="BGPCheck" type="checkbox"
							style="text-align: right"> Enter BGP Prefix manually?
						</label> <br /> <select id="BGPSelect" onchange="refreshpage()"
							class="form-control" style="display: none">
						</select><br />

						<div id="BGPDiv" style="display: none">
							<label for="BGP">BGP Prefix : <br /></label> <input type="text" autocomplete="off"
								name="BGP" id="BGP" placeholder="None" class="form-control"><br />
						</div>

						<input id="submit" type="submit" value="Submit"
							class="btn btn-primary"> <a href="index.php"
							style="text-align: right;">Reset</a>
					</h4>
				</form>
				<br />
				<div id="totalPages" class="text-center"></div>
			</div>
			<div class="col-md-10">
				<div id="map_canvas" style="height: 800px"></div>
			</div>
		</div>
	</div>

	<div class="container-fluid">
		<div class="col-md-2"></div>
		<div class="col-md-10">
			<table id="BGPTable" class="table">
				<thead>
				</thead>
				<tbody></tbody>
			</table>
		</div>
	</div>
	
	<div id="Comments" class="modal fade">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header">
	                <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
	                <h4 class="modal-title">Comments</h4>
	            </div>
	            <div class="modal-body">
					<table class="table">
						<thead>
							<tr><td><h4><b>User Email</b></h4></td><td><h4><b>Comment</b></h4></td><td><h4><b>Action</b></h4></td></tr>
						</thead>
						<tbody id="CmntsTable"></tbody>
					</table>
	            </div>
	            <div class="modal-footer">
	                <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
	            </div>
            </div>
        </div>
    </div>
    
    <div id="AddComment" class="modal fade">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
	            <div class="modal-header">
	                <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
	                <h4 class="modal-title">Add Comment</h4>
	            </div>
	            <div class="modal-body">
					<textarea id="CmntTxt" class="form-control" rows="3"></textarea>
	            </div>
	            <div class="modal-footer">
	                <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
	                <button id="AddCmntBtn" type="button" class="btn btn-primary">Add</button>
	            </div>
            </div>
        </div>
    </div>
    
	<hr>
	<div class="container-fluid">

		<footer class="text-right">
			<p><a href="https://twitter.com/iodbnetsec" class="twitter-follow-button" data-show-count="false">Follow @iodbnetsec</a>
			
</p>
			<p>© Network Security Lab, Colorado State University</p>
		</footer>
	</div>
</body>
</html>

