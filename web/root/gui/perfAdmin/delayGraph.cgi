#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

delayGraph.cgi - CGI script that graphs the output of a perfSONAR MA that
delivers delay data.  

=head1 DESCRIPTION

Given a url of an MA, and a key value (corresponds to a specific delay
result) graph using the Google graph API.  Note this instance is powered by
flash, so browsers will require that a flash player be installed and available.

=cut

use CGI;
use XML::LibXML;
use Date::Manip;
use Socket;
use POSIX;
use Time::Local 'timelocal_nocheck';
use English qw( -no_match_vars );
use Config::General;
use Log::Log4perl qw(get_logger :easy :levels);

use FindBin qw($RealBin);
my $basedir = "$RealBin/";
use lib "$RealBin/../../../../lib";

use perfSONAR_PS::Client::MA;
use perfSONAR_PS::Common qw( extract find );
use perfSONAR_PS::Utils::ParameterValidation;

my $config_file = $basedir . '/etc/web_admin.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our %conf = $conf_obj->getall;

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

our $logger = get_logger( "perfSONAR_PS::WebGUI::ServiceTest::delayGraph" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my $cgi = new CGI;
print "Content-type: text/html\n\n";
if ( $cgi->param( 'key' ) and $cgi->param( 'url' ) ) {

    my $ma = new perfSONAR_PS::Client::MA( { instance => $cgi->param( 'url' ) } );

    my @eventTypes = ();
    my $parser     = XML::LibXML->new();
    my ( $sec, $frac ) = Time::HiRes::gettimeofday;

    my $start;
    my $end;
    if ( $cgi->param( 'length' ) ) {
        $start = $sec - $cgi->param( 'length' );
        $end   = $sec;
    }
    elsif ( $cgi->param( 'smon' ) or $cgi->param( 'sday' ) or $cgi->param( 'syear' ) or $cgi->param( 'dmon' ) or $cgi->param( 'dday' ) or $cgi->param( 'dyear' ) ) {
        if ( $cgi->param( 'smon' ) and $cgi->param( 'sday' ) and $cgi->param( 'syear' ) and $cgi->param( 'dmon' ) and $cgi->param( 'dday' ) and $cgi->param( 'dyear' ) ) {
            $start = timelocal_nocheck 0, 0, 0, ( $cgi->param( 'sday' ) - 1 ), ( $cgi->param( 'smon' ) - 1 ), ( $cgi->param( 'syear' ) - 1900 );
            $end   = timelocal_nocheck 0, 0, 0, ( $cgi->param( 'dday' ) - 1 ), ( $cgi->param( 'dmon' ) - 1 ), ( $cgi->param( 'dyear' ) - 1900 );
        }
        else {
            print "<html><head><title>perfSONAR-PS perfAdmin Delay Graph</title></head>";
            print "<body><h2 align=\"center\">Graph error; Date not correctly entered.</h2></body></html>";
            exit( 1 );
        }
    }
    else {
        $start = $sec - 7200;
        $end   = $sec;
    }

    my @flags = ( 0, 0 );
    my %store = ();

    #retrieve data for forward direction
    foreach my $key1 ( split '_', $cgi->param( 'key' ) ) {
        &retrieveData(
            'key'       => $key1,
            'start'     => $start,
            'end'       => $end,
            'flags'     => \@flags,
            'store'     => \%store,
            'storeType' => 'src',
            'ma'        => $ma,
            'parser'    => $parser
        );
    }

    #retrieve data for reverse direction
    foreach my $key2 ( split '_', $cgi->param( 'key2' ) ) {
        &retrieveData(
            'key'       => $key2,
            'start'     => $start,
            'end'       => $end,
            'flags'     => \@flags,
            'store'     => \%store,
            'storeType' => 'dst',
            'ma'        => $ma,
            'parser'    => $parser
        );
    }

    my $counter = 0;
    foreach my $time ( keys %store ) {
        $counter++;
    }

    print "<html>\n";
    print "  <head>\n";
    print "    <title>perfSONAR-PS perfAdmin Delay Graph</title>\n";

    if ( $flags[0] or $flags[1] ) {
        if ( scalar keys %store > 0 ) {
            my $title = q{};
            if ( $cgi->param( 'src' ) and $cgi->param( 'dst' ) ) {

                if ( $cgi->param( 'shost' ) and $cgi->param( 'dhost' ) ) {
                    $title = "Source: " . $cgi->param( 'shost' );
                    $title .= " (" . $cgi->param( 'src' ) . ") ";
                    $title .= " -- Destination: " . $cgi->param( 'dhost' );
                    $title .= " (" . $cgi->param( 'dst' ) . ") ";
                }
                else {
                    my $display = $cgi->param( 'src' );
                    my $iaddr   = Socket::inet_aton( $display );
                    my $shost   = gethostbyaddr( $iaddr, Socket::AF_INET );
                    $display = $cgi->param( 'dst' );
                    $iaddr   = Socket::inet_aton( $display );
                    my $dhost = gethostbyaddr( $iaddr, Socket::AF_INET );
                    $title = "Source: " . $shost;
                    $title .= " (" . $cgi->param( 'src' ) . ") " if $shost;
                    $title .= " -- Destination: " . $dhost;
                    $title .= " (" . $cgi->param( 'dst' ) . ") " if $dhost;
                }
            }
            else {
                $title = "Observed Latency";
            }

            print "    <script type=\"text/javascript\" src=\"http://www.google.com/jsapi\"></script>\n";
            print "    <script type=\"text/javascript\">\n";
            print "      google.load(\"visualization\", \"1\", {packages:[\"annotatedtimeline\"]});\n";
            print "      google.setOnLoadCallback(drawChart);\n";
            print "      function drawChart() {\n";
            print "        var data = new google.visualization.DataTable();\n";

            print "        data.addColumn('datetime', 'Time');\n";
            print "        data.addColumn('number', '[Src to Dst] Delay (MSec)');\n";
            print "        data.addColumn('string', '[Src to Dst] Observed Loss');\n";
            print "        data.addColumn('string', 'text1');\n";
            print "        data.addColumn('number');\n";
            print "        data.addColumn('string', '[Src to Dst] Observed Duplicates');\n";
            print "        data.addColumn('string', 'text2');\n";

            if ( $cgi->param( 'key2' ) ) {
                print "        data.addColumn('number', '[Dst to Src] Delay (MSec)');\n";
                print "        data.addColumn('string', '[Dst to Src] Observed Loss');\n";
                print "        data.addColumn('string', 'text1');\n";
                print "        data.addColumn('number');\n";
                print "        data.addColumn('string', '[Dst to Src] Observed Duplicates');\n";
                print "        data.addColumn('string', 'text2');\n";
            }
            print "        data.addRows(" . $counter . ");\n";

            print "        data.setValue(0, 0, undefined);\n";
            print "        data.setValue(0, 1, undefined);\n";
            print "        data.setValue(0, 2, undefined);\n";
            print "        data.setValue(0, 3, undefined);\n";
            print "        data.setValue(0, 4, undefined);\n";
            print "        data.setValue(0, 5, undefined);\n";
            if ( $cgi->param( 'key2' ) ) {
                print "        data.setValue(0, 6, undefined);\n";
                print "        data.setValue(0, 7, undefined);\n";
                print "        data.setValue(0, 8, undefined);\n";
                print "        data.setValue(0, 9, undefined);\n";
                print "        data.setValue(0, 10, undefined);\n";
                print "        data.setValue(0, 11, undefined);\n";
                print "        data.setValue(0, 12, undefined);\n";
            }
            $counter = 0;
            foreach my $time ( sort keys %store ) {
                my $date  = ParseDateString( "epoch " . $time );
                my $date2 = UnixDate( $date, "%Y-%m-%d %H:%M:%S" );
                my @array = split( / /, $date2 );
                my @year  = split( /-/, $array[0] );
                my @time  = split( /:/, $array[1] );
                if ( $#year > 1 and $#time > 1 ) {
                    print "        data.setValue(" . $counter . ", 0, new Date(" . $year[0] . "," . ( $year[1] - 1 ) . "," . $year[2] . "," . $time[0] . "," . $time[1] . "," . $time[2] . "));\n";
                    if ( exists $store{$time}{"min"}{"src"} and $store{$time}{"min"}{"src"} ) {
                        print "        data.setValue(" . $counter . ", 1, " . sprintf( "%.3f", ( $store{$time}{"min"}{"src"} * 1000 ) ) . ");\n" if $store{$time}{"min"}{"src"};
                    }
                    if ( $store{$time}{"loss"}{"src"} ) {
                        print "        data.setValue(" . $counter . ", 2, 'Loss Observed (SRC to DST)');\n";
                        print "        data.setValue(" . $counter . ", 3, 'Lost " . $store{$time}{"loss"}{"src"} . " packets out of " . $store{$time}{"sent"}{"src"} . "');\n";
                    }
                    if ( $store{$time}{"dups"}{"src"} ) {
                        print "        data.setValue(" . $counter . ", 4, undefined);\n";
                        print "        data.setValue(" . $counter . ", 5, 'Duplicates Observed (SRC to DST)');\n";
                        print "        data.setValue(" . $counter . ", 6, '" . $store{$time}{"dups"}{"src"} . " duplicate packets out of " . $store{$time}{"sent"}{"src"} . "');\n";
                    }

                    if ( exists $store{$time}{"min"}{"dst"} and $store{$time}{"min"}{"dst"} ) {
                        print "        data.setValue(" . $counter . ", 7, " . sprintf( "%.3f", ( $store{$time}{"min"}{"dst"} * 1000 ) ) . ");\n" if $store{$time}{"min"}{"dst"};
                    }
                    if ( $store{$time}{"loss"}{"dst"} ) {
                        print "        data.setValue(" . $counter . ", 8, 'Loss Observed (DST to SRC)');\n";
                        print "        data.setValue(" . $counter . ", 9, 'Lost " . $store{$time}{"loss"}{"dst"} . " packets out of " . $store{$time}{"sent"}{"dst"} . "');\n";
                    }
                    if ( $store{$time}{"dups"}{"dst"} ) {
                        print "        data.setValue(" . $counter . ", 10, undefined);\n";
                        print "        data.setValue(" . $counter . ", 11, 'Duplicates Observed (DST to SRC)');\n";
                        print "        data.setValue(" . $counter . ", 12, '" . $store{$time}{"dups"}{"dst"} . " duplicate packets out of " . $store{$time}{"sent"}{"dst"} . "');\n";
                    }
                }
                $counter++;
            }
            print "        var chart = new google.visualization.AnnotatedTimeLine(document.getElementById('chart_div'));\n";

            print "        chart.draw(data, {legendPosition: 'newRow', displayAnnotations: true, colors: ['#ff0000', '#00ff00', '#0000ff']});\n";
            # JZ 5/19/10
            #
            # Support for a 'filter box', being withheld for now.
            #print "        chart.draw(data, {legendPosition: 'newRow', displayAnnotations: true, displayAnnotationsFilter: true, colors: ['#ff0000', '#00ff00', '#0000ff']});\n";

            print "        chart.hideDataColumns([4, 10]);\n";
            print "      }\n";
            print "    </script>\n";
            print "  </head>\n";
            print "  <body>\n";
            print "    <h4 align=\"center\">" . $title . "</h4>\n";
            print "    <div id=\"chart_div\" style=\"width: 900px; height: 400px;\"></div>\n";
        }
        else {
            print "  </head>\n";
            print "  <body>\n";
            print "    <br><br>\n";
            print "    <h2 align=\"center\">Internal Error - Service could not find data to plot for this measurement pair.</h2>\n";
            print "    <br><br>\n";
        }
    }
    else {
        print "  </head>\n";
        print "  <body>\n";
        print "    <br><br>\n";
        print "    <h2 align=\"center\">Internal Error - Service returned data, but it is not plotable for this measurement pair.  </h2>\n";
        print "    <br><br>\n";
    }

    print "  </body>\n";
    print "</html>\n";
    exit( 1 );
}
else {
    print "<html><head><title>perfSONAR-PS perfAdmin Delay Graph</title></head>";
    print "<body><h2 align=\"center\">Graph error, cannot find 'key' or 'URL' to contact; Close window and try again.</h2></body></html>";
    exit( 1 );
}

=head2 retrieveData ( { params } )

Retrieve data based on a key using the given parameters

=cut

sub retrieveData() {
    my $parameters = validateParams(
        @_,
        {
            'key'       => 1,
            'start'     => 1,
            'end'       => 1,
            'flags'     => 1,
            'store'     => 1,
            'storeType' => 1,
            'ma'        => 1,
            'parser'    => 1
        }
    );
    my @eventTypes = ();

    my $subject = "  <nmwg:key id=\"key-1\">\n";
    $subject .= "    <nmwg:parameters id=\"parameters-key-1\">\n";
    $subject .= "      <nmwg:parameter name=\"maKey\">" . $parameters->{'key'} . "</nmwg:parameter>\n";
    $subject .= "    </nmwg:parameters>\n";
    $subject .= "  </nmwg:key>  \n";

    my $result = $parameters->{'ma'}->setupDataRequest(
        {
            start      => $parameters->{'start'},
            end        => $parameters->{'end'},
            resolution => 5,
            subject    => $subject,
            eventTypes => \@eventTypes
        }
    );

    my $doc1 = q{};
    eval { $doc1 = $parameters->{'parser'}->parse_string( $result->{"data"}->[0] ); };
    if ( $EVAL_ERROR ) {
        print "<html><head><title>perfSONAR-PS perfAdmin Delay Graph</title></head>";
        print "<body><h2 align=\"center\">Cannot parse XML response from service.</h2></body></html>";
        exit( 1 );
    }

    my $datum1 = find( $doc1->getDocumentElement, "./*[local-name()='datum']", 0 );
    if ( $datum1 ) {
        my $flagIndex = 0;
        if ( $parameters->{'storeType'} eq 'dst' ) {
            $flagIndex = 1;
        }
        foreach my $dt ( $datum1->get_nodelist ) {
            my $s_secs = UnixDate( $dt->getAttribute( "startTime" ), "%s" );
            my $e_secs = UnixDate( $dt->getAttribute( "endTime" ),   "%s" );

            my $min = $dt->getAttribute( "min_delay" );
            $min = eval( $min ) if $min;
            $parameters->{'flags'}->[$flagIndex] = 1 if $min;

            my $sent = $dt->getAttribute( "sent" );
            $sent = eval( $sent ) if $sent;

            my $loss = $dt->getAttribute( "loss" );
            $loss = eval( $loss ) if $loss;

            my $dups = $dt->getAttribute( "duplicates" );
            $dups = eval( $dups ) if $dups;

            $parameters->{'store'}->{$e_secs}{"min"}{ $parameters->{'storeType'} }  = $min  if $e_secs and $min;
            $parameters->{'store'}->{$e_secs}{"loss"}{ $parameters->{'storeType'} } = $loss if $e_secs and $loss;
            $parameters->{'store'}->{$e_secs}{"dups"}{ $parameters->{'storeType'} } = $dups if $e_secs and $dups;
            $parameters->{'store'}->{$e_secs}{"sent"}{ $parameters->{'storeType'} } = $sent if $e_secs and $sent;
        }
    }
}

__END__

=head1 SEE ALSO

L<CGI>, L<XML::LibXML>, L<Date::Manip>, L<Socket>, L<POSIX>, L<Time::Local>,
L<English>, L<perfSONAR_PS::Client::MA>, L<perfSONAR_PS::Common>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: delayGraph.cgi 3838 2010-01-20 16:19:57Z alake $

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
