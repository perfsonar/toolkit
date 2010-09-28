#!/usr/bin/perl -w

use strict;
use warnings;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Ajax;
use CGI::Session;
use Template;
use Data::Dumper;
use Config::General;
use Log::Log4perl qw(get_logger :easy :levels);
use Net::IP;

use FindBin qw($RealBin);

my $basedir = "$RealBin/";

use lib "$RealBin/../../../../lib";

use perfSONAR_PS::NPToolkit::Config::BWCTL;

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

our $logger = get_logger( "perfSONAR_PS::WebAdmin::BWCTL" );
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

my ( $bwctl_conf, $advanced_mode, $status_msg, $error_msg, $other_changes, $is_modified, $initial_state_time );

if ( $session and not $session->is_expired and $session->param( "bwctl_conf" ) ) {
    $bwctl_conf = perfSONAR_PS::NPToolkit::Config::BWCTL->new( { saved_state => $session->param( "bwctl_conf" ) } );
    $advanced_mode = $session->param( "advanced_mode" );
    $is_modified   = $session->param( "is_modified" );
    $initial_state_time = $session->param( "initial_state_time" );
}
else {
    reset_state();
    save_state();
}

if ($bwctl_conf->last_modified() > $initial_state_time) {
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

    'delete_group'   => \&delete_group,
    'delete_network' => \&delete_network,
    'delete_user'    => \&delete_user,

    'add_group'   => \&add_group,
    'add_network' => \&add_network,
    'add_user'    => \&add_user,

    'update_group'   => \&update_group,
    'update_user'    => \&update_user,
    'update_network' => \&update_network,

    'change_password'      => \&change_password,
    'toggle_advanced_mode' => \&toggle_advanced_mode,

    'download_bwctld_limits' => \&generate_bwctld_limits,
    'download_bwctld_keys'   => \&generate_bwctld_keys,
);

my ( $header, $footer );
my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

#$tt->process( "header.tmpl", \%vars, \$header ) or die $tt->error();
#$tt->process( "footer.tmpl", \%vars, \$footer ) or die $tt->error();

my %vars = ();
$vars{self_url}   = $cgi->self_url();
$vars{session_id} = $session->id();

fill_variables( \%vars );

my $html;

$tt->process( "full_page.tmpl", \%vars, \$html ) or die $tt->error();

print $ajax->build_html( $cgi, $html, { '-Expires' => '1d' } );

exit 0;

sub fill_variables {
    my $vars = shift;

    my $groups = $bwctl_conf->get_groups();

    # When building the groups, check if parents have values set.
    my @vars_groups = ();
    foreach my $group_name ( keys %{$groups} ) {
        my $group = $groups->{$group_name};

        my %group_desc = ();
        $group_desc{id}              = $group_name;
        $group_desc{name}            = $group_name;
        $group_desc{parent}          = $group->{parent} ? $group->{parent} : "";

        foreach my $limit (qw( bandwidth pending event_horizon duration allow_tcp allow_udp max_time_error )) {
            my $limit_value       = $bwctl_conf->lookup_limit({ name => $group_name, limit => $limit, constrained => 0 });
            my $constrained_value       = $bwctl_conf->lookup_limit({ name => $group_name, limit => $limit, constrained => 1 });

            if ($limit_value ne $constrained_value) {
                $group_desc{$limit."_constraint"} = $constrained_value;
            }

            $group_desc{$limit} = $limit_value;
        }

        # allow_open_mode doesn't follow the "parent is more strict that child"
        # hierarchy.
        foreach my $limit (qw( allow_open_mode )) {
            my $limit_value       = $bwctl_conf->lookup_limit({ name => $group_name, limit => $limit, constrained => 0 });

            $group_desc{$limit} = $limit_value;
        }

        push @vars_groups, \%group_desc;
    }
    $vars->{groups} = \@vars_groups;

    my $networks = $bwctl_conf->get_networks();

    my @vars_networks = ();
    foreach my $key ( sort keys %{$networks} ) {
        my $network = $networks->{$key};

        my %network_desc = ();
        $network_desc{id} = $network->{name};
        $network_desc{id} =~ s/\//_/;
        $network_desc{group} = $network->{group};
        $network_desc{name}  = $network->{name};

        push @vars_networks, \%network_desc;
    }

    $vars->{networks} = \@vars_networks;

    my $users = $bwctl_conf->get_users();

    my @vars_users = ();
    foreach my $key ( sort keys %{$users} ) {
        my $user = $users->{$key};

        my %user_desc = ();
        $user_desc{group} = $user->{group};
        $user_desc{id}    = $user->{name};
        $user_desc{name}  = $user->{name};

        push @vars_users, \%user_desc;
    }

    $vars->{users} = \@vars_users;

    $vars->{advanced_mode}  = $advanced_mode;
    $vars->{is_modified}    = $is_modified;
    $vars->{status_message} = $status_msg;
    $vars->{error_message}  = $error_msg;
    $vars->{other_changes}  = $other_changes;

    return 0;
}

sub display_body {
    my %vars = ();

    fill_variables( \%vars );

    $logger->debug( "Variables: " . Dumper( \%vars ) );

    my $html;

    my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );
    $tt->process( "body.tmpl", \%vars, \$html ) or die $tt->error();

    return $html;
}

sub save_config {
    my ($status, $res) = $bwctl_conf->save( { restart_services => 1 } );
    if ($status != 0) {
    $error_msg = "Problem saving configuration: $res";
    } else {
        $status_msg = "Configuration Saved And Services Restarted";
    $is_modified = 0;
    $initial_state_time = $bwctl_conf->last_modified();
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

sub add_network {
    my ( $network_name, $group ) = @_;

    unless ( $network_name and $group ) {
        $error_msg = "Invalid input";
        return display_body();
    }

    unless ( $bwctl_conf->lookup_group( { name => $group } ) ) {
        $error_msg = "Invalid group: $group";
        return display_body();
    }

    # If they only give us an IP or hostname, make it a /32
    $network_name = $network_name . "/32" unless ( $network_name =~ /\// );

    # Make sure the netmask is in /N form.
    my ( $network, $netmask ) = split( '/', $network_name );

    $logger->info( "Trying to add $network/$netmask" );

    my $netmask_calc = Net::IP->new( "0.0.0.0/$netmask" );
    unless ( $netmask_calc ) {
        $error_msg = "Invalid netmask";
        return display_body();
    }

    $netmask = $netmask_calc->prefixlen;

    $network_name = $network . "/" . $netmask;

    if ( $bwctl_conf->lookup_network( { name => $network_name } ) ) {
        $error_msg = "Network $network_name already exists";
        return display_body();
    }

    $bwctl_conf->add_network( { name => $network_name, group => $group } );

    $is_modified = 1;

    save_state();

    $logger->info( "Network $network_name added" );

    $status_msg = "Network $network_name added";
    return display_body();
}

sub update_network {

    # no display
    my ( $network, $group ) = @_;

    return unless ( $bwctl_conf->lookup_network( { name => $network } ) );

    $logger->info( "Setting $network to $group" );

    if ( $group eq "no group" ) {
        $group = undef;
    }

    $bwctl_conf->update_network( { name => $network, group => $group } );

    $is_modified = 1;

    save_state();

    return display_body();
}

sub delete_network {
    my ( $network ) = @_;
    $logger->info( "Deleting Network: $network" );

    my $resp;
    if ( $bwctl_conf->lookup_network( { name => $network } ) ) {
        $bwctl_conf->delete_network( { name => $network } );
        $status_msg = "Network $network deleted";
    }
    else {
        $error_msg = "Network $network does not exist";
    }

    $is_modified = 1;

    save_state();
    return display_body();
}

sub change_password {
    my ( $user_name, $password ) = @_;

    $bwctl_conf->update_user( { name => $user_name, password => $password } );

    $is_modified = 1;

    save_state();

    $logger->info( "Password changed for user $user_name" );

    $status_msg = "Password changed for user $user_name";

    return display_body();
}

sub add_user {
    my ( $user_name, $group, $password ) = @_;

    if ( $bwctl_conf->lookup_user( { name => $user_name } ) ) {
        $error_msg = "User $user_name already exists";
        return display_body();
    }

    $bwctl_conf->add_user( { name => $user_name, password => $password, group => $group } );

    $is_modified = 1;

    save_state();

    $logger->info( "User $user_name added" );

    $status_msg = "User $user_name added";
    return display_body();
}

sub update_user {

    # no display
    my ( $user, $group ) = @_;

    return unless ( $bwctl_conf->lookup_user( { name => $user } ) );

    $logger->info( "Setting $user to $group" );

    if ( $group eq "no group" ) {
        $group = undef;
    }

    $bwctl_conf->update_user( { name => $user, group => $group } );

    $is_modified = 1;

    save_state();

    return display_body();
}

sub delete_user {
    my ( $user ) = @_;

    $logger->info( "Deleting User: $user" );

    if ( $bwctl_conf->lookup_user( { name => $user } ) ) {
        $bwctl_conf->delete_user( { name => $user } );
        $status_msg = "User $user deleted";
    }
    else {
        $error_msg = "User $user does not exist";
    }

    $is_modified = 1;

    save_state();
    return display_body();
}

sub add_group {
    my ( $group ) = @_;

    if ( $bwctl_conf->lookup_group( { name => $group } ) ) {
        $error_msg = "Group $group already exists";
        return display_body();
    }

    $bwctl_conf->add_group( { name => $group } );

    $is_modified = 1;

    save_state();

    $logger->info( "Group $group added" );

    $status_msg = "Group $group added";
    return display_body();
}

sub update_group {
    my ($group_id, $allow_tcp, $allow_udp, $bandwidth, $duration, $event_horizon, $allow_open_mode, $pending, $group_parent) = @_;

    unless ( $bwctl_conf->lookup_group( { name => $group_id } ) ) {
        return display_body() 
    }

    my $group = $bwctl_conf->lookup_group( { name => $group_id } );
    my $groups   = $bwctl_conf->get_groups();
    my $children = find_children($group_id);

    # copy any existing data down to the children. 
    foreach my $child_name (@$children) {
        my $child = $bwctl_conf->lookup_group({ name => $child_name });

        foreach my $limit (qw(allow_udp allow_tcp allow_open_mode duration pending bandwidth event_horizon)) {
            next if ( defined $child->{$limit} );

            # Find their pre-existing limit.
            my $current_limit = $bwctl_conf->lookup_limit({ name => $group_id, limit => $limit });
            
            $child->{$limit} = $current_limit;
        }
    }
 
    # now update the curent group
    $bwctl_conf->update_group( { name => $group_id, allow_udp => $allow_udp } );
    $bwctl_conf->update_group( { name => $group_id, allow_tcp => $allow_tcp } );
    $bwctl_conf->update_group( { name => $group_id, allow_open_mode => $allow_open_mode} );
    $bwctl_conf->update_group( { name => $group_id, parent => $group_parent } );
    $bwctl_conf->update_group( { name => $group_id, duration => $duration } );
    $bwctl_conf->update_group( { name => $group_id, pending => $pending } );
    $bwctl_conf->update_group( { name => $group_id, bandwidth => $bandwidth } );
    $bwctl_conf->update_group( { name => $group_id, event_horizon => $event_horizon } );

    # Update any children that might now be more constrained

    my @constrained_changes = ();

    # copy any existing data down to the children since changing the parent
    # shouldn't obviously change the child. sigh.
    foreach my $child (@$children) {
        # NOTE: the allow_open_mode variable is missing here since it does not
        # follow the "parents are more strict as children" rule.

        foreach my $limit (qw(allow_udp allow_tcp duration pending bandwidth event_horizon)) {
            # Find their new constrained amount.
            my $current_limit = $bwctl_conf->lookup_limit({ name => $child, limit => $limit, constrained => 0 });
            my $constrained_limit = $bwctl_conf->lookup_limit({ name => $child, limit => $limit, constrained => 1 });

            $logger->info("Limit: limit=$limit current=$current_limit constrained=$constrained_limit");

	    if ($current_limit ne $constrained_limit) {
                $bwctl_conf->update_group( { name => $child, $limit => $constrained_limit } );

                push @constrained_changes, { group => $child, limit => $limit, value => $constrained_limit };
            }
        }
    }

    $other_changes = \@constrained_changes;

    $is_modified = 1;

    save_state();

    return display_body();
}

sub delete_group {
    my ( $group ) = @_;

    $logger->info( "Deleting Group: $group" );

    unless ( $bwctl_conf->lookup_group( { name => $group } ) ) {
        $status_msg = "Group $group does not exist";
        return display_body();
    }

    my $networks = $bwctl_conf->get_networks();
    my $users    = $bwctl_conf->get_users();
    my $groups   = $bwctl_conf->get_groups();

    foreach my $network ( keys %{$networks} ) {
        if ( $networks->{$network}->{group} eq $group ) {
            $error_msg = "Network $network is a member of $group";
            return display_body();
        }
    }

    foreach my $user ( keys %{$users} ) {
        if ( $users->{$user}->{group} eq $group ) {
            $error_msg = "User $user is a member of $group";
            return display_body();
        }
    }

    $bwctl_conf->delete_group( { name => $group } );

    $is_modified = 1;

    save_state();

    $error_msg = "Group $group deleted";
    return display_body();
}

sub reset_state {
    my ( $status, $res );

    $bwctl_conf = perfSONAR_PS::NPToolkit::Config::BWCTL->new();
    $res = $bwctl_conf->init( { bwctld_limits => $conf{bwctld_limits}, bwctld_keys => $conf{bwctld_keys} } );

    if ( $res != 0 ) {
        die( "Couldn't initialize BWCTL Configuration" );
    }

    $is_modified = 0;
    $initial_state_time = $bwctl_conf->last_modified();
}

sub save_state {
    $session->param( "bwctl_conf",    $bwctl_conf->save_state() );
    $session->param( "advanced_mode", $advanced_mode );
    $session->param( "is_modified",   $is_modified );
    $session->param( "initial_state_time", $initial_state_time );
}

sub toggle_advanced_mode {
    my ( $enabled ) = @_;

    if ( $enabled ) {
        $advanced_mode = 1;
    }
    else {
        $advanced_mode = 0;
    }

    save_state();

    return display_body();
}

sub generate_bwctld_keys {
    return $bwctl_conf->generate_bwctld_keys();
}

sub generate_bwctld_limits {
    return $bwctl_conf->generate_bwctld_limits();
}


=head2 find_children
    Simple function to lookup the "children" of a given group.
=cut
sub find_children {
    my ($group_name) = @_;

    my $groups = $bwctl_conf->get_groups();

    my @ret_groups = ();

    foreach my $curr_group_name ( keys %{$groups} ) {
        my $group = $groups->{$curr_group_name};

        if ($group->{parent} eq $group_name) {
            push @ret_groups, $curr_group_name;
        }
    }

    return \@ret_groups;
}

1;
