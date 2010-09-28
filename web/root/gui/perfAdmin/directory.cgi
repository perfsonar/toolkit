#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

directory.cgi - Script that takes a global inventory of the perfSONAR
information space and presents the results.

=head1 DESCRIPTION

Using the gLS infrastructure, locate all available perfSONAR services and
display the results in a tabulated form.  Using links to GUIs, present the
data for the viewer.

=cut

use Template;
use CGI;
use Log::Log4perl qw(get_logger :easy :levels);
use Config::General;
 
use FindBin qw($RealBin);
my $basedir = "$RealBin/";
use lib "$RealBin/../../../../lib";

my $CGI      = CGI->new();

my $config_file = $basedir . '/etc/web_admin.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our %conf = $conf_obj->getall;

$conf{template_directory} = "templates" unless ( $conf{template_directory} );
$conf{template_directory} = $basedir . "/" . $conf{template_directory} unless ( $conf{template_directory} =~ /^\// );

$conf{cache_directory} = "/var/lib/perfsonar/ls_cache" unless ( $conf{cache_directory} );
$conf{cache_directory} = $basedir . "/" . $conf{cache_directory} unless ( $conf{cache_directory} =~ /^\// );

if ( $conf{logger_conf} ) {
    unless ( $conf{logger_conf} =~ /^\// ) {
        $conf{logger_conf} = $basedir . "/etc/" . $conf{logger_conf};
    }

    Log::Log4perl->init( $conf{logger_conf} );
}
else {

    # If they've not specified a logger, send it all to /dev/null
    Log::Log4perl->easy_init( { level => $DEBUG, file => "/dev/null" } );
}

our $logger = get_logger( "perfSONAR_PS::WebGUI::Directory" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my %serviceMap = (
    "list.snmpma" => {
        "EVENTTYPE" => [ "http://ggf.org/ns/nmwg/characteristic/utilization/2.0", "http://ggf.org/ns/nmwg/tools/snmp/2.0" ],
        "TYPE"      => "SNMP"
    },
    "list.psb.bwctl" => {
        "EVENTTYPE" => [ "http://ggf.org/ns/nmwg/tools/iperf/2.0", "http://ggf.org/ns/nmwg/characteristics/bandwidth/acheiveable/2.0", "http://ggf.org/ns/nmwg/characteristics/bandwidth/achieveable/2.0", "http://ggf.org/ns/nmwg/characteristics/bandwidth/achievable/2.0" ],
        "TYPE"      => "PSB_BWCTL"
    },
    "list.psb.owamp" => {
        "EVENTTYPE" => [ "http://ggf.org/ns/nmwg/tools/owamp/2.0", "http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921" ],
        "TYPE"      => "PSB_OWAMP"
    },
    "list.pinger" => {
        "EVENTTYPE" => [ "http://ggf.org/ns/nmwg/tools/pinger/2.0/", "http://ggf.org/ns/nmwg/tools/pinger/2.0" ],
        "TYPE"      => "PINGER"
    }
);

my %daemonMap = (
    "list.owamp" => {
        "EVENTTYPE" => [ "http://ggf.org/ns/nmwg/tools/owamp/1.0" ],
        "TYPE"      => "OWAMP"
    },
    "list.traceroute" => {
        "EVENTTYPE" => [ "http://ggf.org/ns/nmwg/tools/traceroute/1.0" ],
        "TYPE"      => "TRACEROUTE"
    },
    "list.ping" => {
        "EVENTTYPE" => [ "http://ggf.org/ns/nmwg/tools/ping/1.0" ],
        "TYPE"      => "PING"
    },
    "list.npad" => {
        "EVENTTYPE" => [ "http://ggf.org/ns/nmwg/tools/npad/1.0" ],
        "TYPE"      => "NPAD"
    },
    "list.ndt" => {
        "EVENTTYPE" => [ "http://ggf.org/ns/nmwg/tools/ndt/1.0" ],
        "TYPE"      => "NDT"
    },
    "list.bwctl" => {
        "EVENTTYPE" => [ "http://ggf.org/ns/nmwg/tools/bwctl/1.0" ],
        "TYPE"      => "BWCTL"
    },
    "list.phoebus" => {
        "EVENTTYPE" => [ "http://ggf.org/ns/nmwg/tools/phoebus/1.0" ],
        "TYPE"      => "PHOEBUS"
    }
);

my @daemonList  = ();
my @serviceList = ();
my @anchors     = ();
my $lastMod     = "at an unknown time...";

if ( -d $conf{cache_directory} ) {

    my $hLSFile = $conf{cache_directory} . "/list.hls";
    if ( -f $hLSFile ) {
        my ( $mtime ) = ( stat( $hLSFile ) )[9];
        $lastMod = "on " . gmtime( $mtime ) . " UTC";
    }

    my @anch     = ();
    my $counter1 = 0;
    foreach my $file ( keys %daemonMap ) {
        if ( -f $conf{cache_directory} . "/" . $file ) {
            open( READ, "<" . $conf{cache_directory} . "/" . $file ) or next;
            my @content = <READ>;
            close( READ );

            my @temp     = ();
            my $counter2 = 0;
            my $viewFlag = 0;
            foreach my $c ( @content ) {
                my @daemon = split( /\|/, $c );
                if ( $daemon[0] =~ m/^http:\/\// ) {
                    push @temp, { daemon => $daemon[0], name => $daemon[1], type => $daemon[2], desc => $daemon[3], count1 => $counter1, count2 => $counter2, view => 1 };
                    $viewFlag++;
                }
                else {
                    push @temp, { daemon => $daemon[0], name => $daemon[1], type => $daemon[2], desc => $daemon[3], count1 => $counter1, count2 => $counter2, view => 0 };
                }
                $counter2++;
            }
            push @daemonList, { type => $daemonMap{$file}{"TYPE"}, contents => \@temp, view => $viewFlag };

        }
        push @anch, { anchor => $daemonMap{$file}{"TYPE"}, name => $daemonMap{$file}{"TYPE"} . " Daemon" };
        $counter1++;
    }
    push @anchors, { anchor => "daemons", type => "Measurement Tools", anchoritems => \@anch };

    my @anch     = ();
    my $counter1 = 0;
    foreach my $file ( keys %serviceMap ) {
        if ( -f $conf{cache_directory} . "/" . $file ) {
            open( READ, "<" . $conf{cache_directory} . "/" . $file ) or next;
            my @content = <READ>;
            close( READ );

            my @temp     = ();
            my $counter2 = 0;
            foreach my $c ( @content ) {
                my @service = split( /\|/, $c );
                push @temp, { service => $service[0], name => $service[1], type => $service[2], desc => $service[3], count1 => $counter1, count2 => $counter2, eventtype => $serviceMap{$file}{"EVENTTYPE"}[0] };
                $counter2++;
            }
            push @serviceList, { type => $serviceMap{$file}{"TYPE"}, contents => \@temp };
        }
        push @anch, { anchor => $serviceMap{$file}{"TYPE"}, name => $serviceMap{$file}{"TYPE"} . " Service" };
        $counter1++;
    }
    push @anchors, { anchor => "services", type => "perfSONAR Services", anchoritems => \@anch };
}

print $CGI->header();

my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

my $html;

my %vars = (
    modification_time => $lastMod,
    anchortypes => \@anchors,
    daemons     => \@daemonList,
    services    => \@serviceList
);

$tt->process( "directory.tmpl", \%vars, \$html ) or die $tt->error();

print $html;

__END__

=head1 SEE ALSO

L<HTML::Template>, L<CGI>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.  Bugs,
feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: directory.cgi 2948 2009-07-14 14:08:43Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2

All rights reserved.

=cut
