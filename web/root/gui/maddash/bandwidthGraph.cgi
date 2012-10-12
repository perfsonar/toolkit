#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

delayGraph.cgi - CGI script that graphs the output of a perfSONAR MA that
delivers delay data.  

=head1 DESCRIPTION

Given a url of an MA, and a key value (corresponds to a specific delay
result) graph using the Dygraphs API.  

=cut

use FindBin qw($RealBin);
my $basedir = "$RealBin/";
use lib ("$RealBin/../lib");

use CGI qw(:standard);
use perfSONAR_PS::Client::MA;
use XML::LibXML;
use HTML::Template;
use Time::Local;
use JSON;
use Statistics::Descriptive;
use HTML::Entities;

#print cgi-header
my $cgi = new CGI;

my $ma_url      = $cgi->param('url');
my $key         = $cgi->param('key');
my $keyR        = $cgi->param('keyR');
my $length      = $cgi->param('length');
my $sTime       = $cgi->param('sTime');
my $eTime       = $cgi->param('eTime');
my $src         = $cgi->param('src');
my $dst         = $cgi->param('dst');
my $srcIP       = $cgi->param('srcIP');
my $dstIP       = $cgi->param('dstIP');
my $domparam    = $cgi->param('DOMloaded');
my $basetmpldir = "$RealBin/../templates";

if ( !defined $ma_url || !defined $key ) {

    #print error and exit
    print $cgi->header;
    my $errmsg =
"Missing MA_URL and MA test key information. Please make sure the URL has url and key parameters";
    my $errfile = HTML::Template->new( filename => "$basetmpldir/error.tmpl" );
    $errfile->param( ERRORMSG => $errmsg );
    print $errfile->output;
    exit(1);
}

#calculate start and end time
my $start;
my $end;

#specified length
if ( defined $length ) {
    $end   = time;
    $start = $end - $length;
}
else {

    #specified start and end time
    if ( defined $sTime and defined $eTime ) {
        $start = $sTime;
        $end   = $eTime;
    }
    else {

        #default case
        $end   = time;
        $start = $end - 60 * 60;
    }

}

#request for data
my $stat = Statistics::Descriptive::Sparse->new();
my @finalRes;
my $reverse = 0;
my $res = &getData( $ma_url, $key, $start, $end );

#Error checking has to happen first
unless ( ref($res) ) {
    print $cgi->header;
    my $errmsg = $res;
    my $errfile = HTML::Template->new( filename => "$basetmpldir/error.tmpl" );
    $errfile->param( ERRORMSG => $errmsg );
    print $errfile->output;
    exit(1);
}

while ( my ( $k, $v ) = each %$res ) {
    if ( defined $keyR ) {
        if ( defined $domparam && $domparam eq "yes" ) {
            print "came here";
            $v->{"throughputr"} = undef;
        }
        else {
            $v->{"throughputr"} = "null";
        }
        $reverse = 1;
    }
    $stat->add_data( $v->{"throughput"} );
    push @finalRes, $v;
}
my $resR;
my $statR = Statistics::Descriptive::Sparse->new();
if ( defined $keyR ) {
    $resR = &getData( $ma_url, $keyR, $start, $end );
    $reverse = 1;
    if ( ref($resR) ) {

        while ( my ( $k, $v ) = each %$resR ) {
            $v->{"throughputr"} = $v->{"throughput"};
            if ( defined $domparam && $domparam eq "yes" ) {
                $v->{"throughput"} = undef;
            }
            else {
                $v->{"throughput"} = "null";
            }

            $statR->add_data( $v->{"throughputr"} );
            push @finalRes, $v;
        }
    }
}

my @sortedResult = sort { $a->{timestamp} <=> $b->{timestamp} } @finalRes;

my $stats = ();
$stats->[0]{"dir"}  = "Src-Dst";
$stats->[0]{"max"}  = $stat->max();
$stats->[0]{"min"}  = $stat->min();
$stats->[0]{"mean"} = $stat->mean();
$stats->[1]{"dir"}  = "Dst-Src";
$stats->[1]{"max"}  = $statR->max();
$stats->[1]{"min"}  = $statR->min();
$stats->[1]{"mean"} = $statR->mean();

#set the fullURL and page heading
my $queryparameters =
  $cgi->url() . "?url=$ma_url&key=$key&sTime=$start&eTime=$end";
if ( defined $keyR ) {
    $queryparameters .= "&keyR=$keyR";
}
my $pageHeading = "";

if ( defined $src and defined $dst and defined $srcIP and defined $dstIP ) {
    $pageHeading = "Source: $src($srcIP) -- Destination: $dst($dstIP)";
    $queryparameters .= "&src=$src&dst=$dst&srcIP=$srcIP&dstIP=$dstIP";
}
elsif ( defined $src and defined $dst ) {
    $pageHeading = "Source: $src -- Destination: $dst";
    $queryparameters .= "&src=$src&dst=$dst";
}
elsif ( defined $srcIP and defined $dstIP ) {
    $pageHeading = "Source: $srcIP -- Destination: $dstIP";
    $queryparameters .= "&srcIP=$srcIP&dstIP=$dstIP";
}

#output
print $cgi->header;

# print output
if ( defined $domparam && $domparam eq "yes" ) {
    my $json            = new JSON;
    my $formattedResult = ();
    $formattedResult->{"statistics"} = $stats;
    $formattedResult->{"data"}       = \@sortedResult;
    my $json_text =
      $json->pretty->allow_blessed->allow_nonref->allow_unknown->encode(
        $formattedResult);

    print "\n", $json_text;

}
else {
    my $htmlfile =
      HTML::Template->new( filename => "$basetmpldir/bw_pageDisplay.tmpl" );
    $htmlfile->param(
        STARTTIME => HTML::Entities::encode($start),
        ENDTIME   => HTML::Entities::encode($end),
        MA_URL    => HTML::Entities::encode($ma_url),
        TESTKEY   => HTML::Entities::encode($key),
        TESTKEYR  => HTML::Entities::encode($keyR),
        REVERSE   => HTML::Entities::encode($reverse),
        FULLURL   => HTML::Entities::encode($queryparameters)
    );
    print $htmlfile->output;
    my $jsfile = HTML::Template->new(
        filename          => "$basetmpldir/bw_graphing.tmpl",
        loop_context_vars => "true"
    );
    $jsfile->param(
        TESTHOSTS => HTML::Entities::encode($pageHeading),
        GRAPHDATA => \@sortedResult,
        REVERSE   => HTML::Entities::encode($reverse),
        STATS     => HTML::Entities::encode($stats)
    );
    print $jsfile->output;

}

#getData subroutine
#contacts the MA and retrieves the data from the MA
sub getData() {

    #get the input values
    my ( $ma_url, $key, $startTime, $endTime ) = @_;

	my %finalResult;
    my @keyList=();
    @keyList = split(/_/,$key);

    # Create client
    my $ma = new perfSONAR_PS::Client::MA( { instance => $ma_url } );

    my @eventTypes = ();
   
   foreach my $k (@keyList){ 

    	#define the subject
    	my $subject = "  <nmwg:key id=\"key-1\">\n";
    	$subject .= "    <nmwg:parameters id=\"parameters-key-1\">\n";
    	$subject .= "      <nmwg:parameter name=\"maKey\">" . $k . "</nmwg:parameter>\n";
    	$subject .= "    </nmwg:parameters>\n";
    	$subject .= "  </nmwg:key>  \n";

    	#retrieve data from MA
   	 my $result = $ma->setupDataRequest(
        	{
            	start      => $startTime,
            	end        => $endTime,
            	resolution => 5,
            	subject    => $subject,
            	eventTypes => \@eventTypes
       		 }
    	);

    	#parse XML response
    	#my %finalResult;
    	my $parser = XML::LibXML->new();
    	my $doc;
    	eval { $doc = $parser->parse_string( @{ $result->{data} } ); };

    	if ($@) {
        	return "Error in MA response";
    	}

    	my $root       = $doc->getDocumentElement;
    	my @childnodes = $root->findnodes("./*[local-name()='datum']");

    	#extract required data attributes

    	foreach my $child (@childnodes) {

        	if ( scalar @childnodes == 1 ) {
            	if (   $child->textContent =~ m/(E|e)rror/
                	|| $child->textContent =~ m/Query returned 0 results/ )
            	{
                	#my $returnmsg = "No results were returned from MA. \n Error: ". $child->textContent;
                	#return $returnmsg;
            	}
        	}
        	my %tsresult   = ();
        	my $throughput = eval( $child->getAttribute("throughput") );
        	my $eTime      = $child->getAttribute("timeValue");

        	my $etimestamp;

        	if ( defined $eTime ) {
            		$etimestamp = convertDBtoUnixTS($eTime);
        	}

        	if ( defined $throughput && defined $etimestamp ) {
            		$tsresult{"timestamp"} = $etimestamp;

            	if ( defined $throughput ) {
                	$tsresult{"throughput"} = $throughput;
            	}
            	else {
                	$tsresult{"throughput"} = undef;
            	}
            	$finalResult{$etimestamp} = \%tsresult;
        	}
    	}

   }

   if ( scalar keys %finalResult > 0 ) {
        return \%finalResult;
    }
   else {
        return "Error: Found empty result set";
   }

}

sub convertDBtoUnixTS() {
    my ($dbtime) = @_;

   #my %days = {"Sun"=>0,"Mon"=>1,"Tue"=>2,"Wed"=>3,"Thu"=>4,"Fri"=>5,"Sat"=>6};
    my %months = (
        Jan => "0",
        Feb => "1",
        Mar => "2",
        Apr => "3",
        May => "4",
        Jun => "5",
        Jul => "6",
        Aug => "7",
        Sep => "8",
        Oct => "9",
        Nov => "10",
        Dec => "11"
    );

    my @array = split( / /, $dbtime );

    my $year  = $array[5];
    my $month = $months{ $array[1] };
    my $day   = $array[2];

    my @time = split( /:/, $array[3] );
    my $hour = $time[0];
    my $min  = $time[1];
    my $sec  = $time[2];

    my $unixtime = timegm( $sec, $min, $hour, $day, $month, $year );

    return $unixtime;
}
