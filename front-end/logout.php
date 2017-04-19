<?php

require_once 'app/init.php';
$googleClient = new Google_Client;
$auth = new GoogleAuth(null, $googleClient);
$auth->killSession();

if(session_destroy())
{
header("Location: index.php");
}
?>
