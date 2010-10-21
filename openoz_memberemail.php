<?php

/* For creating JSON result with array of member email addresses and member names.

	Just postcode. 


Test cases: 
 > single constituency
 > multiple constituency

Error condition test cases: 
 > no postcode match
 > 

*/

include_once "../../includes/easyparliament/init.php";
include_once INCLUDESPATH."easyparliament/member.php";

// From http://cvs.sourceforge.net/viewcvs.py/publicwhip/publicwhip/website/
include_once INCLUDESPATH."postcode.inc";
include_once INCLUDESPATH . 'technorati.php';
include_once '../api/api_getGeometry.php';
include_once '../api/api_getConstituencies.php';

twfy_debug_timestamp("after includes");

$errors = array();
$members = array();


if (stristr($_SERVER["HTTP_ACCEPT"], "application/json")) {
   header("Content-type: application/json;charset=utf-8");
} else {
   header("Content-type: text/json;charset=utf-8");
}


// Some legacy URLs use 'p' rather than 'pid' for person id. So we still
// need to detect these.
$pid = get_http_var('pid') != '' ? get_http_var('pid') : get_http_var('p');
$name = strtolower(str_replace(array('_'), array(' '), get_http_var('n')));
$cconstituency = strtolower(str_replace(array('_','.',' and '), array(' ','&amp;',' &amp; '), get_http_var('c'))); # *** postcode functions use global $constituency!!! ***

// CHECK SUBMITTED POSTCODE - only does postcode
if (get_http_var('postcode') != '') {

	// jsonp callback function
	// http://remysharp.com/2007/10/08/what-is-jsonp/
	$jsonp_callback = get_http_var('jsonp_callback');	

	// User has submitted a postcode, so we want to display that. 
	$pc = get_http_var('postcode');
	$pc = preg_replace('#[^a-z0-9 ]#i', '', $pc);
	if (validate_postcode($pc)) {
		twfy_debug ('MP', "MP lookup by postcode");
		# Only do lookup of constituency via postcode if the constituency isn't set
		if ($cconstituency == "")
			$constituency = postcode_to_constituency($pc);
		else
			$constituency = $cconstituency;
		if ($constituency == "connection_timed_out") {
			$errors['pcerr'] = "Sorry, we couldn't check your postcode right now, as our postcode lookup server is under quite a lot of load. Please use the 'All MPs' link above to browse all the MPs.";
		} elseif ($constituency == "") {
			$errors['pcerr'] = "Sorry, ".htmlentities($pc) ." isn't a known postcode.";
			twfy_debug ('MP', "Can't display an MP, as submitted postcode didn't match a constituency");
		} elseif (is_array($constituency)) {
			# @@JR
			# Collect the member names and email addresses 
			foreach ($constituency as $c) {
				$member = new MEMBER(array('constituency' => $c));
				$member_email = $member->email();
				$members[$member_email] = $member->full_name();
			}

		} else {
			$member = new MEMBER(array('constituency' => $constituency));
			$member_email = makeMemberEmail($member);
			$members[$member_email] = $member->full_name();
		}
	} else {
		$errors['pcerr'] = "Sorry, ".htmlentities($pc) ." isn't a valid postcode";
		twfy_debug ('MP', "Can't display an MP because the submitted postcode wasn't of a valid form.");
	}

	if (sizeof($errors) > 0) {
		echo $jsonp_callback . '(' . json_encode($errors) . ')';
	} else {
		echo $jsonp_callback . '(' . json_encode($members) . ')';
	}
}

# Format is f.surname.MP@aph.gov.au
function makeMemberEmail($member) {
	$names = explode(' ', $member->full_name());
	$member_email = substr($names[0], 0, 1) . '.' . $names[1] .  '.MP@aph.gov.au';
	return $member_email;
}

?>
