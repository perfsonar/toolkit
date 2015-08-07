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

use perfSONAR_PS::NPToolkit::DataService::NTP;
use perfSONAR_PS::NPToolkit::WebService::Method;
use perfSONAR_PS::NPToolkit::WebService::Router;
use perfSONAR_PS::NPToolkit::WebService::Auth qw( is_authenticated unauthorized_output );

use Config::General;
use Time::HiRes qw(gettimeofday tv_interval);

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

our $logger = get_logger( "perfSONAR_PS::WebGUI::NTPStatus" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my $data;
my $ntp_info = perfSONAR_PS::NPToolkit::DataService::NTP->new( { 'config_file' => $config_file  } );


my $router = perfSONAR_PS::NPToolkit::WebService::Router->new();

my $ntp_info_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_ntp_info",
    description     =>  "Retrieves ntp summary",
    auth_required   =>  1,
    callback        =>  sub { $ntp_info->get_ntp_information(@_); }
    );

$router->add_method($ntp_info_method);

my $known_servers = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_known_servers",
    description     =>  "Retrieves known ntp servers",
    auth_required   =>  1,
    callback        =>  sub { $ntp_info->get_known_servers(@_); }
    );

$router->add_method($known_servers);

my $selected_servers = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_selected_servers",
    description     =>  "Retrieves selected NTP servers",
    auth_required   =>  1,
    callback        =>  sub { $ntp_info->get_selected_servers(@_); }
    );

$router->add_method($selected_servers);

my $ntp_config = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_ntp_config",
    description     =>  "Retrieves ntp configuration",
    auth_required   =>  1,
    callback        =>  sub { $ntp_info->get_ntp_configuration(@_); }
    );

$router->add_method($ntp_config);

my $add_server_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "add_server",
    description     =>  "Adds an ntp server",
    auth_required   =>  1,
    request_methods => ['POST'],
    callback        =>  sub { $ntp_info->add_server(@_); }
    );

$add_server_method->add_input_parameter(
    name            => "address",
    description     => "The address (hostname or IP) of the NTP server",
    required        => 1,
    allow_empty     => 0,
    type            => 'text',
    );

$add_server_method->add_input_parameter(
    name            => "description",
    description     => "The description of the NTP server",
    required        => 0,
    allow_empty     => 1,
    type            => 'text',
    );

$router->add_method($add_server_method);

my $delete_server_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "delete_server",
    description     =>  "Deletes an ntp server",
    auth_required   =>  1,
    request_methods => ['POST'],
    callback        =>  sub { $ntp_info->delete_server(@_); }
    );

$delete_server_method->add_input_parameter(
    name            => "address",
    description     => "The address (hostname or IP) of the NTP server to delete",
    required        => 1,
    allow_empty     => 0,
    type            => 'text',
    );

$router->add_method($delete_server_method);

$router->handle_request();

# vim: expandtab shiftwidth=4 tabstop=4
