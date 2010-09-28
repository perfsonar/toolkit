<?php
/*
 +-------------------------------------------------------------------------+
 | Copyright (C) 2004-2009 The Cacti Group                                 |
 |                                                                         |
 | This program is free software; you can redistribute it and/or           |
 | modify it under the terms of the GNU General Public License             |
 | as published by the Free Software Foundation; either version 2          |
 | of the License, or (at your option) any later version.                  |
 |                                                                         |
 | This program is distributed in the hope that it will be useful,         |
 | but WITHOUT ANY WARRANTY; without even the implied warranty of          |
 | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           |
 | GNU General Public License for more details.                            |
 +-------------------------------------------------------------------------+
 | Cacti: The Complete RRDTool-based Graphing Solution                     |
 +-------------------------------------------------------------------------+
 | This code is designed, written, and maintained by the Cacti Group. See  |
 | about.php and/or the AUTHORS file for specific developer information.   |
 +-------------------------------------------------------------------------+
 | http://www.cacti.net/                                                   |
 +-------------------------------------------------------------------------+
*/

include("../include/global.php");

/* allow the upgrade script to run for as long as it needs to */
ini_set("max_execution_time", "0");

/* verify all required php extensions */
if (!verify_php_extensions()) {exit;}

$cacti_versions = array("0.8", "0.8.1", "0.8.2", "0.8.2a", "0.8.3", "0.8.3a", "0.8.4", "0.8.5", "0.8.5a", "0.8.6", "0.8.6a", "0.8.6b", "0.8.6c", "0.8.6d", "0.8.6e", "0.8.6f", "0.8.6g", "0.8.6h", "0.8.6i", "0.8.6j", "0.8.6k", "0.8.7", "0.8.7a", "0.8.7b", "0.8.7c", "0.8.7d", "0.8.7e");

$old_cacti_version = db_fetch_cell("select cacti from version");

/* try to find current (old) version in the array */
$old_version_index = array_search($old_cacti_version, $cacti_versions);

/* do a version check */
if ($old_cacti_version == $config["cacti_version"]) {
	exit;
}

function db_install_execute($cacti_version, $sql) {
	$sql_install_cache = (isset($_SESSION["sess_sql_install_cache"]) ? $_SESSION["sess_sql_install_cache"] : array());

	if (db_execute($sql)) {
		$sql_install_cache{sizeof($sql_install_cache)}[$cacti_version][1] = $sql;
	}else{
		$sql_install_cache{sizeof($sql_install_cache)}[$cacti_version][0] = $sql;
	}

	$_SESSION["sess_sql_install_cache"] = $sql_install_cache;
}

function verify_php_extensions() {
	$extensions = array("session", "sockets", "mysql", "xml");
	$ok = true;
	$missing_extension = "	Error: The following PHP extensions are missing:\n";
	foreach ($extensions as $extension) {
		if (!extension_loaded($extension)){
			$ok = false;
			$missing_extension .= " * $extension\n";
		}
	}
	if (!$ok) {
		print $missing_extension . "Please install those PHP extensions and retry\n";
	}
	return $ok;
}

/* if the version is not found, die */
if (!is_int($old_version_index)) {
	print "	Error: Invalid Cacti version: $old_cacti_version cannot upgrade to " . $config["cacti_version"] . "\n";
	exit;
}

/* loop from the old version to the current, performing updates for each version in between */
for ($i=($old_version_index+1); $i<count($cacti_versions); $i++) {
	if ($cacti_versions[$i] == "0.8.1") {
		include ("0_8_to_0_8_1.php");
		upgrade_to_0_8_1();
	}elseif ($cacti_versions[$i] == "0.8.2") {
		include ("0_8_1_to_0_8_2.php");
		upgrade_to_0_8_2();
	}elseif ($cacti_versions[$i] == "0.8.2a") {
		include ("0_8_2_to_0_8_2a.php");
		upgrade_to_0_8_2a();
	}elseif ($cacti_versions[$i] == "0.8.3") {
		include ("0_8_2a_to_0_8_3.php");
		include_once("../lib/utility.php");
		upgrade_to_0_8_3();
	}elseif ($cacti_versions[$i] == "0.8.4") {
		include ("0_8_3_to_0_8_4.php");
		upgrade_to_0_8_4();
	}elseif ($cacti_versions[$i] == "0.8.5") {
		include ("0_8_4_to_0_8_5.php");
		upgrade_to_0_8_5();
	}elseif ($cacti_versions[$i] == "0.8.6") {
		include ("0_8_5a_to_0_8_6.php");
		upgrade_to_0_8_6();
	}elseif ($cacti_versions[$i] == "0.8.6a") {
		include ("0_8_6_to_0_8_6a.php");
		upgrade_to_0_8_6a();
	}elseif ($cacti_versions[$i] == "0.8.6d") {
		include ("0_8_6c_to_0_8_6d.php");
		upgrade_to_0_8_6d();
	}elseif ($cacti_versions[$i] == "0.8.6e") {
		include ("0_8_6d_to_0_8_6e.php");
		upgrade_to_0_8_6e();
	}elseif ($cacti_versions[$i] == "0.8.6g") {
		include ("0_8_6f_to_0_8_6g.php");
		upgrade_to_0_8_6g();
	}elseif ($cacti_versions[$i] == "0.8.6h") {
		include ("0_8_6g_to_0_8_6h.php");
		upgrade_to_0_8_6h();
	}elseif ($cacti_versions[$i] == "0.8.6i") {
		include ("0_8_6h_to_0_8_6i.php");
		upgrade_to_0_8_6i();
	}elseif ($cacti_versions[$i] == "0.8.7") {
		include ("0_8_6j_to_0_8_7.php");
		upgrade_to_0_8_7();
	}elseif ($cacti_versions[$i] == "0.8.7a") {
		include ("0_8_7_to_0_8_7a.php");
		upgrade_to_0_8_7a();
	}elseif ($cacti_versions[$i] == "0.8.7b") {
		include ("0_8_7a_to_0_8_7b.php");
		upgrade_to_0_8_7b();
	}elseif ($cacti_versions[$i] == "0.8.7c") {
		include ("0_8_7b_to_0_8_7c.php");
		upgrade_to_0_8_7c();
	}elseif ($cacti_versions[$i] == "0.8.7d") {
		include ("0_8_7c_to_0_8_7d.php");
		upgrade_to_0_8_7d();
	}elseif ($cacti_versions[$i] == "0.8.7e") {
		include ("0_8_7d_to_0_8_7e.php");
		upgrade_to_0_8_7e();
	}
}

db_execute("delete from version");
db_execute("insert into version (cacti) values ('" . $config["cacti_version"] . "')");

?>
