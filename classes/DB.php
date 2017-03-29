<?php

class DB {
	public $mysqli;

	public function __construct() {
		$this->mysqli = new mysqli('proton.netsec.colostate.edu', 'iyerro', 'rohit533', 'iodbFrontEnd');
	}

	public function query($sql) {
		return $this->mysqli->query($sql);
	}
}
