#!/usr/bin/perl -w -T
#======================================================================
#
#       psTracerouteViewer index.cgi
#
#       A cgi for viewing traceroute data stored in PerfSonar.
#
#		Version 2, with support for revised psTracerouteUtils lib w/
#                  esmond support, and mtu reporting.
#
#       Written by: Dale W. Carder, dwcarder@wisc.edu
#       Network Services Group
#       Division of Information Technology
#       University of Wisconsin at Madison
#
#       Inspired in large part by traceroute_improved.cgi by Yuan Cao <caoyuan@umich.edu>
#
#       Copyright 2014 The University of Wisconsin Board of Regents
#       Licensed and distributed under the terms of the Artistic License 2.0
#
#       See the file LICENSE for details or reference the URL:
#        http://www.perlfoundation.org/artistic_license_2_0
#
#======================================================================

#TODO time each operation and present it at the bottom.


#======================================================================
#    C O N F I G U R A T I O N   S E C T I O N
#

my $Script = 'index.cgi';
my $Default_mahost = 'http://localhost/esmond/perfsonar/archive/';


#
#======================================================================
#======================================================================
#       U S E   A N D   R E Q U I R E

use lib "/usr/lib/perfsonar/lib";
use strict;
use psTracerouteUtils 2.0;
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

# print http header
print("Content-Type: text/html;\n\n");

parseInput();

print "<input type='hidden' name='s' value='$epoch_stime'>\n";
print "<input type='hidden' name='e' value='$epoch_etime'>\n";

displayTop();

my $msg = GetTracerouteMetadata($mahost,$epoch_stime,$epoch_etime,\%endpoint);

if ( scalar(keys((%endpoint))) < 1 ) {
	unless(defined($msg)) { $msg = '&nbsp'; }
       	print "<b><font color=\"red\">Error: No Measurement Archives available.<br>$msg</font></b>\n<br>\n";

} else {

        displaySelectBox(); 

   	if ($epselect ne 'unselected') {
        	displayTrData();
	}
}

print "<br><br>";

exit();



#=============  B E G I N   S U B R O U T I N E S  =============================


# Sanity Check all cgi input, and set defaults if none are given
sub parseInput() {

	# timezone support
	my $tz;
	# It turns out that DateTime::TimeZone can die() if it can't
	# figure out the timezone.  Instead, catch that and set a default.
	# http://code.google.com/p/perfsonar-ps/issues/detail?id=819
	eval { $tz = DateTime::TimeZone->new(name=>'local'); };
	if ( $@ ) {
		$ENV{TZ} = "America/Chicago";
	} else {	
		$ENV{TZ} = $tz->name;
	}
	if (defined(param('tzselect'))) {
		if (param('tzselect') =~ m/^[0-9a-zA-Z:\/_\-]+$/ ) {
			$ENV{TZ} = param('tzselect');
		}
	} 
	tzset;

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
                if (param('epselect') =~ m/^[0-9a-zA-Z\-\/]+$/ ) {
                        $epselect = param('epselect');
                } else {
                        die("Illegal endpoint selection: " . param('epselect'));
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
}



# given something, return the opposite 
sub lookup($;$) {
        my $thing = shift;
        my $af = shift;
        my $r;

        if (defined($af)) {
           if (defined($dnscache{$af}{$thing})) {
               return $dnscache{$af}{$thing};
           }
        } elsif (defined($dnscache{$thing})) {
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
			if (defined($af)) {
				$dnscache{$af}{$thing} = $r;
			} else {
                $dnscache{$thing} = $r;
			}
            return $r;      
        } else {
                return " ";
        }
}


sub displayTrData() {

   # display traceroute data

        my %topology;
		my $msg  = GetTracerouteData($mahost,$epselect,$epoch_stime,$epoch_etime,\%topology);
		if (defined($msg) && $msg ne '') {
			print "<font color='red'>Error: $msg</font><p>";
		}

		unless($donotdedup) {
			my %new_topology;
			DeduplicateTracerouteData(\%topology,\%new_topology);
			undef(%topology);
			%topology = %new_topology;
		}

      #print "<pre>\n";
        #print Dumper(%topology);
      #print "</pre>\n";

      foreach my $time (sort keys %topology) {
              my $humantime = scalar(localtime($time));
              print "\n\n<h3>Topology beginning at $humantime (" . utcOffset($ENV{'TZ'}) .")</h3><blockquote>\n";
	      print "<input type='hidden' name='t' value='$time'>\n";
              print "<table border=1 cellspacing=0 cellpadding=3>\n";
              print "<tr><th>Hop</th><th>Router</th><th>IP</th><th>Delay</th><th>MTU</th></tr>\n";
              foreach my $hopnum (sort { $a <=> $b } keys %{$topology{$time}} ) {
                      my $sayecmp=" ";
                      foreach my $router (keys %{$topology{$time}{$hopnum}}) {
                              # detect if this hop has more than router
                              my $name = $router;
                              if (scalar(keys %{$topology{$time}{$hopnum}}) > 1) { $sayecmp = "(<b>ECMP</b>)"; }
                              if (lookup($router) ne ' ') {
                                      $name = lookup($router); 
                              }
							  
						      # handle RTT and MTU
							  my $mtu = '&nbsp;';
							  my $rtt = '&nbsp;';
							  if (defined($topology{$time}{$hopnum}{$router}) && $topology{$time}{$hopnum}{$router} != 1){
								  $mtu = $topology{$time}{$hopnum}{$router}{'mtu'} if defined $topology{$time}{$hopnum}{$router}{'mtu'};
								  $rtt = $topology{$time}{$hopnum}{$router}{'rtt'} . 'ms' if defined $topology{$time}{$hopnum}{$router}{'rtt'};
							  } 
								 
                              print "<tr><td>$hopnum $sayecmp</td><td>$name</td><td>$router</td><td>$rtt</td><td>$mtu</td></tr>\n";
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

   my %options;

   foreach my $id (keys %endpoint) {

      my $srchost;
      my $dsthost;

      # some logic to do dns lookups as needed to make the select field human friendly
      if ($endpoint{$id}{'srctype'} =~ m/ipv[46]/ ) {
              $srchost = lookup($endpoint{$id}{'srcval'}) . ' ('. $endpoint{$id}{'srcval'} . ')' ;

      } else { # we have a hostname, but want the ip
              if ($endpoint{$id}{'dsttype'} eq 'ipv6') {
                      $srchost = $endpoint{$id}{'srcval'} . ' ('. lookup($endpoint{$id}{'srcval'},AF_INET6) .') ';

			  # so, now we have to guess if this is a v4 or v6 host.  prefer v6 like a typical host.
              } elsif (lookup($endpoint{$id}{'srcval'},AF_INET6) ne ' ' && lookup($endpoint{$id}{'dstval'},AF_INET6) ne ' ') {
                      $srchost = $endpoint{$id}{'srcval'} . ' ('. lookup($endpoint{$id}{'srcval'},AF_INET6) .') ';
			  } else {
                      $srchost = $endpoint{$id}{'srcval'} . ' ('. lookup($endpoint{$id}{'srcval'},AF_INET) .') ';
              }
      }

      if ($endpoint{$id}{'dsttype'} =~ m/ipv[46]/ ) {
              $dsthost = lookup($endpoint{$id}{'dstval'}) . ' ('. $endpoint{$id}{'dstval'} . ')' ;

      } else { # we have a hostname, but want the ip
          if ($endpoint{$id}{'srctype'} eq 'ipv6') {
              $dsthost = $endpoint{$id}{'dstval'} . ' ('. lookup($endpoint{$id}{'dstval'},AF_INET6) .') ';

		  # so, now we have to guess if this is a v4 or v6 host.  prefer v6 like a typical host.
		  } elsif (lookup($endpoint{$id}{'dstval'},AF_INET6) ne ' ' && lookup($endpoint{$id}{'srcval'},AF_INET6) ne ' ') {
              $dsthost = $endpoint{$id}{'dstval'} . ' ('. lookup($endpoint{$id}{'dstval'},AF_INET6) .') ';
          } else{
              $dsthost = $endpoint{$id}{'dstval'} . ' ('. lookup($endpoint{$id}{'dstval'},AF_INET) .') ';
          } 
      }

      # determine if something was already selected or not.
      my $selected=" ";
      if ($id eq $epselect) { $selected="selected=\"selected\""; }
	  $options{"$srchost ---->  $dsthost"} = "<option value=\"$id\" $selected >";
   }

	foreach my $srcdst (sort keys(%options)) {
		print $options{$srcdst} . $srcdst . "\n" ;
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
       <title>psTracerouteViewer v2</title>
       <style type="text/css">\@import url(jscalendar/calendar-win2k-1.css);</style>
       <script type="text/javascript" src="jscalendar/calendar.js"></script>
       <script type="text/javascript" src="jscalendar/lang/calendar-en.js"></script>
       <script type="text/javascript" src="jscalendar/calendar-setup.js"></script>
      </head>

      <h2>psTracerouteViewer v2</h2>

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

