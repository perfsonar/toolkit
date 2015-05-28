#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use Log::Log4perl qw(get_logger :easy :levels);
use Template;
#use POSIX;
use Data::Dumper;
#use FindBin qw($RealBin);

#my $basedir = "$RealBin/../../..";

#use lib "$RealBin/../../../../lib";

my $cgi = CGI->new();

print $cgi->header('text/html');

my $tt = Template->new({
        INCLUDE_PATH => '../templates/'
    }) || die "$Template::ERROR\n";


my $page = 'components/dashboard.html';
my $css = [ 'css/toolkit.css' ];
my $js_files = [ 
    'js/pubsub/jquery.pubsub.js', 
    'js/actions/Dispatcher.js', 
    'js/stores/HostStore.js', 
    'js/stores/TestStore.js', 
    'js/handlebars/handlebars.js', 
    'js/components/HostInfoComponent.js', 
    'js/components/HostStatusSidebarComponent.js', 
    'js/components/HostServicesComponent.js', 
    'js/components/TestResultsComponent.js' 
    ];

my $vars = {};
$vars->{'page'} = $page;
$vars->{'css'} = $css;
$vars->{'js_files'} = $js_files;

$tt->process('page.html', $vars) || die $tt->error(), "\n";

