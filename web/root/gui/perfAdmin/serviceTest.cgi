#!/usr/bin/perl -w

use strict;
use warnings;

=head1 name

serviceTest.cgi - Test out a perfSONAR service (usually a MA) by doing a simple
query and attempting the visualize data (where applicable).

=head1 DESCRIPTION

Perform a metadata key request on a service and offer the ability to graph (if
available for the data type).  

=cut

use CGI;
use XML::LibXML;
use Socket;
use Data::Validate::IP qw(is_ipv4);
use Net::IP;
use English qw( -no_match_vars );
use Template;
use Config::General;
use HTML::Entities;
use Log::Log4perl qw(get_logger :easy :levels);

use Data::Dumper;

use FindBin qw($RealBin);
my $basedir = "$RealBin/";
use lib "$RealBin/../../../../lib";

use lib "/usr/local/perfSONAR-PS/perfSONAR_PS-PingER/lib";

use perfSONAR_PS::Client::MA;
use perfSONAR_PS::Common qw( extract find );
use perfSONAR_PS::Utils::ParameterValidation;
use perfSONAR_PS::Client::PingER;

my $config_file = $basedir . '/etc/web_admin.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our %conf = $conf_obj->getall;

$conf{template_directory} = "templates" unless ( $conf{template_directory} );
$conf{template_directory} = $basedir . "/" . $conf{template_directory} unless ( $conf{template_directory} =~ /^\// );

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

my $cgi      = CGI->new();
print $cgi->header();

my $service;
if ( $cgi->param( 'url' ) ) {
    $service = HTML::Entities::encode($cgi->param( 'url' ));
}
else {
    my $html = errorPage("Service URL not provided.");
    print $html;
    exit( 1 );
}

my $eventType;
if ( $cgi->param( 'eventType' ) ) {
    $eventType = HTML::Entities::encode($cgi->param( 'eventType' ));
    $eventType =~ s/(\s|\n)*//g;
}
else {
    my $html = errorPage("Service eventType not provided.");
    print $html;
    exit( 1 );
}

my $ma = new perfSONAR_PS::Client::MA( { instance => $service } );

my $subject;
my @eventTypes = ();
push @eventTypes, $eventType;
if ( $eventType eq "http://ggf.org/ns/nmwg/characteristic/utilization/2.0" ) {
    $subject = "    <netutil:subject xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\" id=\"s\">\n";
    $subject .= "      <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\" />\n";
    $subject .= "    </netutil:subject>\n";
}
elsif ($eventType eq "http://ggf.org/ns/nmwg/tools/iperf/2.0"
    or $eventType eq "http://ggf.org/ns/nmwg/characteristics/bandwidth/acheiveable/2.0"
    or $eventType eq "http://ggf.org/ns/nmwg/characteristics/bandwidth/achieveable/2.0"
    or $eventType eq "http://ggf.org/ns/nmwg/characteristics/bandwidth/achievable/2.0" )
{
    $subject = "    <iperf:subject xmlns:iperf=\"http://ggf.org/ns/nmwg/tools/iperf/2.0/\" id=\"subject\">\n";
    $subject .= "      <nmwgt:endPointPair xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\" />\n";
    $subject .= "    </iperf:subject>\n";
}
elsif ( $eventType eq "http://ggf.org/ns/nmwg/tools/owamp/2.0" or $eventType eq "http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921" ) {
    $subject = "    <owamp:subject xmlns:owamp=\"http://ggf.org/ns/nmwg/tools/owamp/2.0/\" id=\"subject\">\n";
    $subject .= "      <nmwgt:endPointPair xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\" />\n";
    $subject .= "    </owamp:subject>\n";
}
elsif ( $eventType eq "http://ggf.org/ns/nmwg/tools/pinger/2.0/" or $eventType eq "http://ggf.org/ns/nmwg/tools/pinger/2.0" ) {
    $subject = "    <pinger:subject xmlns:pinger=\"http://ggf.org/ns/nmwg/tools/pinger/2.0/\" id=\"subject\">\n";
    $subject .= "      <nmwgt:endPointPair xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\" />\n";
    $subject .= "    </pinger:subject>\n";
}
else {
    my $html = errorPage("Unrecognized eventType: \"" . $eventType . "\".");
    print $html;
    exit( 1 );
}

my $parser = XML::LibXML->new();
my $result = $ma->metadataKeyRequest(
    {
        subject    => $subject,
        eventTypes => \@eventTypes
    }
);

unless ( $#{ $result->{"metadata"} } > -1 ) {
    my $html = errorPage("MA <b><i>" . $service . "</i></b> did not return the expected response, is it functioning?");
    print $html;
    exit( 1 );
}

my $metadata = q{};
eval { $metadata = $parser->parse_string( $result->{"metadata"}->[0] ); };
if ( $EVAL_ERROR ) {
    my $html = errorPage("Could not parse XML response from MA <b><i>" . $service . "</i></b>.");
    print $html;
    exit( 1 );
}

my $et = extract( find( $metadata->getDocumentElement, ".//nmwg:eventType", 1 ), 0 );

if ( $et eq "error.ma.storage" ) {
    my $html = errorPage("MA <b><i>" . $service . "</i></b> did not return the expected response, be sure it is configured and populated with data.");
    print $html;
    exit( 1 );
}
else {
    if ( $eventType eq "http://ggf.org/ns/nmwg/characteristic/utilization/2.0" ) {
        my %lookup = ();
        foreach my $d ( @{ $result->{"data"} } ) {
            my $data = q{};
            eval { $data = $parser->parse_string( $d ); };
            if ( $EVAL_ERROR ) {
                my $html = errorPage("Could not parse XML response from MA <b><i>" . $service . "</i></b>.");
                print $html;
                exit( 1 );
            }

            my $metadataIdRef = $data->getDocumentElement->getAttribute( "metadataIdRef" );
            my $key           = extract( find( $data->getDocumentElement, ".//nmwg:parameter[\@name=\"maKey\"]", 1 ), 0 );
            if ( $key ) {
                $lookup{$metadataIdRef}{"key1"} = $key if $metadataIdRef;
                $lookup{$metadataIdRef}{"key2"} = q{};
                $lookup{$metadataIdRef}{"type"} = "key";
            }
            else {
                $key = extract( find( $data->getDocumentElement, ".//nmwg:parameter[\@name=\"file\"]", 1 ), 0 );
                $lookup{$metadataIdRef}{"key1"} = $key if $key and $metadataIdRef;
                $key = extract( find( $data->getDocumentElement, ".//nmwg:parameter[\@name=\"dataSource\"]", 1 ), 0 );
                $lookup{$metadataIdRef}{"key2"} = $key if $key and $metadataIdRef;
                $lookup{$metadataIdRef}{"type"} = "nonkey";
            }
        }

        my %list = ();
        foreach my $md ( @{ $result->{"metadata"} } ) {
            my $metadata = q{};
            eval { $metadata = $parser->parse_string( $md ); };
            if ( $EVAL_ERROR ) {
                my $html = errorPage("Could not parse XML response from MA <b><i>" . $service . "</i></b>.");
                print $html;
                exit( 1 );
            }

            my $metadataId = $metadata->getDocumentElement->getAttribute( "id" );
            my $dir        = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:interface/nmwgt:direction", 1 ), 0 );
            my $host       = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:interface/nmwgt:hostName", 1 ), 0 );            
            if ( is_ipv4( $host ) ) {
                my $iaddr = Socket::inet_aton( $host );
                if ( defined $iaddr and $iaddr ) {
                    $host = gethostbyaddr( $iaddr, Socket::AF_INET );
                }
            }     
            
            my $name       = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:interface/nmwgt:ifName", 1 ), 0 );
            if ( $list{$host}{$name} ) {
                if ( $dir eq "in" ) {
                    $list{$host}{$name}->{"key1_1"}    = $lookup{$metadataId}{"key1"};
                    $list{$host}{$name}->{"key1_2"}    = $lookup{$metadataId}{"key2"};
                    $list{$host}{$name}->{"key1_type"} = $lookup{$metadataId}{"type"};
                }
                else {
                    $list{$host}{$name}->{"key2_1"}    = $lookup{$metadataId}{"key1"};
                    $list{$host}{$name}->{"key2_2"}    = $lookup{$metadataId}{"key2"};
                    $list{$host}{$name}->{"key2_type"} = $lookup{$metadataId}{"type"};
                }
            }
            else {
                my %temp = ();
                if ( $dir eq "in" ) {
                    $temp{"key1_1"}    = $lookup{$metadataId}{"key1"};
                    $temp{"key1_2"}    = $lookup{$metadataId}{"key2"};
                    $temp{"key1_type"} = $lookup{$metadataId}{"type"};
                }
                else {
                    $temp{"key2_1"}    = $lookup{$metadataId}{"key1"};
                    $temp{"key2_2"}    = $lookup{$metadataId}{"key2"};
                    $temp{"key2_type"} = $lookup{$metadataId}{"type"};
                }
                $temp{"hostName"}      = $host;
                $temp{"ifName"}        = $name;
                $temp{"ifIndex"}       = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:interface/nmwgt:ifIndex", 1 ), 0 );
                $temp{"ipAddress"}     = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:interface/nmwgt:ipAddress", 1 ), 0 );
                unless ( is_ipv4( $temp{"ipAddress"} ) ) {
                    unless ( &Net::IP::ip_is_ipv6( $temp{"ipAddress"} ) ) {
                        my $packed_ip = gethostbyname( $temp{"ipAddress"} );
                        if ( defined $packed_ip and $packed_ip ) {
                            $temp{"ipAddress"} = inet_ntoa( $packed_ip );
                        }
                    }
                }

                $temp{"ifDescription"} = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:interface/nmwgt:ifDescription", 1 ), 0 );
                unless ( exists $temp{"ifDescription"} and $temp{"ifDescription"} ) {
                    $temp{"ifDescription"} = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:interface/nmwgt:description", 1 ), 0 );
                }
                $temp{"ifAddress"} = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:interface/nmwgt:ifAddress", 1 ), 0 );
                unless ( is_ipv4( $temp{"ifAddress"} ) ) {
                    unless ( &Net::IP::ip_is_ipv6( $temp{"ifAddress"} ) ) {
                        my $packed_ip = gethostbyname( $temp{"ifAddress"} );
                        if ( defined $packed_ip and $packed_ip ) {
                            $temp{"ifAddress"} = inet_ntoa( $packed_ip );
                        }
                    }
                }

                $temp{"capacity"}  = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:interface/nmwgt:capacity",  1 ), 0 );

                if ( $temp{"capacity"} ) {
                    $temp{"capacity"} /= 1000000;
                    if ( $temp{"capacity"} < 1000 ) {
                        $temp{"capacity"} .= " Mbps";
                    }
                    elsif ( $temp{"capacity"} < 1000000 ) {
                        $temp{"capacity"} /= 1000;
                        $temp{"capacity"} .= " Gbps";
                    }
                    elsif ( $temp{"capacity"} < 1000000000 ) {
                        $temp{"capacity"} /= 1000000;
                        $temp{"capacity"} .= " Tbps";
                    }
                }
                $list{$host}{$name} = \%temp;
            }
        }

        my @interfaces = ();
        my $counter    = 0;
        foreach my $host ( sort keys %list ) {
            foreach my $name ( sort keys %{ $list{$host} } ) {

                push @interfaces,
                    {
                    address   => $list{$host}{$name}->{"ipAddress"},
                    host      => $list{$host}{$name}->{"hostName"},
                    ifname    => $list{$host}{$name}->{"ifName"},
                    ifindex   => $list{$host}{$name}->{"ifIndex"},
                    desc      => $list{$host}{$name}->{"ifDescription"},
                    ifaddress => $list{$host}{$name}->{"ifAddress"},
                    capacity  => $list{$host}{$name}->{"capacity"},
                    key1type  => $list{$host}{$name}->{"key1_type"},
                    key11     => $list{$host}{$name}->{"key1_1"},
                    key12     => $list{$host}{$name}->{"key1_2"},
                    key2type  => $list{$host}{$name}->{"key2_type"},
                    key21     => $list{$host}{$name}->{"key2_1"},
                    key22     => $list{$host}{$name}->{"key2_2"},
                    count     => $counter,
                    service   => $service
                    };

                $counter++;
            }
        }

        my %vars = (
            eventtype  => $eventType,
            service    => $service,
            interfaces => \@interfaces
        );

        my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} );

	my $html;

	$tt->process( "serviceTest_utilization.tmpl", \%vars, \$html ) or die $tt->error();

	print $html;

	exit ( 0 );
    }
    elsif ($eventType eq "http://ggf.org/ns/nmwg/tools/iperf/2.0"
        or $eventType eq "http://ggf.org/ns/nmwg/characteristics/bandwidth/acheiveable/2.0"
        or $eventType eq "http://ggf.org/ns/nmwg/characteristics/bandwidth/achieveable/2.0"
        or $eventType eq "http://ggf.org/ns/nmwg/characteristics/bandwidth/achievable/2.0" )
    {
        my $sec = time;

        my %lookup = ();
        foreach my $d ( @{ $result->{"data"} } ) {
            my $data = q{};
            eval { $data = $parser->parse_string( $d ); };
            if ( $EVAL_ERROR ) {
                my $html = errorPage("Could not parse XML response from MA <b><i>" . $service . "</i></b>.");
                print $html;
                exit( 1 );
            }

            my $metadataIdRef = $data->getDocumentElement->getAttribute( "metadataIdRef" );
            my $key           = extract( find( $data->getDocumentElement, ".//nmwg:parameter[\@name=\"maKey\"]", 1 ), 0 );
            $lookup{$metadataIdRef} = $key if $key and $metadataIdRef;
        }

        my %list = ();
        my %data = ();
        foreach my $md ( @{ $result->{"metadata"} } ) {
            my $metadata = q{};
            eval { $metadata = $parser->parse_string( $md ); };
            if ( $EVAL_ERROR ) {
                my $html = errorPage("Could not parse XML response from MA <b><i>" . $service . "</i></b>.");
                print $html;
                exit( 1 );
            }

            my $metadataId = $metadata->getDocumentElement->getAttribute( "id" );

            my $src   = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:endPointPair/nmwgt:src", 1 ), 0 );
            my $saddr = q{};
            my $shost = q{};
            if ( is_ipv4( $src ) ) {
                $saddr = $src;
                my $iaddr = Socket::inet_aton( $src );
                if ( defined $iaddr and $iaddr ) {
                    $shost = gethostbyaddr( $iaddr, Socket::AF_INET );
                }
                $shost = $src unless $shost;
            }
            elsif ( &Net::IP::ip_is_ipv6( $src ) ) {
                $saddr = $src;
                $shost = $src;

                # do something?
            }
            else {
                $shost = $src;
                my $packed_ip = gethostbyname( $src );
                if ( defined $packed_ip and $packed_ip ) {
                    $saddr = inet_ntoa( $packed_ip );
                }
                $saddr = $src unless $saddr;
            }

            my $dst   = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:endPointPair/nmwgt:dst", 1 ), 0 );
            my $daddr = q{};
            my $dhost = q{};
            if ( is_ipv4( $dst ) ) {
                $daddr = $dst;
                my $iaddr = Socket::inet_aton( $dst );
                if ( defined $iaddr and $iaddr ) {
                    $dhost = gethostbyaddr( $iaddr, Socket::AF_INET );
                }
                $dhost = $dst unless $dhost;
            }
            elsif ( &Net::IP::ip_is_ipv6( $dst ) ) {
                $daddr = $dst;
                $dhost = $dst;

                # do something?
            }
            else {
                $dhost = $dst;
                my $packed_ip = gethostbyname( $dst );
                if ( defined $packed_ip and $packed_ip ) {
                    $daddr = inet_ntoa( $packed_ip );
                }
                $daddr = $dst unless $daddr;
            }

            my %temp = ();
            my $params = find( $metadata->getDocumentElement, "./*[local-name()='parameters']/*[local-name()='parameter']", 0 );
            foreach my $p ( $params->get_nodelist ) {
                my $pName = $p->getAttribute( "name" );
                my $pValue = extract( $p, 0 );
                $temp{$pName} = $pValue if $pName and $pValue;
            }

            $temp{"key"}   = $lookup{$metadataId};
            $temp{"src"}   = $shost;
            $temp{"dst"}   = $dhost;
            $temp{"saddr"} = $saddr;
            $temp{"daddr"} = $daddr;

            unless ( exists $data{$shost} ) {
                $data{$shost}{"out"}{"total"} = 0;
                $data{$shost}{"in"}{"total"}  = 0;
                $data{$shost}{"out"}{"count"} = 0;
                $data{$shost}{"in"}{"count"}  = 0;
            }
            unless ( exists $data{$dhost} ) {
                $data{$dhost}{"out"}{"total"} = 0;
                $data{$dhost}{"in"}{"total"}  = 0;
                $data{$dhost}{"out"}{"count"} = 0;
                $data{$dhost}{"in"}{"count"}  = 0;
            }

            my @eventTypes = ();
            my $parser     = XML::LibXML->new();

            my $subject = "<nmwg:key id=\"key-1\"><nmwg:parameters id=\"parameters-key-1\"><nmwg:parameter name=\"maKey\">" . $lookup{$metadataId} . "</nmwg:parameter></nmwg:parameters></nmwg:key>";
            my $time    = 604800;

            my $result = $ma->setupDataRequest(
                {
                    start      => ( $sec - $time ),
                    end        => $sec,
                    subject    => $subject,
                    eventTypes => \@eventTypes
                }
            );

            my $doc1 = q{};
            eval { $doc1 = $parser->parse_string( $result->{"data"}->[0] ); };
            if ( $EVAL_ERROR ) {
                my $html = errorPage("Could not parse XML response from MA <b><i>" . $service . "</i></b>.");
                print $html;
                exit( 1 );
            }

            my $datum1 = find( $doc1->getDocumentElement, "./*[local-name()='datum']", 0 );
            if ( $datum1 ) {
                my $dcounter = 0;
                my $total    = 0;
                foreach my $dt ( $datum1->get_nodelist ) {
                    if ( $dt->getAttribute( "throughput" ) ) {
                        $total += $dt->getAttribute( "throughput" );
                        $dcounter++;
                    }
                }

                if ( $dcounter ) {
                    $data{$shost}{"out"}{"total"} += ( $total / $dcounter ) if $dcounter;
                    $data{$dhost}{"in"}{"total"}  += ( $total / $dcounter ) if $dcounter;
                    $data{$shost}{"out"}{"count"}++;
                    $data{$dhost}{"in"}{"count"}++;
                    $temp{"active"} = 1;
                    $temp{"out"} = ( $total / $dcounter ) if $dcounter;
                }
                else {
                    $temp{"active"} = 0;
                }
            }
            else {
                $temp{"active"} = 0;
            }
            
            #check for duplicate tests
            my $testFound = 0;
            foreach my $test (@{ $list{$shost}{$dhost} }){
                if(&bwctlTestParamsEqual($test, \%temp)){
                    $test->{"key"} .= '_' . $temp{"key"};
                    $testFound = 1;
                    last;
                }
            }
            push @{ $list{$shost}{$dhost} }, \%temp unless $testFound;
        }

        # figure out if hosts are equal - requires unrolling all of the options and comparing (ugh)
        my %hostMap = ();
        foreach my $src ( sort keys %list ) {
            foreach my $dst ( sort keys %{ $list{$src} } ) {
                foreach my $set ( @{ $list{$src}{$dst} } ) {
                    #compare reverse tests
                    if ( $#{ $list{$src}{$dst} } > -1 and $#{ $list{$dst}{$src} } > -1 ) {
                        foreach my $set2 ( @{ $list{$dst}{$src} } ) {
                            if ( $set->{"src"} eq $set2->{"dst"} and $set->{"dst"} eq $set2->{"src"} and $set->{"saddr"} eq $set2->{"daddr"} and $set->{"daddr"} eq $set2->{"saddr"} ) {
                                if(&bwctlTestParamsEqual($set, $set2)){
                                    push @{ $hostMap{ $set->{"key"} } }, $set2->{"key"};
                                }
                            }
                        }
                    }
                }
            }
        }

        my ( $stsec, $stmin, $sthour, $stday, $stmonth, $styear ) = localtime();
        $stmonth += 1;
        $styear  += 1900;

        # XXX
        # JZ 8/24 - until we can get a date range from the service, start
        #           2 months back...
        $stmonth -= 2;
        if ( $stmonth <= 0 ) {
            $stmonth += 12;
            $styear -= 1;
        }

        my ( $dtsec, $dtmin, $dthour, $dtday, $dtmonth, $dtyear ) = localtime();
        $dtmonth += 1;
        $dtyear  += 1900;

        my @mon      = ( "", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );
        my @sday     = ();
        my @smon     = ();
        my @syear    = ();
        my @dday     = ();
        my @dmon     = ();
        my @dyear    = ();
        my $selected = 0;
        for ( my $x = 1; $x < 13; $x++ ) {

            if ( $stmonth == $x ) {
                push @smon, { value => $x, name => $mon[$x], selected => 1 };
            }
            else {
                push @smon, { value => $x, name => $mon[$x] };
            }
        }
        for ( my $x = 1; $x < 32; $x++ ) {
            if ( $stday == $x ) {
                push @sday, { value => $x, name => $x, selected => 1 };
            }
            else {
                push @sday, { value => $x, name => $x };
            }
        }
        for ( my $x = 2000; $x < 2016; $x++ ) {
            if ( $styear == $x ) {
                push @syear, { value => $x, name => $x, selected => 1 };
            }
            else {
                push @syear, { value => $x, name => $x };
            }
        }

        for ( my $x = 1; $x < 13; $x++ ) {
            if ( $dtmonth == $x ) {
                push @dmon, { value => $x, name => $mon[$x], selected => 1 };
            }
            else {
                push @dmon, { value => $x, name => $mon[$x] };
            }
        }
        for ( my $x = 1; $x < 32; $x++ ) {
            if ( $dtday == $x ) {
                push @dday, { value => $x, name => $x, selected => 1 };
            }
            else {
                push @dday, { value => $x, name => $x };
            }
        }
        for ( my $x = 2000; $x < 2016; $x++ ) {
            if ( $dtyear == $x ) {
                push @dyear, { value => $x, name => $x, selected => 1 };
            }
            else {
                push @dyear, { value => $x, name => $x };
            }
        }

        my @pairs     = ();
        my @histPairs = ();
        my $counter   = 0;
        my %mark      = ();
        foreach my $src ( sort keys %list ) {
            foreach my $dst ( sort keys %{ $list{$src} } ) {
                foreach my $set ( @{ $list{$src}{$dst} } ) {
                    next if $mark{ $set->{"key"} };
                    my $bidir = "No";
                    $bidir = "Yes" if $hostMap{ $set->{"key"} }->[0];
                    if ( exists $set->{"active"} and $set->{"active"} ) {
                        push @pairs,
                            {
                            saddress       => $set->{"saddr"},
                            shost          => $set->{"src"},
                            daddress       => $set->{"daddr"},
                            dhost          => $set->{"dst"},
                            protocol       => $set->{"protocol"},
                            timeduration   => $set->{"timeDuration"},
                            bufferlength   => $set->{"bufferLength"},
                            windowsize     => $set->{"windowSize"},
                            interval       => $set->{"interval"},
                            bandwidthlimit => $set->{"bandwidthLimit"},
                            key            => $set->{"key"},
                            count          => $counter,
                            service        => $service,
                            key2           => $hostMap{ $set->{"key"} }->[0],
                            bidir          => $bidir
                            };
                        $counter++;
                    }
                    else {
                        push @histPairs,
                            {
                            saddress       => $set->{"saddr"},
                            shost          => $set->{"src"},
                            daddress       => $set->{"daddr"},
                            dhost          => $set->{"dst"},
                            protocol       => $set->{"protocol"},
                            timeduration   => $set->{"timeDuration"},
                            bufferlength   => $set->{"bufferLength"},
                            windowsize     => $set->{"windowSize"},
                            interval       => $set->{"interval"},
                            bandwidthlimit => $set->{"bandwidthLimit"},
                            key            => $set->{"key"},
                            count          => $counter,
                            service        => $service,
                            key2           => $hostMap{ $set->{"key"} }->[0],
                            smon           => \@smon,
                            sday           => \@sday,
                            syear          => \@syear,
                            dmon           => \@dmon,
                            dday           => \@dday,
                            dyear          => \@dyear,
                            bidir          => $bidir
                            };
                        $counter++;
                    }
                    foreach my $hm ( @{ $hostMap{ $set->{"key"} } } ) {
                        $mark{ $hm } = 1 if $hm;
                    }
                }
            }
        }

        my @graph       = ();
        my $datacounter = 0;
        my $max         = 0;
        foreach my $d ( sort keys %data ) {
            next if $data{$d}{"out"}{"count"} == 0 and $data{$d}{"in"}{"count"} == 0;           
            my $din  = 0;
            my $dout = 0;            
            $din  = ( $data{$d}{"in"}{"total"} / $data{$d}{"in"}{"count"} )   if $data{$d}{"in"}{"count"};
            $dout = ( $data{$d}{"out"}{"total"} / $data{$d}{"out"}{"count"} ) if $data{$d}{"out"}{"count"};
            $max  = $din                                                      if $din > $max;
            $max  = $dout                                                     if $dout > $max;
            push @graph, { c => $datacounter, location => $d, in => $din, out => $dout };
            $datacounter++;
        }
        my $temp = scaleValue( { value => $max } );
        foreach my $g ( @graph ) {
            $g->{"in"}  /= $temp->{"scale"};
            $g->{"out"} /= $temp->{"scale"};
        }

        my %vars = ( 
            eventtype   => $eventType,
            service     => $service,
            histpairs   => \@histPairs,
            pairs       => \@pairs,
            graphtotal  => $datacounter,
            graph       => \@graph,
            graphprefix => $temp->{"mod"}
        );

	my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

	my $html;

        $tt->process( "serviceTest_psb_bwctl.tmpl", \%vars, \$html ) or die $tt->error();

	print STDERR Dumper(\%vars);

        print $html;

        exit( 0 );
    }
    elsif ( $eventType eq "http://ggf.org/ns/nmwg/tools/owamp/2.0" or $eventType eq "http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921" ) {
        my $sec = time;

        my %lookup = ();
        foreach my $d ( @{ $result->{"data"} } ) {
            my $data = q{};
            eval { $data = $parser->parse_string( $d ); };
            if ( $EVAL_ERROR ) {
                my $html = errorPage("Could not parse XML response from MA <b><i>" . $service . "</i></b>.");
                print $html;
                exit( 1 );
            }

            my $metadataIdRef = $data->getDocumentElement->getAttribute( "metadataIdRef" );
            my $key           = extract( find( $data->getDocumentElement, ".//nmwg:parameter[\@name=\"maKey\"]", 1 ), 0 );
            $lookup{$metadataIdRef} = $key if $key and $metadataIdRef;
        }

        my %list = ();
        my %data = ();
        foreach my $md ( @{ $result->{"metadata"} } ) {
            my $metadata = q{};
            eval { $metadata = $parser->parse_string( $md ); };
            if ( $EVAL_ERROR ) {
                my $html = errorPage("Could not parse XML response from MA <b><i>" . $service . "</i></b>.");
                print $html;
                exit( 1 );
            }

            my $metadataId = $metadata->getDocumentElement->getAttribute( "id" );

            my $src   = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:endPointPair/nmwgt:src", 1 ), 0 );
            my $saddr = q{};
            my $shost = q{};

            if ( is_ipv4( $src ) ) {
                $saddr = $src;
                my $iaddr = Socket::inet_aton( $src );
                if ( defined $iaddr and $iaddr ) {
                    $shost = gethostbyaddr( $iaddr, Socket::AF_INET );
                }
                $shost = $src unless $shost;
            }
            elsif ( &Net::IP::ip_is_ipv6( $src ) ) {
                $saddr = $src;
                $shost = $src;

                # do something?
            }
            else {
                $shost = $src;
                my $packed_ip = gethostbyname( $src );
                if ( defined $packed_ip and $packed_ip ) {
                    $saddr = inet_ntoa( $packed_ip );
                }
                $saddr = $src unless $saddr;
            }

            my $dst   = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:endPointPair/nmwgt:dst", 1 ), 0 );
            my $daddr = q{};
            my $dhost = q{};
            if ( is_ipv4( $dst ) ) {
                $daddr = $dst;
                my $iaddr = Socket::inet_aton( $dst );
                if ( defined $iaddr and $iaddr ) {
                    $dhost = gethostbyaddr( $iaddr, Socket::AF_INET );
                }
                $dhost = $dst unless $dhost;
            }
            elsif ( &Net::IP::ip_is_ipv6( $dst ) ) {
                $daddr = $dst;
                $dhost = $dst;

                # do something?
            }
            else {
                $dhost = $dst;
                my $packed_ip = gethostbyname( $dst );
                if ( defined $packed_ip and $packed_ip ) {
                    $daddr = inet_ntoa( $packed_ip );
                }
                $daddr = $dst unless $daddr;
            }

            my %temp = ();
            my $params = find( $metadata->getDocumentElement, "./*[local-name()='parameters']/*[local-name()='parameter']", 0 );
            foreach my $p ( $params->get_nodelist ) {
                my $pName  = $p->getAttribute( "name" );
                my $pValue = q{};
                if ( lc( $pName ) eq "schedule" ) {
                    $pValue = extract( find( $p, ".//interval[\@type=\"exp\"]", 1 ), 0 );
                }
                else {
                    $pValue = extract( $p, 0 );
                }
                $temp{$pName} = $pValue if $pName and $pValue;
            }

            $temp{"key"}   = $lookup{$metadataId};
            $temp{"src"}   = $shost;
            $temp{"dst"}   = $dhost;
            $temp{"saddr"} = $saddr;
            $temp{"daddr"} = $daddr;

            unless ( exists $data{$shost}{$dhost} ) {
                $data{$shost}{$dhost}{"max"} = 0;
                $data{$shost}{$dhost}{"min"} = 0;
            }

            my @eventTypes = ();
            my $parser     = XML::LibXML->new();

            my $subject = "<nmwg:key id=\"key-1\"><nmwg:parameters id=\"parameters-key-1\"><nmwg:parameter name=\"maKey\">" . $lookup{$metadataId} . "</nmwg:parameter></nmwg:parameters></nmwg:key>";
            my $time    = 43200;

            my $result = $ma->setupDataRequest(
                {
                    start      => ( $sec - $time ),
                    end        => $sec,
                    subject    => $subject,
                    eventTypes => \@eventTypes
                }
            );

            my $doc1 = q{};
            eval { $doc1 = $parser->parse_string( $result->{"data"}->[0] ); };
            if ( $EVAL_ERROR ) {
                my $html = errorPage("Could not parse XML response from MA <b><i>" . $service . "</i></b>.");
                print $html;
                exit( 1 );
            }

            my $datum1 = find( $doc1->getDocumentElement, "./*[local-name()='datum']", 0 );
            if ( $datum1 ) {
                my $max = 0;
                my $min = 999999;
                foreach my $dt ( $datum1->get_nodelist ) {
                    my $maxval = $dt->getAttribute( "max_delay" );
                    $max = $maxval if $maxval and $maxval > $max;

                    my $minval = $dt->getAttribute( "min_delay" );
                    $min = $minval if $minval and $minval < $min;
                }
                if ( $max or ( $min < 999999 ) ) {
                    $temp{"active"} = 1;
                    $data{$shost}{$dhost}{"max"} = sprintf( "%.4f", ( $max * 1000 ) ) if $max;
                    $data{$shost}{$dhost}{"min"} = sprintf( "%.4f", ( $min * 1000 ) ) if $min < 999999;
                }
                else {
                    $temp{"active"} = 0;
                }
            }
            else {
                $temp{"active"} = 0;
            }
            
            #check for duplicate tests
            my $testFound = 0;
            foreach my $test (@{ $list{$shost}{$dhost} }){
                if(&owampTestParamsEqual($test, \%temp)){
                    $test->{"key"} .= '_' . $temp{"key"};
                    $testFound = 1;
                    last;
                }
            }
            push @{ $list{$shost}{$dhost} }, \%temp unless $testFound;
        }

        # figure out if hosts are equal - requires unrolling all of the options and comparing (ugh)
        my %hostMap = ();
        foreach my $src ( sort keys %list ) {
            foreach my $dst ( sort keys %{ $list{$src} } ) {
                foreach my $set ( @{ $list{$src}{$dst} } ) {
                    if ( $#{ $list{$src}{$dst} } > -1 and $#{ $list{$dst}{$src} } > -1 ) {
                        foreach my $set2 ( @{ $list{$dst}{$src} } ) {
                            #compare reverse tests
                            if ( $set->{"src"} eq $set2->{"dst"} and $set->{"dst"} eq $set2->{"src"} and $set->{"saddr"} eq $set2->{"daddr"} and $set->{"daddr"} eq $set2->{"saddr"} ) {
                                if(&owampTestParamsEqual($set, $set2)){
                                    push @{ $hostMap{ $set->{"key"} } }, $set2->{"key"};
                                }
                            }
                        }
                    }
                }
            }
        }

        my ( $stsec, $stmin, $sthour, $stday, $stmonth, $styear ) = localtime();
        $stmonth += 1;
        $styear  += 1900;

        # XXX
        # JZ 8/24 - until we can get a date range from the service, start
        #           2 months back...
        $stmonth -= 2;
        if ( $stmonth <= 0 ) {
            $stmonth += 12;
            $styear -= 1;
        }

        my ( $dtsec, $dtmin, $dthour, $dtday, $dtmonth, $dtyear ) = localtime();
        $dtmonth += 1;
        $dtyear  += 1900;

        my @mon      = ( "", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );
        my @sday     = ();
        my @smon     = ();
        my @syear    = ();
        my @dday     = ();
        my @dmon     = ();
        my @dyear    = ();
        my $selected = 0;
        for ( my $x = 1; $x < 13; $x++ ) {

            if ( $stmonth == $x ) {
                push @smon, { value => $x, name => $mon[$x], selected => 1 };
            }
            else {
                push @smon, { value => $x, name => $mon[$x] };
            }
        }
        for ( my $x = 1; $x < 32; $x++ ) {
            if ( $stday == $x ) {
                push @sday, { value => $x, name => $x, selected => 1 };
            }
            else {
                push @sday, { value => $x, name => $x };
            }
        }
        for ( my $x = 2000; $x < 2016; $x++ ) {
            if ( $styear == $x ) {
                push @syear, { value => $x, name => $x, selected => 1 };
            }
            else {
                push @syear, { value => $x, name => $x };
            }
        }

        for ( my $x = 1; $x < 13; $x++ ) {
            if ( $dtmonth == $x ) {
                push @dmon, { value => $x, name => $mon[$x], selected => 1 };
            }
            else {
                push @dmon, { value => $x, name => $mon[$x] };
            }
        }
        for ( my $x = 1; $x < 32; $x++ ) {
            if ( $dtday == $x ) {
                push @dday, { value => $x, name => $x, selected => 1 };
            }
            else {
                push @dday, { value => $x, name => $x };
            }
        }
        for ( my $x = 2000; $x < 2016; $x++ ) {
            if ( $dtyear == $x ) {
                push @dyear, { value => $x, name => $x, selected => 1 };
            }
            else {
                push @dyear, { value => $x, name => $x };
            }
        }

        my @pairs     = ();
        my @histPairs = ();
        my $counter   = 0;
        my %mark      = ();
        foreach my $src ( sort keys %list ) {
            foreach my $dst ( sort keys %{ $list{$src} } ) {
                foreach my $set ( @{ $list{$src}{$dst} } ) {
                    next if $mark{ $set->{"key"} };
                    my $bidir = "No";
                    $bidir = "Yes" if $hostMap{ $set->{"key"} }->[0];
                    if ( exists $set->{"active"} and $set->{"active"} ) {
                        push @pairs,
                            {
                            saddress => $set->{"saddr"},
                            shost    => $set->{"src"},
                            daddress => $set->{"daddr"},
                            dhost    => $set->{"dst"},
                            key      => $set->{"key"},
                            count    => $counter,
                            service  => $service,
                            key2     => $hostMap{ $set->{"key"} }->[0],
                            bidir    => $bidir
                            };
                        $counter++;
                    }
                    else {
                        push @histPairs,
                            {
                            saddress => $set->{"saddr"},
                            shost    => $set->{"src"},
                            daddress => $set->{"daddr"},
                            dhost    => $set->{"dst"},
                            key      => $set->{"key"},
                            count    => $counter,
                            service  => $service,
                            key2     => $hostMap{ $set->{"key"} }->[0],
                            smon     => \@smon,
                            sday     => \@sday,
                            syear    => \@syear,
                            dmon     => \@dmon,
                            dday     => \@dday,
                            dyear    => \@dyear,
                            bidir    => $bidir
                            };
                        $counter++;
                    }
                    foreach my $hm ( @{ $hostMap{ $set->{"key"} } } ) {
                        $mark{ $hm } = 1 if $hm;
                    }
                }
            }
        }

        my %colspan = ();
        foreach my $src ( sort keys %data ) {
            $colspan{$src} = 1;
            foreach my $dst ( sort keys %{ $data{$src} } ) {
                $colspan{$dst} = 1;
            }
        }

        my @matrixHeader = ();
        my @matrix       = ();
        foreach my $h1 ( sort keys %colspan ) {
            push @matrixHeader, { name => $h1 };
            my @temp = ();
            foreach my $h2 ( sort keys %colspan ) {
                $data{$h1}{$h2}{"min"} = "*" unless $data{$h1}{$h2}{"min"};
                $data{$h1}{$h2}{"max"} = "*" unless $data{$h1}{$h2}{"max"};
                push @temp, { minvalue => $data{$h1}{$h2}{"min"}, maxvalue => $data{$h1}{$h2}{"max"} };
            }
            push @matrix, { name => $h1, matrixcols => \@temp };
        }

        my %vars = (
            eventtype     => $eventType,
            service       => $service,
            pairs         => \@pairs,
            histpairs     => \@histPairs,
            matrixcolspan => ( scalar( keys %colspan ) + 1 ),
            matrixheader  => \@matrixHeader,
            matrix        => \@matrix
        );

        my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

        my $html;

        $tt->process( "serviceTest_psb_owamp.tmpl", \%vars, \$html ) or die $tt->error();

        print $html;

        exit( 0 );
    }
    elsif ( $eventType eq "http://ggf.org/ns/nmwg/tools/pinger/2.0/" or $eventType eq "http://ggf.org/ns/nmwg/tools/pinger/2.0" ) {
        my $sec = time;

        my %lookup = ();
        foreach my $d ( @{ $result->{"data"} } ) {
            my $data = q{};
            eval { $data = $parser->parse_string( $d ); };
            if ( $EVAL_ERROR ) {
                my $html = errorPage("Could not parse XML response from MA <b><i>" . $service . "</i></b>.");
                print $html;
                exit( 1 );
            }

            my $eT = extract( find( $metadata->getDocumentElement, "./nmwg:eventType", 1 ), 0 );
            if ( $eT eq "http://schemas.perfsonar.net/status/failure/metadatakey/1.0/" ) {
                my $html = errorPage("No PingER tests scheduled for PingER MA <b><i>" . $service . "</i></b>." );
                print $html;
                exit( 1 );
            }

            my $metadataIdRef = $data->getDocumentElement->getAttribute( "metadataIdRef" );
            next unless $metadataIdRef;

            my $nmwg_key = find( $data->getDocumentElement, ".//nmwg:key", 1 );
            next unless ( $nmwg_key );

            my $key = $nmwg_key->getAttribute( "id" );
            $lookup{$metadataIdRef} = $key if $key;
        }

        my %list = ();
        foreach my $md ( @{ $result->{"metadata"} } ) {
            my $metadata = q{};
            eval { $metadata = $parser->parse_string( $md ); };
            if ( $EVAL_ERROR ) {
                my $html = errorPage("Could not parse XML response from MA <b><i>" . $service . "</i></b>.");
                print $html;
                exit( 1 );
            }

            my $metadataId = $metadata->getDocumentElement->getAttribute( "id" );
            
            my $src        = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:endPointPair/nmwgt:src",             1 ), 0 );
            my $saddr = q{};
            my $shost = q{};

            if ( is_ipv4( $src ) ) {
                $saddr = $src;
                my $iaddr = Socket::inet_aton( $src );
                if ( defined $iaddr and $iaddr ) {
                    $shost = gethostbyaddr( $iaddr, Socket::AF_INET );
                }
                $shost = $src unless $shost;
            }
            elsif ( &Net::IP::ip_is_ipv6( $src ) ) {
                $saddr = $src;
                $shost = $src;

                # do something?
            }
            else {
                $shost = $src;
                my $packed_ip = gethostbyname( $src );
                if ( defined $packed_ip and $packed_ip ) {
                    $saddr = inet_ntoa( $packed_ip );
                }
                $saddr = $src unless $saddr;
            }

            my $dst        = extract( find( $metadata->getDocumentElement, "./*[local-name()='subject']/nmwgt:endPointPair/nmwgt:dst",             1 ), 0 );
            my $daddr = q{};
            my $dhost = q{};
            if ( is_ipv4( $dst ) ) {
                $daddr = $dst;
                my $iaddr = Socket::inet_aton( $dst );
                if ( defined $iaddr and $iaddr ) {
                    $dhost = gethostbyaddr( $iaddr, Socket::AF_INET );
                }
                $dhost = $dst unless $dhost;
            }
            elsif ( &Net::IP::ip_is_ipv6( $dst ) ) {
                $daddr = $dst;
                $dhost = $dst;

                # do something?
            }
            else {
                $dhost = $dst;
                my $packed_ip = gethostbyname( $dst );
                if ( defined $packed_ip and $packed_ip ) {
                    $daddr = inet_ntoa( $packed_ip );
                }
                $daddr = $dst unless $daddr;
            }
            
            my $packetsize = extract( find( $metadata->getDocumentElement, "./*[local-name()='parameters']/nmwg:parameter[\@name=\"packetSize\"]", 1 ), 0 );

            my %temp = ();
            $temp{"key"}        = $lookup{$metadataId};
            $temp{"src"}        = $shost;
            $temp{"dst"}        = $dhost;
            $temp{"saddr"}      = $saddr;
            $temp{"daddr"}      = $daddr;
            $temp{"packetsize"} = $packetsize ? $packetsize : 1000;
            $list{$src}{$dst}   = \%temp;

            $temp{"active"}     = 0;

            # is there data in the last 4 hours (needs to be longer, but this makes it slow enough...)
            my $ma = new perfSONAR_PS::Client::PingER( { instance => $service } );
            my $result = $ma->setupDataRequest(
                {
                    start => ( $sec - 14400 ),
                    end   => $sec,
                    keys  => [ $lookup{$metadataId} ],
                    cf    => "AVERAGE"
                }
            );

            if ( $result ) {
                my $data_md = $ma->getData( $result );
                foreach my $key_id ( keys %{$data_md} ) {
                    foreach my $id ( keys %{ $data_md->{$key_id}{data} } ) {
                        foreach my $timev ( keys %{ $data_md->{$key_id}{data}{$id} } ) {
                            my $datum = $data_md->{$key_id}{data}{$id}{$timev};
                            my $min   = $datum->{minRtt};
                            my $med   = $datum->{medianRtt};
                            my $mean  = $datum->{meanRtt};
                            my $max   = $datum->{maxRtt};

                            if ( $timev and ( $min or $med or $mean or $max ) ) {
                                $temp{"active"} = 1;
                                last;
                            }
                        }
                        last if $temp{"active"} == 1;
                    }
                    last if $temp{"active"} == 1;
                }
            }
            $list{$src}{$dst} = \%temp;

        }

        my ( $stsec, $stmin, $sthour, $stday, $stmonth, $styear ) = localtime();
        $stmonth += 1;
        $styear  += 1900;

        # XXX
        # JZ 8/24 - until we can get a date range from the service, start
        #           2 months back...
        $stmonth -= 2;
        if ( $stmonth <= 0 ) {
            $stmonth += 12;
            $styear -= 1;
        }

        my ( $dtsec, $dtmin, $dthour, $dtday, $dtmonth, $dtyear ) = localtime();
        $dtmonth += 1;
        $dtyear  += 1900;

        my @mon      = ( "", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );
        my @sday     = ();
        my @smon     = ();
        my @syear    = ();
        my @dday     = ();
        my @dmon     = ();
        my @dyear    = ();
        my $selected = 0;
        for ( my $x = 1; $x < 13; $x++ ) {

            if ( $stmonth == $x ) {
                push @smon, { value => $x, name => $mon[$x], selected => 1 };
            }
            else {
                push @smon, { value => $x, name => $mon[$x] };
            }
        }
        for ( my $x = 1; $x < 32; $x++ ) {
            if ( $stday == $x ) {
                push @sday, { value => $x, name => $x, selected => 1 };
            }
            else {
                push @sday, { value => $x, name => $x };
            }
        }
        for ( my $x = 2000; $x < 2016; $x++ ) {
            if ( $styear == $x ) {
                push @syear, { value => $x, name => $x, selected => 1 };
            }
            else {
                push @syear, { value => $x, name => $x };
            }
        }

        for ( my $x = 1; $x < 13; $x++ ) {
            if ( $dtmonth == $x ) {
                push @dmon, { value => $x, name => $mon[$x], selected => 1 };
            }
            else {
                push @dmon, { value => $x, name => $mon[$x] };
            }
        }
        for ( my $x = 1; $x < 32; $x++ ) {
            if ( $dtday == $x ) {
                push @dday, { value => $x, name => $x, selected => 1 };
            }
            else {
                push @dday, { value => $x, name => $x };
            }
        }
        for ( my $x = 2000; $x < 2016; $x++ ) {
            if ( $dtyear == $x ) {
                push @dyear, { value => $x, name => $x, selected => 1 };
            }
            else {
                push @dyear, { value => $x, name => $x };
            }
        }

        my @pairs   = ();
        my @histpairs   = ();

        my $counter = 0;
        foreach my $src ( sort keys %list ) {
            foreach my $dst ( sort keys %{ $list{$src} } ) {
		my $p_time = $sec - 43200;
                my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = gmtime( $p_time );
                my $p_start = sprintf "%04d-%02d-%02dT%02d:%02d:%02d", ( $year + 1900 ), ( $mon + 1 ), $mday, $hour, $min, $sec;
                $p_time += 43200;
                ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = gmtime( $p_time );
                my $p_end = sprintf "%04d-%02d-%02dT%02d:%02d:%02d", ( $year + 1900 ), ( $mon + 1 ), $mday, $hour, $min, $sec;

                if ( $list{$src}{$dst}->{"active"} ) {
                    push @pairs,
                        {
                        key      => $list{$src}{$dst}->{"key"},
                        shost    => $list{$src}{$dst}->{"src"},
                        saddress => $list{$src}{$dst}->{"saddr"},,
                        dhost    => $list{$src}{$dst}->{"dst"},
                        daddress => $list{$src}{$dst}->{"daddr"},
                        count    => $counter,
                        service  => $service
                        };
		} else {
                    push @histpairs,
                        {
                        key      => $list{$src}{$dst}->{"key"},
                        shost    => $list{$src}{$dst}->{"src"},
                        saddress => $list{$src}{$dst}->{"saddr"},,
                        dhost    => $list{$src}{$dst}->{"dst"},
                        daddress => $list{$src}{$dst}->{"daddr"},
                        count    => $counter,
                        service  => $service,
			smon     => \@smon,
			sday     => \@sday,
			syear    => \@syear,
			dmon     => \@dmon,
			dday     => \@dday,
			dyear    => \@dyear
                        };
	 	}

                $counter++;
            }
        }

        my %vars = (
            eventtype => $eventType,
            service   => $service,
            pairs     => \@pairs,
	    histpairs => \@histpairs

        );

        my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

        my $html;

        $tt->process( "serviceTest_pinger.tmpl", \%vars, \$html ) or die $tt->error();

        print $html;

        exit( 0 );
    }
    else {
        my $html = errorPage("Unrecognized eventType: \"" . $eventType . "\".");
	print $html;
	exit( 1 );
    }
}

=head2 scaleValue ( { value } )

Given a value, return the value scaled to a magnitude.

=cut

sub scaleValue {
    my $parameters = validateParams( @_, { value => 1 } );
    my %result = ();
    if ( $parameters->{"value"} < 1000 ) {
        $result{"scale"} = 1;
        $result{"mod"}   = q{};
    }
    elsif ( $parameters->{"value"} < 1000000 ) {
        $result{"scale"} = 1000;
        $result{"mod"}   = "K";
    }
    elsif ( $parameters->{"value"} < 1000000000 ) {
        $result{"scale"} = 1000000;
        $result{"mod"}   = "M";
    }
    elsif ( $parameters->{"value"} < 1000000000000 ) {
        $result{"scale"} = 1000000000;
        $result{"mod"}   = "G";
    }
    return \%result;
}

sub errorPage {
    my ($msg) = @_;

    my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

    my $html;

    my %vars = ();
    $vars{error_msg} = $msg;

    $tt->process( "serviceTest_error.tmpl", \%vars, \$html ) or die $tt->error();

    return $html;
}

=head2 bwctlTestParamsEqual ( { test1, test2 } )

Given two bwctl tests, return true if parameters are equal

=cut
sub bwctlTestParamsEqual(){
    my ($test1, $test2) = @_;
    
    my @type = ( q{}, q{} );
    $type[0] = $test1->{"type"}  if $test1->{"type"};
    $type[1] = $test2->{"type"} if $test2->{"type"};
    return 0 unless $type[0] eq $type[1];
    
    my @timeDuration = ( q{}, q{} );
    $timeDuration[0] = $test1->{"timeDuration"}  if $test1->{"timeDuration"};
    $timeDuration[1] = $test2->{"timeDuration"} if $test2->{"timeDuration"};
    return 0 unless $timeDuration[0] eq $timeDuration[1];
    
    my @windowSize = ( q{}, q{} );
    $windowSize[0] = $test1->{"windowSize"}  if $test1->{"windowSize"};
    $windowSize[1] = $test2->{"windowSize"} if $test2->{"windowSize"};
    return 0 unless $windowSize[0] eq $windowSize[1];
    
    my @bufferLength = ( q{}, q{} );
    $bufferLength[0] = $test1->{"bufferLength"}  if $test1->{"bufferLength"};
    $bufferLength[1] = $test2->{"bufferLength"} if $test2->{"bufferLength"};
    return 0 unless $bufferLength[0] eq $bufferLength[1];
    
    my @interval = ( q{}, q{} );
    $interval[0] = $test1->{"interval"}  if $test1->{"interval"};
    $interval[1] = $test2->{"interval"} if $test2->{"interval"};
    return 0 unless $interval[0] eq $interval[1];
    
    my @bandwidthLimit = ( q{}, q{} );
    $bandwidthLimit[0] = $test1->{"bandwidthLimit"}  if $test1->{"bandwidthLimit"};
    $bandwidthLimit[1] = $test2->{"bandwidthLimit"} if $test2->{"bandwidthLimit"};
    return 0 unless $bandwidthLimit[0] eq $bandwidthLimit[1];
    
    my @active = ( q{}, q{} );
    $active[0] = $test1->{"active"}  if $test1->{"active"};
    $active[1] = $test2->{"active"} if $test2->{"active"};
    return 0 unless $active[0] eq $active[1];
    
    return 1;
}

sub owampTestParamsEqual(){
    my ($test1, $test2) = @_;
    
    my @bucket_width = ( q{}, q{} );
    $bucket_width[0] = $test1->{"bucket_width"}  if $test1->{"bucket_width"};
    $bucket_width[1] = $test2->{"bucket_width"} if $test2->{"bucket_width"};
    return 0 unless $bucket_width[0] eq $bucket_width[1];

    my @count = ( q{}, q{} );
    $count[0] = $test1->{"count"}  if $test1->{"count"};
    $count[1] = $test2->{"count"} if $test2->{"count"};
    return 0 unless $count[0] eq $count[1];

    my @schedule = ( q{}, q{} );
    $schedule[0] = $test1->{"schedule"}  if $test1->{"schedule"};
    $schedule[1] = $test2->{"schedule"} if $test2->{"schedule"};
    return 0 unless $schedule[0] eq $schedule[1];

    my @DSCP = ( q{}, q{} );
    $DSCP[0] = $test1->{"DSCP"}  if $test1->{"DSCP"};
    $DSCP[1] = $test2->{"DSCP"} if $test2->{"DSCP"};
    return 0 unless $DSCP[0] eq $DSCP[1];

    my @timeout = ( q{}, q{} );
    $timeout[0] = $test1->{"timeout"}  if $test1->{"timeout"};
    $timeout[1] = $test2->{"timeout"} if $test2->{"timeout"};
    return 0 unless $timeout[0] eq $timeout[1];

    my @packet_padding = ( q{}, q{} );
    $packet_padding[0] = $test1->{"packet_padding"}  if $test1->{"packet_padding"};
    $packet_padding[1] = $test2->{"packet_padding"} if $test2->{"packet_padding"};
    return 0 unless $packet_padding[0] eq $packet_padding[1];

    my @active = ( q{}, q{} );
    $active[0] = $test1->{"active"}  if $test1->{"active"};
    $active[1] = $test2->{"active"} if $test2->{"active"};
    return 0 unless $active[0] eq $active[1];
    
    return 1;
}
__END__

=head1 SEE ALSO

L<CGI>, L<Template>, L<XML::LibXML>, L<Socket>, L<Data::Validate::IP>,
L<English>, L<Net::IP>, L<perfSONAR_PS::Client::MA>,
L<perfSONAR_PS::Common>, L<perfSONAR_PS::Utils::ParameterValidation>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.  Bugs,
feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: serviceTest.cgi 3619 2009-08-24 17:29:41Z zurawski $

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
