#!/usr/bin/perl -w
# This test verifies the output of the get_metadata method
# The general approach here is to create an array of tests to run, with some parameters
# We test that get_metadata works initially.
# Then run update_metadata, reload the config, and make sure get_metadata matches
# check all these situations:
# save method succeds, service restart fails
# save method fails, restart succeeds
# save method fails, restart fails

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( {level => 'OFF'} );

use Test::More tests => 23;

use Config::General;
use Data::Dumper;
use Test::MockObject::Extends;
use Params::Validate qw(:all);
use File::Copy::Recursive qw( fcopy );
local $File::Copy::Recursive::RMTrgFil = 1;

use perfSONAR_PS::NPToolkit::DataService::Host;
use perfSONAR_PS::NPToolkit::UnitTests::Mock qw( save_file_mock succeed_value );
use perfSONAR_PS::NPToolkit::UnitTests::Util qw( test_result hash_to_parameters );
use perfSONAR_PS::NPToolkit::UnitTests::Router;

my $basedir = 't';
my $config_file = $basedir . '/etc/web_admin.conf';
my $ls_file_orig = $basedir . '/etc/lsregistrationdaemon.conf';
my $ls_file_new = $basedir . '/tmp/etc/lsregistrationdaemon.conf';
my $ls_file_new_first = $ls_file_new;
my $delete_files = 1;

my $conf_obj = Config::General->new( -ConfigFile => $config_file );
my %conf = $conf_obj->getall;

my $data;
my $host_params = {};
$host_params->{'config_file'} = $config_file;
$host_params->{'load_ls_registration'} = 1;
$host_params->{'ls_config_file'} = $ls_file_new;

# original_metadata is the data we expect to get back before making changes
my $original_metadata = get_original_metadata();

# updated_metadata is the data we expect after a successful edit/save
my $updated_metadata = get_updated_metadata();

# We must create our mocks before instantiating the objects that use them
# mock the external dependencies called by new

my $tests = [];
my $row = {};
# NOTE: For these tests, 'save_succeeded' and 'restart_succeded' use 0 for false
# and 1 for true. 
# However, the restart response uses 0 for success and -1 for failure.
$row->{'save_succeed'}              = 0;
$row->{'restart_succeed'}           = -1;
$row->{'expected_save_response'}    = 0;
$row->{'expected_data'}             = $original_metadata; # save was unsucessful
push @$tests, $row;

$row = {};
$row->{'save_succeed'}              = 1;
$row->{'restart_succeed'}           = 0;
$row->{'expected_save_response'}    = 1;
$row->{'expected_data'}             = $updated_metadata;
push @$tests, $row;

$row = {};
$row->{'save_succeed'}              = 1;
$row->{'restart_succeed'}           = -1;
$row->{'expected_save_response'}    = 1;
# the file is saved before the services are restarted, so the file should be updated
$row->{'expected_data'}             = $updated_metadata;
push @$tests, $row;

# COPY OVER INITIAL CONFIG
fcopy( $ls_file_orig, $ls_file_new ) or die ("Error copying config file");

# GET INITIAL DATA
my $router = perfSONAR_PS::NPToolkit::UnitTests::Router->new( );

isa_ok( $router, 'perfSONAR_PS::NPToolkit::UnitTests::Router' );

my $info = perfSONAR_PS::NPToolkit::DataService::Host->new( $host_params );
isa_ok( $info, 'perfSONAR_PS::NPToolkit::DataService::Host' );

$data = $router->call_method( { method => sub { $info->get_metadata(@_); } } );

# check the metadata
test_result($data, $original_metadata, "Metadata values are as expected");

my $i = 0;
foreach my $test ( @$tests ) {
    my $save_success = $test->{'save_succeed'};
    my $restart_success = $test->{'restart_succeed'};
    my $expected_data = $test->{'expected_data'};
    my $expected_save_response = $test->{'expected_save_response'};
    my $qmock = Test::MockObject->new();

    $ls_file_new = $basedir . '/tmp/etc/lsregistrationdaemon.conf-' . $i;
    fcopy( $ls_file_orig, $ls_file_new ) or die ("Error copying config file");
    $host_params->{'ls_config_file'} = $ls_file_new;

# Testing this scenario
# save method succeeds, restarting service succeeds
    $qmock->fake_module(
        'perfSONAR_PS::NPToolkit::ConfigManager::ConfigClient',
        saveFile => sub { perfSONAR_PS::NPToolkit::UnitTests::Mock::save_file_mock( $save_success, @_ ) }
    );

    $qmock->fake_module(
        'perfSONAR_PS::NPToolkit::ConfigManager::ConfigClient',
        restartService => sub{ perfSONAR_PS::NPToolkit::UnitTests::Mock::succeed_value( $restart_success ) }
    );

    $router = perfSONAR_PS::NPToolkit::UnitTests::Router->new( );

    isa_ok( $router, 'perfSONAR_PS::NPToolkit::UnitTests::Router' );

    $info = perfSONAR_PS::NPToolkit::DataService::Host->new( $host_params );
    isa_ok( $info, 'perfSONAR_PS::NPToolkit::DataService::Host' );


    my $update = flatten_metadata ( $updated_metadata );
    $update = hash_to_parameters( $update );
    $router->set_input_params( { input_params => $update } );

    $data = $router->call_method( { method => sub { $info->update_metadata(@_); } } );


    my $message = $data->{'error_msg'};
    $message = $data->{'status_msg'} if $data->{'status_msg'};
    my $response = $data->{'success'};
    $message = "Save response is as expected";
    $message .= " ( save_success: $save_success; restart_success: $restart_success )";

    is( $response, $expected_save_response, $message );

    # re-instantiate the Host info object so it reloads the config
    $info = perfSONAR_PS::NPToolkit::DataService::Host->new( $host_params );

    $router->set_input_params( { input_params => {} } );
    $data = $router->call_method( { method => sub { $info->get_metadata(@_); } } );
    $message = "Metadata values are as expected";
    $message .= " ( save_success: $save_success; restart_success: $restart_success )";
    test_result($data, $expected_data, $message);

    if ( $delete_files ) {
        unlink $ls_file_new or die ("Error deleting temp config file");
    }
    $i++;
}

if ( $delete_files ) {
    unlink $ls_file_new_first or die ("Error deleting temp config file");
    my $ls_file_new = $basedir . '/tmp/etc/lsregistrationdaemon.conf';
    rmdir $basedir . '/tmp/etc' or die "Error deleting t/tmp/etc directory";
    rmdir $basedir . '/tmp' or warn "Error deleting t/tmp directory";
}


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
    return $flattened;
}

sub get_updated_metadata {
    my $data = {
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
            'state' => 'Newstate'
        },
        'config' => {
            'access_policy' => 'private',
            'role' => 'regional',
            'access_policy_notes' => 'New node'
        }
    };
    return $data;
}

sub get_original_metadata {
    my $data = {
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
    return $data;
}

