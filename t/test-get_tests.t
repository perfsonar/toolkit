#!/usr/bin/perl -w
# This test verifies the output of the get_test_configuration method

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( {level => 'OFF'} );

# we don't know how many tests there will be, so no plan here
use Test::More;

use Data::Dumper;

use perfSONAR_PS::NPToolkit::DataService::RegularTesting;
use perfSONAR_PS::NPToolkit::UnitTests::Util qw( test_result );
use perfSONAR_PS::NPToolkit::UnitTests::Util qw( compare_PStests );

my $basedir = 't';
my $regtesting_file    = $basedir.'/etc/regulartesting.conf';  
my $expected_data_file = $basedir.'/expected/test-get_tests.txt';

# EXPECTED METHOD RESULTS - read hash from a file 
our $expected;           # must be "our"
do $expected_data_file;  # sets $expected 

# RESULTS OF METHOD - use DataService::RegularTesting::get_test_configuration() to read the xml config file 
my $params = {};
$params->{'load_regular_testing'} = 1;
$params->{'config_file'} = $regtesting_file;
my $service = perfSONAR_PS::NPToolkit::DataService::RegularTesting->new( $params );
my $results = $service->get_test_configuration();

#warn "----------\n";
#warn "DATA: \n" . Dumper $results;
#warn "----------\n\n";

# check things in $results->{'status'} 
test_result($results->{'status'}->{'traceroute_tests'}, $expected->{'status'}->{'traceroute_tests'}, 
     'No. of traceroute tests');
test_result($results->{'status'}->{'owamp_tests'},      $expected->{'status'}->{'owamp_tests'}, 
    'No. of owamp tests');
test_result($results->{'status'}->{'throughput_tests'}, $expected->{'status'}->{'throughput_tests'}, 
    'No. of throughput tests');
test_result($results->{'status'}->{'pinger_tests'},     $expected->{'status'}->{'pinger_tests'}, 
    'No. of pinger tests');
#                         'network_percent_used' => '5',
#                         'hosts_file_matches_dns' => undef,
#                         'bwctl_ports' => {},
#                         'bwctl_port_range' => undef,
#                         'bwctl_port_usage' => 8,
#                         'owamp_ports' => {},
#                         'owamp_port_range' => undef,
#                         'owamp_port_usage' => 0,

# Test data from the method
my $tests = $results->{'test_configuration'};  
# Test data expected 
my $expected_tests = $expected->{'test_configuration'};  # array-ref

# compare Tests, disregarding order in hashes and arrays
compare_PStests($tests, $expected_tests);

done_testing();
