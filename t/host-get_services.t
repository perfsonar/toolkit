#!/usr/bin/perl -w
# This test verifies the output of the get_services method

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( {level => 'OFF'} );

use Test::More tests => 3;

use Config::General;
use Data::Dumper;

use perfSONAR_PS::NPToolkit::DataService::Host;
use perfSONAR_PS::NPToolkit::UnitTests::Util qw( test_result );

my $basedir = 't';
my $config_file = $basedir . '/etc/web_admin.conf';
my $ls_file = $basedir . '/etc/lsregistrationdaemon.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
my %conf = $conf_obj->getall;

my $bwctl_config = 't/etc/bwctl-server.conf';
my $bwctl_limits = 't/etc/bwctl-server.limits';

my $owamp_config = 't/etc/owamp-server.conf';
my $owamp_limits = 't/etc/owamp-server.limits';

my $data;
my $params = {};
$params->{'config_file'} = $config_file;
$params->{'load_ls_registration'} = 1;
$params->{'ls_config_file'} = $ls_file;

$params->{'bwctl_config'} = $bwctl_config;
$params->{'bwctl_limits'} = $bwctl_limits;

$params->{'owamp_config'} = $owamp_config;
$params->{'owamp_limits'} = $owamp_limits;

my $info = perfSONAR_PS::NPToolkit::DataService::Host->new( $params );

$data = $info->get_services();

warn "data:\n" . Dumper $data;

# check the services

# check the administrative info

my $expected_admin_info = {
    'administrator' => 
        { 'name' => 'Node Admin',
            'organization' => 'Test Org',
            'email' => 'admin@test.com',
        },
    'location' => {
        'country' => 'US',
        'city' => 'Bloomington',
        'state' => 'IN',
        'zipcode' => '47401',
        'longitude' => '-28.23',
        'latitude' => '123.456',
    },
};

my $admin_info = {};
$admin_info->{'administrator'} = $data->{'administrator'};
$admin_info->{'location'} = $data->{'location'};

test_result($admin_info, $expected_admin_info, "Services info is as expected");
