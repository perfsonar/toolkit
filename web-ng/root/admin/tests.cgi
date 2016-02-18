#!/usr/bin/perl

use strict;
use warnings;
use CGI qw( url );
use Log::Log4perl qw(get_logger :easy :levels);
use Template;
use Data::Dumper;

# Set some variable to control the page layout
my $include_prefix = '../';
my $sidebar = 0;

use FindBin qw($RealBin);
my $basedir = "$RealBin/../../..";
use lib "$RealBin/../../../lib";

use perfSONAR_PS::NPToolkit::WebService::Auth qw( is_authenticated unauthorized_output );


my $cgi = CGI->new();

my $section = 'tests';
my $remote_user = $cgi->remote_user();
my $auth_type = '';

if($cgi->auth_type()){
    $auth_type = $cgi->auth_type();
}
my $authenticated = is_authenticated($cgi);

if ( !$authenticated ) {
    print unauthorized_output($cgi);
    exit;
}

my $full_url = url( -path=>1, -query=>1);
my $https_url = $full_url;
#if (!$full_url =~ /^https/) {
    $https_url =~ s/^http:/https:/i;
#}

print $cgi->header(-type=>'text/html', -charset=>'utf-8');

my $tt = Template->new({
        INCLUDE_PATH => '/usr/lib/perfsonar/web-ng/templates/'
    }) || die "$Template::ERROR\n";

my $page = 'admin/pages/tests.html';
my $css = [ $include_prefix . 'css/toolkit.css' ];
my $js_files = [ 
    $include_prefix . 'js/pubsub/jquery.pubsub.js', 
    $include_prefix . 'js/actions/Dispatcher.js', 
    $include_prefix . 'js/stores/DataStore.js', 
    $include_prefix . 'js/stores/TestConfigStore.js', 
    $include_prefix . 'js/stores/TestConfigAdminStore.js', 
    $include_prefix . 'js/stores/HostDetailsStore.js', 
    $include_prefix . 'js/handlebars/handlebars.js', 
    '/perfsonar-graphs/JS/d3.min.js', # TODO: fix to better relative URL
    '/perfsonar-graphs/JS/TestResultUtils.js', # TODO: fix to better relative URL
    $include_prefix . 'js/shared/SharedUIFunctions.js', 
    $include_prefix . 'js/admin/components/StickySaveBar.js', 
    $include_prefix . 'js/components/PageHeader.js', 
    $include_prefix . 'js/admin/components/TestConfigComponent.js', 
    $include_prefix . 'js/admin/pages/TestConfigPage.js'
    ];

my $vars = {};
$vars->{'page'} = $page;
$vars->{'section'} = $section;
$vars->{'css'} = $css;
$vars->{'js_files'} = $js_files;
$vars->{'authenticated'} = $authenticated;
$vars->{'remote_user'} = $remote_user;
$vars->{'https_url'} = $https_url;
$vars->{'include_prefix'} = $include_prefix;

$tt->process('page.html', $vars) || die $tt->error(), "\n";

