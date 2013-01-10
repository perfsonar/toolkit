#!/usr/bin/perl -w

use strict;
use warnings;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Ajax;
use Template;
use Data::Dumper;
use Config::General;
use Log::Log4perl qw(get_logger :easy :levels);
use LWP::UserAgent;
use Crypt::SSLeay;
use Digest::MD5 qw(md5_hex);

use FindBin qw($RealBin);

my $basedir = "$RealBin/";

use lib "$RealBin/../../../../lib";

use lib "$RealBin/lib";

use perfSONAR_PS::NPToolkit::WebAdmin::MaDDash;

my $config_file = $basedir . '/etc/web_admin.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our %conf = $conf_obj->getall;

$conf{sessions_directory} = "/tmp" unless ( $conf{sessions_directory} );
$conf{sessions_directory} = $basedir . "/" . $conf{sessions_directory} unless ( $conf{sessions_directory} =~ /^\// );

$conf{template_directory} = "templates" unless ( $conf{template_directory} );
$conf{template_directory} = $basedir . "/" . $conf{template_directory} unless ( $conf{template_directory} =~ /^\// );

#if ( $conf{logger_conf} ) {
#    unless ( $conf{logger_conf} =~ /^\// ) {
#        $conf{logger_conf} = $basedir . "/etc/" . $conf{logger_conf};
#    }
#
#    Log::Log4perl->init( $conf{logger_conf} );
#}
#else {

    # If they've not specified a logger, send it all to /dev/null
    #Log::Log4perl->easy_init( { level => $DEBUG, file => "/dev/null" } );
    Log::Log4perl->easy_init( { level => $DEBUG } );
#}

our $logger = get_logger( "perfSONAR_PS::WebAdmin::MaDDash" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my $cgi = CGI->new();

my ( $status_msg, $error_msg );

my $maddash_client = perfSONAR_PS::NPToolkit::WebAdmin::MaDDash->new({ maddash_url => $conf{maddash_url} });

#get_check("/maddash/grids/Internet2+mesh+-+Internet2+IPv4+Latency/64.57.16.162/64.57.16.226/Loss");
#get_grid("/maddash/grids/Internet2+mesh+-+Internet2+IPv4+Latency", "json");
#print get_dashboards("Internet2 mesh");
#print get_dashboard("ed25d2f6ebb32c3365fafa8ef4de2097");
#die("argh");

my $ajax = CGI::Ajax->new(
    'get_dashboards' => \&get_dashboards,
    'get_dashboard'  => \&get_dashboard,
    'get_grid'       => \&get_grid,
    'get_check'      => \&get_check,
);

my ( $header, $footer );
my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

my $content = get_dashboards();

my $html;

$tt->process( "full_page.tmpl", { content => $content }, \$html ) or die $tt->error();

print $ajax->build_html( $cgi, $html );

exit 0;

sub get_dashboards {
    my $error_msg;
    my @dashboards = ();

    my $dashboards = $maddash_client->get_dashboards();
    unless ($dashboards) {
        $error_msg = "Problem loading dashboards";
    }
    else {
        $error_msg = "";
        @dashboards = @{ $dashboards->{dashboards} };
        foreach my $dashboard (@dashboards) {
            $dashboard->{id} = md5_hex($dashboard->{name});
        }
    }

    my $vars = {
                   error_message => $error_msg,
                   dashboards    => \@dashboards,
                   self_url      => $cgi->self_url(),
               };

    my $html;

    #print Dumper($vars);

    my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );
    $tt->process( "dashboards.tmpl", $vars, \$html ) or die $tt->error();

    return $html;
}

sub get_dashboard {
    my ( $id ) = @_;

    my ($error_msg, $dashboard);

    my $dashboards = $maddash_client->get_dashboards();
    unless ($dashboards) {
        $error_msg = "Problem loading dashboard";
    }
    else {
        $error_msg = "";
        foreach my $curr_dashboard (@{ $dashboards->{dashboards} }) {
            $curr_dashboard->{id} = md5_hex($curr_dashboard->{name});
            $dashboard = $curr_dashboard if ($curr_dashboard->{id} eq $id);
        }

        unless ($dashboard) {
            $error_msg = "Couldn't find dashboard: ".$id;
        }
        else {
            my @grids = ();
            foreach my $grid (@{ $dashboard->{grids} }) {
                my $full_grid = $maddash_client->get_grid({ uri => $grid->{uri} });
                if ($full_grid) {
                    $full_grid->{uri} = $grid->{uri};
                    push @grids, $full_grid;
                }
                else {
                    push @grids, { error_msg => "Problem loading grid: ".$grid->{name} };
                }
                $dashboard->{grids} = \@grids;
            }
        }
    }

    my $vars = {
                   error_message => $error_msg,
                   dashboard     => $dashboard,
               };

    my $html;

    my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );
    $tt->process( "dashboard.tmpl", $vars, \$html ) or die $tt->error();

    return $html;
}

sub get_check {
    my ( $uri, $format ) = @_;
    my $error_msg;
    my @dashboards = ();

    my $check = $maddash_client->get_check({ uri => $uri });
    unless ($check) {
        $error_msg = "Problem loading check";
    }
    else {
        $error_msg = "";
    }

    # Fill out the 'key' parameters in the historical checks, and include the checked start and end times (roughly)
    if ($check->{history}) {
        my $time_range; 
        my $nagios_cmd = $check->{params}->{command};

        if ($nagios_cmd and $nagios_cmd =~ /-r ([0-9]+)/) {
            $time_range = $1;
        }

        foreach my $historical_check (@{ $check->{history} }) {
            my $graphUrl = $historical_check->{returnParams}->{graphUrl};
            my $key;
            if ($graphUrl =~ /key=([^&]*)/) {
                $key = $1;
            }

            $historical_check->{returnParams}->{key} = $key;
            if ($time_range) {
                $historical_check->{returnParams}->{check_start_time} = $historical_check->{time} - $time_range;
            }

            $historical_check->{returnParams}->{check_end_time} = $historical_check->{time};

            $historical_check->{returnParams}->{graphUrl} =~ s/length=[0-9]+(&?)//;
            $historical_check->{returnParams}->{graphUrl} =~ s/keyR=[^&]*//;

            $historical_check->{returnParams}->{graphUrl} =~ s/.*((delayGraph.cgi|bandwidthGraph.cgi).*)/$1/g;
            unless ($historical_check->{returnParams}->{graphUrl} =~ /bucket_width=/) {
                $historical_check->{returnParams}->{graphUrl} .= "&bucket_width=0.0001"; # the most likely bucket width
            }
        }
    }

    if (not $format or $format eq "html") {
        my $vars = {
                       error_message => $error_msg,
                       check         => $check,
                   };

        return render($vars, "html", "check.tmpl");
    }
    else {
        return render($check, $format);
    }
}

sub get_grid {
    my ( $uri, $format ) = @_;
    my $error_msg;
    my @dashboards = ();

    my $grid = $maddash_client->get_grid({ uri => $uri });
    unless ($grid) {
        $error_msg = "Problem loading check";
    }
    else {
        $error_msg = "";
    }

    if ($format eq "html") {
        my $vars = {
                       error_message => $error_msg,
                       grid          => $grid,
                   };

        return render($vars, "html", "grid.tmpl");
    }
    else {
        return render($grid, $format);
    }
}

sub render {
    my ($vars, $format, $template) = @_;

    if ($format eq "html" ) {
        my $html;

        my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );
        $tt->process( $template, $vars, \$html ) or die $tt->error();

        return $html;
    }
    elsif ($format eq "json") {
        return JSON->new->encode($vars);
    }

    die("Unknown render format: ".$format);
}

1;
