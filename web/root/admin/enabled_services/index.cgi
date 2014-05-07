#!/usr/bin/perl -w

use strict;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Ajax;
use CGI::Session;
use Template;
use Config::General;
use Log::Log4perl qw(get_logger :easy :levels);
use Net::IP;
use Params::Validate;
use Data::Dumper;
use JSON::XS;

use FindBin qw($RealBin);

my $basedir = "$RealBin/";

use lib "$RealBin/../../../../lib";

use perfSONAR_PS::NPToolkit::Services::ServicesMap qw(get_service_object);
use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw( save_file start_service restart_service stop_service );

use perfSONAR_PS::Web::Sidebar qw(set_sidebar_vars);

my $config_file = $basedir . '/etc/web_admin.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our %conf = $conf_obj->getall;

$conf{sessions_directory} = "/tmp" unless ( $conf{sessions_directory} );
$conf{sessions_directory} = $basedir . "/" . $conf{sessions_directory} unless ( $conf{sessions_directory} =~ /^\// );

$conf{template_directory} = "templates" unless ( $conf{template_directory} );
$conf{template_directory} = $basedir . "/" . $conf{template_directory} unless ( $conf{template_directory} =~ /^\// );

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

our $logger = get_logger( "perfSONAR_PS::WebAdmin::EnabledServices" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my $cgi = CGI->new();

my $function = $cgi->param("fname");
unless ($function) {
    main();
} elsif ($function eq "save_config") {
    save_config();
} elsif ($function eq "reset_config") {
    reset_config();
} else {
    die("Unknown function: $function");
}

exit 0;

sub main {
    my ( $header, $footer );
    my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

    my %vars = ();

    $vars{self_url}   = $cgi->self_url();

    fill_variables( \%vars );    
    set_sidebar_vars( { vars => \%vars } );

    my $html;

    $tt->process( "full_page.tmpl", \%vars, \$html ) or die $tt->error();

    print "Content-type: text/html\n\n";
    print $html;

}

sub fill_variables {
    my $vars = shift;

    my %service_list = ();

    foreach my $service_name ("bwctl", "owamp", "ndt", "npad") {
        my $service = get_service_object($service_name);

        next unless $service;

        $service_list{$service_name}->{enabled} = not $service->disabled;
    }

    $vars->{services} = \%service_list;

    return 0;
}

sub display_body {
    my %vars = ();

    fill_variables( \%vars );

    my $html;

    my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );
    $tt->process( "body.tmpl", \%vars, \$html ) or die $tt->error();

    return $html;
}

sub save_config {
    my $params = $cgi->Vars;

    my ($status, $res);

    $logger->error("CONFIG: ".Dumper($params));

    foreach my $name (keys %$params) {
        unless (get_service_object($name)) {
            $logger->error("Service $name not found");
            next;
        }

        if ($params->{$name} eq "off") {
            stop_service( { name => $name, disable => 1 });
        } else {
            start_service( { name => $name, enable => 1 });
        }
    }

    my %resp = ( message => "Configuration Saved And Services Restarted" );
    print "Content-type: text/json\n\n";
    print encode_json(\%resp);
}

sub reset_config {

    my %service_list = ();

    foreach my $service_name ("bwctl", "owamp", "ndt", "npad") {
        my $service = get_service_object($service_name);

        next unless $service;

        $service_list{$service_name}->{enabled} = not $service->disabled;
    }

    my %resp = ( services => \%service_list );

    print "Content-type: text/json\n\n";
    print encode_json(\%resp);

    $logger->debug("JSON: ".encode_json(\%resp));
}

1;
