#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( {level => 'OFF'} );

use Test::More tests => 9;

use Config::General;
use Data::Dumper;

use perfSONAR_PS::NPToolkit::DataService::Host;

my $basedir = 't';
my $config_file = $basedir . '/etc/web_admin.conf';
my $ls_file = $basedir . '/etc/lsregistrationdaemon.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
my %conf = $conf_obj->getall;

my $data;
my $params = {};
$params->{'config_file'} = $config_file;
$params->{'load_ls_registration'} = 1;
$params->{'ls_config_file'} = $ls_file;

my $info = perfSONAR_PS::NPToolkit::DataService::Host->new( $params );

$data = $info->get_admin_information();

# check the administrative info
is ( $data->{'administrator'}->{'name'}, 'Node Admin', 'Administrator Name' );
is ( $data->{'administrator'}->{'organization'}, 'Test Org', 'Organization' );
is ( $data->{'administrator'}->{'email'}, 'admin@test.com', 'E-mail address' );

# check the location
is ( $data->{'location'}->{'country'}, 'US', 'Country' );
is ( $data->{'location'}->{'city'}, 'Bloomington', 'City' );
is ( $data->{'location'}->{'state'}, 'IN', 'State' );
is ( $data->{'location'}->{'zipcode'}, '47401', 'Zip Code' );
is ( $data->{'location'}->{'longitude'}, '-28.23', 'Longitude' );
is ( $data->{'location'}->{'latitude'}, '123.456', 'Longitude' );

