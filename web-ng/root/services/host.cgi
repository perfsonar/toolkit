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

my $basedir = "$RealBin/../../";

use lib "$RealBin/../../../lib";

use perfSONAR_PS::NPToolkit::DataService::Host;
use perfSONAR_PS::NPToolkit::WebService::Method;
use perfSONAR_PS::NPToolkit::WebService::Router;

use Config::General;
use Time::HiRes qw(gettimeofday tv_interval);


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
my $host_info = perfSONAR_PS::NPToolkit::DataService::Host->new( { 'config_file' => $config_file  } );

#my $cgi = CGI->new();

my $router = perfSONAR_PS::NPToolkit::WebService::Router->new();

my $summary_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_summary",
    description     =>  "Retrieves host summary",
    callback        =>  sub { $host_info->get_summary(@_); }
    );

$router->add_method($summary_method);

my $info_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_info",
    description     =>  "Retrieves host information",
    callback        =>  sub { $host_info->get_information(@_); }
    );

$router->add_method($info_method);

my $status_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_status",
    description     =>  "Retrieves host status information",
    callback        =>  sub { $host_info->get_status(@_); }
    );

$router->add_method($status_method);

my $health_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            => "get_health",
    description     =>  " Retrieves host health information",
    auth_required   => 1,
    callback        => sub {$host_info->get_system_health(@_);}
);

$router->add_method($health_method);

my $services_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_services",
    description     =>  "Retrieves host services information",
    callback        =>  sub { $host_info->get_services(@_); }
    );

$router->add_method($services_method);

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

my $meshes_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_meshes",
    description     =>  "Retrieves host mesh information",
    callback        =>  sub { $host_info->get_meshes(@_); }
    );

$router->add_method($meshes_method);

$router->handle_request();

# vim: expandtab shiftwidth=4 tabstop=4
