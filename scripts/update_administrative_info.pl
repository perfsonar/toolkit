#!/usr/bin/perl -w

use strict;
use FindBin qw($RealBin);

my $basedir = "$RealBin/";

use lib "$RealBin/../lib";

use perfSONAR_PS::NPToolkit::Config::AdministrativeInfo;

my $administrative_info_conf = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new();
$administrative_info_conf->init();
$administrative_info_conf->save( { restart_services => 0 } );