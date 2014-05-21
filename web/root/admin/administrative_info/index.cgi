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

use FindBin qw($RealBin);

my $basedir = "$RealBin/";

use lib "$RealBin/../../../../lib";

use perfSONAR_PS::NPToolkit::Config::AdministrativeInfo;
use perfSONAR_PS::NPToolkit::Config::ExternalAddress;
use perfSONAR_PS::Utils::GeoIp qw(ipToLatLong);
use perfSONAR_PS::Client::gLS::Keywords;
use perfSONAR_PS::Web::Sidebar qw(set_sidebar_vars);

my $config_file = $basedir . '/etc/web_admin.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our $warning_class = "warning";
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

our $logger = get_logger( "perfSONAR_PS::WebAdmin::AdministrativeInfo" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my $cgi = CGI->new();
our $session;

if ( $cgi->param( "session_id" ) ) {
    $session = CGI::Session->new( "driver:File;serializer:Storable", $cgi->param( "session_id" ), { Directory => $conf{sessions_directory} } );
}
else {
    $session = CGI::Session->new( "driver:File;serializer:Storable", $cgi, { Directory => $conf{sessions_directory} } );
}

die( "Couldn't instantiate session: " . CGI::Session->errstr() ) unless ( $session );

our ( $administrative_info_conf, $status_msg, $error_msg, $is_modified, $initial_state_time );
if ( $session and not $session->is_expired and $session->param( "administrative_info_conf" ) ) {
    $administrative_info_conf = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new( { saved_state => $session->param( "administrative_info_conf" ) } );
    $is_modified   = $session->param( "is_modified" );
    $initial_state_time = $session->param( "initial_state_time" );
    $logger->debug( "Restoring administrative_info_conf object" );
}
else {
    $logger->debug( "Reverting administrative_info_conf object" );
    reset_state();
    save_state();
}

if ($administrative_info_conf->last_modified() > $initial_state_time) {
    reset_state();
    save_state();
    $status_msg = "The on-disk configuration has changed. Any changes you made have been lost.";

    my $html = display_body();

    print "Content-Type: text/html\n\n";
    print $html;
    exit 0;
}

my $ajax = CGI::Ajax->new(
    'save_config'  => \&save_config,
    'reset_config' => \&reset_config,

    'set_host_information'   => \&set_host_information,

    'add_keyword'    => \&add_keyword,
    'delete_keyword' => \&delete_keyword,
);

my ( $header, $footer );
my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

my %vars = ();

$vars{self_url}   = $cgi->self_url();
$vars{session_id} = $session->id();

fill_variables( \%vars );

my $html;

$tt->process( "full_page.tmpl", \%vars, \$html ) or die $tt->error();

print $ajax->build_html( $cgi, $html, { '-Expires' => '-1d' } );

sub display_body {
my %vars = ();

fill_variables( \%vars );

my $html;

my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );
$tt->process( "body.tmpl", \%vars, \$html ) or die $tt->error();

return $html;
}

sub fill_variables {
    my ( $vars ) = @_;

    my @vars_keywords = ();
    my $known_keywords_age;

    my $keyword_client = perfSONAR_PS::Client::gLS::Keywords->new( { cache_directory => $conf{cache_directory} } );

    my ($status, $res) = $keyword_client->get_keywords();
    if ( $status == 0) {
        $logger->debug("Got keywords: ".Dumper($res));

        $known_keywords_age = "$res->{time}";

        my $popular_keywords = $res->{keywords};

        my $keywords = $administrative_info_conf->get_keywords();

        foreach my $keyword ( @$keywords ) {

            # Get rid of any used keywords
            $keyword = "project:" . $keyword unless ( $keyword =~ /^project:/ );

            delete( $popular_keywords->{$keyword} ) if ( $popular_keywords->{$keyword} );
        }
        $logger->debug( Dumper( $popular_keywords ) );

        my @frequencies = sort { $popular_keywords->{$b} <=> $popular_keywords->{$a} } keys %$popular_keywords;

        my $max = $popular_keywords->{ $frequencies[0] };
        my $min = $popular_keywords->{ $frequencies[$#frequencies] };

        foreach my $keyword ( sort { lc($a) cmp lc($b) } keys %$popular_keywords ) {
            next unless ( $keyword =~ /^project:/ );

            my $class;

            if ( $max == $min ) {
                $class = 1;
            }
            else {

                # 10 steps maximum
                $class = 1 + int( 9 * ( $popular_keywords->{$keyword} - $min ) / ( $max - $min ) );
            }

            my $display_keyword = $keyword;
            $display_keyword =~ s/^project://g;

            my %keyword_info = ();
            $keyword_info{keyword} = $display_keyword;
            $keyword_info{class}   = $class;
            push @vars_keywords, \%keyword_info;
        }
    }
    $vars->{known_keywords} = \@vars_keywords;
    $vars->{known_keywords_check_time} = $known_keywords_age;

    $vars->{organization_name}   = $administrative_info_conf->get_organization_name();
    set_error_variables( $vars, 'organization_name' );
    $vars->{administrator_name}  = $administrative_info_conf->get_administrator_name();
    set_error_variables( $vars, 'administrator_name' );
    $vars->{administrator_email} = $administrative_info_conf->get_administrator_email();
    set_error_variables( $vars, 'administrator_email' );
    $vars->{location}            = $administrative_info_conf->get_location();
    set_error_variables( $vars, 'location' );
    $vars->{city}            = $administrative_info_conf->get_city();
    set_error_variables( $vars, 'city' );
    $vars->{state}            = $administrative_info_conf->get_state();
    set_error_variables( $vars, 'state' );
    $vars->{country}            = $administrative_info_conf->get_country();
    set_error_variables( $vars, 'country' );
    $vars->{zipcode}            = $administrative_info_conf->get_zipcode();
    set_error_variables( $vars, 'zipcode' );
    $vars->{latitude}            = $administrative_info_conf->get_latitude();
    set_error_variables( $vars, 'latitude' );
    $vars->{longitude}            = $administrative_info_conf->get_longitude();
    set_error_variables( $vars, 'longitude' );

    #if latitude and longitude are empty then populate lat,long using geoip
    if((!$vars->{latitude} || $vars->{latitude} eq "") && (!$vars->{longitude} || $vars->{longitude} eq "")){
        my $address_conf = perfSONAR_PS::NPToolkit::Config::ExternalAddress->new();
        $address_conf->init();
        my $ip = $address_conf->get_primary_address();
        my $res = ipToLatLong($ip);

        if($res->{longitude} && $res->{latitude} ){
            $vars->{longitude} = $res->{longitude};
            $vars->{latitude} = $res->{latitude};
        }

    }

    my $keywords         = $administrative_info_conf->get_keywords();
    my @display_keywords = ();
    if ( $keywords ) {
        foreach my $keyword ( sort @{$keywords} ) {
            push @display_keywords, $keyword;
        }
    }
    $vars->{is_modified}         = $is_modified;
    $vars->{configured_keywords} = \@display_keywords;
    $vars->{status_message}      = $status_msg;
    $vars->{error_message}       = $error_msg;

    if (!$administrative_info_conf->is_complete()) {
        $vars->{warning_message}  = "IMPORTANT - Some elements on this page are not completed. Please complete the fields highlighted below.";
    }

    set_sidebar_vars( { vars => $vars } );

    return 0;
}

# Helper function for set_error_variables, in case we want to have 
# different displays based on whether a field has a value
sub set_error_variables {
    my ($vars, $field_name) = @_;

    my $required_indicator = '<span class="' . $warning_class . '"> * </span>';
    $vars->{"${field_name}_class"} = $warning_class if ($administrative_info_conf->field_empty( { field_name => $field_name}) );
    $vars->{"${field_name}_required"} = $required_indicator if ($administrative_info_conf->field_empty( { field_name => $field_name}) );
    $vars->{required_indicator} = $required_indicator;
}

sub set_host_information  {
    my ( $organization_name, $host_location, $city, $state, $country, $zipcode, $administrator_name, $administrator_email, $latitude, $longitude, $subscribe ) = @_;

    $administrative_info_conf->set_organization_name( { organization_name => $organization_name } );
    $administrative_info_conf->set_city( { city => $city } );
    $administrative_info_conf->set_state( { state => $state } );
    $administrative_info_conf->set_country( { country => $country } );
    $administrative_info_conf->set_zipcode( { zipcode => $zipcode } );
    $administrative_info_conf->set_latitude( { latitude => $latitude } );
    $administrative_info_conf->set_longitude( { longitude => $longitude } );
    $administrative_info_conf->set_administrator_name( { administrator_name => $administrator_name } );
    $administrative_info_conf->set_administrator_email( { administrator_email => $administrator_email } );


    if($administrator_email && $subscribe eq "true"){
        subscribe($administrator_email);
    }
    $is_modified = 1;

    save_state();

    $status_msg = "Host information updated. NOTE: You must click the Save button to save your changes.";
    return display_body();
}

sub add_keyword {
    my ( $value ) = @_;
    $administrative_info_conf->add_keyword( { keyword => $value } );
    $is_modified = 1;

    save_state();

    $status_msg = "Keyword $value added";
    return display_body();
}

sub delete_keyword {
    my ( $value ) = @_;
    $administrative_info_conf->delete_keyword( { keyword => $value } );

    $is_modified = 1;
    save_state();

    $status_msg = "Keyword $value deleted";
    return display_body();
}

sub subscribe{
    my ($value) = @_;
    #my $email = $administrative_info_conf->get_administrator_email();
    print "came here";
    my $sendmail = "/usr/sbin/sendmail -t";
    if($value){
        open(SENDMAIL, "| $sendmail");
        my $subject = "Subject: Do not reply. NP Toolkit user list subscription\n";
        my $content = "Please click<a href=\"https://lists.internet2.edu/sympa/subscribe/perfsonar-user\"> NP Toolkit user list</a> to complete the subscription process\n";
        my $send_to = "To: ".$value."\n";
        my $from = "From: admin\n";
        print SENDMAIL $from;
        print SENDMAIL $send_to;
        print SENDMAIL $subject;
        print SENDMAIL "Content-type: text/html\n\n";
        print SENDMAIL $content;
        close(SENDMAIL);
    }
}


sub save_config {
    my ($status, $res) = $administrative_info_conf->save( { restart_services => 1 } );
    if ($status != 0) {
        $error_msg = "Problem saving configuration: $res";
    } else {
        $status_msg = "Configuration Saved And Services Restarted";
        $is_modified = 0;
        $initial_state_time = $administrative_info_conf->last_modified();
    }
    save_state();

    return display_body();
}

sub reset_config {
    reset_state();
    save_state();
    $status_msg = "Configuration Reset";
    return display_body();
}

sub reset_state {
    $administrative_info_conf = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new();
    my $res = $administrative_info_conf->init( { administrative_info_file => $conf{administrative_info_file} } );
    if ( $res != 0 ) {
        die( "Couldn't initialize Administrative Info Configuration" );
    }
    $is_modified = 0;
    $initial_state_time = $administrative_info_conf->last_modified();
}

sub save_state {
    my $state = $administrative_info_conf->save_state();
    $session->param( "administrative_info_conf", $state );
    $session->param( "is_modified", $is_modified );
    $session->param( "initial_state_time", $initial_state_time );
}



1;

