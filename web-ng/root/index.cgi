#!/usr/bin/perl

use strict;
use warnings;
use CGI qw( url );
use Log::Log4perl qw(get_logger :easy :levels);
use Template;
#use POSIX;
use Data::Dumper;
#use FindBin qw($RealBin);

#my $basedir = "$RealBin/../../..";

#use lib "$RealBin/../../../../lib";

my $cgi = CGI->new();

my $remote_user = $cgi->remote_user();
my $auth_type = $cgi->auth_type();
my $authenticated = 0;
$authenticated = 1 if ($auth_type ne '');

my $full_url = url( -path=>1, -query=>1);
my $https_url = $full_url;
#if (!$full_url =~ /^https/) {
    $https_url =~ s/^http:/https:/i;
#}

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
    '/serviceTest/JS/d3.min.js', # TODO: fix to better relative URL
    '/serviceTest/JS/TestResultUtils.js', # TODO: fix to better relative URL
    'js/components/HostInfoComponent.js', 
    'js/components/HostStatusSidebarComponent.js', 
    'js/components/HostServicesComponent.js', 
    'js/components/TestResultsComponent.js',
    'js/pages/DashboardPage.js'
    ];

my $vars = {};
$vars->{'page'} = $page;
$vars->{'css'} = $css;
$vars->{'js_files'} = $js_files;
$vars->{'authenticated'} = $authenticated;
$vars->{'remote_user'} = $remote_user;
$vars->{'https_url'} = $https_url;
$tt->process('page.html', $vars) || die $tt->error(), "\n";

