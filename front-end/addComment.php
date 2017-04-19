<?php
require_once 'app/init.php';

$db = new DB ();

$sql = "SELECT UserID FROM GoogleUsers WHERE GoogleID = " . $_SESSION['google_id'];
$result = $db->query ( $sql );
$row = mysqli_fetch_assoc ( $result );
$UserID = $row['UserID'];

echo $UserID;
$sql = "INSERT INTO Comments (`UserID`, `FrontenDataID`, `CommentText`) VALUES (" . $UserID . ", " . $_POST['fid'] . ",'" . $_POST['comment'] . "')";
$result = $db->query ( $sql );
?>