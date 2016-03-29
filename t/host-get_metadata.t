#!/usr/bin/perl -w
# This test verifies the output of the get_metadata method

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( {level => 'OFF'} );

use Test::More tests => 1;

use Config::General;
use Data::Dumper;

use perfSONAR_PS::NPToolkit::DataService::Host;
use perfSONAR_PS::NPToolkit::UnitTests::Util qw( test_result );

my $basedir = 't';
my $config_file = $basedir . '/etc/web_admin.conf';
my $ls_file = $basedir . '/etc/lsregistrationdaemon.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
my %conf = $conf_obj->getall;

my $data;
my $params = {};
$params->{'config_file'} = $config_file;
$params->{'load_ls_registration'} = 1;
$params->{'ls_config_file'} = $ls_file;

my $info = perfSONAR_PS::NPToolkit::DataService::Host->new( $params );

$data = $info->get_metadata();

#warn "data:\n" . Dumper $data;

# check the metadata

my $expected_metadata = {
    'communities' => [
        'Indiana',
        'perfSONAR',
        'perfSONAR-PS'
    ],
    'administrator' => {
        'email' => 'admin@test.com',
        'name' => 'Node Admin',
        'organization' => 'Test Org'
    },
    'location' => {
        'country' => 'US',
        'longitude' => '-28.23',
        'city' => 'Bloomington',
        'latitude' => '123.456',
        'zipcode' => '47401',
        'state' => 'IN'
    },
    'config' => {
        'access_policy' => 'public',
        'role' => 'test-host',
        'access_policy_notes' => 'This is a unit test, but feel free to test to it if you like.'
    }
};

test_result($data, $expected_metadata, "Metadata values are as expected");
