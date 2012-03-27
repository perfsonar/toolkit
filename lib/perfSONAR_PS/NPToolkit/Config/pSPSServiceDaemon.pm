package perfSONAR_PS::NPToolkit::Config::pSPSServiceDaemon;

use strict;
use warnings;

our $VERSION = 3.2;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::pSPSServiceDaemons

=head1 DESCRIPTION

Module for reading/writing commonly configured aspects of the perfSONAR-PS
service daemon. Currently, the external address, site location and site name
are configurable.

=cut

use Template;

use base 'perfSONAR_PS::NPToolkit::Config::Base';

use fields 'CONFIG_FILE', 'SERVICE_NAME', 'ORGANIZATION_NAME', 'LOCATION', 'EXTERNAL_ADDRESS', 'PROJECTS', 'LS_REGISTRATION_INTERVAL';

use Params::Validate qw(:all);
use Storable qw(store retrieve freeze thaw dclone);
use Data::Dumper;
use File::Basename qw(dirname basename);

use Config::General qw(ParseConfig SaveConfigString);
use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw( save_file restart_service );

=head2 init({ config_file => 1, service_name => 1 })

XXX

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            config_file  => 1,
            service_name => 1,
        }
    );

    $self->{CONFIG_FILE}     = $parameters->{config_file};
    $self->{SERVICE_NAME}    = $parameters->{service_name};

    my $res = $self->reset_state();
    if ( $res != 0 ) {
        return $res;
    }

    return 0;
}

=head2 get_external_address({ external_address => 1 })
Returns the external address used to advertise in the gLS
=cut

sub get_service_name {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { } );

    return $self->{SERVICE_NAME};
}

=head2 get_external_address({ external_address => 1 })
Returns the external address used to advertise in the gLS
=cut

sub get_external_address {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { } );

    return $self->{EXTERNAL_ADDRESS};
}

=head2 get_organization_name({ organization_name => 1 })
Returns the name of the organization to advertise in the gLS
=cut

sub get_organization_name {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { } );

    return $self->{ORGANIZATION_NAME};
}

=head2 get_location({ location => 1 })
Returns the location of the service to advertise in the gLS
=cut

sub get_location {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { } );

    return $self->{LOCATION};
}

=head2 get_projects({ location => 1 })
Returns the location of the service to advertise in the gLS
=cut

sub get_projects {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { } );

    return $self->{PROJECTS};
}

=head2 get_ls_registration_interval({ })
Returns the LS registration interval
=cut

sub get_ls_registration_interval {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { } );

    return $self->{LS_REGISTRATION_INTERVAL};
}

=head2 set_ls_registration_interval({ ls_registration_interval => 1 })
Sets the LS registration interval
=cut

sub set_ls_registration_interval {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { ls_registration_interval => 1, } );

    my $ls_registration_interval = $parameters->{ls_registration_interval};

    $self->{LS_REGISTRATION_INTERVAL} = $ls_registration_interval;

    return 0;
}

=head2 set_external_address({ external_address => 1 })
Sets the external address used to advertise in the gLS
=cut

sub set_external_address {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { external_address => 1, } );

    my $external_address = $parameters->{external_address};

    $self->{EXTERNAL_ADDRESS} = $external_address;

    return 0;
}

=head2 set_organization_name({ organization_name => 1 })
Sets the name of the organization to advertise in the gLS
=cut

sub set_organization_name {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { organization_name => 1, } );

    my $organization_name = $parameters->{organization_name};

    $self->{ORGANIZATION_NAME} = $organization_name;

    return 0;
}

=head2 set_location({ location => 1 })
Sets the location of the service to advertise in the gLS
=cut

sub set_location {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { location => 1, } );

    my $location = $parameters->{location};

    $self->{LOCATION} = $location;

    return 0;
}

=head2 set_projects({ projects => 1 })
Sets the projects of the service to advertise in the gLS
=cut

sub set_projects {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { projects => 1, } );

    my $projects = $parameters->{projects};

    $self->{PROJECTS} = $projects;

    return 0;
}

=head2 last_modified()
    Returns when the site information was last saved.
=cut

sub last_modified {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my ($mtime) = (stat ( $self->{CONFIG_FILE} ) )[9];

    return $mtime;
}

=head2 save({ restart_services => 0 })
    Saves the configuration to disk. 
=cut

sub save {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { restart_services => 0, } );

    my $config = $self->load_config({ file => $self->{CONFIG_FILE} });
    unless ($config) {
        return -1;
    }

    my @config_vars = (
                        {
                            cv => "external_address",
                            lv => "EXTERNAL_ADDRESS",
                            ov => [
                                    "service_accesspoint"
                                  ],
                        },
                        {
                            cv => "site_name",
                            lv => "ORGANIZATION_NAME",
                            ov => [
                                    "service_type",
                                    "service_name",
                                    "service_description"
                                  ],
                        },
                        {
                            cv => "site_location",
                            lv => "LOCATION",
                            ov => [
                                    "service_type",
                                    "service_name",
                                    "service_description"
                                  ],
                        },
                        {
                            cv => "site_project",
                            lv => "PROJECTS",
                            ov => [],
                        },
                        {
                            cv => "ls_registration_interval",
                            lv => "LS_REGISTRATION_INTERVAL",
                            ov => [],
                        }
                    );

    foreach my $var (@config_vars) {
        if (defined $self->{$var->{lv}}) {
            foreach my $ov (@{ $var->{ov} }) {
                $self->psps_config_clear_variable({
                                                    config => $config,
                                                    variable => $ov
                                                });
            }

            my $res = $self->psps_config_replace_variable({
                                                config => $config,
                                                variable => $var->{cv},
                                                value    => $self->{$var->{lv}}
                                            });

            $config->{$var->{cv}} = $self->{$var->{lv}} unless ($res);
        }
    }

    my $content = SaveConfigString_pSPS($config);

    my $res = save_file( { file => $self->{CONFIG_FILE}, content => $content } );
    if ( $res == -1 ) {
        return -1;
    }

    if ( $parameters->{restart_services} ) {
        $res = restart_service({ name => $self->{SERVICE_NAME} });
        if ($res == -1) {
             return -1;
        }
    }

    return 0;
}

=head2 psps_config_replace_variable ({ config => 1, variable => 1 })
    Recursive function that takes a pSPS configuration (as a hash), and finds
    the specified variable, recursing through the structure if needed. It takes
    the most deep instance of that variable.
=cut
sub psps_config_replace_variable {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { config => 1, variable => 1, value => 1 } );

    my $config   = $parameters->{config};
    my $variable = $parameters->{variable};
    my $value    = $parameters->{value};

    my $retval;

    foreach my $key (keys %$config) {
        if (ref($config->{$key}) eq "ARRAY") {
            foreach my $entry (@{ $config->{$key} }) {
                if (ref($entry) eq "HASH") {
                    my $res = $self->psps_config_replace_variable({
                                                        config => $entry,
                                                        variable => $variable,
                                                        value    => $value
                                                });

                    $retval = $res if ($res);
                }
            }
        }
        elsif (ref($config->{$key}) eq "HASH") {
            my $res = $self->psps_config_replace_variable({
                                                config => $config->{$key},
                                                variable => $variable,
                                                value    => $value
                                        });
            $retval = $res if ($res);
        }
    }

    foreach my $key (keys %$config) {
        if ($key eq $variable) {
            $config->{$key} = $value;
            $retval = 1;
        }
    }

    return $retval;
}

=head2 psps_config_find_variable ({ config => 1, variable => 1 })
    Recursive function that takes a pSPS configuration (as a hash), and finds
    the specified variable, recursing through the structure if needed. It takes
    the most deep instance of that variable.
=cut
sub psps_config_find_variable {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { config => 1, variable => 1 } );

    my $config   = $parameters->{config};
    my $variable = $parameters->{variable};

    foreach my $key (keys %$config) {
        if (ref($config->{$key}) eq "ARRAY") {
            foreach my $entry (@{ $config->{$key} }) {
                if (ref($entry) eq "HASH") {
                    my $res = $self->psps_config_find_variable({
                                                        config => $entry,
                                                        variable => $variable
                                                });
		    return $res if (defined $res);
                }
            }
        }
        elsif (ref($config->{$key}) eq "HASH") {
            my $res = $self->psps_config_find_variable({
                                                config => $config->{$key},
                                                variable => $variable
                                        });
	    return $res if (defined $res);
        }
    }

    foreach my $key (keys %$config) {
        if ($key eq $variable) {
            return $config->{$key};
        }
    }

    return;
}

=head2 psps_config_clear_variable ({ config => 1, variable => 1 })
    Recursive function that takes a pSPS configuration (as a hash), and deletes
    the specified variable, recursing through the structure if needed.
=cut
sub psps_config_clear_variable {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { config => 1, variable => 1 } );

    my $config   = $parameters->{config};
    my $variable = $parameters->{variable};

    foreach my $key (keys %$config) {
        if ($key eq $variable) {
            delete($config->{$key});
            next;
        }

        if (ref($config->{$key}) eq "ARRAY") {
            foreach my $entry (@{ $config->{$key} }) {
                if (ref($entry) eq "HASH") {
                    $self->psps_config_clear_variable({
                                                        config => $entry,
                                                        variable => $variable
                                                });
                }
            }
        }
        elsif (ref($config->{$key}) eq "HASH") {
            $self->psps_config_clear_variable({
                                                config => $config->{$key},
                                                variable => $variable
                                        });
        }
    }

    return;
}

=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
=cut

sub reset_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my $config = $self->load_config({ file => $self->{CONFIG_FILE} });
    unless ($config) {
        return -1;
    }

    $self->{EXTERNAL_ADDRESS}  = $self->psps_config_find_variable({ config => $config, variable => "external_address" });
    $self->{ORGANIZATION_NAME} = $self->psps_config_find_variable({ config => $config, variable => "site_name" });
    $self->{LOCATION}          = $self->psps_config_find_variable({ config => $config, variable => "site_location" });
    $self->{PROJECTS}          = $self->psps_config_find_variable({ config => $config, variable => "site_project" });
    if ($self->{PROJECTS} and ref($self->{PROJECTS}) ne "ARRAY") {
        $self->{PROJECTS} = [ $self->{PROJECTS} ];
    }
    $self->{LS_REGISTRATION_INTERVAL} = $self->psps_config_find_variable({ config => $config, variable => "ls_registration_interval" });

    return 0;
}

=head2 load_config()
    Resets the state of the module to the state immediately after having run "init()".
=cut
sub load_config {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { file => 1 } );

    my $file = $parameters->{file};

    my %config;
    eval {
        %config = ParseConfig(-ConfigFile => $file, AutoTrue => 1);
    };
    if ($@) {
        return undef;
    }

    return \%config;
}

=head2 save_state()
    Saves the current state of the module as a string. This state allows the
    module to be recreated later.
=cut

sub save_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %state = (
        config_file            => $self->{CONFIG_FILE},
        service_name           => $self->{SERVICE_NAME},
        organization_name      => $self->{ORGANIZATION_NAME},
        location               => $self->{LOCATION},
        external_address       => $self->{EXTERNAL_ADDRESS},
        projects               => $self->{PROJECTS},
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

    $self->{CONFIG_FILE}            = $state->{config_file};
    $self->{SERVICE_NAME}           = $state->{service_name};
    $self->{ORGANIZATION_NAME}      = $state->{organization_name};
    $self->{LOCATION}               = $state->{location};
    $self->{PROJECTS}               = $state->{projects};
    $self->{EXTERNAL_ADDRESS}       = $state->{external_address};

    return;
}

=head2 SaveConfigString_pSPS

TBD

=cut

sub SaveConfigString_pSPS {
    my ( $hash ) = @_;

    my $result = printValue( q{}, $hash, -4 );

    return $result;
}

=head2 printSpaces

TBD

=cut

sub printSpaces {
    my ( $count ) = @_;
    my $str = "";
    while ( $count > 0 ) {
        $str .= " ";
        $count--;
    }
    return $str;
}

=head2 printScalar

TBD

=cut

sub printScalar {
    my ( $name, $value, $depth ) = @_;

    my $str = "";

    $str .= printSpaces( $depth );
    if ( $value =~ /\n/mx ) {
        my @lines = split( $value, '\n' );
        $str .= "$name     <<EOF\n";
        foreach my $line ( @lines ) {
            $str .= printSpaces( $depth );
            $str .= $line . "\n";
        }
        $str .= printSpaces( $depth );
        $str .= "EOF\n";
    }
    else {
        $str .= "$name     " . $value . "\n";
    }

    return $str;
}

=head2 printValue

TBD

=cut

sub printValue {
    my ( $name, $value, $depth ) = @_;

    my $str = "";

    if ( ref $value eq "" ) {
        $str .= printScalar( $name, $value, $depth );
    }
    elsif ( ref $value eq "ARRAY" ) {
        foreach my $elm ( @{$value} ) {
            $str .= printValue( $name, $elm, $depth );
        }
    }
    elsif ( ref $value eq "HASH" ) {
        if ( $name eq "endpoint" or $name eq "port" ) {
            foreach my $elm ( sort keys %{$value} ) {
                $str .= printSpaces( $depth );
                $str .= "<$name $elm>\n";
                $str .= printValue( q{}, $value->{$elm}, $depth + 4 );
                $str .= printSpaces( $depth );
                $str .= "</$name>\n";
            }
        }
        else {
            if ( $name ) {
                $str .= printSpaces( $depth );
                $str .= "<$name>\n";
            }
            foreach my $elm ( sort keys %{$value} ) {
                $str .= printValue( $elm, $value->{$elm}, $depth + 4 );
            }
            if ( $name ) {
                $str .= printSpaces( $depth );
                $str .= "</$name>\n";
            }
        }
    }

    return $str;
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
