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

use perfSONAR_PS::NPToolkit::WebService::ParameterTypes qw($parameter_types);

use perfSONAR_PS::NPToolkit::DataService::Communities;
use perfSONAR_PS::NPToolkit::WebService::Method;
use perfSONAR_PS::NPToolkit::WebService::Router;

use Config::General;

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
my $communities_info = perfSONAR_PS::NPToolkit::DataService::Communities->new( { 'config_file' => $config_file  } );

my $router = perfSONAR_PS::NPToolkit::WebService::Router->new();

my $all_communities_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_all_communities",
    description     =>  "Retrieves all communities",
    callback        =>  sub { $communities_info->get_all_communities(@_); }
    );

$router->add_method($all_communities_method);

my $host_communities_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_host_communities",
    description     =>  "Retrieves host community information",
    callback        =>  sub { $communities_info->get_host_communities(@_); }
    );

$router->add_method($host_communities_method);

my %input_parameters=();

$input_parameters{'community'}{'required'}=1;
$input_parameters{'community'}{'type'}=$parameter_types->{'text'};

my $min_parameters = 1;
my $add_host_community_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "add_host_communities",
    description     =>  "Add a host community",
    auth_required   => 1,
    callback        =>  sub { $communities_info->add_host_communities(@_); },
    input_params    => \%input_parameters,
    min_params      => $min_parameters
    );

$router->add_method($add_host_community_method);

my $remove_host_community_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "remove_host_communities",
    description     =>  "Remove a host community",
    auth_required   => 1,
    callback        =>  sub { $communities_info->remove_host_communities(@_); },
    input_params    => \%input_parameters,
    min_params      => $min_parameters
    );

$router->add_method($remove_host_community_method);

$router->handle_request();

# vim: expandtab shiftwidth=4 tabstop=4
