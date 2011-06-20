package perfSONAR_PS::Utils::Config::BWCTL;

use strict;
use warnings;

use Params::Validate;
use Log::Log4perl qw(get_logger);
use Digest::MD5 qw(md5_hex);

use base 'Exporter';

our @EXPORT_OK = qw( bwctl_conf_parse bwctl_conf_parse_file bwctl_conf_output bwctl_conf_output_file bwctl_keys_parse bwctl_keys_parse_file bwctl_keys_output bwctl_keys_output_file bwctl_keys_hash_password bwctl_limits_parse bwctl_limits_parse_file bwctl_limits_output bwctl_limits_output_file bwctl_known_limits );

our $logger = get_logger(__PACKAGE__);

our %known_limits = (
    parent          => {
   	type => "group",
	default => undef,
    },
    bandwidth       =>  {
   	type => "bandwidth",
	default => 0,
    },
    pending         =>  {
   	type => "integer",
	default => 0,
    },
    event_horizon   =>  {
   	type => "time",
	default => 0,
    },
    duration =>  {
   	type => "time",
	default => 0,
    },
    allow_open_mode =>  {
   	type => "boolean",
	default => "off",
    },
    allow_tcp =>  {
   	type => "boolean",
	default => "on",
    },
    allow_udp =>  {
   	type => "boolean",
	default => "off",
    },
    max_time_error  => {
   	type => "time",
	default => "off",
    },
);

sub bwctl_known_limits {
    my $parameters = validate( @_, { limit => 0, } );

    my $limit = $parameters->{limit};

    if ($limit) {
        return (0, $known_limits{$limit});
    } else {
        return (0, \%known_limits);
    }
}

sub bwctl_conf_parse_file {
    my $parameters = validate( @_, { file => 1, } );

    unless ( open( LIMITS_FILE, $parameters->{file} ) ) {
        return ( -1, "Couldn't open file: " . $parameters->{file} );
    }

    my @lines = <LIMITS_FILE>;

    close( LIMITS_FILE );

    return bwctl_conf_parse( { lines => \@lines } );
}

sub bwctl_conf_output_file {
    my $parameters = validate(
        @_,
        {
            file  => 1,
            variables => 0,
        }
    );

    my ( $status, $res ) = bwctl_conf_output( { variables => $parameters->{variables} } );

    if ( $status != 0 ) {
        return ( $status, $res );
    }

    unless ( open( CONF_FILE, ">" . $parameters->{file} ) ) {
        return ( -1, "Couldn't open file: " . $parameters->{file} );
    }

    foreach my $line ( @{$res} ) {
        print CONF_FILE $line . "\n";
    }

    close( CONF_FILE );

    return ( 0, "" );
}

sub bwctl_conf_parse {
    my $parameters = validate( @_, { lines => 1, } );

    my $line_number = 0;

    my %variables = ();

    foreach my $line ( @{ $parameters->{lines} } ) {
        chomp( $line );

        $line_number++;

        # Strip out comments
        $line =~ s/#.*//;

        # Strip leading and trailing whitespace
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;

        # skip empty lines (may be empty because they were comments)
        next if ( $line eq "" );

        my ($variable, $value);

        if ($line =~ /^(\S*)\s+(\S*)$/) {
            $variables{$1} = $2;
        }
        elsif ($line =~ /^(\S*)$/) {
            $variables{$1} = undef;
        }
        else {
            return ( -1, "Invalid line $line_number" );
        }
    }

    return ( 0, \%variables );
}

sub bwctl_conf_output {
    my $parameters = validate( @_, { variables => 1, } );

    my $variables = $parameters->{variables};

    my @lines = ();

    foreach my $variable ( keys %{$variables} ) {
        my $line = $variable;

	$line .= "\t" . $variables->{$variable} if (defined $variables->{$variable});

        push @lines, $line;
    }

    return ( 0, \@lines );
}

sub bwctl_keys_parse_file {
    my $parameters = validate( @_, { file => 1, } );

    unless ( open( LIMITS_FILE, $parameters->{file} ) ) {
        return ( -1, "Couldn't open file: " . $parameters->{file} );
    }

    my @lines = <LIMITS_FILE>;

    close( LIMITS_FILE );

    return bwctl_keys_parse( { lines => \@lines } );
}

sub bwctl_keys_output_file {
    my $parameters = validate(
        @_,
        {
            file  => 1,
            users => 0,
        }
    );

    my ( $status, $res ) = bwctl_keys_output( { users => $parameters->{users} } );

    if ( $status != 0 ) {
        return ( $status, $res );
    }

    unless ( open( KEYS_FILE, ">" . $parameters->{file} ) ) {
        return ( -1, "Couldn't open file: " . $parameters->{file} );
    }

    foreach my $line ( @{$res} ) {
        print KEYS_FILE $line . "\n";
    }

    close( KEYS_FILE );

    return ( 0, "" );
}

sub bwctl_keys_parse {
    my $parameters = validate( @_, { lines => 1, } );

    my %users = ();

    my $line_number = 0;

    foreach my $line ( @{ $parameters->{lines} } ) {
        chomp( $line );

        $line_number++;

        # Strip out comments
        $line =~ s/#.*//;

        # Strip leading and trailing whitespace
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;

        # skip empty lines (may be empty because they were comments)
        next if ( $line eq "" );

        if ( $line =~ /^([^ ]+)\t([a-f0-9]+)$/ ) {
            my $user     = $1;
            my $password = $2;

            if ( $users{$user} ) {
                return ( -1, "User $user redefined" );
            }

            $users{$user} = $password;
        }
        else {
            return ( -1, "Invalid line $line_number" );
        }
    }

    return ( 0, \%users );
}

sub bwctl_keys_output {
    my $parameters = validate( @_, { users => 1, } );

    my $users = $parameters->{users};

    my @lines = ();

    foreach my $user ( keys %{$users} ) {
        unless ( $users->{$user} =~ /^[a-z0-9]+$/ ) {
            return ( -1, "User $user has an invalid hashed password" );
        }
        if ( $user =~ / / ) {
            return ( -1, "User '$user' has an invalid name, no spaces allowed" );
        }

        my $line = $user . "\t" . $users->{$user};
        push @lines, $line;
    }

    return ( 0, \@lines );
}

sub bwctl_keys_hash_password {
    my $parameters = validate(
        @_,
        {
            salt     => 0,
            username => 0,
            password => 1,
        }
    );

    return md5_hex( $parameters->{password} );
}

sub bwctl_limits_parse_file {
    my $parameters = validate( @_, { file => 1, } );

    unless ( open( LIMITS_FILE, $parameters->{file} ) ) {
        return ( -1, "Couldn't open file: " . $parameters->{file} );
    }

    my @lines = <LIMITS_FILE>;

    close( LIMITS_FILE );

    return bwctl_limits_parse( { lines => \@lines } );
}

sub bwctl_limits_output_file {
    my $parameters = validate(
        @_,
        {
            file          => 1,
            groups        => 1,
            users         => 0,
            networks      => 0,
            default_group => 0,
        }
    );

    my ( $status, $res ) = bwctl_limits_output( { groups => $parameters->{groups}, users => $parameters->{users}, networks => $parameters->{networks}, default_group => $parameters->{default_group} } );

    if ( $status != 0 ) {
        return ( $status, $res );
    }

    unless ( open( LIMITS_FILE, ">" . $parameters->{file} ) ) {
        return ( -1, "Couldn't open file: " . $parameters->{file} );
    }

    foreach my $line ( @{$res} ) {
        print LIMITS_FILE $line . "\n";
    }

    close( LIMITS_FILE );

    return ( 0, "" );
}

sub bwctl_limits_parse {
    my $parameters = validate( @_, { lines => 1, } );

    my %groups   = ();
    my %users    = ();
    my %networks = ();
    my $default_group;

    my $curr_line;
    my $line_number = 0;

    foreach my $line ( @{ $parameters->{lines} } ) {
        $curr_line = "" unless ( $line );

        chomp( $line );

        $line_number++;

        # Strip out comments
        $line =~ s/#.*//;

        # Strip leading and trailing whitespace
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;

        # skip empty lines (may be empty because they were comments)
        next if ( $line eq "" );

        $curr_line .= $line;

        # check if this is a continuation line
        if ( $curr_line =~ /\\$/ ) {
            $curr_line =~ s/\\$//;

            next;
        }

        if ( $curr_line =~ /^limit ([^ ]*) with (.*)/ ) {
            unless ( $1 and $2 ) {
                return ( -1, "Invalid limit ending on line $line_number" );
            }

            my %limits = ();

            # Sanity check the group
            my $group = lc( $1 );
            if ( $groups{$group} ) {
                return ( -1, "Group $group specified multiple times. Most recently ending on line $line_number" );
            }

            my @pairs = split( ",", $2 );
            foreach my $pair ( @pairs ) {
                my ( $key, $value ) = split( "=", $pair );
                unless ( defined $key and defined $value ) {
                    return ( -1, "Invalid limit in group $group" );
                }

                # Trim whitespace from the key/value pair
                $key   =~ s/^\s+//;
                $key   =~ s/\s+$//;
                $value =~ s/^\s+//;
                $value =~ s/\s+$//;

                $key   = lc( $key );
                $value = lc( $value );

                my ($status, $res) = bwctl_parse_limit({ limit => $key, value => $value });
                unless ($status == 0) {
                    print "Invalid limit $key: $res\n";
                    return (-1, "Invalid limit $key: $res");
                }

                # Returns the parsed value (e.g. 500m is converted to 500000000);
                $value = $res;

                if ( $limits{$key} ) {
                    # Sanity check the limits
                    return ( -1, "Limit $key specified multiple times in group $group" );
                }

                $limits{$key} = $value;
            }

            $groups{$group} = \%limits;
        }
        elsif ( $curr_line =~ /^assign net\s+([^ ]*)\s+(.*)/ ) {
            unless ( $1 and $2 ) {
                return ( -1, "Invalid net assignment on line $line_number" );
            }

            my ( $address, $netmask ) = split( "/", $1 );
            my $group = lc( $2 );

            # Trim whitespace from the key/value pair
            $address =~ s/^\s+//;
            $address =~ s/\s+$//;
            $netmask =~ s/^\s+//;
            $netmask =~ s/\s+$//;

            unless ( $address and $netmask ) {
                return ( -1, "Invalid network assignment on line $line_number: must be in form address/netmask" );
            }

            unless ( $netmask =~ /^[0-9]+$/ ) {
                return ( -1, "Invalid network mask $netmask on line $line_number" );
            }

            my $network = "$address/$netmask";

            if ( $networks{$network} ) {
                return ( -1, "Network $network reassigned on line $line_number" );
            }

            $networks{$network} = $group;
        }
        elsif ( $curr_line =~ /^assign\s+user\s+([^ ]*)\s+(.*)/ ) {
            unless ( $1 and $2 ) {
                return ( -1, "Invalid user assignment on line $line_number" );
            }

            my $user  = lc( $1 );
            my $group = lc( $2 );

            if ( $users{$user} ) {
                return ( -1, "User $user reassigned on line $line_number" );
            }

            $users{$user} = $group;
        }
        elsif ( $curr_line =~ /^assign\s+default\s+(.*)/ ) {
            unless ( $1 ) {
                return ( -1, "Invalid default assignment on line $line_number" );
            }

            if ( $default_group ) {
                return ( -1, "Default group redefined on line $line_number" );
            }

            $default_group = lc( $1 );
        }
        else {
            return ( -1, "Invalid line $line_number" );
        }

        $curr_line = undef;
    }

    my ( $status, $error_msg ) = validate_limits( { groups => \%groups, users => \%users, networks => \%networks, default_group => $default_group } );
    if ( $status != 0 ) {
        return ( $status, $error_msg );
    }

    my %conf = (
        groups        => \%groups,
        users         => \%users,
        networks      => \%networks,
        default_group => $default_group,
    );

    return ( 0, \%conf );
}

sub bwctl_parse_limit {
    my $parameters = validate(
        @_,
        {
            limit         => 1,
            value         => 1,
        }
    );

    my $limit = $parameters->{limit};
    my $value = $parameters->{value};

    unless ($known_limits{$limit}) {
    	print "Unknown limit type: $limit\n";
        return (-1, "Unknown limit type");
    }

    if ($known_limits{$limit}->{type} eq "time") {
        if ($value =~ /^([0-9]+)([sSmMhH]?)$/) {
            $value = $1;
            if ($2) {
                if (lc($2) eq "m") {
                    $value *= 60;
                } elsif (lc($2) eq "h") {
                    $value *= 3600;
                }
            }
        }
        else {
            return (-1, "Invalid time specified ".$value);
        }
    } elsif ($known_limits{$limit}->{type} eq "bandwidth") {
        if ($value =~ /^([0-9]+)([bBkKmMgG]?)$/) {
            $value = $1;
            if ($2) {
                if (lc($2) eq "k") {
                    $value *= 1000;
                } elsif (lc($2) eq "m") {
                    $value *= 1000*1000;
                } elsif (lc($2) eq "g") {
                    $value *= 1000*1000*1000;
                }
            }
        }
        else {
            return (-1, "Invalid bandwidth specified ".$value);
        }
    } elsif ($known_limits{$limit}->{type} eq "disk") {
        if ($value =~ /^([0-9]+)([bBkKmMgG]?)$/) {
            $value = $1;
            if ($2) {
                if (lc($2) eq "k") {
                    $value *= 1024;
                } elsif (lc($2) eq "m") {
                    $value *= 1024*1024;
                } elsif (lc($2) eq "g") {
                    $value *= 1024*1024*1024;
                }
            }
        }
        else {
            return (-1, "Invalid disk unit specified ".$value);
        }
    }

    return (0, $value);
}

sub bwctl_limits_output {
    my $parameters = validate(
        @_,
        {
            groups        => 1,
            users         => 0,
            networks      => 0,
            default_group => 0,
        }
    );

    my $groups        = $parameters->{groups};
    my $users         = $parameters->{users};
    my $networks      = $parameters->{networks};
    my $default_group = $parameters->{default_group};

    my ( $status, $error_msg ) = validate_limits( { groups => $groups, users => $users, networks => $networks, default_group => $default_group } );
    if ( $status != 0 ) {
        return ( $status, $error_msg );
    }

    my @lines = ();

    my %have_output = ();

    my $output_subroutine = sub {
        my $group        = $_[0];
        my $groups       = $_[1];
        my $output_hash  = $_[2];
        my $output_sub   = $_[3];
        my $output_lines = $_[4];

        return if ( $output_hash->{$group} );

        $output_hash->{$group} = 1;

        if ( $groups->{$group}->{parent} ) {
            $output_sub->( $groups->{$group}->{parent}, $groups, $output_hash, $output_sub, $output_lines );
        }

        my $line  = "limit $group with";
        my $comma = "";
        foreach my $key ( keys %{ $groups->{$group} } ) {
            my $value = $groups->{$group}->{$key};

            next if ($key eq "parent" and not $value);

            $line .= $comma . " " . $key . "=" . $value;
            $comma = ",";
        }

        push @{$output_lines}, $line;
    };

    foreach my $group ( keys %{$groups} ) {
        $output_subroutine->( $group, $groups, \%have_output, $output_subroutine, \@lines );
    }

    if ( $users ) {
        foreach my $user ( keys %{$users} ) {
            my $line = "assign user " . $user . " " . $users->{$user};
            push @lines, $line;
        }
    }

    if ( $networks ) {
        foreach my $network ( keys %{$networks} ) {
            my $line = "assign net " . $network . " " . $networks->{$network};
            push @lines, $line;
        }
    }

    if ( $default_group ) {
        my $line = "assign default $default_group";
        push @lines, $line;
    }

    return ( 0, \@lines );
}

sub validate_limits {
    my $parameters = validate(
        @_,
        {
            groups        => 1,
            users         => 0,
            networks      => 0,
            default_group => 0,
        }
    );

    my $groups        = $parameters->{groups};
    my $users         = $parameters->{users};
    my $networks      = $parameters->{networks};
    my $default_group = $parameters->{default_group};

    foreach my $group ( keys %{$groups} ) {
        foreach my $key ( keys %{ $groups->{$group} } ) {
            unless ( $known_limits{$key} ) {
                return ( -1, "Invalid limit specified in group $group: $key" );
            }
            if ($known_limits{$key}->{type} eq "boolean") {
                unless ($groups->{$group}->{$key} eq "on" or $groups->{$group}->{$key} eq "off") {
                    return (-1, "Invalid limit value for $key. Must be either 'on' or 'off'");
                }
            } elsif ($known_limits{$key}->{type} eq "group") {
                if ($groups->{$group}->{$key} and not $groups->{ $groups->{$group}->{$key} } ) {
                    return ( -1, "Invalid parent group specified in group $group: " . $groups->{$group}->{$key} );
                }
            }
        }
    }

    if ( $users ) {
        foreach my $user ( keys %{$users} ) {
            unless ( $groups->{ $users->{$user} } ) {
                return ( -1, "User $user has an invalid group: " . $users->{$user} );
            }
        }
    }

    if ( $networks ) {
        foreach my $network ( keys %{$networks} ) {
            unless ( $groups->{ $networks->{$network} } ) {
                return ( -1, "Network $network has an invalid group: " . $networks->{$network} );
            }
        }
    }

    if ( $default_group and not $groups->{$default_group} ) {
        return ( -1, "Invalid default group: " . $default_group );
    }

    return ( 0, "" );
}

1;
