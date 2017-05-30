#!/usr/bin/perl -w
# This test verifies the output of the geoIPLookup method

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( {level => 'OFF'} );

use Test::More tests => 20;

use Data::Dumper;

use perfSONAR_PS::NPToolkit::UnitTests::Util qw( test_result geo_range );
use perfSONAR_PS::Utils::GeoLookup qw(geoIPLookup geoIPVersion);

my $versions = geoIPVersion();

my $libversion = $versions->{'lib'};

# test IP addresses below are for:
#             perfsonar-dev.grnoc.iu.edu ipv4 & ipv6,
#             ps-dashboard.es.net ipv4 & ipv6,
#             bdw-vncv1.pfs2.canarie.ca ipv4 & ipv6,
#             www.swisscom.com ipv4 (coords are of the country-center) & ipv6
my $expected_results = {
    "140.182.44.162" => {
          'country' => 'US',
          'country_full' => 'United States',
          'state_abbr' => 'IN',
          'state' => 'Indiana',
          'city' => 'Bloomington',
          'latitude' => '39.2499',
          'longitude' => '-86.4555',
          'time_zone' => 'America/Indiana/Indianapolis',
          'code' => '47408'
        },
    "2001:18e8:3:10:8000::1" => {
          'country' => 'US',
          'country_full' => 'United States'
        },
    "198.128.153.14" => {
          'country' => 'US',
          'country_full' => 'United States',
          'state_abbr' => 'CA',
          'state' => 'California',
          'city' => 'Berkeley',
          'latitude' => '37.8668',
          'longitude' => '-122.2536',
          'time_zone' => 'America/Los_Angeles',
          'code' => '94720'
    },
    "2001:400:210:153::14" => {
          'country' => 'US',
          'country_full' => 'United States'
    },
    "205.189.32.128" => {
          'country' => 'CA',
          'country_full' => 'Canada',
          'state_abbr' => 'ON',
          'state' => 'Ontario',
          'city' => 'Ottawa',
          'latitude' => '45.4225',
          'longitude' => '-75.7026',
          'time_zone' => 'America/Toronto',
          'code' => 'K1P'
    },
    "2001:410:102:b81b::2" => {
          'country' => 'CA',
          'country_full' => 'Canada'
    },
    "193.222.73.227" => {
          'country' => 'CH',
          'longitude' => '8.4610',
          'latitude' => '47.4102',
          'time_zone' => 'Europe/Zurich',
          'country_full' => 'Switzerland',
          'state_abbr' => 25,
	  'state' => 'Zurich',
	  'city' => 'Oberengstringen',
	  'code' => '8102'
     },
    "2a02:a90:ffff:ffff::c:1d" => {
          'country' => 'CH',
          'country_full' => 'Switzerland'
    }
};

$expected_results->{'140.182.44.162'}->{'time_zone'} = 'America/IndianapolisZ';
$expected_results->{'205.189.32.128'}->{'time_zone'} = 'America/Rainy_RiverZ';
$expected_results->{'193.222.73.227'}->{'longitude'} = '8.1552';
$expected_results->{'193.222.73.227'}->{'latitude'} = '47.1450';
delete $expected_results->{'193.222.73.227'}->{'state_abbr'};
delete $expected_results->{'193.222.73.227'}->{'state'};
delete $expected_results->{'193.222.73.227'}->{'city'};
delete $expected_results->{'193.222.73.227'}->{'code'};

my $result;
foreach my $ip (keys %$expected_results) {
    $result = geoIPLookup($ip);
    test_result($result, $expected_results->{$ip}, "location data is as expected for $ip");
    #warn $ip." geoIPLookup result = ".Dumper $result;
}


