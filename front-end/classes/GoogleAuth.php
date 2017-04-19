<?php

const CLIENT_ID = '409139447429-uc664h8asn780f6ckfi2vh9j00d1689p.apps.googleusercontent.com';
const CLIENT_SECRET = 'faeOFJt-FZ3KZAo-1FlKoXnT';
const APPLICATION_NAME = "IODB";

class GoogleAuth {
	protected $db;
	protected $client;
	
	public function __construct( DB $db = null, Google_Client $googleClient = null) {
		$this->db = $db;
		$this->client = $googleClient;
		
		if ($this->client) {
			$this->client->setApplicationName(APPLICATION_NAME);
			$this->client->setClientId(CLIENT_ID);
			$this->client->setClientSecret(CLIENT_SECRET);
			$this->client->setRedirectUri('http://iodb.netsec.colostate.edu/index.php');
			$this->client->setScopes('email');
		}
	}

	public function isLoggedIn() {
		return isset($_SESSION['access_token']);
	}

	public function getAuthUrl() {
		return $this->client->createAuthUrl();
	}

	public function checkRedirectCode() {
		if (isset($_GET['code'])) {
			$this->client->authenticate($_GET['code']);
			$this->setToken($this->client->getAccessToken());
			$payload = $this->getPayload();
			$_SESSION['google_id'] = $payload['sub'];
			$_SESSION['email'] = $payload['email'];
			$this->storeUser($payload);
			return true;
		}
		return false;
	}

	public function getEmail() {
		return $this->email;
	}

	public function setToken($token) {
		$_SESSION['access_token'] = $token;
		$this->client->setAccessToken($token);
	}

	protected function getPayload() {
		$payload = $this->client->verifyIdToken()->getAttributes()['payload'];
		//echo '<pre>', print_r($payload), '</pre>';

		return $payload;
	}

	protected function storeUser($payload) {
		$sql = "INSERT INTO GoogleUsers (GoogleID, Email)
			VALUES ({$payload['sub']}, '{$payload['email']}')
			ON DUPLICATE KEY UPDATE UserID = UserID";

		$this->db->query($sql);

	}

	public function killSession() {
		$this->client->revokeToken($_SESSION['access_token']);
	}
}
