package perfSONAR_PS::NPToolkit::Config::OWAMP;

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::OWAMP

=head1 DESCRIPTION

Module for configuring OWAMP limits and pfs files. Longer term, This should get
extended to configure all aspects of OWAMP configuration.

=cut

use base 'perfSONAR_PS::NPToolkit::Config::Base';

use fields 'OWAMP_LIMITS', 'OWAMP_PFS', 'OWAMPD_LIMITS_FILE', 'OWAMPD_LIMITS_TEMPLATE', 'OWAMPD_PFS_FILE', 'OWAMPD_PFS_TEMPLATE';

use Params::Validate qw(:all);
use Storable qw(store retrieve freeze thaw dclone);

use perfSONAR_PS::Utils::Config::OWAMP qw( owamp_pfs_parse_file owamp_limits_parse_file owamp_pfs_hash_password owamp_pfs_output owamp_limits_output owamp_known_limits );
use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw( save_file restart_service );

# These are the defaults for the current NPToolkit
my %defaults = (
    owampd_limits => "/etc/owampd/owampd.limits",
    owampd_pfs    => "/etc/owampd/owampd.pfs",
);

=head2 init({ owampd_limits => 0, owampd_pfs => 0 })

Initializes the client. Returns 0 on success and -1 on failure. The
owampd_limits and owampd_pfs parameters can be specified to set which files
the module should use for reading/writing the configuration.

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            owampd_limits => 0,
            owampd_pfs    => 0,
        }
    );

    my $res;

    $res = $self->SUPER::init();
    if ( $res != 0 ) {
        return $res;
    }

    # Initialize the defaults
    $self->{OWAMPD_PFS_FILE}    = $defaults{owampd_pfs};
    $self->{OWAMPD_LIMITS_FILE} = $defaults{owampd_limits};

    $self->{OWAMPD_PFS_FILE}    = $parameters->{owampd_pfs}    if ( $parameters->{owampd_pfs} );
    $self->{OWAMPD_LIMITS_FILE} = $parameters->{owampd_limits} if ( $parameters->{owampd_limits} );

    $res = $self->reset_state();
    if ( $res != 0 ) {
        return $res;
    }

    return 0;
}

=head2 save({ restart_services => 0 })
    Saves the configuration to disk. The owamp service can be restarted by
    specifying the "restart_services" parameter as 1. 
=cut

sub save {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { restart_services => 0, } );

    my ( $status, $res );

    ( $status, $res ) = owamp_limits_output( { groups => $self->{OWAMP_LIMITS}->{groups}, users => $self->{OWAMP_LIMITS}->{users}, networks => $self->{OWAMP_LIMITS}->{networks}, default_group => $self->{OWAMP_LIMITS}->{default_group} } );
    if ($status != 0) {
        $self->{LOGGER}->error("Couldn't save limits: ".$res);
        return (-1, "Problem generating limits file");
    }

    my $owampd_limits_output = join( "\n", @{$res} );

    ( $status, $res ) = owamp_pfs_output( { users => $self->{OWAMP_PFS} } );
    if ($status != 0) {
        $self->{LOGGER}->error("Couldn't save pfs: ".$res);
        return (-1, "Problem generating pfs file");
    }

    my $owampd_pfs_output = join( "\n", @{$res} );

    $res = save_file( { file => $self->{OWAMPD_LIMITS_FILE}, content => $owampd_limits_output } );
    if ( $res == -1 ) {
        return (-1, "Problem saving limits file");
    }

    $res = save_file( { file => $self->{OWAMPD_PFS_FILE}, content => $owampd_pfs_output } );
    if ( $res == -1 ) {
        return (-1, "Problem saving pfs file");
    }

    if ( $parameters->{restart_services} ) {
        $res = restart_service( { name => "owamp" } );
        if ( $res == -1 ) {
            return (-1, "Problem restarting owamp");
        }
    }

    return 0;
}

=head2 lookup_network({ name => 1 })

Networks are defined by their "name". This is the 192.168.0.2/32. The return
value is either undefined if that network does not exist, or a hash reference
containing "name" and "group" keys with corresponding values.

=cut

sub lookup_network {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    return unless $self->{OWAMP_LIMITS}->{networks}->{$name};

    my %network = (
        name  => $name,
        group => $self->{OWAMP_LIMITS}->{networks}->{$name},
    );

    return \%network;
}

=head2 get_networks ({})

Returns the set of networks as a hash keyed on the network's name.

=cut

sub get_networks {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %network_list = ();

    my @networks = ();

    foreach my $name ( keys %{ $self->{OWAMP_LIMITS}->{networks} } ) {

        my %network = (
            name  => $name,
            group => $self->{OWAMP_LIMITS}->{networks}->{$name},
        );

        $network_list{$name} = \%network;
    }

    return \%network_list;
}

=head2 add_network({ name => 1, group => 1})

Adds the network to the list. Returns 0 if successful and -1 on failure. The
'name' parameter must be of the form '[ip address]/[0-32]', and that name must
not already be in use for another network. Group must correspond to one of the
defined groups.

=cut

sub add_network {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name  => 1,
            group => 1,
        }
    );

    my $name  = $parameters->{name};
    my $group = $parameters->{group};

    return -1 if ( $self->{OWAMP_LIMITS}->{networks}->{$name} );
    return -1 unless ( $self->{OWAMP_LIMITS}->{groups}->{$group} );
    return -1 unless ( $name =~ /\// );

    my ( $ip, $netmask ) = split( '/', $name );

    # verify the netmask is of /[number] form
    return -1 unless ( int( $netmask ) == $netmask and int( $netmask ) >= 0 and int( $netmask ) <= 64 );

    $self->{OWAMP_LIMITS}->{networks}->{$name} = $group;

    return 0;
}

=head2 update_network({ name => 1, group => 1})

Updates the network in the list. The 'name' parameter must correspond to a
defined network.  Group must correspond to one of the defined groups.

=cut

sub update_network {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name  => 1,
            group => 1,
        }
    );

    my $name  = $parameters->{name};
    my $group = $parameters->{group};

    return -1 unless ( $self->{OWAMP_LIMITS}->{networks}->{$name} );
    return -1 unless ( $self->{OWAMP_LIMITS}->{groups}->{$group} );

    $self->{OWAMP_LIMITS}->{networks}->{$name} = $group;

    return 0;
}

=head2 delete_network({ name => 1 })

Deletes the network in the list. Returns 0 if the network is no longer in the list (even if it never was).

=cut

sub delete_network {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    delete( $self->{OWAMP_LIMITS}->{networks}->{$name} );

    return 0;
}

=head2 update_user({ name => 1, password => 0, group => 0 })

Updates the user's properties . The 'name' parameter must correspond to a
defined user.  'group', if specified, must correspond to one of the defined
groups.

=cut

sub update_user {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name     => 1,
            password => 0,
            group    => 0,
        }
    );

    my $name     = $parameters->{name};
    my $password = $parameters->{password};
    my $group    = $parameters->{group};

    return -1 unless ( $self->{OWAMP_PFS}->{$name} or $self->{OWAMP_LIMITS}->{users}->{$name} );

    if ( $password ) {
        my $hashed_pw = owamp_pfs_hash_password( { password => $password } );
        $self->{OWAMP_PFS}->{$name} = $hashed_pw;
    }

    if ( exists $parameters->{group} ) {
        $self->{OWAMP_LIMITS}->{users}->{$name} = $group;
    }

    return 0;
}

=head2 lookup_user({ name => 1 })

Users are defined by their name. The return value is either undefined if that
user does not exist, or a hash reference containing "name" and "group" keys
with corresponding values.

=cut

sub lookup_user {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    return undef unless ( $self->{OWAMP_LIMITS}->{users}->{$name} or $self->{OWAMP_PFS}->{$name} );

    my %user = (
        name     => $name,
        group    => $self->{OWAMP_LIMITS}->{users}->{$name},
        password => $self->{OWAMP_PFS}->{$name},
    );

    return \%user;
}

=head2 get_users ({})

Returns the set of users as a hash keyed on the users's name.

=cut

sub get_users {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %user_list = ();

    my @users = ();
    push @users, keys %{ $self->{OWAMP_LIMITS}->{users} };
    push @users, keys %{ $self->{OWAMP_PFS} };

    foreach my $user_name ( @users ) {
        next if ( $user_list{$user_name} );

        my %user = (
            name     => $user_name,
            group    => $self->{OWAMP_LIMITS}->{users}->{$user_name},
            password => $self->{OWAMP_PFS}->{$user_name},
        );

        $user_list{$user_name} = \%user;
    }

    return \%user_list;
}

=head2 add_user({ name => 1, password => 1, group => 1})

Adds the user to the list. Returns 0 if successful and -1 on failure. The
'name' parameter must not already be in use for another user. Group must
correspond to one of the defined groups.

=cut

sub add_user {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name     => 1,
            password => 1,
            group    => 1,
        }
    );

    my $name     = $parameters->{name};
    my $password = $parameters->{password};
    my $group    = $parameters->{group};

    return -1 if ( $self->{OWAMP_PFS}->{$name} or $self->{OWAMP_LIMITS}->{users}->{$name} );

    my $hashed_pw = owamp_pfs_hash_password( { password => $password } );
    $self->{OWAMP_PFS}->{$name} = $hashed_pw;
    $self->{OWAMP_LIMITS}->{users}->{$name} = $group;

    return 0;
}

=head2 delete_user ({ name => 1 })

Deletes the user from the list. Returns 0 if the user is no longer in the list (even if it never was).

=cut

sub delete_user {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    delete( $self->{OWAMP_PFS}->{$name} );
    delete( $self->{OWAMP_LIMITS}->{users}->{$name} );

    return 0;
}

=head2 lookup_group({ name => 1 })

Groups are defined by their name. The return value is either undefined if that
group does not exist, or a hash reference containing "name" and the attributes
for that group.

=cut

sub lookup_group {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    return $self->{OWAMP_LIMITS}->{groups}->{$name};
}

=head2 get_groups ({})

Returns the set of groups as a hash keyed on the group's name.

=cut

sub get_groups {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{OWAMP_LIMITS}->{groups};
}

=head2 add_group({ name => 1, parent => 0, bandwidth => 0, disk => 0, delete_on_fetch => 0, allow_open_mode => 0, })

Adds the group to the list. Returns 0 if successful and -1 on failure. The
'name' parameter must not already be in use for another group. The limits
parameters are sanity checked. The allow_open_mode and delete_on_fetch
parameters must be "on" or "off".  'parent' correspond to an existing group.
'bandwidth' and 'disk' must be 0 or more.

=cut

sub add_group {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name            => 1,
            parent          => 0,
            bandwidth       => 0,
            disk            => 0,
            delete_on_fetch => 0,
            allow_open_mode => 0,
        }
    );

    my $name            = $parameters->{name};
    my $parent          = $parameters->{parent};
    my $bandwidth       = $parameters->{bandwidth};
    my $disk            = $parameters->{disk};
    my $delete_on_fetch = $parameters->{delete_on_fetch};
    my $allow_open_mode = $parameters->{allow_open_mode};

    # Sanity check the arguments
    return -1 if ( $self->{OWAMP_LIMITS}->{groups}->{$name} );
    return -1 if ( $allow_open_mode and $allow_open_mode ne "on" and $allow_open_mode ne "off" );
    return -1 if ( $delete_on_fetch and $delete_on_fetch ne "on" and $delete_on_fetch ne "off" );
    return -1 if ( $parent    and not $self->{OWAMP_LIMITS}->{groups}->{$parent} );
    return -1 if ( $bandwidth and ( $bandwidth !~ /^([0-9]+)[mMbBgGkK]?$/ ) );
    return -1 if ( $disk      and ( $disk !~ /^([0-9]+)[mMbBgGkK]?$/ ) );

    my %group = ();
    $group{disk}            = $disk            if ( defined $disk );
    $group{bandwidth}       = $bandwidth       if ( defined $bandwidth );
    $group{allow_open_mode} = $allow_open_mode if ( defined $allow_open_mode );
    $group{delete_on_fetch} = $delete_on_fetch if ( defined $delete_on_fetch );
    $group{parent}          = $parent          if ( defined $parent );

    $self->{OWAMP_LIMITS}->{groups}->{$name} = \%group;

    return 0;
}

=head2 update_group({ name => 1, parent => 0, bandwidth => 0, disk => 0, delete_on_fetch => 0, allow_open_mode => 0, })

Updates the specified group. Returns 0 if successful and -1 on failure. The
'name' parameter must correspond to an existing another group. The limits
parameters are sanity checked. The allow_open_mode and delete_on_fetch
parameters must be "on" or "off".  'parent' correspond to an existing group.
'bandwidth' and 'disk' must be 0 or more.

=cut

sub update_group {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name            => 1,
            parent          => 0,
            bandwidth       => 0,
            disk            => 0,
            delete_on_fetch => 0,
            allow_open_mode => 0,
        }
    );

    my $name            = $parameters->{name};
    my $parent          = $parameters->{parent};
    my $bandwidth       = $parameters->{bandwidth};
    my $disk            = $parameters->{disk};
    my $delete_on_fetch = $parameters->{delete_on_fetch};
    my $allow_open_mode = $parameters->{allow_open_mode};

    $self->{LOGGER}->debug( "Updating $name" );

    # Sanity check the arguments
    return -1 unless ( $self->{OWAMP_LIMITS}->{groups}->{$name} );
    return -1 if ( $allow_open_mode and $allow_open_mode ne "on" and $allow_open_mode ne "off" );
    return -1 if ( $delete_on_fetch and $delete_on_fetch ne "on" and $delete_on_fetch ne "off" );
    return -1 if ( $parent    and not $self->{OWAMP_LIMITS}->{groups}->{$parent} );
    return -1 if ( $bandwidth and ( $bandwidth !~ /^([0-9]+)[mMbBgGkK]?$/ ) );
    return -1 if ( $disk      and ( $disk !~ /^([0-9]+)[mMbBgGkK]?$/ ) );

    my $group = $self->{OWAMP_LIMITS}->{groups}->{$name};

    $group->{disk}            = $disk            if ( defined $disk );
    $group->{bandwidth}       = $bandwidth       if ( defined $bandwidth );
    $group->{allow_open_mode} = $allow_open_mode if ( defined $allow_open_mode );
    $group->{delete_on_fetch} = $delete_on_fetch if ( defined $delete_on_fetch );
    $group->{parent}          = $parent          if ( defined $parent );

    return 0;
}

=head2 delete_group ({ name => 1 })

Deletes the group from the list. Returns (0, "") if the group is no longer in
the list (even if it never was). Returns (-1, $error_msg) if a network or user
is a member of that group.

=cut

sub delete_group {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    foreach my $network ( keys %{ $self->{OWAMP_LIMITS}->{networks} } ) {
        if ( $self->{OWAMP_LIMITS}->{networks}->{$network} eq $name ) {
            return ( -1, "Network $network is a member of $name" );
        }
    }

    foreach my $user ( keys %{ $self->{OWAMP_LIMITS}->{users} } ) {
        if ( $self->{OWAMP_LIMITS}->{users}->{$user} eq $name ) {
            return ( -1, "User $user is a member of $name" );
        }
    }

    delete( $self->{OWAMP_LIMITS}->{groups}->{$name} );

    return ( 0, "" );
}

=head2 lookup_limit
	Looks up the limit for the specified group
=cut
sub lookup_limit {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, limit => 1, non_recursive => 0, constrained => 0 } );

    my $name = $parameters->{name};
    my $limit = $parameters->{limit};
    my $non_recursive = $parameters->{non_recursive};
    my $constrained   = $parameters->{constrained};

    my ($status, $res);

    unless ($self->{OWAMP_LIMITS}->{groups}->{$name}) {
        return (-1, "Unknown group: $name");
    }

    ($status, $res) = owamp_known_limits({ limit => $limit });
    if ($status != 0) {
        return (-1, "Unknown limit: $limit");
    }

    my $group = $self->{OWAMP_LIMITS}->{groups}->{$name};

    if ($non_recursive) {
        return $group->{$limit};
    }
    else {
        return $self->__lookup_limit($group, $self->{OWAMP_LIMITS}->{groups}, $limit, $constrained);
    }
}

sub __lookup_limit {
    my ($self, $group, $groups, $limit, $constrained ) = @_;

    my ($new_limit, $existing_limit);

    use Data::Dumper;

    $self->{LOGGER}->info("Group: ".Dumper($group));

    if (defined $group->{$limit} && not $constrained) {
        return $group->{$limit}; 
    }

    if ($group->{parent}) {
        $self->{LOGGER}->info("Found parent, looking up $limit in parent");
        $existing_limit = $self->__lookup_limit($groups->{$group->{parent}}, $groups, $limit, $constrained);
    }

    unless (defined $existing_limit) {
        $self->{LOGGER}->info("No existing limit for $limit");
        $new_limit = $group->{$limit};
    } else {
        my $limit_type = owamp_known_limits({ limit => $limit });

        if ($limit_type->{type} eq "boolean") {
            $self->{LOGGER}->info("Limit type is booltean: $limit");
            if (defined $group->{$limit} and $existing_limit eq "on") {
                $new_limit = $group->{$limit};
            } else {
                $new_limit = $existing_limit;
            }
        } elsif ($limit_type->{type} eq "bandwidth" or $limit_type->{type} eq "disk" or $limit_type->{type} eq "time"  or $limit_type->{type} eq "integer" ) {
            $self->{LOGGER}->info("Limit type is not boolean: $limit");
            $new_limit = $existing_limit;

            if (defined $group->{$limit}) {
                if ($group->{$limit} < $existing_limit or $existing_limit == 0) {
                    $new_limit = $group->{$limit};
                }
            }
        }
    }

    unless (defined $new_limit) {
        my $limit_type = owamp_known_limits({ limit => $limit });
        $new_limit = $limit_type->{default};
    }

    return $new_limit;
}

=head2 set_default_group({ name => 1 })

Sets the group for incoming connections that aren't authenticated with a
password and don't come from one of the configured networks. Returns 0 on
success and -1 on failure. The name must correspond to a defined group.

=cut

sub set_default_group {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    return -1 unless ( $self->{OWAMP_LIMITS}->{groups}->{$name} );

    $self->{OWAMP_LIMITS}->{default_group} = $name;

    return 0;
}

=head2 last_modified()
    Returns when the site information was last saved.
=cut

sub last_modified {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my ($mtime1) = (stat ( $self->{OWAMPD_PFS_FILE} ) )[9];
    my ($mtime2) = (stat ( $self->{OWAMPD_LIMITS_FILE} ) )[9];

    $mtime1 = 0 unless ($mtime1);
    $mtime2 = 0 unless ($mtime2);

    my $mtime = ($mtime1 > $mtime2)?$mtime1:$mtime2;

    return $mtime;
}

=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
=cut

sub reset_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my ( $status, $res );

    if ( -f $self->{OWAMPD_LIMITS_FILE} ) {
        ( $status, $res ) = owamp_limits_parse_file( { file => $self->{OWAMPD_LIMITS_FILE} } );
        if ( $status != 0 ) {
            $self->{LOGGER}->error( "Limits: $res" );
            return -1;
        }

	$self->{OWAMP_LIMITS} = $res;
    }
    else {
        $self->{OWAMP_LIMITS} = {};
    }

    if ( -f $self->{OWAMPD_PFS_FILE} ) {
        ( $status, $res ) = owamp_pfs_parse_file( { file => $self->{OWAMPD_PFS_FILE} } );
        if ( $status != 0 ) {
            $self->{LOGGER}->error( "Keys: $res" );
            return -1;
        }

        $self->{OWAMP_PFS} = $res;
    }
    else {
        $self->{OWAMP_PFS} = {};
    }

    return 0;
}

=head2 save_state()
    Saves the current state of the module as a string. This state allows the
    module to be recreated later.
=cut

sub save_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %state = (
        owamp_limits       => $self->{OWAMP_LIMITS},
        owamp_pfs          => $self->{OWAMP_PFS},
        owampd_limits_file => $self->{OWAMPD_LIMITS_FILE},
        owampd_pfs_file    => $self->{OWAMPD_PFS_FILE},
    );

    my $str = freeze( \%state );

    return $str;
}

=head2 restore_state({ state => \$state })
    Restores the modules state based on a string provided by the "save_state"
    function above.
=cut

sub restore_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { state => 1, } );

    my $state = thaw( $parameters->{state} );

    $self->{OWAMP_LIMITS}       = $state->{owamp_limits};
    $self->{OWAMP_PFS}          = $state->{owamp_pfs};
    $self->{OWAMPD_LIMITS_FILE} = $state->{owampd_limits_file};
    $self->{OWAMPD_PFS_FILE}    = $state->{owampd_pfs_file};

    $self->{LOGGER}->info("FDSALimits: ".Dumper($self->{OWAMP_LIMITS}));

    return;
}

1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 COPYRIGHT

Copyright (c) 2008-2010, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
