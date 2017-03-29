<?php
require_once 'app/init.php';

$db = new DB ();

$UserID = '';

if (isset($_SESSION['google_id'])) {
	$sql = "SELECT UserID FROM GoogleUsers WHERE GoogleID = " . $_SESSION['google_id'];
	$result = $db->query ( $sql );
	$row = mysqli_fetch_assoc ( $result );
	$UserID = $row['UserID'];
	mysqli_free_result($result);
}

$sql = "SELECT Comments.CommentID, Comments.UserID, CommentText, Email FROM Comments JOIN GoogleUsers ON Comments.UserID = GoogleUsers.UserID JOIN FrontendData ON Comments.FrontenDataID = FrontendData.FrontendDataID WHERE FrontendData.FrontendDataID = " . $_POST['fid'];
$result = $db->query ( $sql );

if (mysqli_num_rows ( $result ) == 0) {
	echo "<h4>No Comments!</h4>";
} else {
	while ($row = mysqli_fetch_assoc ( $result )) {
		if ($UserID == $row['UserID']) {
			echo "<tr><td><b>" . $row["Email"] . " (You) </b></td><td>" . $row["CommentText"] . "</td><td><button type=\"button\" class=\"btn btn-default btn-xs DelCmntBtn\" aria-label=\"Delete\" onclick=\"DelComment('" . $row["CommentID"] . "')\"><span class=\"glyphicon glyphicon-remove\" aria-hidden=\"true\" style=\"color:red\"></span></button></td></tr>";
		} else {
			echo "<tr><td><b>" . $row["Email"] . "</b></td><td>" . $row["CommentText"] . "</td><td></td></tr>";
		}
	}
}
?>