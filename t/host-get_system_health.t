#!/usr/bin/perl
# This test checks the values returned for the get_system_health call
# First, it calls the function as an unauthenticated user and
# makes sure that no information is disclosed that should be private.
# Then, it calls the function as an authenticated user and verifies
# that the correct addition fields are present.
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( {level => 'OFF'} );

use Test::More tests => 18;

use Config::General;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

use perfSONAR_PS::NPToolkit::DataService::Host;
use perfSONAR_PS::NPToolkit::UnitTests::Router;
use perfSONAR_PS::NPToolkit::UnitTests::Util qw( positive_number nonnegative_number );

my $basedir = 't';
my $config_file = $basedir . '/etc/web_admin.conf';
my $ls_file = $basedir . '/etc/lsregistrationdaemon.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
my %conf = $conf_obj->getall;

my $router = perfSONAR_PS::NPToolkit::UnitTests::Router->new( { authenticated => 0 } );

isa_ok( $router, 'perfSONAR_PS::NPToolkit::UnitTests::Router' );

my $data;
my $params = {};
$params->{'config_file'} = $config_file;

my $info = perfSONAR_PS::NPToolkit::DataService::Host->new( $params );

isa_ok( $info, 'perfSONAR_PS::NPToolkit::DataService::Host' );

# This first call with not be authenticated
$data = $router->call_method( { method => sub { $info->get_system_health(@_); } } );

#warn "data: " . Dumper $data;

ok( positive_number( $data->{'mem_total'} ), 'Total memory is a positive number');
ok( nonnegative_number ( $data->{'swap_total'} ), 'Swap memory is a positive number');
ok( positive_number ( $data->{'rootfs'}->{'total'} ), 'Root FS total space is a positive number');


# make sure these values are NOT defined, since we aren't authenticated

is( $data->{'mem_used'}, undef, "Used mememory not disclosed to unauthenticated users");
is( $data->{'rootfs'}->{'used'}, undef, "Used root FS space not disclosed to unauthenticated users");
is( $data->{'cpu_util'}, undef, "CPU utilization not disclosed to unauthenticated users");
is( $data->{'load_avg'}, undef, "Load average not disclosed to unauthenticated users");



# Set the router to authenticated
$router->set_authenticated( { authenticated => 1 } );

# This call to get_system_health should be authenticated and should
# return more values
$data = $router->call_method( { method => sub { $info->get_system_health(@_); } } );

#warn "data: " . Dumper $data;

# Check public values
ok( positive_number( $data->{'mem_total'} ), 'Total memory is a positive number');
ok( nonnegative_number ( $data->{'swap_total'} ), 'Swap memory is a positive number');
ok( positive_number ( $data->{'rootfs'}->{'total'} ), 'Root FS total space is a positive number');

# Check private values (which we should now have, since we're authenticated)
ok( positive_number( $data->{'mem_used'} ), 'Used memory is a positive number');
ok( positive_number( $data->{'rootfs'}->{'used'} ), 'Used root FS space is a positive number');
ok( nonnegative_number( $data->{'cpu_util'} ), 'CPU utilization is a number');
ok( nonnegative_number( $data->{'load_avg'}->{'avg_15'} ), 'Load average (15 minute) is a positive number');
ok( nonnegative_number( $data->{'load_avg'}->{'avg_5'} ), 'Load average (5 minute) is a positive number');
ok( nonnegative_number( $data->{'load_avg'}->{'avg_1'} ), 'Load average (1 minute) is a positive number');

