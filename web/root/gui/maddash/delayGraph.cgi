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
use HTML::Entities;

#print cgi-header
my $cgi = new CGI;

my $ma_url   = $cgi->param('url');
my $key      = $cgi->param('key');
my $keyR     = $cgi->param('keyR');
my $length   = $cgi->param('length');
my $sTime    = $cgi->param('sTime');
my $eTime    = $cgi->param('eTime');
my $src      = $cgi->param('src');
my $dst      = $cgi->param('dst');
my $srcIP    = $cgi->param('srcIP');
my $dstIP    = $cgi->param('dstIP');
my $domparam = $cgi->param('DOMloaded');
my $bucketVal = $cgi->param('bucket_width');


my $basetmpldir = "$RealBin/../templates";

if ( !defined $ma_url and !defined $key ) {

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

my $resR;
my $reverse;
my @finalRes = ();

my $bucketsFlag;
my $chkcnt = 0;
my $negLatChk=0;
while ( my ( $k, $v ) = each %$res ) {
    if ( $chkcnt == 0 ) {
        if ( $v->{"buckets"} eq "true" && !defined $bucketsFlag ) {
            $bucketsFlag = 1;
        }
        elsif ( $v->{"buckets"} eq "false" && !defined $bucketsFlag ) {
            $bucketsFlag = 0;
        }
    }

    if ( defined $domparam && $domparam eq "yes" ) {

        #will be sent as JSON. so undef will be converted to null
        $v->{"minr"}  = undef;
        $v->{"lossr"} = undef;
        $v->{"maxr"}  = undef;
        if ( $bucketsFlag == 1 ) {
            $v->{"thirdqr"} = undef;
            $v->{"medianr"} = undef;
            $v->{"firstqr"} = undef;
        }
    }
    else {

        #should specify null explicitly
        $v->{"minr"}  = "null";
        $v->{"lossr"} = "null";
        $v->{"maxr"}  = "null";
        if ( $bucketsFlag == 1 ) {
            $v->{"thirdqr"} = "null";
            $v->{"medianr"} = "null";
            $v->{"firstqr"} = "null";

        }
    }
    if ( defined $keyR ) {
        $reverse = 1;
    }
    if($v->{"min"} <0){
        $negLatChk=1;
    }
    push @finalRes, $v;
    $chkcnt++;
}

if ( $domparam eq "yes" && defined $keyR ) {
    $resR = &getData( $ma_url, $keyR, $start, $end );
    $reverse = 1;
    if ( ref($resR) ) {
        while ( my ( $k, $v ) = each %$resR ) {
            $v->{"minr"}  = $v->{"min"};
            $v->{"min"}   = undef;
            $v->{"lossr"} = $v->{"loss"};
            $v->{"loss"}  = undef;
            $v->{"maxr"}  = $v->{"max"};
            $v->{"max"}   = undef;
            if ( $bucketsFlag == 1 ) {
                $v->{"thirdqr"} = $v->{"thirdq"};
                $v->{"thirdq"}  = undef;
                $v->{"medianr"} = $v->{"median"};
                $v->{"median"}  = undef;
                $v->{"firstqr"} = $v->{"firstq"};
                $v->{"firstq"}  = undef;
            }

            push @finalRes, $v;
        }
    }

}

my @sortedResult = sort { $a->{timestamp} <=> $b->{timestamp} } @finalRes;

#set the fullURL and page heading
my $queryparameters =
  $cgi->url() . "?url=$ma_url&key=$key&keyR=$keyR&sTime=$start&eTime=$end";
my $pageHeading = "";

if ( defined $src and defined $dst and defined $srcIP and defined $dstIP ) {
    $pageHeading = "One way latency between Source: $src($srcIP) -- Destination: $dst($dstIP)";
    $queryparameters .= "&src=$src&dst=$dst&srcIP=$srcIP&dstIP=$dstIP";
}
elsif ( defined $src and defined $dst ) {
    $pageHeading = "One way latency between Source: $src -- Destination: $dst";
    $queryparameters .= "&src=$src&dst=$dst";
}
elsif ( defined $srcIP and defined $dstIP ) {
    $pageHeading = "One way latency between Source: $srcIP -- Destination: $dstIP";
    $queryparameters .= "&srcIP=$srcIP&dstIP=$dstIP";
}

$queryparameters .= "&bucket_width=$bucketVal";
#output
if ( defined $domparam && $domparam eq "yes" ) {
    my $json = new JSON;
    my $json_text =
      $json->pretty->allow_blessed->allow_nonref->allow_unknown->encode(
        \@sortedResult );

    print "\n", $json_text;

}
else {
    print $cgi->header;

    #print output
    my $htmlfile =
      HTML::Template->new( filename => "$basetmpldir/pageDisplay.tmpl" );
    $htmlfile->param(
        BUCKETS    => HTML::Entities::encode($bucketsFlag),
        STARTTIME  => HTML::Entities::encode($start),
        ENDTIME    => HTML::Entities::encode($end),
        MA_URL     => HTML::Entities::encode($ma_url),
        TESTKEY    => HTML::Entities::encode($key),
        FULLURL    => HTML::Entities::encode($queryparameters),
        TESTHOSTS  => HTML::Entities::encode($pageHeading),
        TESTKEYREV => HTML::Entities::encode($keyR),
    );
    print $htmlfile->output;
    my $jsfile = HTML::Template->new(
        filename          => "$basetmpldir/graphing.tmpl",
        loop_context_vars => "true",
        die_on_bad_params => 0
    );
    $jsfile->param(
        BUCKETS   => HTML::Entities::encode($bucketsFlag),
	NEGATIVELATENCY => HTML::Entities::encode($negLatChk),
        GRAPHDATA => HTML::Entities::encode(\@sortedResult)
    );
    print $jsfile->output;
}

#getData subroutine
#contacts the MA and retrieves the data from the MA
#NOTE: The data returned contains loss, min_delay and the quartile ranges (that is, the difference is returned - 1stQ-MinDelay, Median-1stQ, etc)
sub getData() {

    #get the input values
    my ( $ma_url, $key, $startTime, $endTime ) = @_;

    my %finalResult;
    # Create client
    my $ma = new perfSONAR_PS::Client::MA( { instance => $ma_url } );

    my @eventTypes = ();

    my @keyList=();
    @keyList = split(/_/,$key);

    foreach my $k (@keyList){
    	#define the subject
    	my $subject = "  <nmwg:key id=\"key-1\">\n";
    	$subject .= "    <nmwg:parameters id=\"parameters-key-1\">\n";
   	$subject .="      <nmwg:parameter name=\"maKey\">" . $key . "</nmwg:parameter>\n";
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
    	my $parser = XML::LibXML->new();
    	my $doc;
    	
    	eval { $doc = $parser->parse_string( @{ $result->{data} } ); };
    	my $root       = $doc->getDocumentElement;
    	
    	my @childnodes = $root->findnodes("./*[local-name()='datum']");

    	if ($@) {
        	return "Error in MA response";
    	}

  

    	#extract required data attributes
    	my $bktFlag;
    	foreach my $child (@childnodes) {

        	if ( scalar @childnodes == 1 ) {
            		if (   $child->textContent =~ m/(E|e)rror/
                		|| $child->textContent =~ m/returned 0 results/i )
            		{
                		return;
            		}
        	}
        	my %tsresult     = ();
        	my $min          = $child->getAttribute("min_delay") * 1000;
        	my $max          = $child->getAttribute("max_delay") * 1000;
        	my $loss         = $child->getAttribute("loss");
        	my $sent_packets = $child->getAttribute("sent");
        	my $duplicates   = $child->getAttribute("duplicates");
        	my $sTime        = $child->getAttribute("startTime");
       	 	 my $eTime        = $child->getAttribute("endTime");

        	my $etimestamp;

        	if ( defined $eTime ) {
            		$etimestamp = convertDBtoUnixTS($eTime);
        	}

        	my @summaryBuckets =$child->findnodes(".//*[local-name()='value_bucket']");
        	my %histogram = ();
        	foreach my $sumTag (@summaryBuckets) {
            		my $tmpKey = $sumTag->getAttribute("value");
            		my $cnt    = $sumTag->getAttribute("count");
            		$histogram{$tmpKey} = $cnt;
        	}

        	if (defined $min && defined $max && defined $loss && defined $etimestamp )
        	{
            		$tsresult{"timestamp"} = $etimestamp;

            		if ( defined $max ) {
                		$tsresult{"max"} = $max;
            		}else {
                		$tsresult{"max"} = undef;
            		}
            		if ( defined $min ) {
                		$tsresult{"min"} = $min;
            		}
            		else {
                		$tsresult{"min"} = undef;
            		}
            		if ( defined $loss and defined $sent_packets ) {
            			if($sent_packets >0 ){
            				$tsresult{"loss"} = $loss / $sent_packets * 100;
            			}else{
            				$tsresult{"loss"} = undef;
            			}
                		
            		}else {
                		$tsresult{"loss"} = undef;
            		}
            		my $median;
            		my $firstq;
            		my $thirdq;

            		if ( scalar @summaryBuckets > 0 ) {
            			if($bucketVal > 0){
            				$median = getPercentile( $sent_packets, 50, \%histogram ) * ($bucketVal/0.001);
                			$firstq = getPercentile( $sent_packets, 25, \%histogram ) * ($bucketVal/0.001);
                			$thirdq = getPercentile( $sent_packets, 75, \%histogram ) * ($bucketVal/0.001);
                			$tsresult{"buckets"} = "true";
            			}else{
            				$tsresult{"buckets"} = "false";
            			}
                		
                		
            		}else {
                		$tsresult{"buckets"} = "false";
            		}

            		if ( defined $firstq ) {
                		$tsresult{"firstq"} = $firstq;
            		}else {
                		$tsresult{"firstq"} ="null";    #JS function needs null to be specified this way
            		}

           	 	if ( defined $median ) {
                		$tsresult{"median"} = $median;
            		}else {
                		$tsresult{"median"} = "null";
            		}

            		if ( defined $thirdq ) {
                		$tsresult{"thirdq"} = $thirdq;
            		}else {
                		$tsresult{"thirdq"} = "null";
            		}
            		$finalResult{$etimestamp} = \%tsresult;
        	}
    	}
  }

    if ( scalar keys %finalResult >= 0 ) {
        return \%finalResult;
    }
    else {
        return "Error: Found empty result set";
    }

}

sub getPercentile() {
    my ( $nvalue, $percentile, $dataHash ) = @_;

    if ( $percentile > 100 || $percentile < 0 ) {
        print "ERROR: Percentile should be a positive number < 100 ";
        exit(0);
    }

    my $totalCount = 0;
    my $result     = 0;
    my $dm         = 0;

    my $index = ( $percentile * $nvalue / 100 ) + 0.5;
    my ( $int, $frac ) = split( /\./, $index );
    if ( !$frac ) {
        $frac = 0;
    }
    my $xint        = 0;
    my $xintplusone = 0;
    my $flag        = 0;
  PERCENTILELOOP: foreach my $k ( sort { $a <=> $b } ( keys %$dataHash ) ) {
        $totalCount += $dataHash->{$k};
        if ( $totalCount == $int ) {
            $xint = $k;
            $flag = 1;
        }
        elsif ( $totalCount >= $int + 1 ) {
            if ( $flag == 1 ) {
                $xintplusone = $k;
            }
            else {
                $xint        = $k;
                $xintplusone = $k;
            }
            last PERCENTILELOOP;
        }

    }

    #convert the fractional part into a proper fraction
    my $num   = $frac;
    my $denom = $frac;
    $denom =~ s/\d/0/g;
    $denom  = "1$denom";
    $frac   = $num / $denom;
    $result = ( ( 1 - $frac ) * $xint ) + ( $frac * $xintplusone );
    return $result;
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

