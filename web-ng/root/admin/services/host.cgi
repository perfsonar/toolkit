#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use Log::Log4perl qw(get_logger :easy :levels);
use POSIX;
use Data::Dumper;
use JSON::XS;
use XML::Simple;
use FindBin qw($RealBin);

my $basedir = "$RealBin/../../../";

use lib "$RealBin/../../../../lib";

use perfSONAR_PS::NPToolkit::DataService::Host;
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

our $logger = get_logger( "perfSONAR_PS::WebGUI::ServiceStatus" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my $data;
my $params = {};
$params->{'config_file'} = $config_file;
$params->{'load_ls_registration'} = 1;

my $host_info = perfSONAR_PS::NPToolkit::DataService::Host->new( $params );


my $router = perfSONAR_PS::NPToolkit::WebService::Router->new();

my $summary_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_summary",
    description     =>  "Retrieves host summary",
    callback        =>  sub { $host_info->get_summary(@_); }
    );

$router->add_method($summary_method);

my $info_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_admin_info",
    description     =>  "Retrieves host admin information",
    callback        =>  sub { $host_info->get_admin_information(@_); }
    );

$router->add_method($info_method);


my $metadata_update_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            => "update_metadata",
    description     => "Updates host metadata",
    auth_required   => 1,
    callback        => sub { $host_info->update_metadata(@_); },
    min_params      => 1,
    request_methods => ['POST'],
    );

$metadata_update_method->add_input_parameter(
    name            => "role",
    description     => "The name(s) of the node role(s)",
    required        => 0,
    allow_empty     => 1,
    type            => 'text',
    multiple        => 1,
    );

$metadata_update_method->add_input_parameter(
    name            => "access_policy",
    description     => "The access policy of the node",
    required        => 0,
    allow_empty     => 1,
    type            => 'text',
    );

$metadata_update_method->add_input_parameter(
    name            => "access_policy_notes",
    description     => "Freeform text field describing the access policy of the node",
    required        => 0,
    allow_empty     => 1,
    type            => 'text',
    );

$metadata_update_method->add_input_parameter(
    name            => "site_name",
    description     => "Freeform text field describing the site name of the node",
    required        => 0,
    allow_empty     => 1,
    type            => 'text',
    );

$metadata_update_method->add_input_parameter(
    name            => "domain",
    description     => "Freeform text field describing the domain of the node",
    required        => 0,
    allow_empty     => 1,
    type            => 'text',
    );

$metadata_update_method->add_input_parameter(
    name            => "communities",
    description     => "A list of enabled communities, disabled communities and deleted communities",
    required        => 0,
    multiple        => 1,
    max_length      => 1024 * 512, # 512K
    allow_empty     => 0,
    type            => 'text',
    );

$metadata_update_method->add_input_parameter(
    name            => "organization_name",
    description     => "The name of the organization",
    required        => 0,
    allow_empty     => 1,
    type            => 'text',
    );

$metadata_update_method->add_input_parameter(
    name            => "admin_name",
    description     => "The name of the administrator",
    required        => 0,
    allow_empty     => 1,
    type            => 'text',
    );

$metadata_update_method->add_input_parameter(
    name            => "admin_email",
    description     => "The e-mail address of the administrator",
    required        => 0,
    allow_empty     => 1,
    type            => 'text',
    );

$metadata_update_method->add_input_parameter(
    name            => "city",
    description     => "The city of the administrator or organization",
    required        => 0,
    allow_empty     => 1,
    type            => 'text',
    );

$metadata_update_method->add_input_parameter(
    name            => "state",
    description     => "The state/province of the administrator or organization",
    required        => 0,
    allow_empty     => 1,
    type            => 'text',
    #min_length      => 2,
    #max_length      => 6,

    );

$metadata_update_method->add_input_parameter(
    name            => "postal_code",
    description     => "The postal code of the administrator or organization",
    required        => 0,
    allow_empty     => 1,
    type            => 'postal_code',
    );

$metadata_update_method->add_input_parameter(
    name            => "country",
    description     => "The country of the administrator or organization",
    required        => 0,
    allow_empty     => 1,
    type            => 'text',
    );

$metadata_update_method->add_input_parameter(
    name            => "latitude",
    description     => "The latitude of the node",
    required        => 0,
    allow_empty     => 1,
    type            => 'number',
    );

$metadata_update_method->add_input_parameter(
    name            => "longitude",
    description     => "The longitude of the node",
    required        => 0,
    allow_empty     => 1,
    type            => 'number',
    );

$metadata_update_method->add_input_parameter(
    name            => "subscribe",
    description     => "Whether to subscribe the administrator to the perfsonar user list",
    required        => 0,
    allow_empty     => 1,
    type            => 'boolean',
    );

$router->add_method($metadata_update_method);

my $status_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            => "get_details",
    description     => "Retrieves host status information",
    auth_required   => 1,
    callback        => sub { $host_info->get_details(@_); }
    );

$router->add_method($status_method);

my $health_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            => "get_health",
    description     =>  " Retrieves host health information",
    auth_required   => 1,
    callback        => sub {$host_info->get_system_health(@_);}
);

$router->add_method($health_method);

my $ntp_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            => "get_ntp_info",
    description     =>  " Retrieves ntp information",
    auth_required   => 1,
    callback        => sub {$host_info->get_ntp_information(@_);}
);

$router->add_method($ntp_method);

my $geoip_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            => "get_calculated_lat_lon",
    description     =>  "Estimates lat/lon based on node IP address",
    auth_required   => 1,
    callback        => sub {$host_info->get_calculated_lat_lon(@_);}
);

$router->add_method($geoip_method);

my $services_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_services",
    description     =>  "Retrieves host services information",
    callback        =>  sub { $host_info->get_services(@_); }
    );

$router->add_method($services_method);

my $get_auto_updates_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            => "get_auto_updates",
    description     => "Gets auto updates configuration",
    auth_required   => 1,
    callback        => sub { $host_info->get_auto_updates(@_); },
    );

$router->add_method($get_auto_updates_method);

my $auto_updates_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            => "update_auto_updates",
    description     => "Updates auto updates configuration",
    auth_required   => 1,
    callback        => sub { $host_info->update_auto_updates(@_); },
    request_methods => ['POST'],
    );

$auto_updates_method->add_input_parameter(
    name            => "enabled",
    description     => "Whether to enable auto updates",
    required        => 1,
    allow_empty     => 0,
    type            => 'boolean',
    );

$router->add_method($auto_updates_method);

my $metadata_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_metadata",
    description     =>  "Retrieves host metadata",
    callback        =>  sub { $host_info->get_metadata(@_); }
    );

$router->add_method($metadata_method);

my $communities_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_communities",
    description     =>  "Retrieves host communities information",
    callback        =>  sub { $host_info->get_communities(@_); }
    );

$router->add_method($communities_method);

#TODO: more testing on the get_all_communities method
my $all_communities_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_all_communities",
    description     =>  "Retrieves all available communities",
    callback        =>  sub { $host_info->get_all_communities(@_); }
    );

$router->add_method($all_communities_method);

my $templates_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_templates",
    description     =>  "Retrieves list of pSConfig templates in use",
    callback        =>  sub { $host_info->get_templates(@_); }
    );

$router->add_method($templates_method);

$router->handle_request();

# vim: expandtab shiftwidth=4 tabstop=4
