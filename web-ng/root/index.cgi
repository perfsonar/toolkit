#!/usr/bin/perl

use strict;
use warnings;
use CGI qw( url );
use Log::Log4perl qw(get_logger :easy :levels);
use Template;
#use POSIX;
use Data::Dumper;
#use FindBin qw($RealBin);

# Set some variable to control the page layout
my $include_prefix = '';
my $sidebar = 1;

#my $basedir = "$RealBin/../../..";

#use lib "$RealBin/../../../../lib";

my $cgi = CGI->new();

my $remote_user = $cgi->remote_user();
my $auth_type = '';

if($cgi->auth_type()){
    $auth_type = $cgi->auth_type();
}
my $authenticated = 0;
$authenticated = 1 if ($auth_type ne '');

my $full_url = url( -path=>1, -query=>1);
my $https_url = $full_url;
#if (!$full_url =~ /^https/) {
    $https_url =~ s/^http:/https:/i;
#}

print $cgi->header('text/html');

my $tt = Template->new({
        INCLUDE_PATH => '/opt/perfsonar_ps/toolkit/web-ng/templates/'
    }) || die "$Template::ERROR\n";


my $page = 'components/dashboard.html';
my $css = [ $include_prefix . 'css/toolkit.css' ];
my $js_files = [ 
    $include_prefix . 'js/pubsub/jquery.pubsub.js', 
    $include_prefix . 'js/actions/Dispatcher.js', 
    $include_prefix . 'js/shared/SharedUIFunctions.js', 
    $include_prefix . 'js/stores/HostDetailsStore.js', 
    $include_prefix . 'js/stores/HostServicesStore.js', 
    #$include_prefix . 'js/stores/HostAdminInfoStore.js',  # TODO: Remove entirely
    $include_prefix . 'js/stores/HostMetadataStore.js', 
    $include_prefix . 'js/stores/HostNTPInfoStore.js', 
    $include_prefix . 'js/stores/HostHealthStore.js', 
    #$include_prefix . 'js/stores/HostStore.js', 
    $include_prefix . 'js/stores/TestStore.js', 
    $include_prefix . 'js/handlebars/handlebars.js', 
    '/serviceTest/JS/d3.min.js', # TODO: fix to better relative URL
    '/serviceTest/JS/TestResultUtils.js', # TODO: fix to better relative URL
    $include_prefix . 'js/components/HostInfoComponent.js', 
    $include_prefix . 'js/components/HostStatusSidebarComponent.js', 
    $include_prefix . 'js/components/HostServicesComponent.js', 
    $include_prefix . 'js/components/TestResultsComponent.js',
    $include_prefix . 'js/pages/DashboardPage.js'
    ];

my $vars = {};
$vars->{'page'} = $page;
$vars->{'css'} = $css;
$vars->{'js_files'} = $js_files;
$vars->{'authenticated'} = $authenticated;
$vars->{'remote_user'} = $remote_user;
$vars->{'https_url'} = $https_url;
$vars->{'include_prefix'} = $include_prefix;
$vars->{'sidebar'} = $sidebar;

$tt->process('page.html', $vars) || die $tt->error(), "\n";

