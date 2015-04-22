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

my $cgi = CGI->new();

my $info_method = perfSONAR_PS::NPToolkit::WebService::Method->new(
    name            =>  "get_info",
    description     =>  "Retrieves host information",
    callback        =>  sub { $host_info->get_summary(@_); }
    );

my $router = perfSONAR_PS::NPToolkit::WebService::Router->new();
$router->add_method($info_method);
$router->handle_request();

# vim: expandtab shiftwidth=4 tabstop=4
