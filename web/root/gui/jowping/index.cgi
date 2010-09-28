#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use Template;
use Log::Log4perl qw(get_logger :easy :levels);
use Config::General;

use FindBin qw($RealBin);

my $basedir = "$RealBin/";

use lib "$RealBin/../../../../lib";

use perfSONAR_PS::NPToolkit::Config::ExternalAddress;

#my $config_file = $basedir . '/etc/web_admin.conf';
#my $conf_obj = Config::General->new( -ConfigFile => $config_file );
#our %conf = $conf_obj->getall;

#if ( $conf{logger_conf} ) {
#    unless ( $conf{logger_conf} =~ /^\// ) {
#        $conf{logger_conf} = $basedir . "/etc/" . $conf{logger_conf};
#    }
#
#    Log::Log4perl->init( $conf{logger_conf} );
#}
#else {
#
#    # If they've not specified a logger, send it all to /dev/null
#    Log::Log4perl->easy_init( { level => $DEBUG, file => "/dev/null" } );
#}
#
#our $logger = get_logger( "perfSONAR_PS::JOWPing" );
#if ( $conf{debug} ) {
#    $logger->level( $DEBUG );
#}

my $cgi = CGI->new;

my $script_url = $cgi->url(-full=>1);
my $script_name = $cgi->url(-relative=>1);

#$logger->info("SCRIPT URL: ".$script_url."\n");
#$logger->info("SCRIPT NAME: ".$script_name."\n");

my $codebase_url = $script_url;
$codebase_url =~ s/$script_name//;

my $port = 861;

my $owampd_address;

my $addr_conf = perfSONAR_PS::NPToolkit::Config::ExternalAddress->new();
my $res = $addr_conf->init();
if ($res == 0) {
	my $external_address = $addr_conf->get_primary_address();
	if ($external_address) {
		$owampd_address = $external_address.":".$port;
		if ($codebase_url =~ /localhost/) {
			$codebase_url =~ s/localhost/$external_address/g;
		}
		if ($codebase_url =~ /127.0.0.1/) {
			$codebase_url =~ s/127.0.0.1/$external_address/g;
		}
	}
}

my $output;

my %vars = (
	owampd_address => $owampd_address,
	codebase_url   => $codebase_url,
);

my $tt = Template->new( INCLUDE_PATH => '.' ) or die( "Couldn't initialize template toolkit" );

$tt->process( "jowping_jnlp.tmpl", \%vars, \$output ) or die $tt->error();

print "Content-type: application/x-java-jnlp-file\n";
print "Content-Disposition:attachment;filename=JOWPing.jnlp\n\n";

print $output;

exit 0;
