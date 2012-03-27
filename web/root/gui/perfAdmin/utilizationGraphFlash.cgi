#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

utilizationGraph.cgi - CGI script that graphs the output of a perfSONAR MA that
delivers utilization data.  

=head1 DESCRIPTION

Given a url of an MA, and a key value (corresponds to a specific pair [in and
out] of utilization results) graph using the Google graph API.  Note this
instance is powered by flash, so browsers will require that a flash player be
installed and available.

=cut

use CGI;
use XML::LibXML;
use Date::Manip;
use Socket;
use POSIX;
use Data::Validate::IP qw(is_ipv4);
use English qw( -no_match_vars );
use Config::General;
use Log::Log4perl qw(get_logger :easy :levels);
use HTML::Entities;

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

our $logger = get_logger( "perfSONAR_PS::WebGUI::ServiceTest::UtilizationGraphFlash" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my $cgi = new CGI;
print "Content-type: text/html\n\n";
if ( ( $cgi->param( 'key1_type' ) or $cgi->param( 'key2_type' ) ) and $cgi->param( 'url' ) ) {

    my $ma = new perfSONAR_PS::Client::MA( { instance => $cgi->param( 'url' ) } );

    my @eventTypes = ();
    my $parser     = XML::LibXML->new();
    my ( $sec, $frac ) = Time::HiRes::gettimeofday;

    # 'in' data
    my $subject = q{};
    if ( $cgi->param( 'key1_type' ) eq "key" ) {
        $subject = "  <nmwg:key id=\"key-1\">\n";
        $subject .= "    <nmwg:parameters id=\"parameters-key-1\">\n";
        $subject .= "      <nmwg:parameter name=\"maKey\">" . $cgi->param( 'key1_1' ) . "</nmwg:parameter>\n";
        $subject .= "    </nmwg:parameters>\n";
        $subject .= "  </nmwg:key>  \n";
    }
    else {
        $subject = "  <nmwg:key id=\"key-1\">\n";
        $subject .= "    <nmwg:parameters id=\"parameters-key-1\">\n";
        $subject .= "      <nmwg:parameter name=\"file\">" . $cgi->param( 'key1_1' ) . "</nmwg:parameter>\n";
        $subject .= "      <nmwg:parameter name=\"dataSource\">" . $cgi->param( 'key1_2' ) . "</nmwg:parameter>\n";
        $subject .= "    </nmwg:parameters>\n";
        $subject .= "  </nmwg:key>  \n";
    }

    my $time;
    if ( $cgi->param( 'length' ) ) {
        $time = $cgi->param( 'length' );
    }
    else {
        $time = 86400;
    }

    my $res;
    if ( $cgi->param( 'resolution' ) ) {
        $res = $cgi->param( 'resolution' );
    }
    else {
        $res = 5;
    }

    my $result = $ma->setupDataRequest(
        {
            start                 => ( $sec - $time ),
            end                   => $sec,
            resolution            => $res,
            consolidationFunction => "AVERAGE",
            subject               => $subject,
            eventTypes            => \@eventTypes
        }
    );

    # 'out' data
    my $subject2 = q{};
    if ( $cgi->param( 'key2_type' ) eq "key" ) {
        $subject2 = "  <nmwg:key id=\"key-2\">\n";
        $subject2 .= "    <nmwg:parameters id=\"parameters-key-2\">\n";
        $subject2 .= "      <nmwg:parameter name=\"maKey\">" . $cgi->param( 'key2_1' ) . "</nmwg:parameter>\n";
        $subject2 .= "    </nmwg:parameters>\n";
        $subject2 .= "  </nmwg:key>  \n";
    }
    else {
        $subject2 = "  <nmwg:key id=\"key-2\">\n";
        $subject2 .= "    <nmwg:parameters id=\"parameters-key-2\">\n";
        $subject2 .= "      <nmwg:parameter name=\"file\">" . $cgi->param( 'key2_1' ) . "</nmwg:parameter>\n";
        $subject2 .= "      <nmwg:parameter name=\"dataSource\">" . $cgi->param( 'key2_2' ) . "</nmwg:parameter>\n";
        $subject2 .= "    </nmwg:parameters>\n";
        $subject2 .= "  </nmwg:key>  \n";
    }

    my $result2 = $ma->setupDataRequest(
        {
            start                 => ( $sec - $time ),
            end                   => $sec,
            resolution            => $res,
            consolidationFunction => "AVERAGE",
            subject               => $subject2,
            eventTypes            => \@eventTypes
        }
    );

    my $doc1 = q{};
    eval { $doc1 = $parser->parse_string( $result->{"data"}->[0] ); };
    if ( $EVAL_ERROR ) {
        print "<html><head><title>perfSONAR-PS perfAdmin Utilization Graph</title></head>";
        print "<body><h2 align=\"center\">Cannot parse XML response from service.</h2></body></html>";
        exit( 1 );
    }
    my $datum1 = find( $doc1->getDocumentElement, "./*[local-name()='datum']", 0 );

    my $doc2 = q{};
    eval { $doc2 = $parser->parse_string( $result2->{"data"}->[0] ); };
    if ( $EVAL_ERROR ) {
        print "<html><head><title>perfSONAR-PS perfAdmin Utilization Graph</title></head>";
        print "<body><h2 align=\"center\">Cannot parse XML response from service.</h2></body></html>";
        exit( 1 );
    }
    my $datum2 = find( $doc2->getDocumentElement, "./*[local-name()='datum']", 0 );

    my %store   = ();
    my $counter = 0;
    my $inUnit  = q{};
    my $outUnit = q{};
    if ( $datum1 and $datum2 ) {
        foreach my $dt ( $datum1->get_nodelist ) {
            $counter++;
        }
        foreach my $dt ( $datum1->get_nodelist ) {
            $store{ $dt->getAttribute( "timeValue" ) }{"in"} = eval( $dt->getAttribute( "value" ) );
            $inUnit = $dt->getAttribute( "valueUnits" ) unless $inUnit;
        }
        foreach my $dt ( $datum2->get_nodelist ) {
            $store{ $dt->getAttribute( "timeValue" ) }{"out"} = eval( $dt->getAttribute( "value" ) );
            $outUnit = $dt->getAttribute( "valueUnits" ) unless $outUnit;
        }
    }

    print "<html>\n";
    print "  <head>\n";
    print "    <title>perfSONAR-PS perfAdmin Utilization Graph</title>\n";

    if ( scalar keys %store > 0 ) {

        my $title = q{};
        if ( $cgi->param( 'host' ) and $cgi->param( 'interface' ) ) {
            my $host = q{};
            if ( is_ipv4( $cgi->param( 'host' ) ) ) {
                my $iaddr = Socket::inet_aton( $cgi->param( 'host' ) );
                if ( defined $iaddr and $iaddr ) {
                    $host = gethostbyaddr( $iaddr, Socket::AF_INET );
                }
            }
            else {
                my $packed_ip = gethostbyname( $cgi->param( 'host' ) );
                if ( defined $packed_ip and $packed_ip ) {
                    $host = inet_ntoa( $packed_ip );
                }
            }
            $title = "Device: " . HTML::Entities::encode($cgi->param( 'host' ));
            $title .= " (" . HTML::Entities::encode($host) . ") " if $host;
            $title .= " -- " . HTML::Entities::encode($cgi->param( 'interface' ));
        }
        else {
            $title = "Interface Utilization";
        }

        print "    <script type=\"text/javascript\" src=\"http://www.google.com/jsapi\"></script>\n";
        print "    <script type=\"text/javascript\">\n";
        print "      google.load(\"visualization\", \"1\", {packages:[\"annotatedtimeline\"]});\n";
        print "      google.setOnLoadCallback(drawChart);\n";
        print "      function drawChart() {\n";
        print "        var data = new google.visualization.DataTable();\n";
        print "        data.addColumn('datetime', 'Time');\n";

        $counter = 0;
        my %inStats  = ();
        my %outStats = ();
        foreach my $time ( keys %store ) {
            if ( exists $store{$time}{"in"} and $store{$time}{"in"} and exists $store{$time}{"out"} and $store{$time}{"out"} ) {
                $inStats{"average"}  += $store{$time}{"in"};
                $outStats{"average"} += $store{$time}{"out"};
                $inStats{"max"}  = $store{$time}{"in"}  if $store{$time}{"in"} > $inStats{"max"};
                $outStats{"max"} = $store{$time}{"out"} if $store{$time}{"out"} > $outStats{"max"};
                $inStats{"current"}  = $store{$time}{"in"};
                $outStats{"current"} = $store{$time}{"out"};
                $counter++;
            }
        }
        $inStats{"average"}  /= $counter if $counter;
        $outStats{"average"} /= $counter if $counter;

        my $mod   = q{};
        my $scale = q{};
        if ( $inUnit and $outUnit and ( $inUnit eq $outUnit ) and ( lc( $inUnit ) eq "bps" ) ) {
            $scale = $inStats{"max"};
            $scale = $outStats{"max"} if $outStats{"max"} > $scale;
            if ( $scale < 1000 ) {
                $scale = 1;
            }
            elsif ( $scale < 1000000 ) {
                $mod   = "K";
                $scale = 1000;
            }
            elsif ( $scale < 1000000000 ) {
                $mod   = "M";
                $scale = 1000000;
            }
            elsif ( $scale < 1000000000000 ) {
                $mod   = "G";
                $scale = 1000000000;
            }
        }

        my $yLabel = q{};
        if ( $inUnit and $outUnit and $inUnit eq $outUnit ) {
            print "        data.addColumn('number', 'Incoming Traffic in " . $mod . $inUnit . "');\n";
            print "        data.addColumn('number', 'Outgoing Traffic in " . $mod . $outUnit . "');\n";
            $yLabel = $mod . $inUnit;
        }
        else {
            print "        data.addColumn('number', 'Incoming Traffic in unknown units');\n";
            print "        data.addColumn('number', 'Outgoing Traffic in unknown units');\n";
            $yLabel = "unknown units";
        }
        print "        data.addRows(" . $counter . ");\n";

        $counter = 0;
        foreach my $time ( sort keys %store ) {
            my $date  = ParseDateString( "epoch " . $time );
            my $date2 = UnixDate( $date, "%Y-%m-%d %H:%M:%S" );
            my @array = split( / /, $date2 );
            my @year  = split( /-/, $array[0] );
            my @time  = split( /:/, $array[1] );
            if ( $#year > 1 and $#time > 1 and ( exists $store{$time}{"in"} and $store{$time}{"in"} and exists $store{$time}{"out"} and $store{$time}{"out"} ) ) {
                if ( $scale and $mod ) {
                    $store{$time}{"in"}  /= $scale;
                    $store{$time}{"out"} /= $scale;
                }
                print "        data.setValue(" . $counter . ", 0, new Date(" . $year[0] . "," . ( $year[1] - 1 ) . "," . $year[2] . "," . $time[0] . "," . $time[1] . "," . $time[2] . "));\n";
                print "        data.setValue(" . $counter . ", 1, " . sprintf( "%.2f", $store{$time}{"in"} ) . ");\n";
                print "        data.setValue(" . $counter . ", 2, " . sprintf( "%.2f", $store{$time}{"out"} ) . ");\n";
                $counter++;
            }
        }

        print "        var chart = new google.visualization.AnnotatedTimeLine(document.getElementById('chart_div'));\n";
        print "        chart.draw( data, { colors: ['#00cc00', '#0000ff'] } );\n";
        print "      }\n";
        print "    </script>\n";
        print "  </head>\n";
        print "  <body>\n";
        print "    <h3 align=\"center\">" . $title . "</h3>\n";
        print "    <div id=\"chart_div\" style=\"width: 900px; height: 400px;\"></div><br>\n";

        print "    <table border=\"0\" cellpadding=\"0\" width=\"75%\" align=\"center\">";
        print "      <tr>\n";
        print "        <th align=\"left\" width=\"15%\"><font size=\"-1\">Maximum In</font></th>\n";
        my $temp = scaleValue( { value => $inStats{"max"}, units => $yLabel } );
        printf( "        <td align=\"right\" width=\"30%\"><font size=\"-1\">%.2f " . $temp->{"mod"} . $inUnit . "</font></td>\n", $temp->{"value"} );
        print "        <td align=\"right\" width=\"10%\"><br></td>\n";
        print "        <th align=\"left\" width=\"15%\"><font size=\"-1\">Maximum Out</font></th>\n";
        $temp = scaleValue( { value => $outStats{"max"}, units => $yLabel } );
        printf( "        <td align=\"right\" width=\"30%\"><font size=\"-1\">%.2f " . $temp->{"mod"} . $outUnit . "</font></td>\n", $temp->{"value"} );
        print "      <tr>\n";
        print "      <tr>\n";
        print "        <th align=\"left\" width=\"15%\"><font size=\"-1\">Average In</font></th>\n";
        $temp = scaleValue( { value => $inStats{"average"}, units => $yLabel } );
        printf( "        <td align=\"right\" width=\"30%\"><font size=\"-1\">%.2f " . $temp->{"mod"} . $inUnit . "</font></td>\n", $temp->{"value"} );
        print "        <td align=\"right\" width=\"10%\"><br></td>\n";
        print "        <th align=\"left\" width=\"15%\"><font size=\"-1\">Average Out</font></th>\n";
        $temp = scaleValue( { value => $outStats{"average"}, units => $yLabel } );
        printf( "        <td align=\"right\" width=\"30%\"><font size=\"-1\">%.2f " . $temp->{"mod"} . $outUnit . "</font></td>\n", $temp->{"value"} );
        print "      <tr>\n";
        print "      <tr>\n";
        print "        <th align=\"left\" width=\"15%\"><font size=\"-1\">Current In</font></th>\n";
        $temp = scaleValue( { value => $inStats{"current"}, units => $yLabel } );
        printf( "        <td align=\"right\" width=\"30%\"><font size=\"-1\">%.2f " . $temp->{"mod"} . $inUnit . "</font></td>\n", $temp->{"value"} );
        print "        <td align=\"right\" width=\"10%\"><br></td>\n";
        print "        <th align=\"left\" width=\"15%\"><font size=\"-1\">Current Out</font></th>\n";
        $temp = scaleValue( { value => $outStats{"current"}, units => $yLabel } );
        printf( "        <td align=\"right\" width=\"30%\"><font size=\"-1\">%.2f " . $temp->{"mod"} . $outUnit . "</font></td>\n", $temp->{"value"} );
        print "      <tr>\n";
        print "    </table>\n";

    }
    else {
        print "  </head>\n";
        print "  <body>\n";
        print "    <br><br>\n";
        print "    <h2 align=\"center\">Internal Error - Try again later.</h2>\n";
        print "    <br><br>\n";
    }

    print "  </body>\n";
    print "</html>\n";
}
else {
    print "<html><head><title>perfSONAR-PS perfAdmin Utilization Graph</title></head>";
    print "<body><h2 align=\"center\">Graph error, cannot find 'key1_type', 'key2_type', or 'URL' to contact; Close window and try again.</h2></body></html>";
}

=head2 scaleValue ( { value, units } )

Given a value, return the value scaled to a magnitude.

=cut

sub scaleValue {
    my $parameters = validateParams( @_, { value => 1, units => 0 } );
    my %result = ();
    if ( exists $parameters->{"units"} and $parameters->{"units"} =~ m/^unknown/ ) {
        $result{"value"} = $parameters->{"value"};
        $result{"mod"}   = q{};
    }
    else {
        if ( $parameters->{"value"} < 1000 ) {
            $result{"value"} = $parameters->{"value"};
            $result{"mod"}   = q{};
        }
        elsif ( $parameters->{"value"} < 1000000 ) {
            $result{"value"} = $parameters->{"value"} / 1000;
            $result{"mod"}   = "K";
        }
        elsif ( $parameters->{"value"} < 1000000000 ) {
            $result{"value"} = $parameters->{"value"} / 1000000;
            $result{"mod"}   = "M";
        }
        elsif ( $parameters->{"value"} < 1000000000000 ) {
            $result{"value"} = $parameters->{"value"} / 1000000000;
            $result{"mod"}   = "G";
        }
    }
    return \%result;
}

__END__

=head1 SEE ALSO

L<CGI>, L<XML::LibXML>, L<Date::Manip>, L<Socket>, L<POSIX>, L<English>,
L<perfSONAR_PS::Client::MA>, L<perfSONAR_PS::Common>,
L<perfSONAR_PS::Utils::ParameterValidation>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: utilizationGraphFlash.cgi 3617 2009-08-24 16:52:58Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2

All rights reserved.

=cut
