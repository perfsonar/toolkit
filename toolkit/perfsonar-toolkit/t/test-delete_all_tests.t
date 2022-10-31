#!/usr/bin/perl -w
# This test verifies the that method delete_all_tests() works

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( {level => 'OFF'} );

use Test::More tests => 4;

use Data::Dumper;

use perfSONAR_PS::NPToolkit::DataService::RegularTesting;

my $basedir = 't';
my $regtesting_file    = $basedir.'/etc/regulartesting.conf';  

# read in regulartesting.conf
my $params = {};
$params->{'load_regular_testing'} = 1;
$params->{'config_file'} = $regtesting_file;
my $service = perfSONAR_PS::NPToolkit::DataService::RegularTesting->new( $params );
my $results = $service->get_test_configuration();
isnt( $service->{'regular_testing_conf'}->{'TESTS'}, undef, 'tests found' );

#warn "----------\n";
#warn "SERVICE: \n" . Dumper $service;
#warn "----------\n\n";

# delete all the tests
$results = $service->delete_all_tests();

#warn "----------\n";
#warn "RESULTS: \n" . Dumper $results;
#warn "SERVICE: \n" . Dumper $service;
#warn "----------\n\n";

# checks
is( $results->{'Return code'}, 0, 'Return code is 0' );
is( $service->{'regular_testing_conf'}->{'TESTS'}, undef, 'no tests found' );
is( $results->{'Error message'}, '', 'Return msg is blank' );
