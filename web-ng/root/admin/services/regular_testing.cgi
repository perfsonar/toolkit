#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use Log::Log4perl qw(get_logger :easy :levels);
use POSIX;
use Data::Dumper;
use JSON::XS;
use XML::Simple;
use Sys::MemInfo qw(totalmem);
use FindBin qw($RealBin);


my $basedir = "$RealBin/../../../";

use lib "$RealBin/../../../../lib";

use perfSONAR_PS::NPToolkit::WebService::ParameterTypes qw($parameter_types);

use perfSONAR_PS::NPToolkit::DataService::RegularTesting;
use perfSONAR_PS::NPToolkit::WebService::Method;
use perfSONAR_PS::NPToolkit::WebService::Router;
use perfSONAR_PS::NPToolkit::WebService::Auth qw( is_authenticated unauthorized_output );

my $cgi = CGI->new();
my $authenticated = is_authenticated($cgi);

if ( !$authenticated ) {
    print unauthorized_output($cgi);
    exit;
}


my $config_file = $basedir . '/etc/web_admin.conf';
my $test_config_defaults_file = $basedir . '/etc/test_config_defaults.conf';
warn "test config defaults file: $test_config_defaults_file";
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our %conf = $conf_obj->getall;

if ( $conf{logger_conf} ) {
    unless ( $conf{logger_conf} =~ /^\// ) {
        $conf{logger_conf} = $basedir . "/etc/" . $conf{logger_conf};
    }

    Log::Log4perl->init( $conf{logger_conf} );
}
else {

    # If they've not specified a logger, send it all to /dev/null
    Log::Log4perl->easy_init( { level => $DEBUG, file => "/dev/null" } );
}

our $logger = get_logger( "perfSONAR_PS::WebGUI::ServiceStatus" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my $data;
my $params = {};
$params->{config_file} = $config_file;
$params->{load_regular_testing} = 1;
$params->{load_ls_registration} = 0;
$params->{test_config_defaults_file} = $test_config_defaults_file;
my $regular_testing_info = perfSONAR_PS::NPToolkit::DataService::RegularTesting->new( $params );

my $router = perfSONAR_PS::NPToolkit::WebService::Router->new();

my $test_configuration_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_test_configuration",
    description     =>  "Retrieves the entire testing configuration",
    callback        =>  sub { $regular_testing_info->get_test_configuration(@_); },
    auth_required   =>  1,
    );
$router->add_method($test_configuration_method);

my $add_test_configuration_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "add_test_configuration",
    description     =>  "Add test configuration",
    auth_required   =>  1,
    request_methods => ['POST'],
    callback        =>  sub { $regular_testing_info->add_test_configuration(@_); }
    );

$add_test_configuration_method->add_input_parameter(
    name            => "POSTDATA",
    description     => "JSON blob containing tests",
    required        => 1,
    allow_empty     => 0,
    max_length      => 1024 * 1024, # 1M
    type            => 'text',
    );

$router->add_method($add_test_configuration_method);

my $update_test_configuration_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "update_test_configuration",
    description     =>  "Update test configuration - first deletes all tests and then adds the test configuration",
    auth_required   =>  1,
    request_methods => ['POST'],
    callback        =>  sub { $regular_testing_info->update_test_configuration(@_); }
    );

$update_test_configuration_method->add_input_parameter(
    name            => "POSTDATA",
    description     => "JSON blob containing tests",
    required        => 1,
    allow_empty     => 0,
    max_length      => 1024 * 1024, # 1M
    type            => 'text',
    );

$router->add_method($update_test_configuration_method);


my $test_config_defaults_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_default_test_parameters",
    description     =>  "Retrieves the default test parameters for all tests",
    callback        =>  sub { $regular_testing_info->get_default_test_parameters(@_); },
    auth_required   =>  1,
    );
$router->add_method($test_config_defaults_method);


$router->handle_request();

# vim: expandtab shiftwidth=4 tabstop=4
