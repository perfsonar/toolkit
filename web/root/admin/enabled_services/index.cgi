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

use perfSONAR_PS::NPToolkit::Config::Services;

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

#$tt->process( "header.tmpl", \%vars, \$header ) or die $tt->error();
#$tt->process( "footer.tmpl", \%vars, \$footer ) or die $tt->error();

	my %vars = ();

	$vars{self_url}   = $cgi->self_url();

	fill_variables( \%vars );

	my $html;

	$tt->process( "full_page.tmpl", \%vars, \$html ) or die $tt->error();

	print "Content-type: text/html\n\n";
	print $html;

}

sub fill_variables {
    my $vars = shift;

    my $services_conf = perfSONAR_PS::NPToolkit::Config::Services->new();
    my $res = $services_conf->init( { enabled_services_file => $conf{enabled_services_file} } );
    if ( $res != 0 ) {
        $vars->{error_message}  = "Couldn't initialize Services Configuration";
    } else {
	    my $services = $services_conf->get_services();

	    my %vars_services = ();
	    foreach my $key ( keys %{$services} ) {
		    my $service = $services->{$key};

		    my %service_desc = ();
		    $service_desc{name}        = $service->{name};
		    $service_desc{description} = $service->{description};
		    $service_desc{enabled}     = $service->{enabled};
		    $service_desc{system}      = $service->{system}?1:0;

		    $vars_services{ $service->{name} } = \%service_desc;
	    }

	    $vars->{services}       = \%vars_services;
    }

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

    my $services_conf = perfSONAR_PS::NPToolkit::Config::Services->new();
    $res = $services_conf->init( { enabled_services_file => $conf{enabled_services_file} } );
    if ( $res != 0 ) {
        my %resp = ( error => "Couldn't initialize Services Configuration" );
	print "Content-type: text/json\n\n";
	print encode_json(\%resp);
	return;
    }

    foreach my $name (keys %$params) {
    	unless ($services_conf->lookup_service({ name => $name })) {
            $logger->error("Service $name not found");
            next;
        }

	if ($params->{$name} eq "off") {
		$services_conf->disable_service({ name => $name});
	} else {
		$services_conf->enable_service({ name => $name});
	}
    }

    ($status, $res) = $services_conf->save( { restart_services => 1 } );
    if ($status != 0) {
        my %resp = ( error => "Couldn't save Services Configuration: $res" );
	print "Content-type: text/json\n\n";
	print encode_json(\%resp);
	return;
    }

    my %resp = ( message => "Configuration Saved And Services Restarted" );
    print "Content-type: text/json\n\n";
    print encode_json(\%resp);
}

sub reset_config {
    my $services_conf = perfSONAR_PS::NPToolkit::Config::Services->new();
    my $res = $services_conf->init( { enabled_services_file => $conf{enabled_services_file} } );
    if ( $res != 0 ) {
        my %resp = ( error => "Couldn't initialize Services Configuration" );
	print "Content-type: text/json\n\n";
	print encode_json(\%resp);
    }

    my $services = $services_conf->get_services();
    my %service_list = ();
    foreach my $name (keys %$services) {
	    $service_list{$name} = $services->{$name}->{enabled};
    }

    my %resp = ( services => \%service_list );

    print "Content-type: text/json\n\n";
    print encode_json(\%resp);

    $logger->debug("JSON: ".encode_json(\%resp));
}

1;
