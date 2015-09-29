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
my $regular_testing_info = perfSONAR_PS::NPToolkit::DataService::RegularTesting->new( $params );

my $router = perfSONAR_PS::NPToolkit::WebService::Router->new();

my $test_configuration_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_test_configuration",
    description     =>  "Retrieves the entire testing configuration",
    callback        =>  sub { $regular_testing_info->get_test_configuration(@_); },
    auth_required   =>  1,
    );

$router->add_method($test_configuration_method);

$router->handle_request();

# vim: expandtab shiftwidth=4 tabstop=4
