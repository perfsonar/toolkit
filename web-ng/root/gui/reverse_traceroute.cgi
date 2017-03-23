#!/usr/bin/perl -w
###############################################################################
use strict;
$ENV{PATH}='/bin:/usr/bin:/sbin:/usr/local/bin:/usr/local/etc:/usr/sbin:/usr/local/sbin';#For untainting
my $t00=time();
########################## Testing ##############################################
# For testing from command line you need to set some environment variables, 
# e.g. assuming you are using the tcsh shell
# setenv REQUEST_URI /cgi-wrap/traceroute.pl
# setenv QUERY_STRING 'target=www.slac.stanford.edu&function=ping'
#For IPv4
# setenv QUERY_STRING www.cern.ch;  setenv REMOTE_HOST www.google.com
# setenv REMOTE_ADDR 72.14.204.105; setenv SERVER_NAME www.slac.stanford.edu
#For IPv6
# setenv QUERY_STRING 'target=ipv6.google.com'; setenv REMOTE_HOST ipv6.google.com 
# setenv REMOTE_ADDR 2a00:1450:8007::6a;        setenv SERVER_NAME ui2-4.dir.garr.it
# #To find the IPv6 address of a host use
# #dig ipv6.google.com -t AAAA
# You will also need to include the -T option in the command line if you want to
# use the perl -d debug facility, i.e. you need to use:
# perl -d -T traceroute.pl
# REMOTE_HOST, REMOTE_ADDR are the name and IP address of the client/browser
# SERVER_NAME is the name of the web server,
# QUERY_STRING is the name or IP address of the host to be probed.

################################################################################
# Put out header right at start to ensure it precedes any errors or bug reports.
# To enable line-buffered output (more interactive output), change the name
# of this script to nph-traceroute.pl or use a Unix logical link.
select(STDOUT);  $| = 1;	# Flush output after each print
my $msg="";
if ($0 =~ /nph-/) {
   $msg="$ENV{SERVER_PROTOCOL} 200 OK\nServer: $ENV{SERVER_SOFTWARE}\n";
}
#Get this out first so can get out error messages
print $msg."Content-type: text/html\n\n";
my $version="7.0, 7/30/2016, Les Cottrell";
# Print server user name (e.g. apache) if max_processes exceeded
# Increase to 2 the debug value to exceed if we are to  print the process list 
# following max_processes exceeded.  It caused confusion since it looked
# like instead of traceroute ps was being executed.
# Released to perfSONAR
###############################################################################
#Understand the local environment
use Cwd;
my $AF_INET=2;
my $debug=0;
(my $progname = $0) =~ s'^.*/'';
my $uid=scalar(getpwuid($<));
#Get fully qualified IP address of the local host
use Net::Domain qw(hostname hostfqdn hostdomain);
my $hostname = hostfqdn();
my $ipv="4";#set default used by gethostbyname6 to decide if to force IPv6
my $ipaddr=gethostbyname6($hostname);
my $site="";#Allows us to special case SLAC's configuration
if($hostname=~/\.slac\.stanford\.edu/) {$site="slac";}
my $archname=$^O;
########################## Get the form action field #########################
#$form allows one to use a different form action field, e.g.
#REQUEST_URI is of the form: /cgi-bin/traceroute.pl?choice=yes
my ($temp, $bin_dir);
($temp,$bin_dir,$temp)=split /\//,$ENV{'REQUEST_URI'};
my $form="<form action='$progname' method='GET'>";
if($debug>0) {
  print "REQUEST_URI=$ENV{'REQUEST_URI'}, bin_dir=$bin_dir, form=$form<br>\n";
}
# **********************  tailor first section as required:- *****************
# Traceroute options can be customized to reduce (or increase) impact
# There is no need to set @Tropts unless one is using non-defaults.
my @Tropts=qw(-m 30 -q 3); # equivalent default options for traceroute
my $start=""; #default value.
my $max_processes=11;# Maximum # of simultaneously running traceroute processes
                  # 10 gave no alerts for several weeks in May 2000. Set to a
                  # large number if you don't care. Extended from 9 to 11 on
	          # 9/13/00 since getting a few alerts per day (5-6 yesterday,
	          # though that was a record, I think).
#$to contains the email address(es) to send the warning of too many processes
# If you don't want an email warning if too many processes are running then
# set $to to ""
my $to=""; # Default, no email will be sent and none of the tailoring
	   # variables following $to below will be used.
my $mail="/usr/ucb/mail"; #mail client on this host
my $mail_help="/u/sf/cottrell/lib/traceroute.list"; #help type information to go
                  #with email message
# ************** end of first part of tailoring *********************
my $Sy;
my $Tr = 'traceroute'; # Usually works
################# SLAC site specific ##################################
if($site eq "slac") {
  if($archname eq "solaris") {
    $Sy="/afs/slac/package/pinger/old/synack/sun4x_56/synack";
  }
  else {
    $Sy ="/afs/slac/package/pinger/old/synack/i386_linux22/synack";
    @Tropts = qw(-m 30 -q 1 -w 3 -A);#options for SLAC traceroute, comment if uncertain
  }
  $to="cottrell\@slac.stanford.edu,ben.calvert\@slac.stanford.edu";
}
else {$Sy=$Tr;} #Only support synack at SLAC
#######################################################################
my $timeout=0.05/24; # Don't send 2nd email item if previous sent in < timeout hrs
my $err="";
my $errhead='</pre><font color="magenta"><b><i>';
my $errtail="</font></i></b>";
my $warn="";
my $addr = $ENV{'REMOTE_ADDR'}; $addr=~s/\s+//g;
my $host = $addr;
###############################################################################
# if we're being accessed via a proxy that passes the client's address:
# For more on this see: http://www.zope.org/Members/TWilson/GettingVisitorsIP
# Note if using ssl and going through a firewall/NAT then,
# because of encryption, it may not be
# possible for the firewall/NAT to add the http header for HTTP_X_FORWARDED_FOR
my $oldaddr=$addr;
if (defined $ENV{'HTTP_X_FORWARDED_FOR'}) {
  $addr = $ENV{'HTTP_X_FORWARDED_FOR'};
  $addr =~ s/,.*$//;  # if address1, address2, ... keep only address1
  #if($addr=~/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) {
  my $valid_ip=valid_ip($addr);
  if($valid_ip eq "4" || $valid_ip eq "6") {
    if($valid_ip eq "4" && private($addr)) { 
      $warn.="Proxy provided a private IPv4 address for your web client/browser,"
          . " HTTP_X_FORWARDED_FOR=$ENV{'HTTP_X_FORWARDED_FOR'}<br>\n";
      $addr=$oldaddr;#Private address restore original address
    }     
    $host = gethostbyaddr(pack('C4',split(/\./,$addr)),$AF_INET);
  }
  else {
    $warn.="Proxy provided an invalid IP address for your web client/browser,"
         . " HTTP_X_FORWARDED_FOR=$ENV{'HTTP_X_FORWARDED_FOR'}<br>\n";
  }
}
###########################################################################
# Process QUERY_STRING if present. QUERY_STRING may contain the target host.
my $query="";
if (defined($ENV{'QUERY_STRING'}) && $ENV{'QUERY_STRING'} ne '') {
  unless($ENV{'QUERY_STRING'} eq "choice=yes") {
    $query = $ENV{'QUERY_STRING'};  # might be an IP address or a name
    if(length($query)>300) {#sanity check to prevent overflows
      print "QUERY_STRING is > 300 characters\n";
      exit 6;
    }
    $host = '';  # not so nice, but anyway...
  }
}
############################################################################
#Get optional information from QUERY_STRING, if supplied
my $function;#Allows us to either ping or traceroute or tracepath
if($progname =~ /ping/)          {$function="ping";}
elsif ($progname =~ /tracepath/) {$function="tracepath";} 
else                             {$function="traceroute";}
my @pairs=split(/&/,$query);
my $ping_size="56";
my $probe=""; #Can be overwritten (to -I) by probe=ICMP for traceroute
my @options=();
foreach my $pair (@pairs) {
  my ($name,$value)=split(/=/,$pair);
  $name=lc($name);
  if($name eq "target") {
    $addr=$value;
  }
  elsif($name eq "function") {
    if($value eq "ping") {$function=$value;}
    elsif($value =~ /synack/) {
      if($site eq "slac") {$function=$value;}
      else {$err .= "Only SLAC supports synack function.<br>\n";}
    }
    elsif($value eq "tracepath") {
      my $tracepath=`which tracepath`; 
      chomp $tracepath;
      if($tracepath eq "") {#Failure looks like alias: no match or tracepath: not found etc.
        $err .= "tracepath command not found, OS=$archname<br>\n";
      }
      $function=$value;
    }
    elsif($value eq "traceroute") {;}
    else {
      $err .= "Invalid function value, "
           .  "valid values=ping or tracepath or traceroute<br>\n";
    }
  }
  elsif($name eq "debug") {$debug=$value;}
  elsif($name eq "size")  {
    #$ping_size=$value;
    #if($ping_size eq "") {$ping_size=56;}
    #if(!($ping_size =~ /\d+/)) {
    #  $err .= "Size must be positive integer.<br>\n";
    if($value eq "") {
      $ping_size=56;
    }
    #elsif (($ping_size < 56) || ($ping_size > 1400)) {
    #  $err .= "Size must be >= 56 & <= 1400.<br>\n";
    elsif ($value =~ /^(\d+)$/) {
      $ping_size = $1;
      if ($ping_size > 8972) {
        $err .= "Size must be <= 8972.<br>\n";
      }
    }
    else {
      $err .= "Size must be positive integer.<br>\n";
    }
  }
  elsif($name eq "probe") {
    if($value=="ICMP")     {$probe="-I";}#OK for Linux & Solaris
  }
  elsif($name eq "ipv") {
    $ipv=$value;
    unless ($ipv eq "6" || $ipv eq "4"){
      $err .= "ipv='$ipv' is invalid, if supplied  must equal 6 or 4<br>\n";
    }
  }
  elsif($name eq "options") {
    my @arguments=(split/%20/,$value);
    for my $arg(@arguments) {
      if($arg=~/^(-\w+)$/) {#option name
        push(@options, $1);
      }
      elsif ($arg=~/^(\d*\.*\d*)$/) {#option value
        push(@options, $1);
      }
      #elsif ($arg="") {;} 
      else {
        $err.="Invalid characters ($arg) found in options string=";
        for my $token (@arguments) {$err.="$token ";}
        $err.="\n";
        last;
      }
    }  
  }
}
###########################################################################
#Add in the ICMP option if requested
my $ping_npackets="";
if($function eq "traceroute") {if($probe ne "") {push (@Tropts,$probe);}}
###########################################################################
# Build the executable function for ping
elsif($function eq "ping") {
  $Tr="ping";
  if($archname eq "solaris")  {
    $ping_npackets="5"; @Tropts=qw(-s);
  }
  else {@Tropts=("-c 5","-s $ping_size");}
}
##########################################################################
# Build the executable function for synack
elsif($function =~ /synack/) {
  if ($function =~ /synack -p (\d{1,3})/) {
    @Tropts=("-p ".$1,"-k 5","-S 5");
  }
  else {
    @Tropts=("-p 80","-k 5","-S 5");
  }
  $Tr=$Sy;
}
#########################################################################
# Build the executable function for tracepath
elsif($function eq "tracepath") {
  $Tr="/bin/tracepath";
  @Tropts=();
}
#########################################################################
#Keep track of last request
my $last="/tmp/$function".".pl.time"; # file to be 'touched' to note last time email sent.
#########################################################################
#Clean up the target address.
$addr =~ s/\%([a-fA-F0-9][a-fA-F0-9])/pack('H2',$1)/eg; #De-webify %xx stuff
$addr =~ s/\%([a-fA-F0-9][a-fA-F0-9])/pack('H2',$1)/eg; #De-webify %xx stuff
$addr=~tr/+/ /; #De-webify + signs to spaces
$addr=~s/^\s+|\s+$//; # Remove extraneous white space at start & finish
if($addr=~s/^([a-zA-Z]+:\/\/|[a-zA-Z]+:\/\/\/)([\w\.\-_]+)[\w\.\/\-_]*$/$2/) {#Extract host from URL
  $warn.="Looks like a web URL, I will try and extract the target.<br>\n";
  my $prot=$1; $prot =~ tr/a-z/A-Z/;
  if ($prot eq "FILE:///") { #Looks like a local file
    $addr=$ENV{'REMOTE_ADDR'};
    $warn.="Target looks like a local file, ".
           "I will try and $function to your browser at $addr.<br>\n";
  }
}
$addr=~s/\/$//; #Remove trailing slash (/).
#############################################################
#Check if it is a probable email address
if($addr=~/.\@./) {#Looks like an email address, provide guidance
  $err.="Looks like an email address (i.e. name\@mail_domain),".
        " needs to be host name or address (e.g. must not include \@).<br>\n";
}
#####################################################################
#Complete the name and address of the target host
my @target=split(/\./,$addr); my $target_domain;
my $ipv6=0;
if(valid_ip($addr) eq "6") { #Check for possible IPv6 addr format
  $ipv6=1;
  if($archname ne 'solaris') {
    $Tr = $Tr . "6";#append "6" on end of command name "traceroute" -> "traceroute6", 
                    #"ping" -> "ping6"
  }
  else {
    push(@Tropts, "-A inet6");
  }
}
elsif(valid_ip($addr) eq "n") {#Target is a valid host name
  $host=$addr;
  $addr=(gethostbyname6($host));
  if($addr eq "") {
    $err.="Can't find IPv$ipv address for host name ".
          "<font color='red'> $host</font>.".
          " Probably an unknown host.<br>\n";
  }
  else {
    # compare class-C networks correctly.
    if(valid_ip($addr) eq "4") {
      $temp=gethostbyname($host);
      my ($a1, $b1, $c1, $d1)=unpack('C4',$temp);
      if ($a1>=192) {
        $target_domain=$a1.".".$b1.".".$c1;
      }
      else {
        $target_domain=$a1.".".$b1;
      }
    }
    else {
      $ipv6=1;
      if($archname ne 'solaris') {$Tr=$Tr."6";}
      #else                       {$Tr=$Tr." -A inet6 ";}#Unable to test. It gives traceroute: ifaddrlist: SIOCGLIFCONF: Error 0
      else {push(@Tropts,"-A inet6");}
    }
  }
}
elsif(valid_ip($addr) eq "4") {#$QUERY_STRING contains an IPv4 target address
  $target_domain=$target[0].".".$target[1];
  if(!($host = gethostbyaddr(pack('C4',split(/\./,$addr)),$AF_INET))) {
    $host=$addr;#Get name if address resolves
  }
}
else {
  $err.="Invalid character in IP address or name. Valid characters are 'a-zA-Z0-9_.-:'.<br>\n";
}
if($err ne "") {
  print "$errhead $err $errtail";
  exit 5;
}
if($debug>0) {
  print "<br>\n".scalar(localtime())." $progname: $addr($host), function=$function<br>\n" .
        " Server=$uid\@$hostname($ipaddr), REMOTE_ADDR=$ENV{'REMOTE_ADDR'}<br>\n".
        " REQUEST_URI=$ENV{'REQUEST_URI'}<br>\n".
        " Executing $Tr ($err)\n";
}
#################################################################################
# Temporary kludge to block abusive hosts
#my @denies=("211.216.50.200","212.91.225.114","135.207.29.241"); #Add by cottrell 3/23/02.
# re-enabled the above 5/11/04 to see if still a problem.
#my @denies=("128.194.135.80","irl-crawler.cs.tamu.edu","128.194.135.73","irl-spider.cs.tamu.edu");
# re-enabled the above 10/22/04 to see if still a problem
#Added "68.202.115.238 (238-115.202-68.se.rr.com)","218.102.96.95 (pcd565095.netvigator.com" 14134, 5202 hits 10/22/04 Cottrell
# re-enabled the above 1/4/05 Cottrell
#Added "63.231.133.192 (63-231-133-192.mpls.qwest.net) 12/5/04 Cottrell (3738 requests/day)
#Added "203.51.137.39 CPE-203-51-137-39.vic.bigpond.net.au" 1/4/05 Cottrell (2059 requests/day)
#Added "63.203.98.156 adsl-63-203-98-156.dsl.lsan03.pacbell.net" 1/23/05 Cottrell (3181 requests)
#Added "68.205.16.194 194.16.205.68.cfl.res.rr.com" 2/23/05 Cottrell (1903 requests/day)
#Added "24.106.79.234" 6/8/05 Cottrell (28822 requests/day)
#Added "68.44.148.52 pcp03312553pcs.wchryh01.nj.comcast.net" 11/25/05 Cottrell (2876 requests/day)
#Added "81.20.6.18 N/A" 545 requests, "203.162.3.153 N/A" 398 requests, 3/18/06 Cottrell"
#Added "198.174.110.146" 1555 requests 4/23/06 Cottrell
#Added "198.30.132.8" 4185 requests 6/6/06 Cottrell
#Removed block on "198.174.110.146", Hallelujah I found someone who fixed their problem!
#Added "203.162.3.147" proxy03-hcm.vnn.vn 1035 requests 4/26/06 Cottrell
#Added "198.30.132.8" no name, > 790 requests 5/20/06 Cottrell
#Added "198.30.132.6" no name, > 4580 requests 6/5/06 Cottrell
#Added "211.28.103.29 c211-28-103-29.eburwd4.vic.optusnet.com.au" > 3800 requests 9/28/06 Cottrell
#Added "200.94.128.219 static-200-94-128-219.alestra.net.mx" 12 requests/min 3/3/2016 Cottrell
my @denies=("63.231.133.192","203.51.137.39","63.203.98.156", "68.205.16.194","24.106.79.234",
            "68.44.148.52",  "81.20.6.18",   "203.162.3.153", "203.162.3.147","198.30.132.8",
            "198.30.132.6", "211.28.103.29", "200.94.128.219","200.94.128.220");
#if($addr ne "") {
if(defined($ENV{'REMOTE_ADDR'}) && $ENV{'REMOTE_ADDR'} ne "") {
  #my @remote=split(/\./,$addr);
  foreach my $deny (@denies) {
    #if(uc($deny) eq uc($addr) || uc($deny) eq uc($host)) {
    if(uc($deny) eq uc($ENV{'REMOTE_ADDR'}) || uc($deny) eq uc($host)) {
      print "Deny request from $host($deny) due to large number of requests,".
            " contact cottrell\@slac.stanford.edu to re-enable.\n";
      exit 3;
    }
  }
}
if($host=~/in-addr\.btopenworld\.com/) {
  print "There are now over 30 hosts from the btopenworld.com domain ".
        "automatically requesting 70-140 traceroutes / day from $hostname($ipaddr).".
        "As of 11/25/05, these requests have been blocked. ".
        "Please contact cottrell\@slac.stanford.edu to describe the purposes ".
        "of these requests, so we can justify re-enabling the access for ".
        "btopenworld.com. Thank you.\n";
      exit 4;
}
#########################################################################
# As a security measure we do not allow a remote host in a different
# domain to do a traceroute to
# a host within the same domain as the web server. One concern is that
# allowing such a traceroute would allow an external host to traceroute
# to a host within the Internet Free Zone that the web server is in.
# Get domain of web server.
my ($http_addr, $http_domain, $remote_domain);
if($function ne 'traceroute') {;}
#elsif(!( $http_addr=(gethostbyname($ENV{'SERVER_NAME'}))[4] )) {
elsif(!( $http_addr=(gethostbyname6($ENV{'SERVER_NAME'})))) {
   $err.="Can't find address of $function SERVER_NAME $ENV{'SERVER_NAME'}:$!$?.<br>\n";
}
elsif($ipv6 == 1) {;}#No domain check for IPv6 (add by Cottrell 4/15/2011)
else {#IPv4 traceroute function
  my ($a1, $b1, $c1, $d1)=unpack('C4',$http_addr);
  # compare class-C networks correctly.
  if ($a1>=192) {
      $http_domain=$a1.".".$b1.".".$c1;
  }
  else {
    $http_domain=$a1.".".$b1;
  }
  # Get domain of remote host.
  my @remote=split(/\./,$ENV{'REMOTE_ADDR'});
  $remote_domain=$remote[0].".".$remote[1];
  @target=split(/\./,$addr);
  # Client/browser & web server are in different domains.
  if(!($http_domain eq $remote_domain)) {
    #Under some error conditions $target_domain is not defined
    if(defined($target_domain)) {
      if( ($target_domain eq $http_domain) 
       && ($http_domain ne "121.52") #Special case PERN
       && ($http_domain ne "111.68")) {
        # Client (browser) is outside the web server domain and so is not
        # allowed to traceroute to a target inside the web server's domain.
        $err.="$function server does not provide $function"."s to ".
              "targets such as $addr inside the $http_domain domain, ".
              "for browsers outside the $http_domain domain.<br>\n";
      }
    }
    #push(@Tropts,"-f 3");
  }
  else {#Client/browser & web server are in the same domain
    $start=""; #no need to hide internal routing from insiders
  }
}
#######################################################
my $browser;
unless (defined($ENV{'QUERY_STRING'}) && $ENV{'QUERY_STRING'} ne '') {
  $browser="your web browser at";
}
else {$browser="";}
$msg = "$function from $ipaddr ($ENV{SERVER_NAME}) "
     . "to $browser $addr ($host) for $ENV{'REMOTE_ADDR'}";
if($host eq "") {$host="host with no DNS entry";}
###############Put out header etc.#####################
print "<html>\n<head>\n<title>$msg</title>\n"
    . "<meta name='robots' content='noindex,nofollow'>\n"
    . "</head>\n<body>\n";
#######################################################
# *** Sites may want to tailor the following statement to meet their needs. ******
if (defined($ENV{'QUERY_STRING'}) && $ENV{'QUERY_STRING'} ne '') {
  if($debug>=0) {
    print "<div align='center'><table border='1'>
        <tr><td align='center'>",
      "<a href='http://www.stanford.edu/'>
        <img src='http://www.slac.stanford.edu/comp/net/wan-mon/stanford-seal.gif'
           alt='Stanford University seal' title='Stanford University seal'></a>
        <a href='http://www.slac.stanford.edu/'>
          <!--
          <img src='http://www.slac.stanford.edu/icon/slac3.gif'
          -->
          <img src='http://www.slac.stanford.edu/icon/newlogo-sm.gif'
          alt='SLAC logo, click here to learn more about SLAC'
          title='SLAC logo, click here to learn more about SLAC'
        ></a>
      </td>",
      "<td align='center'><h2>$msg</h2>\n",
      "CGI script maintainer:
       <a href='mailto:cottrell\@slac.stanford.edu'><i>
       Les Cottrell</i></a>, <a href='http://www.slac.stanford.edu/'>SLAC</a>.
       Script version $version.<br>
       <a href='http://www.slac.stanford.edu/comp/net/traceroute/traceroute.pl'>
       Download perl source code</a>.<br>",
      "<small>To perform a
       <!-- a href='http://boardwatch.internet.com/mag/96/dec/bwm38.html' -->
        traceroute/ping/tracepath function
        from $ENV{SERVER_NAME} to the target,
        enter the desired target 
        <a href='http://en.wikipedia.org/wiki/Domain_name'>host.domain</a>
       (e.g. www.yahoo.com) or
       <a href='http://en.wikipedia.org/wiki/IP_address'>Internet
       address</a> (e.g. 137.138.28.228) in the box
       below. Note the fucntion is performed for the target's
       resolved Internet address.</small>
       $form
       Enter target name or address:
       <input type='text' size='30' name='target'> then push 'Enter' key.
       <input type='hidden' name='function' value='$function'>
       </form>",
      "Lookup:
       <a href='http://www.networksolutions.com/cgi-bin/whois/whois'>domain name</a> |
       <!--
          <a href='http://cello.cs.uiuc.edu/cgi-bin/slamm/ip2ll/'>latitude & longitude</a> |
       -->
       <a href='http://www.geoiptool.com/'>Locating a Host</a> |
       <a href='http://visualroute.visualware.com/'>visual traceroute</a> |
       <a href='http://www.fixedorbit.com/trace.htm'>Find AS's between hosts</a> |
       <a href='http://asn.cymru.com/cgi-bin/whois.cgi'>Find AS of a host</a> |
       <a href='http://www.ietf.org/rfc/rfc2142.txt'>contacting someone</a>
       </td>",
      "<td><b>Related web sites</b><br>",
      "<a href='http://www.slac.stanford.edu/comp/net/wan-mon/traceroute-srv.html'>
        <b>Traceroute servers</b></a>,<br>",
      "<a href='http://www.slac.stanford.edu/comp/net/wan-mon/tutorial.html'>
        Monitoring tutorial</a>,<br>",
      "<a href='http://www-iepm.slac.stanford.edu/'>
        Internet monitoring</a><br>",
      "<a href='http://www.ipaddressworld.com/'>What is my IP address?</a>",
      "</tr></table></div>\n";
  }
}
# *** end of second and last part of tailoring *******************************
if($function ne "ping") {
  if($debug>=0) {
    print "<table bgcolor='yellow'><tr><td align='center'><font color=red><b>\n",
      "Please note that traceroutes can appear similar \n",
      "to port scans. If you see a suspected port scan alert, \n",
      "for example from your firewall, with \n",
      "a series of ports in the range 33434 - 33465, coming \n",
      "from $ENV{SERVER_NAME} it is probably a reverse traceroute from our \n",
      "web based reverse traceroute server. Please do NOT report this to \n",
      "us, it will almost certainly be a waste of both of our times. \n",
      "For more on this see<br>\n",
      "<a href='http://www.slac.stanford.edu/comp/net/wan-mon/traceroute-srv.html#security'>\n",
      "Traceroute security issues</a>.</b></font></td></tr></table>\n";
  }
  #No query string, user maybe a novice and needs to be warned that the
  #traceroute may result in something that appears as a port scan to
  #some firewalls, so she/he won't later complain about our web server
  #'attacking' her/his host.
  unless (defined($ENV{'QUERY_STRING'}) && $ENV{'QUERY_STRING'} ne '') {
    print "<hr><table border=6><tr><td align='center'>\n",
        "<font color='red' size=+2><b>\n",
        "You are about to request a traceroute that may be\n",
        "interpreted as an 'attack' from $ENV{SERVER_NAME}, \n",
        "by a firewall protecting your browser: $addr ($host). \n",
        "Have you read the description above and is it OK to proceed?</b></font>\n",
        "$form\n",
        "<INPUT type='hidden' name=choice value='yes'>\n",
        "<INPUT type='submit' value='YES'\n>",
        "</form></table>\n</body></html>\n",
        "<div align='center'><font size=+3><b>Your host is: $addr ($host).</b></font></div>\n";
    exit;
  }
}
###################################################################
# Let's trample on obvious attempts to trace to a broadcast address
#    (associated with some denial-of-service attacks based on ICMP)
if (($ipv6 ne "1") && ($addr =~ /\.(0|255)$/)) {
  $err.="Broadcast address ($addr) not allowed for IPv4.<br>\n";
};
###################################################################
# Check to ensure there are not already too many traceroute
# processes running. This is to try and avoid a denial of service
# attack. If there are too many then send email warning, unless we already
# sent an email warning less than an hour ago.
my @processes=grep(/$function/, `ps -o comm -u $>`);
if(scalar(@processes) > $max_processes) {
  $err.="$function server busy at the moment with "
      . scalar(@processes)
      . " processes that exceeds max of $max_processes for UID=$>("
      . getpwuid($>)
      . "). Please try again later.<br>\n";
  if ($debug>0) {
    $err.="(debug=$debug)List of traceroute processes for UID=$> ("
        . getpwuid($>)."):<br>\n";
    my @ans=`ps -ef -u $>`;
    for my $ans (@ans) {$err.="$ans<br>\n";}
  }
  if(!($to eq "" || $mail eq "")) {
    if (! -e $last || -M _ > $timeout) {# was it > $timeout since last sent email?
      system('touch', $last); # yes, note new time and send an email warning
      my $time=scalar localtime;
      open(MAIL, "| $mail -s 'Warning $function".".pl busy at $time on $hostname.' $to")
        or die "Unable to send mail to $to warning $function busy at $time: $!";
      $msg="$time HTTP_REFERER = $ENV{'HTTP_REFERER'} found "
         . scalar(@processes)." running "
         . "$function processes in "
         . "SERVER_NAME = $ENV{'SERVER_NAME'} = $uid\@$hostname($ipaddr) "
         . "when doing $function to address=$addr "
         . "host=$host. Request was received from " 
         . "REMOTE_ADDR = $ENV{REMOTE_ADDR}"
         . "(REMOTE_HOST = $ENV{REMOTE_HOST})";
      if(valid_ip($ENV{REMOTE_ADDR}) eq '4') {
        my @tokens=gethostbyaddr(pack('C4',split(/\./,$ENV{REMOTE_ADDR})),$AF_INET);
        $msg.="(name=$tokens[0])";
      }
      if (defined $ENV{'HTTP_X_FORWARDED_FOR'}) {#Prob won't work for encrypted
        $msg.=" FORWARDED_FOR=$ENV{'HTTP_X_FORWARDED_FOR'}.";
      }
      $msg.=".\n";
      $msg.=`cat $mail_help`;
      print MAIL $msg;
      close(MAIL);
    }
  }
}
if(private($addr)) {$err.="$addr is a private address<br>\n";}
if($debug > 0) {print "debug=$debug<br>\n";}
if($warn ne "") {
  print "$errhead $warn $errtail";
}
if($err ne "") {
  printerr($err);
  exit 2;
}
################################################################
# Finally, we can do something useful...
print "<pre>\n";
if($debug > 0)  {
  if($function ne "ping" or $archname ne "solaris")  {
    if($function eq "tracepath")  {
      $temp = "$Tr @Tropts $addr";
    }
    else {
      $temp = "$Tr @Tropts $addr";
    }
  }
  else {
    $temp="$Tr @Tropts $addr $ping_size $ping_npackets";
    system('iptables -L');
  }
  print scalar(localtime())." server $uid\@$hostname($ipaddr)\n".
        " running $archname called: $0\n".
        " to execute: $temp\n".
        " with path=$ENV{'PATH'}\n".
        " from cwd=".cwd()." under shell $ENV{'SHELL'}\n".
        " for REMOTE_ADDR=$ENV{'REMOTE_ADDR'}\n"." function=$function\n";
  $function=untaint($function);
  my @ans=`which $function`; print "Found $function at @ans";
}
#################################################################
# Note that the following exec avoids shell expansions so we do not
# worry about checking the $addr for shell meta-characters. Note also that
# SIGALRM is carried across the exec thus allowing the timeout to work.
open(STDERR, '>&STDOUT');# Redirect stderr onto stdout
#alarm(45);	     # Timeout function in case of problems (used to be 45)
if(!($addr=~ /^([\w\.:\-]+)$/)) {#Untaint Check for valid characters
  print "<font color='red'><b>Invalid target = $addr, traceroute aborted!</b></font><br>\n";
  exit 1;
}
$addr=$1; #Untaint $addr.
push(@Tropts, @options);
if($function eq "traceroute" and $archname ne "solaris") {
  $temp="140"; #Added the 140 to tracreoute command
  #to get round the bug in Redhat's traceroute package in which some
  #MPLS encapsulation info is incorrectly included in the ICMP checksum.
  #Notification of by pass from Bryson Lee of SLAC.
  my @args =($Tr, @Tropts, $addr, $temp);
  alarm(240);
  &exec(@args);
}
elsif($function eq "tracepath") {
  my @args=($Tr, @Tropts, $addr);
  alarm(45);
  &exec(@args);
}
elsif($archname eq "solaris" && $function eq "ping") {
  my @args=($Tr, @Tropts, $addr, $ping_size, $ping_npackets);
  alarm(45);
  &exec(@args);
}
elsif($function eq "traceroute" || $function eq "ping" || $function eq "synack") {
  my @args=($Tr, @Tropts, $addr);
  alarm(90); 
  &exec(@args);
}
else {
  print "Invalid command $Tr options=@Tropts address=$addr\n";
}
######################################################
#&exec($commmand, @options, $target [,$extra_options])
#Executes the command with the given options on the given target
#
#Examples:
# &exec("ping", "-c 5 -s 56", "137.138.144.168");
# &exec("traceroute, "-m 30 -q 1 -w 3", "134.79.230.225", "140");
sub exec {
  my @args=@_;
  print "Executing exec(@args)\n";
  my $t0=time();
  #system(@args) == 0 or die "Can't system(@args): $?";
  my $exitcode = system(@args);
  if ( $exitcode == 0 ) {
     # Exit was normal
  }
  elsif ( $exitcode == 1) {
     die "Responses not seen --- Can't system(@args): $?"
  }
  elsif ( $exitcode == 2 ) {
     die "Error in command --- Can't system(@args): $?"
  }
  elsif ( $exitcode == 256 ) {
     die "Operation timed out --- Can't system(@args): $?"
  }
  else {
     die "Other error code seen --- Can't system(@args): $?"
  }
  my $username = getpwuid( $< );
  print "@args took ".(time()-$t0)."secs. Total time=".(time()-$t00)."secs. user=$username\n";
  return;
}
##############################################################################
## Untaint will check for a vaild Unix file name and untaint it.
## Example:
##   $fn = untaint($fn)
##------------------------------------------------------------------------------
sub untaint {
  my $file = $_[0];
  unless ($file =~ /(^[\w\.\-\+\d\/]*$)/) { #Taint check
    die "$0 encountered tainted file name $file.";
  }
  return $1;
}
######################################################
sub private {
   #Returns true if it is a private IPv4 address
   my $addr=$_[0];
   if(valid_ip($addr) eq "4") {
     #Check if address is a private address, there are three ranges:
     #10.0.0.0 - 10.255.255.255 a single class A net
     #172.16.0.0 -  172.31.255.255 16 contiguous class Bs
     #192.168.0.0 - 192.168.255.255 256 contiguous class Cs
     #127.0.0.0 - 127.255.255.255 local loopback
     my ($a1, $b1, $c1, $d1)=split(/\./,$addr);
     if (  ($a1 ==  10) 
        ||( ($a1 == 172) && (($b1 >= 16)  && ($b1 <=  31)))
        ||( ($a1 == 192) &&  ($b1 == 168) || ($a1 == 127))
       ){#Is it a private address?
       return 1;
     } 
   }    
   return 0;
}
#############################################################
sub valid_ip {
  #Given a string, it checks whether it is a valid IP name (returns "n"),
  #or valid IPv4 address (returns "4"), or valid IPv6 address returns "6").
  #If invalid it returns "0";
  #For IP name see: http://stackoverflow.com/questions/106179/regular-expression-to-match-hostname-or-ip-address
  #For IPv4 address see: http://answers.oreilly.com/topic/318-how-to-match-ipv4-addresses-with-regular-expressions/
  #For IPv6 address see: http://forums.dartware.com/viewtopic.php?t=452
  #Test cases for IPv6 address (we are using aeron) see http://download.dartware.com/thirdparty/test-ipv6-regex.pl
  #Examples:
  if(length($_[0])<256) {
    if($_[0]=~/^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/){#IPv4 address
      return "4";
    }
    elsif($_[0]=~/^(((?=(?>.*?::)(?!.*::)))(::)?([0-9A-F]{1,4}::?){0,5}|([0-9A-F]{1,4}:){6})(\2([0-9A-F]{1,4}(::?|$)){0,2}|((25[0-5]|(2[0-4]|1[0-9]|[1-9])?[0-9])(\.|$)){4}|[0-9A-F]{1,4}:[0-9A-F]{1,4})(?<![^:]:)(?<!\.)\z/i) {#IPv6 Address
      return "6";
    }
    elsif($_[0]=~/^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])(\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]))*$/) {#Name
    #if($_[0]=~/(([a-z0-9]+|([a-z0-9]+[-]+[a-z0-9]+))[.])+/) {#Name
      return "n";
    }
  }
  return "0";
}
######################################################################
sub printerr {
  my $err=$_[0];
  print  "<p><hr>$errhead $err",
       "See <a href='http://www.webteacher.org/winnet/domain/name.html'>",
       "The Naming System</a> for information on host.domain and ",
       "<a href='http://www.webteacher.org/winnet/domain/addresses.html'>",
       "Addresses</a> for information on Internet addresses.<br>",
       "$errtail\n";
}
#############################################################
sub gethostbyname6 {
  #gethostbyname6 yields the IPv6 or IPv6 address for a host name
  # uses dig to get AAAA address for given name
  # returns IPv6 address if successful else returns ""
  my $name=$_[0];
  my $ipaddr="";
  if($ipv eq "4" && gethostbyname($name)) {
    $ipaddr=gethostbyname($name);
    my ($a1, $b1, $c1, $d1)=unpack('C4',$ipaddr);
    $ipaddr=$a1.".".$b1.".".$c1.".".$d1;
  }
  else {
    my $cmd="dig $name -t AAAA";
    if(!($cmd=~ /^([\w\.:\-\s]+)$/)) {#Untaint Check for valid characters    
      print "<font color='red'><b>Invalid (tainted) command = $cmd, traceroute aborted!</b></font><br>\n";
      exit 1;
    }
    $cmd=$1; #Untaint $cmd.
    my @result=grep(/\s+AAAA\s+/,`$cmd`);
    foreach my $result(@result) {
      if($result =~ /^;/) {next;}
      my @tokens=split(/\s+/,$result);
      if(defined($tokens[4])) {$ipaddr=$tokens[4]; last;}
    }
  }
  return $ipaddr;
}
__END__
#Examples:
http://net.its.hawaii.edu/cgi-bin/traceroute.pl?target=2001%3A4860%3A8005%3A%3A68&function=traceroute&ipv=6
http://www.slac.stanford.edu/cgi-bin/traceroute.pl?target=ipv6.google.com&function=traceroute
#--------------------------------------------------------------#
#                                                              #
#                      DISCLAIMER NOTICE                       #
#                                                              #
# This  document  and/or portions  of  the  material and  data #
# furnished herewith,  was developed under sponsorship  of the #
# U.S.  Government.  Neither the  U.S. nor the U.S.D.O.E., nor #
# the Leland Stanford Junior  University, nor their employees, #
# nor their  respective contractors, subcontractors,  or their #
# employees,  makes  any  warranty,  express  or  implied,  or #
# assumes  any  liability   or  responsibility  for  accuracy, #
# completeness  or usefulness  of any  information, apparatus, #
# product  or process  disclosed, or  represents that  its use #
# will not  infringe privately-owned  rights.  Mention  of any #
# product, its manufacturer, or suppliers shall not, nor is it #
# intended to, imply approval, disapproval, or fitness for any #
# particular use.   The U.S. and  the University at  all times #
# retain the right to use and disseminate same for any purpose #
# whatsoever.                                                  #
#--------------------------------------------------------------#
#Copyright (c) 1995, 1996, 1997, 1998, 1999, 2000, 2001,
#              2002, 2003, 2004, 2005, 2006, 2007, 2008,
#              2009, 2010, 2011, 2012, 2013, 2014, 2015
#              1026
#  The Board of Trustees of the Leland
#  Stanford Junior University. All Rights Reserved.

#----------------------------------------------------------------
# This perl script enables someone to initiate a traceroute from your
# Web server to their browser without requiring an account at your site.
# You will need to get your Web Master/Mistress to make this script executable
# on your Web server.
#
# To demonstrate the use of this script point your Web browser to:
#	http://www.slac.stanford.edu/cgi-bin/nph-traceroute.pl
#
# If you do install it on your Web server, I would appreciate it if you
# would notify me (cottrell@slac.stanford.edu) by e-mail so I can put a
# pointer to your Web traceroute server URL in the SLAC Traceroute server page:
#	http://www.slac.stanford.edu/comp/net/traceroute-srv.html
# Thanks.

# ########################## History ################################
# Authors: Les Cottrell & John Halperin (SLAC),  July 3, 1995.
# Modifications:

# Apr 1998: by A.Flavell@physics.gla.ac.uk :
#  Adapted to optionally utilise the NIKHEF version of traceroute
#      ( see ftp://ftp.nikhef.nl/pub/network/ )
#   and use it to return AS-number information; but to avoid risk
#   from timeouts, AS-lookup is only active if this code is
#   used as an nph- script.  The script can be used without further
#   modification if $Tr points to a traditional traceroute, however.
#
#  Detect x-forwarded-for header (might be set by web proxy caches)
#   and trace to the real client instead of merely to the proxy.
#  Detect the presence of a query string and use that as the
#   destination to trace to instead (could be IP address or host name).
#
#  Note that the variables at the start of the script may need tailoring
#   for your situation (traceroute command/path, local whois server).

# Jun 29 1997:
#   Make the use of No Parse Header interactive mode dependent on the
#     name of this script (suggestion from Alan Flavell of Glasgow U);
#     by using a symlink the same copy of this code can be used as both
#     the nph- and the non-nph version of the script if you wish.

# August 30 1998 (Cottrell, Halperin):
#   Check for maximum length of host to avoid buffer overflows.
#   Redirect stderr onto stdout so that traceroute's header line goes
#     back to the browser instead of to the server's log.

# July 4, 1999 (Mod from Alan Flavell added by Cottrell):
#   By-passed shortcoming in the handling of X-Forwarded-For
#   headers.  If the caller is behind a chain of two or more proxies (a
#   situation that is becoming more-common, at least in the UK academic
#   domain), then it can happen that each proxy (Squid etc.) adds the
#   address of its predecessor into the X-Forwarded-For header, separated
#   by commas.

# January 4, 2000 (Cottrell): vsn 2.0
#   Deny requests for traceroutes to a target inside the same domain as the
#   web server, from clients/browsers outside the domain.  This is a security
#   measure to reduce the uses for scanning a site (especially for Internet
#   Free Zone addresses).

# March 2, 2000 (DeLuca/Cottrell), vsn 2.1
#   Replaced exec($Tr, $Tropt_m, $Tropt_q, $addr) with
#   exec(split(' ',join(' ', $Tr, $Tropt_m, $Tropt_q, $addr)));
#   due to the NIKHEF traceroute wanting the numeric
#   argument for the options as a separated parameter to the exec statement.
#   Replacement courtesy of <deluca@tandar.cnea.gov.ar>

# March 15, 2000 (Cottrell), vsn 2.2
#   Added warning on traceroutes appearing as port scans.

# April 20, 2000 (Cottrell), vsn 2.3
#   Added check for max number of traceroute processes running in order to
#   reduce chance of denial of service attack.

# April 22, 2000 (Cottrell, Halperin), vsn 2.4
#   Modified to work with latest NIKHEF traceroute and some clean up from John.
#   Also show ttl field in each returned packet (this can be used to detect
#   asymmetric routing). Also start the traceroute after the first 2 hops to
#   hide internal routing information.  Cleaned up some unreferenced variables
#   and turned on Perl's warning and taint-check modes. Also added email
#   warning if maximum number of processes exceeded.

# April 24, 2000 (Cottrell, Halperin), vsn 2.51
#   Only send email if a previous email was not sent in the last hour.

# April 27, 2000 (Cottrell), vsn 2.6
#   Fill in name or address if other provided by QUERY_STRING
#   Provide help to go along with email.
#   De-webify + signs into spaces in case input comes from user.

# May 4, 2000 (Cottrell), vsn 2.7
#   Diagnose email addresses and provide assistance. Provide assistance
#   for addresses with no periods in them.

# May 7, 2000 (Cottrell), vsn 2.8
#   Replace ISINDEX with form. Provide assistance for addresses with
#   spaces or other embedded invalid characters.

# May 15, 2000 (Cottrell), vsn 2.9
#   Extract host from URL. Also remove trailing slashes (/).

# May 28, 2000 (Cottrell), vsn 2.91
#   Try and provide help with local files of the form file:///

# October 18 (Cottrell), 2000, vsn 2.92
#   Bug fix for undefined variable ($target_domain), and AF_INET in proxy code,
#   Also moved printing of header to start.
#   Bugs AND suggested fixes kindly provided by Alan Flavell, Glasgow U

# October 22 (Cottrell), 2001, 2.93
#  Allowed for host with no DNS entry so do not get uninitialized variable.
#  Bug identified by Alan Flavell

# December 2, 2001 (Cottrell), 2.94
#  Provided information contacting responsible person at a site.

# March 22, 2002 (Cottrell), 3.0
#  For novice users requesting a traceroute to their browser, put up form
#  to make sure they read about the similarities to port scans, and
#  they agree to proceed. Also added extra information to the email sent
#  when too many processes running.

# August 28, 2002
# (Scot Colburn [colburn@ucar.edu] patch applied by Cottrell), 3.1
# Fix bug for class C networks

# December 14, 2002 (Cottrell), 3.2
# Suggestion from Thomas M. Payerle [payerle@benfranklin.physics.umd.edu]
# made form action field a variable, fix an un-escaped @ sign

#$version="3.3, 8/5/04";
# August 5, 2004 (cottrell), 3.3
# Buffered the nph- output with the Content-type output.
# There may be a problem with using nph- (to unbuffer the output) with an HTTP/1.1
# server that causes an extra Content-type: to be inserted by the server if there
# is extra output before the first Content-type: put out by traceroute.pl

#$version="3.4, 12/16/04, Les Cottrell";
# December 16, 2004 (cottrell), 3.4
# Replaced die with print so error messages are seen by browser.

#$version="3.5, 6/25/05, Les Cottrell";
# June 25 2005, (cottrell), 3.5
# Provided ping capability

#$version="3.6, 8/18/05, Les Cottrell";
# Improved the execution of ping & traceroute to work on Linux also

#$version="3.7, 9/3/05, Les Cottrell";
# Enabled selecting the ping function from the QUERY_STRING and added a
# debug option. Also removed most of the need for tailoring at sites,
# detecting whether we are at SLAC and adding our special cases.

#$version="3.71, 10/13/05, Les Cottrell";
# Added explicit report of file address and name
# Improved debugging and gave REMOTE_ADDR information.

#my $version="3.72, 11/20/05, Les Cottrell";
# Denied btopenworld.com

#my $version="3.73, 3/2/06, Les Cottrell";
# Replaced use of uname with $^O to improve tainting
# Increased the debug output to show the pwd

#my $version="3.74, 5/8/06, Les Cottrell";
#Enabled pings from onsite to onsite

#my $version="4.0, 5/13/06, Les Cottrell";
#Added synack for SLAC

#my $version="4.1, 6/16/06, Les Cottrell";
#Modifications to work on applications server.

#my $version="4.2, 7/19/06, Les Cottrell";
#Add in the size option. Add use strict.

#my $version="4.21, 7/27/06, Les Cottrell";
#Support for SLAC application server, add Taint checking

#my $version="4.22, 9/4/06, Les Cottrell";
#Removed dependence on $ENV{'REMOTE_HOST'}

#my $version="4.23, 9/5/06, Les Cottrell";
#Trying to remove uninitialized $host

#my $version="4.24, 10/2/06, Les Cottrell";
#Special case to allow ICMP traceroute for Brunsvigia

#my $version="4.25, 1/25/07, Les Cottrell";
#Fixed -T on first line, removed useless use of 
#private variable $temp around line 743.
#Also explicity untainted the $addr before passing to traceroute.

#my $version="4.26, 1/27/07, Les Cottrell";
#Check for valid IP address in proxy address

#my $version="4.27, 5/2/07, Les Cottrell";
#Add /sbin:/usr/sbin into PATH

#my $version="4.30, 12/20/07, Les Cottrell";
#Removed NiKHEF version, problem with AFS and SUID
#Fixed an = that should have been an == in the test for ICMP

#my $version="4.40, 12/13/07, Les Cottrell";
#Issue warning or error if the address is private.
#Add /usr/local/sbin to path

#my $version="4.50, 5/23/09, Les Cottrell";
#Add 140 to packet size of traceroute to avoid RHAT bug that adds
#chksum errors for MPLS links. See:
#http://www.webhostingtalk.com/showthread.php?t=615385

#my $version="4.60, 7/6/09, Les Cottrell";
#If the addr is an IPv6 address then change traceroute>traceroute6
#and ping>ping6.
#Recognizing that on many systems, "traceroute6" is equivalent to "traceroute", 
#and permits use of IPv6 addresses in place of v4 addresses.
#This change also requires relaxation of a constraint in the original code 
#(that required having a "." in the addr field).
#We just permit the address to pass even if it doesn't have one or more 
#periods in the string.
#This suggestion came from Mark Foster [mark.foster @ nasa.gov]

#my $version="4.65, 8/9/09, Les Cottrell";
#Replaced the lat/long link with a Link to GeoIPTools

#my $version="4.70, 8/20/10, Les Cottrell";
#Added $debug=-1 capability to remove most of the fancy formatting at the beginning 

#my $version="4.80, 9/13/2010, Les Cottrell";
#Retained function as enter a new host.

#my $version="5.0, 12/13/2010, Les Cottrell";
#Removed potential XSS vulnerability

#my $version="5.1, 12/29/2010, Les Cottrell";

#my $version="5.2, 04/15/2011, Les Cottrell";
#Do not check whether client and server are in the same 1st 2 octets if IPv6

#my $version="5.3, 05/20/2011, Les Cottrell";
#Special case PERN nodes at multiple sites having the  same class B 
#network starting with 111.68 or 121.51

#my $version="5.4, 9/17/2011, Les Cottrell";
#start at first hop.

#my $version="5.5, 12/02/2011, Les Cottrell";
#Make $hostname work with IPv4 & IPv6

#version="5.71, 2/23/2012, Les Cottrell";
# used dig to get IPv6 address. Change SLAC logo. Fixed up some links.

#$version="5.8, 5/12/2012, Les Cottrell";
# Added option to force IPv6, made fix to private proxy address

#$version="5.9, 6/4/2012, Les Cottrell";
# Attempted to support ipv6 on Solaris, unable to test.
#my $version="6.0, 10/5/2012, Les Cottrell";
#  Added meta tag to reduce robots visting the page and end up producing
#  a measurement as a result (and cache the results for all time in the process)
#my $version="6.1, 2/15/2013, Les Cottrell";
#  Added link to Fixed orbits to find AS's on route between 2 hosts
#  my $version="6.2, 2/27/2013, Les Cottrell";
#  Improved the final execution to add timing and various alarm durations.
#my $version="6.3, 5/2/2013, Les Cottrell";
#  Added ability provide extra options, such as ASN or number of hops info.
#  Only for the intrepid.  Example:
#  http://www-wanmon.slac.stanford.edu/cgi-bin/traceroute.pl?options=-m 5 -A
#my $version="6.4, 8/29/2013, Jason Zurawski, Les Cottrell";
#  Enabled jumbo frames.
#my $version="6.5, 6/27/2014, Les Cottrell";
#my $version="6.51, 9/15/2014, Les Cottrell";#Notified perfsonar.
#   Improved too many processes error message.
#my $version="6.52, 6/24/2015, Les Cottrell";
#   Added extra debug to report the function, enabled options for tracepath
#When making a significant change, please notify: i2-perfsonar@internet2.edu
#my $version="6.62, 2/8/2016, Les Cottrell";
#   Reports HTTP_X_FORWARDED_FOR if exists,
#   name of requesting host if too many requests,
#   only print process list for $debug>=1;
#my $version="7.0, 7/30/2016, Les Cottrell";
#   Print server user name (e.g. apache) if max_processes exceeded
#   Increase to 2 the debug value to exceed if we print the process list
#   following max_processes exceeded.  It caused confusion sinced it looked
#   like instead of traceroute ps was being executed.
#   Coupled with the reverse traceroute server name potentially starting 
#   with ps this looked like it was possible to execute  commands other 
#   than the intended traceroute based on the host name (which would be 
#   a security problem).   
#   Rolf Seuster <seuster@uvic.ca> pointed this out with some useful examples. 
