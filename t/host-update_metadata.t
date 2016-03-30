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
use Test::MockObject::Extends;
use Params::Validate qw(:all);
use File::Copy::Recursive qw( fcopy );
local $File::Copy::Recursive::RMTrgFil = 1;

use perfSONAR_PS::NPToolkit::DataService::Host;
use perfSONAR_PS::NPToolkit::UnitTests::Mock qw( save_file_mock success_value );
use perfSONAR_PS::NPToolkit::UnitTests::Util qw( test_result hash_to_parameters );
use perfSONAR_PS::NPToolkit::UnitTests::Router;

my $basedir = 't';
my $config_file = $basedir . '/etc/web_admin.conf';
my $ls_file_orig = $basedir . '/etc/lsregistrationdaemon.conf';
my $ls_file = $basedir . '/tmp/etc/lsregistrationdaemon.conf';

fcopy( $ls_file_orig, $ls_file ) or die ("Error copying config file");

my $conf_obj = Config::General->new( -ConfigFile => $config_file );
my %conf = $conf_obj->getall;

my $data;
my $params = {};
$params->{'config_file'} = $config_file;
$params->{'load_ls_registration'} = 1;
$params->{'ls_config_file'} = $ls_file;

# We must create our mocks before instantiating the objects that use them
# mock the external dependencies called by new

my $qmock = Test::MockObject->new();
$qmock->fake_module('perfSONAR_PS::NPToolkit::ConfigManager::ConfigClient', saveFile => sub { perfSONAR_PS::NPToolkit::UnitTests::Mock::save_file_mock(1, @_) } );
$qmock->fake_module('perfSONAR_PS::NPToolkit::ConfigManager::ConfigClient', restartService => sub{ perfSONAR_PS::NPToolkit::UnitTests::Mock::succeed_value( 0 ) } );

my $router = perfSONAR_PS::NPToolkit::UnitTests::Router->new( );

isa_ok( $router, 'perfSONAR_PS::NPToolkit::UnitTests::Router' );

my $info = perfSONAR_PS::NPToolkit::DataService::Host->new( $params );
isa_ok( $info, 'perfSONAR_PS::NPToolkit::DataService::Host' );

$data = $router->call_method( { method => sub { $info->get_metadata(@_); } } );

warn "data:\n" . Dumper $data;

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


my $updated_metadata = {
    'communities' => [
        'IndianaZ',
        'perfSONAR new',
        'perfSONAR-PS new'
    ],
    'administrator' => {
        'email' => 'newadmin@test.com',
        'name' => 'Node Adminz',
        'organization' => 'Test Orgz'
    },
    'location' => {
        'country' => 'CO',
        'longitude' => '-74.0779491',
        'city' => 'Bogatá',
        'latitude' => '4.7002952',
        'zipcode' => '113456',
        'state' => ''
    },
    'config' => {
        'access_policy' => 'private',
        'role' => 'regional',
        'access_policy_notes' => 'New node'
    }
};

my $update = flatten_metadata ( $updated_metadata );

$update = hash_to_parameters( $update );

$router->set_input_params( { input_params => $update } );

$data = $router->call_method( { method => sub { $info->update_metadata(@_); } } );

warn "data:\n" . Dumper $data;

$router->set_input_params( { input_params => {} } );

$data = $router->call_method( { method => sub { $info->get_metadata(@_); } } );
test_result($data, $updated_metadata, "Metadata values are as expected");

warn "updated data:\n" . Dumper $data;

# check all these situations
# save method succeeds, restart succeeds
# save method succeds, restart fails
# save method fails, restart succeeds
# save method fails, restart fails
# unauthorized attempt to save

#$qmock->fake_module('perfSONAR_PS::NPToolkit::ConfigManager::ConfigClient', saveFile => sub { save_file_mock(0, @_) } );

#my $router = perfSONAR_PS::NPToolkit::UnitTests::Router->new( );

#$router->set_input_params( { input_params => $update } );

#$data = $router->call_method( { method => sub { $info->update_metadata(@_); } } );

#warn "data:\n" . Dumper $data;


#unlink $ls_file or die ("Error deleting temp config file");

sub flatten_metadata {
    my $data = shift;
    my $flattened = {};
    while ( my ($key, $value) = each %$data ) {
        if ($key eq 'communities') {
            $flattened->{$key} = $value;
        } else {
            while ( my ($subkey, $subvalue) = each %$value) {
                if ( $subkey eq 'role' ) {
                    $flattened->{$subkey} = [ $subvalue ];
                    next;
                }
                $subkey =~ s/^organization$/organization_name/;
                $subkey =~ s/^email$/admin_email/;
                $subkey =~ s/^name$/admin_name/;
                $subkey =~ s/^zipcode$/postal_code/;
                $flattened->{$subkey} = $subvalue;

            }

        }

    }
    warn "flattened\n" . Dumper $flattened;
    return $flattened;
}
