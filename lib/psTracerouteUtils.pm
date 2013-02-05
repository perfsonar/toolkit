#!/usr/bin/perl
#======================================================================
#
#       psTracerouteUtils.pm
#       $Id: psTracerouteUtils.pm,v 1.3 2012/10/03 23:20:58 dwcarder Exp $
#
#       Helper Utilities for viewing traceroute data stored in PerfSonar.
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

package psTracerouteUtils;


#=====================================================
#    U S E  A N D  R E Q U I R E
#=====================================================
use warnings;
use strict;
use lib '/opt/perfsonar_ps/traceroute_ma/lib';
use perfSONAR_PS::Client::MA;
use Exporter;                           # easy perl module functions
use XML::Twig;
use XML::Simple qw(:strict);
use Data::Dumper;


#======================================================================
#    B E G I N   C O N F I G U R A T I O N   S E C T I O N

# 'XML::SAX::ExpatXS is technically optional, but performance will tank without it.
# Do this: sudo yum install expat-devel; sudo cpan -i XML::SAX::ExpatXS
local $ENV{XML_SIMPLE_PREFERRED_PARSER} = 'XML::SAX::ExpatXS';

#      E N D   C O N F I G U R A T I O N   S E C T I O N
#======================================================================


#=====================================================
#   E X P O R T
#=====================================================
use vars qw(@ISA @EXPORT);              # perl module variables
our $VERSION = 1.0;
@ISA = qw(Exporter);
@EXPORT = qw(   GetTracerouteMetadataFromMA ParseTracerouteMetadataAnswer 
                GetTracerouteDataFromMA DeduplicateTracerouteDataAnswer
             );


#=====================================================
#    P R O T O T Y P E S
#=====================================================
sub GetTracerouteMetadataFromMA($$$);
sub ParseTracerouteMetadataAnswer($$);
sub GetTracerouteDataFromMA($$$$);
sub DeduplicateTracerouteDataAnswer($$;$);



#==============================================================================
#            B E G I N   S U B R O U T I N E S 




#===============================================================================
#                       GetTracerouteMetadataFromMA
#
#  Arguments:
#     arg[0]: full url of the tracerouteMA 
#     arg[1]: start time to query (unix time)
#     arg[2]: end time to query (unix time)
#
#  Returns: 
#     a hash of arrays with the xml responses  (yuck!)
#
sub GetTracerouteMetadataFromMA($$$) {

        my $ma_host = shift;    
        my $start_time = shift;
        my $end_time = shift;

        my $ma = new perfSONAR_PS::Client::MA( { instance => $ma_host } );

        # Define subject.  I have no idea what this does, but it sure does look important.
        my $subject = "<trace:subject xmlns:trace=\"http://ggf.org/ns/nmwg/tools/traceroute/2.0\" id=\"subject\">\n";
        $subject .= "     <nmwgt:endPointPair xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
        $subject .= "     </nmwgt:endPointPair>\n";
        $subject .=   "</trace:subject>\n";

        # Set eventType
        my @eventTypes = ("http://ggf.org/ns/nmwg/tools/traceroute/2.0");

        my $result = $ma->metadataKeyRequest(
                        {
                                start     => $start_time,
                                end             => $end_time,
                                subject => $subject,
                                eventTypes => \@eventTypes
                        }
                );
        if(not defined $result){
                die("Cannot connect MA.\n");
        }

        return($result);

} # end GetTracerouteMetadataFromMA



#===============================================================================
#                       ParseTracerouteMetadataAnswer
#
#	Parses the xml results from the metadata query and builds
#	a hash of hash datastrcuture summarizing the results, indexed
#	by metadata key.
#
#  Arguments:
#     arg[0]: a hash of arrays containing the xml metadata responses
#     arg[1]: a hash reference to fill with endpoint information
#
#  Returns: 
#
#
sub ParseTracerouteMetadataAnswer($$) {

	my $xmlresult = shift;
	my $endpoint = shift;

	# each row is a set of source-dest traceroute pairs
        foreach my $xmlrow (@{$xmlresult->{"metadata"}}) {

		# parse xml
        	my $twig = XML::Twig->new(pretty_print => 'indented');
		$twig->parse($xmlrow);

		# for debugging
        	#$twig->print;

		# grab metadata key
		my $id = $twig->first_elt('nmwg:metadata')->{'att'}->{'id'};

		# strip off "meta.".  I have no idea why it is there.
		$id =~ s/meta\.//;

		# make sure we have a src and dst
		if(!$twig->first_elt('nmwgt:src') || !$twig->first_elt('nmwgt:dst')){
			next;
		}

		# sometime there is a bogus row where the source is the destination.  not useful.
		if ($twig->first_elt('nmwgt:src')->{'att'}->{'value'} eq $twig->first_elt('nmwgt:dst')->{'att'}->{'value'}) {
			next;
		} else {
			# build datastructure
			$$endpoint{$id}{'srctype'} = $twig->first_elt('nmwgt:src')->{'att'}->{'type'};
			$$endpoint{$id}{'srcval'}  = $twig->first_elt('nmwgt:src')->{'att'}->{'value'};
			$$endpoint{$id}{'dsttype'} = $twig->first_elt('nmwgt:dst')->{'att'}->{'type'};
			$$endpoint{$id}{'dstval'}  = $twig->first_elt('nmwgt:dst')->{'att'}->{'value'};
		}

	}

}


#===============================================================================
#                       GetTracerouteDataFromMA
#
#  Arguments:
#     arg[0]: host url of measurement archive
#     arg[1]: id key to the data
#     arg[2]: start time to query (unix time)
#     arg[3]: end time to query (unix time)
#
#  Returns: 
#     a hash of arrays with the xml responses
#
sub GetTracerouteDataFromMA($$$$) {

        my $ma_host = shift;    
	my $metadata_id = shift;
        my $start_time = shift;
        my $end_time = shift;

        my $ma = new perfSONAR_PS::Client::MA( { instance => $ma_host } );

        # ask for this key's stuff to be returned.
	my $subject = "<nmwg:key id=\"key1\">\n";
	$subject .= "  <nmwg:parameters id=\"key1\">\n";
	$subject .= "    <nmwg:parameter name=\"maKey\">$metadata_id</nmwg:parameter>\n";
	$subject .= "  </nmwg:parameters>\n";
	$subject .= "</nmwg:key>\n";


        # Set eventType
        my @eventTypes = ("http://ggf.org/ns/nmwg/tools/traceroute/2.0");

        my $result = $ma->setupDataRequest(
                        {
                                start     => $start_time,
                                end             => $end_time,
                                subject => $subject,
                                eventTypes => \@eventTypes
                        }
                );
        if(not defined $result){
                die("Cannot connect to MA.\n");
        }

        return($result);

}




#===============================================================================
#                       DeduplicateTracerouteDataAnswer
#
#  Arguments:
#     arg[0]: datastructure containing xml to parse
#     arg[1]: hash ref datastructure to fill
#     arg[2]: (optional) boolean, do not actually deduplicate
#
#  Returns: 
#
#
sub DeduplicateTracerouteDataAnswer($$;$) {
	my $xmlresult = shift;
	my $topology = shift;
	my $donotdedup = shift;

	if (!defined($donotdedup)) {
		$donotdedup = 0;
	}

	my %last_topology;
	my $last_timestamp=0;

	# each row is a timestamp
        foreach my $xmlrow (@{$xmlresult->{"data"}}) {

		my %current_topology;
		my $current_timestamp=0;

		#print "\n\nNEW TIME\n";

		# parse xml into a datastructure
		my $parsed_xml = XMLin($xmlrow, 
    			ForceArray => 1, 
    			KeyAttr	   => 0
  		);

		#print Dumper($parsed_xml);
		my @arr = $$parsed_xml{'traceroute:datum'};

		#print Dumper(@arr);

		#foreach my $hashref ( @{$arr[0]} ) {
		#foreach my $hashref ( @arr ) {
		foreach my $hashref ( @{$$parsed_xml{'traceroute:datum'}} ) {
			#print "\n\nROW\n";
			#print Dumper($hashref);

			if ($$hashref{'timeValue'} < $last_timestamp) {
				die ("Times from XML response are out of order");
			} else {
				# update timestamp
				$current_timestamp = $$hashref{'timeValue'};
			}

			$current_topology{$$hashref{'ttl'}}{$$hashref{'hop'}} = 1;
		}


		my $topologychange=0;
		# see if this is the 1st run
		if (scalar(keys(%last_topology)) < 1) {
			%last_topology = %current_topology;
			$topologychange=1;

		# or, let's compare topologies
		} else {

			#print "current: -------------\n";
			#print Dumper(\%current_topology);
			#print "last: -------------\n";
			#print Dumper(\%last_topology);

		   TOPOCOMPARE1:
		   foreach my $hop (keys(%last_topology)) {

			# see if the old toplology has something the new one doen't have
			foreach my $rtr ( keys(%{$last_topology{$hop}}) ) {
				if (! defined($current_topology{$hop}{$rtr})) {
					$topologychange=1;
					#print "topo change1 at $current_timestamp for $rtr\n";
					last TOPOCOMPARE1;
				}
			}
		   }

		   if ($topologychange eq 0) {
		   TOPOCOMPARE2:
		     foreach my $hop (keys(%current_topology)) {
			# see if the new toplology has something the old one doen't have
			foreach my $rtr ( keys(%{$current_topology{$hop}}) ) {
				if (! defined($last_topology{$hop}{$rtr})) {
					$topologychange=1;
					#print "topo change2 at $current_timestamp for $rtr\n";
					last TOPOCOMPARE2;
				}
			}
		     }
		   }
		}

		if ($topologychange) {
			#print "topology change at $current_timestamp\n";
			# save this topology at this timestamp
			$$topology{$current_timestamp} = \%current_topology;
			%last_topology = %current_topology;
		}

		# save the timestamp
		$last_timestamp = $current_timestamp;
	
	} # end for each timestamp row

	return;

} # end DeduplicateTracerouteDataAnswer


