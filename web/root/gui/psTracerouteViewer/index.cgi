#!/usr/bin/perl -w -T
#======================================================================
#
#       psTracerouteViewer index.cgi
#       $Id: index.cgi,v 1.2 2012/10/03 23:20:34 dwcarder Exp $
#
#       A cgi for viewing traceroute data stored in PerfSonar.
#
#       Written by: Dale W. Carder, dwcarder@wisc.edu
#       Network Services Group
#       Division of Information Technology
#       University of Wisconsin at Madison
#
#       Inspired in large part by traceroute_improved.cgi by Yuan Cao <caoyuan@umich.edu>
#
#       Copyright 2012 The University of Wisconsin Board of Regents
#       Licensed and distributed under the terms of the Artistic License 2.0
#
#       See the file LICENSE for details or reference the URL:
#        http://www.perlfoundation.org/artistic_license_2_0
#
#======================================================================

#TODO select measurement archive from a list.
#TODO time each operation and present it at the bottom.


#======================================================================
#    C O N F I G U R A T I O N   S E C T I O N
#

my $Script = 'index.cgi';
my $Default_mahost = 'http://localhost:8086/perfSONAR_PS/services/tracerouteMA';


#
#======================================================================
#======================================================================
#       U S E   A N D   R E Q U I R E

use lib "/opt/perfsonar_ps/toolkit/lib";
use strict;
use psTracerouteUtils;
use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);
use Date::Manip;
use Socket;
use Socket6;
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use Data::Dumper;
use DateTime::TimeZone;
use POSIX qw(tzset);

#
#======================================================================


#======================================================================
#       F U N C T I O N   P R O T O T Y P E S

sub parseInput();
sub lookup($;$);
sub displayTrData();
sub displayTop();
sub displaySelectBox();
sub utcOffset($);

#
#======================================================================


#======================================================================
#       G L O B A L S
my $mahost;     # measurement archive host url
my $stime;      # start time passed in 
my $etime;      # end time passed in 
my $epoch_stime;        # start time in unix epoch
my $epoch_etime;        # end time in unix epoch
my %endpoint;   # measurement endpoints
my $epselect;   # endpoint selection
my $donotdedup; # deduplication checkbox
my %dnscache;   # duh

#
#======================================================================



#======================================================================
#       M A I N 

parseInput();

my $ma_result = GetTracerouteMetadataFromMA($mahost,$epoch_stime,$epoch_etime);
ParseTracerouteMetadataAnswer($ma_result,\%endpoint);


# print http header
print("Content-Type: text/html;\n\n");


displayTop();

if ( scalar(keys((%endpoint))) < 1 ) {
        print "<b><font color=\"red\">Error: No Measurement Archives available.</font></b>\n<br>\n";

} else {

        displaySelectBox(); 

   	if ($epselect ne 'unselected') {
        	displayTrData();
	}
}

#print "<br><br><hr>$Ver<br>\n";
print "<br><br>";

exit();



#=============  B E G I N   S U B R O U T I N E S  =============================


# Sanity Check all cgi input, and set defaults if none are given
sub parseInput() {

        # measurement archive url
        if (defined(param("mahost"))) {
                if (param("mahost") =~ m/^[0-9a-zA-Z\/:_\.\-]+$/) {
                         $mahost = param("mahost");
                } else { 
                        die("Illegal characters in measurement archive host url.");
                }
        } else {
                $mahost = $Default_mahost;
        }

        # start time
        if (defined(param("stime"))) {
                if (param("stime") =~ m/^[0-9a-zA-Z: \/]+$/) {
                        $stime = param("stime");
                        $epoch_stime = UnixDate(ParseDate($stime),"%s");
                } else {
                        die('Illegal start time: ' . param('stime'));
                }
        } else {
                # default to last 24 hours
                #$epoch_stime = UnixDate(ParseDate("now"),"%s") - 86400;
                #$stime = ParseDateString("epoch $epoch_stime");
                $stime = "yesterday";
                $epoch_stime = UnixDate(ParseDate($stime),"%s");
        }

        # end time
        if (defined(param("etime"))) {
                if (param("etime") =~ m/^[0-9a-zA-Z: \/]+$/) {
                        $etime = param("etime");
                        $epoch_etime = UnixDate(ParseDate($etime),"%s");
                } else {
                        die("Illegal end time.");
                }
        } else {
                $etime = "now";
                $epoch_etime = UnixDate(ParseDate($etime),"%s");
        }
        
        if ($epoch_stime >= $epoch_etime) { 
                die("Start time $epoch_stime is after end time $epoch_etime.");
        }

        if (defined(param('epselect'))) {
                if (param('epselect') =~ m/[0-9a-z]/ ) {
                        $epselect = param('epselect');
                } else {
                        $epselect = "unselected";
                }
        } else {
		$epselect = "unselected";
	}

        # deduplication checkbox
        if (defined(param('donotdedup'))) {
                if (param('donotdedup') eq 1) {
                        $donotdedup = 1;
                } 
        } else {
                $donotdedup = 0;
        }

	# timezone support
	my $tz = DateTime::TimeZone->new(name=>'local');
	$ENV{TZ} = $tz->name;
	if (defined(param('tzselect'))) {
		if (param('tzselect') =~ m/^[0-9a-zA-Z:\/_\-]+$/ ) {
			#my $zone = param('tzselect');
			#my $tz = DateTime::TimeZone->new(name=>$zone);
			#$ENV{TZ} = $tz->name;
			$ENV{TZ} = param('tzselect');
		}
	} 
	tzset;

}



# given something, return the opposite 
sub lookup($;$) {
        my $thing = shift;
        my $af = shift;
        my $r;

        if (defined($dnscache{$thing})) {
                return $dnscache{$thing};
        }

        if (is_ipv4($thing)) {
                $r = gethostbyaddr(inet_pton(AF_INET,$thing),AF_INET);

        } elsif (is_ipv6($thing)) {
                $r = gethostbyaddr(inet_pton(AF_INET6,$thing),AF_INET6);

        # assume we're given a name, and a preference
        } elsif (defined($af)) {
                my $n = scalar(gethostbyname2($thing,$af));
                if (defined($n)) {
                        $r = inet_ntop($af,$n);
                }
        }

        if (defined($r)) { 
                $dnscache{$thing} = $r;
                return $r;      
        } else {
                return " ";
        }
}


sub displayTrData() {

   # display traceroute data

        my $trdata = GetTracerouteDataFromMA($mahost,$epselect,$epoch_stime,$epoch_etime);

        #print Dumper($trdata);

        my %topology;
        DeduplicateTracerouteDataAnswer($trdata,\%topology,$donotdedup);

      #print "<pre>\n";
        #print Dumper(%topology);
      #print "</pre>\n";

      foreach my $time (sort keys %topology) {
              my $humantime = scalar(localtime($time));
              print "<h3>Topology beginning at $humantime (" . utcOffset($ENV{'TZ'}) .")</h3><blockquote>\n";
              print "<table border=1 cellspacing=0 cellpadding=3>\n";
              print "<tr><th>Hop</th><th>Router</th><th>IP</th></tr>\n";
              foreach my $hopnum (sort { $a <=> $b } keys %{$topology{$time}} ) {
                      my $sayecmp=" ";
                      foreach my $router (keys %{$topology{$time}{$hopnum}}) {
                              # detect if this hop has more than router
                              my $name = $router;
                              if (scalar(keys %{$topology{$time}{$hopnum}}) > 1) { $sayecmp = "(<b>ECMP</b>)"; }
                              if (lookup($router) ne ' ') {
                                      $name = lookup($router); 
                              }
                              print "<tr><td>$hopnum $sayecmp</td><td>$name</td><td>$router</td></tr>\n";
                      }
              }
              print "</table></blockquote>";
      }
   
} # end displayTrData()


sub displaySelectBox() {

   my $html3=<<EOM;
   Select endpoints available on  $mahost<br>
   <select name="epselect">
   <option value="unselected">Select one ...
EOM
   print $html3;


   foreach my $id (keys %endpoint) {

      my $srchost;
      my $dsthost;

      # some logic to do dns lookups as needed to make the select field human friendly
      if ($endpoint{$id}{'srctype'} =~ m/ipv[46]/ ) {
              $srchost = lookup($endpoint{$id}{'srcval'}) . ' ('. $endpoint{$id}{'srcval'} . ')' ;

      } else { # we have a hostname, but want the ip
              if ($endpoint{$id}{'dsttype'} eq 'ipv6') {
                      $srchost = $endpoint{$id}{'srcval'} . ' ('. lookup($endpoint{$id}{'srcval'},AF_INET6) .') ';
              }else{
                      $srchost = $endpoint{$id}{'srcval'} . ' ('. lookup($endpoint{$id}{'srcval'},AF_INET) .') ';
              }
      }

      if ($endpoint{$id}{'dsttype'} =~ m/ipv[46]/ ) {
              $dsthost = lookup($endpoint{$id}{'dstval'}) . ' ('. $endpoint{$id}{'dstval'} . ')' ;

      } else { # we have a hostname, but want the ip, try to guess v4 or v6
          if ($endpoint{$id}{'srctype'} eq 'ipv6') {
              $dsthost = $endpoint{$id}{'dstval'} . ' ('. lookup($endpoint{$id}{'dstval'},AF_INET6) .') ';
          } else{
              $dsthost = $endpoint{$id}{'dstval'} . ' ('. lookup($endpoint{$id}{'dstval'},AF_INET) .') ';
          } 
      }

      # determine if something was already selected or not.
      my $selected=" ";
      if ($id eq $epselect) { $selected="selected=\"selected\""; }
      print "<option value=\"$id\" $selected > $srchost ---->  $dsthost \n";
   }

   # see if the checkbox should be selected
   my $dedupsel = " ";
   if ($donotdedup) { 
      $dedupsel = "checked=\"yes\""; 
   } 

   my $html2=<<EOM;
   </select><br>
   <input type="checkbox" name="donotdedup" value="1" $dedupsel>Do not de-duplicate results &nbsp;
   <input type="submit" value="Submit query">
   </form>

EOM
   print $html2;

} #end displaySelectBox()



sub displayTop() {
      my $ma_size = length($mahost) + 10;

      # print some html
      my $html1 =<<EOM;
      <html>
      <head>
       <META NAME="robots" CONTENT="noindex,nofollow">
       <title>psTracerouteViewer</title>
       <style type="text/css">\@import url(jscalendar/calendar-win2k-1.css);</style>
       <script type="text/javascript" src="jscalendar/calendar.js"></script>
       <script type="text/javascript" src="jscalendar/lang/calendar-en.js"></script>
       <script type="text/javascript" src="jscalendar/calendar-setup.js"></script>
      </head>

      <h2>psTracerouteViewer</h2>

    <table border=0 width="100%">
    <tr>
    <td valign="top">
      <form name="query1" method="get" action="$Script">
      Measurement Archive: <input type="text" name="mahost" value="$mahost" size="$ma_size"> <br>

      Start Time: <input type="text" id="stime" name="stime" value="$stime" size="18"> 
      <img src="calendaricon.jpg" id="s_trigger" border=0>
      <script type="text/javascript">
         Calendar.setup({
              inputField     :    "stime",           
              ifFormat       :    "%m/%d/%Y %I:%M %p",
              showsTime      :    true,
              button         :    "s_trigger",       
              step           :    1
         });
      </script><br>


      End Time: &nbsp;<input type="text" id="etime" name="etime" value="$etime" size="18">
      <img src="calendaricon.jpg" id="e_trigger" border=0>
      <script type="text/javascript">
         Calendar.setup({
              inputField     :    "etime",           
              ifFormat       :    "%m/%d/%Y %I:%M %p",
              showsTime      :    true,
              button         :    "e_trigger",        
              step           :    1
         });
      </script>
      <br>

EOM
      print $html1;

	# timezone support
	#print "tz=" . $ENV{TZ} . "<br>\n";
	print "Timezone: <select name=\"tzselect\">\n";
	foreach my $tz (DateTime::TimeZone->all_names) {
		my $tz_selected = " ";
		if ($tz eq $ENV{'TZ'}) { $tz_selected = "selected=\"selected\""; }


		print "<option $tz_selected value=\"$tz\">$tz &nbsp; (" . utcOffset($tz) . ")</option>\n";
	}

	print "</select>\n";

 	my $html11=<<EOM;
	<input type="submit" value="Query MA">
	</td><td valign="top">
	<center>
	<a href="http://www.wisc.edu" border=0><img src="uwm.gif"></a><br>
	<br>
	Maintained by <a href="http://net.doit.wisc.edu/~dwcarder">Dale W. Carder</a><br>
	Get the <a href=\"https://github.com/dwcarder/psTracerouteViewer\">source!
	</center>
	</td></tr></table>

	<br><hr>

EOM
	print $html11;

} #end displayTop();


sub utcOffset($) { 

	my $tz = shift;

	# figure out the offset from gmt
	my $t = DateTime::TimeZone->new(name => $tz);
	my $now = DateTime->now;
	my $offset = $t->offset_for_datetime($now);
	$offset = $offset / 60 / 60;
	if ($offset > 0) { $offset = "UTC +" . $offset; } 
	elsif ($offset == 0) { $offset = "UTC"; } 
	else { $offset = "UTC $offset"; }

	return($offset);

} # end utcOffset

