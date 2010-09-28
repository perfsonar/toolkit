#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

PingERGraph.cgi - CGI script that graphs the output of a perfSONAR MA that
delivers pinger data.  

=head1 DESCRIPTION

Given a url of an MA, and a key value (corresponds to a specific pinger
result) graph using the Google graph API.  Note this instance is powered by
flash, so browsers will require that a flash player be installed and available.

=cut

use CGI;
use XML::LibXML;
use Date::Manip;
use Socket;
use POSIX;
use Time::Local 'timelocal_nocheck';
use Config::General;
use English qw( -no_match_vars );
use Log::Log4perl qw(get_logger :easy :levels);

use FindBin qw($RealBin);
my $basedir = "$RealBin/";
use lib "$RealBin/../../../../lib";

use perfSONAR_PS::Client::PingER;
use perfSONAR_PS::Common qw( extract find );

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

our $logger = get_logger( "perfSONAR_PS::WebGUI::ServiceTest::PingERGraph" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my $cgi = new CGI;
print "Content-type: text/html\n\n";
if ( $cgi->param( 'key' ) and $cgi->param( 'url' ) ) {
    my $sec = time;
    my $ma = new perfSONAR_PS::Client::PingER( { instance => $cgi->param( 'url' ) } );

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
            print "<html><head><title>perfSONAR-PS perfAdmin PingER Graph</title></head>";
            print "<body><h2 align=\"center\">Graph error; Date not correctly entered.</h2></body></html>";
            exit( 1 );
        }
    }
    else {
        $start = $sec - 43200;
        $end   = $sec;
    }

    my $result = $ma->setupDataRequest(
        {
            start => $start,
            end   => $end,
            keys  => [ $cgi->param( 'key' ) ],

            # resolution => 5,
            cf => "AVERAGE",
        }
    );

    my %store = ();

    if ( $result ) {
        my $data_md = $ma->getData( $result );
        foreach my $key_id ( keys %{$data_md} ) {
            foreach my $id ( keys %{ $data_md->{$key_id}{data} } ) {
                foreach my $timev ( keys %{ $data_md->{$key_id}{data}{$id} } ) {

                    my $datum = $data_md->{$key_id}{data}{$id}{$timev};

                    my $time = UnixDate( $timev );
                    my $min  = $datum->{minRtt};
                    my $med  = $datum->{medianRtt};
                    my $mean = $datum->{meanRtt};
                    my $max  = $datum->{maxRtt};

                    $store{$timev}{"min"}    = $min  if ( defined $min );
                    $store{$timev}{"max"}    = $max  if ( defined $max );
                    $store{$timev}{"median"} = $med  if ( defined $med );
                    $store{$timev}{"mean"}   = $mean if ( defined $mean );
                }
            }
        }
    }

    my $counter = 0;
    foreach my $time ( keys %store ) {
        $counter++;
    }

    print "<html>\n";
    print "  <head>\n";
    print "    <title>perfSONAR-PS perfAdmin PingER Graph</title>\n";

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
            $title = "Observed Round-Trip Time";
        }

        print "    <script type=\"text/javascript\" src=\"http://www.google.com/jsapi\"></script>\n";
        print "    <script type=\"text/javascript\">\n";
        print "      google.load(\"visualization\", \"1\", {packages:[\"annotatedtimeline\"]});\n";
        print "      google.setOnLoadCallback(drawChart);\n";
        print "      function drawChart() {\n";
        print "        var data = new google.visualization.DataTable();\n";

        print "        data.addColumn('datetime', 'Time');\n";

        print "        data.addColumn('number', 'Min Delay (MSec)');\n";
        print "        data.addColumn('number', 'Median Delay (MSec)');\n";
        print "        data.addColumn('number', 'Mean Delay (MSec)');\n";
        print "        data.addColumn('number', 'Max Delay (MSec)');\n";
        print "        data.addRows(" . $counter . ");\n";

        $counter = 0;
        foreach my $time ( sort keys %store ) {
            my $date  = ParseDateString( "epoch " . $time );
            my $date2 = UnixDate( $date, "%Y-%m-%d %H:%M:%S" );
            my @array = split( / /, $date2 );
            my @year  = split( /-/, $array[0] );
            my @time  = split( /:/, $array[1] );
            if ( $#year > 1 and $#time > 1 ) {
                if ( exists $store{$time}{"min"} and $store{$time}{"min"} ) {
                    print "        data.setValue(" . $counter . ", 0, new Date(" . $year[0] . "," . ( $year[1] - 1 ) . ",";
                    print $year[2] . "," . $time[0] . "," . $time[1] . "," . $time[2] . "));\n";

                    print "        data.setValue(" . $counter . ", 1, " . $store{$time}{"min"} . ");\n"    if $store{$time}{"min"};
                    print "        data.setValue(" . $counter . ", 2, " . $store{$time}{"median"} . ");\n" if $store{$time}{"median"};
                    print "        data.setValue(" . $counter . ", 3, " . $store{$time}{"mean"} . ");\n"   if $store{$time}{"mean"};
                    print "        data.setValue(" . $counter . ", 4, " . $store{$time}{"max"} . ");\n"    if $store{$time}{"max"};
                }
            }
            $counter++;
        }

        print "        var chart = new google.visualization.AnnotatedTimeLine(document.getElementById('chart_div'));\n";
        print "        chart.draw(data, {legendPosition: 'newRow', colors: ['#ff8800', '#ff0000', '#0088ff', '#0000ff'], displayAnnotations: true});\n";
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
        print "    <h2 align=\"center\">No results.</h2>\n";
        print "    <br><br>\n";
    }

    print "  </body>\n";
    print "</html>\n";
}
else {
    print "<html><head><title>perfSONAR-PS perfAdmin PingER Graph</title></head>";
    print "<body><h2 align=\"center\">Graph error, cannot find 'key' or 'URL' to contact; Close window and try again.</h2></body></html>";
}

__END__

=head1 SEE ALSO

L<CGI>, L<XML::LibXML>, L<Date::Manip>, L<Socket>, L<POSIX>, L<Config::General>,
L<English>, L<perfSONAR_PS::Client::PingER>, L<perfSONAR_PS::Common>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: PingERGraph.cgi 3715 2009-09-23 15:21:57Z zurawski $

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

