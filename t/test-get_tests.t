#!/usr/bin/perl -w
# This test verifies the output of the get_test_configuration method

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( {level => 'OFF'} );

# note that if a test or member is not found, it will say you didn't run the no. of tests planned.
use Test::More tests => 126;

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
my $status = $results->{'status'};
my $expected_status = $expected->{'status'};
is( $status->{'traceroute_tests'}, $expected_status->{'traceroute_tests'}, 'No. of traceroute tests' );
is( $status->{'owamp_tests'},      $expected_status->{'owamp_tests'},      'No. of owamp tests' );
is( $status->{'throughput_tests'}, $expected_status->{'throughput_tests'}, 'No. of throughput tests' );
is( $status->{'pinger_tests'},     $expected_status->{'pinger_tests'},     'No. of pinger tests' );
is( $status->{'network_percent_used'}, $expected_status->{'network_percent_used'}, 'Network percent used' );
# check these?
#                         'hosts_file_matches_dns' => undef,
#                         'bwctl_ports' => {},
#                         'bwctl_port_range' => undef,
#                         'bwctl_port_usage' => 8,
#                         'owamp_ports' => {},
#                         'owamp_port_range' => undef,
#                         'owamp_port_usage' => 0,

# check Test configurations, disregarding order in hashes and arrays
my $tests = $results->{'test_configuration'};  
my $expected_tests = $expected->{'test_configuration'};  # array-ref
compare_PStests( $tests, $expected_tests );

