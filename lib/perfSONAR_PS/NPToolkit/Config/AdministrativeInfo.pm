package perfSONAR_PS::NPToolkit::Config::AdministrativeInfo;

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::AdministrativeInfo

=head1 DESCRIPTION

Module for configuring the "Administrative Information". This includes the
keywords for the node, the node's organization and location, the administrators
name and email. When this module's save function is called, it also configures
NDT and NPAD since they both use these same settings for their configuration.

=cut

use base 'perfSONAR_PS::NPToolkit::Config::Base';

use fields 'SITE_INFO_FILE', 'ADMINISTRATOR_NAME', 'ADMINISTRATOR_EMAIL', 'ORGANIZATION_NAME', 'LOCATION', 'KEYWORDS', 'CITY', 'REGION', 'COUNTRY', 'ZIP_CODE','LATITUDE','LONGITUDE';

use Params::Validate qw(:all);
use Storable qw(store retrieve freeze thaw dclone);
use Data::Dumper;

use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw( save_file restart_service );
use perfSONAR_PS::NPToolkit::Config::NDT;
use perfSONAR_PS::NPToolkit::Config::NPAD;
use perfSONAR_PS::NPToolkit::Config::PingER;
use perfSONAR_PS::NPToolkit::Config::perfSONARBUOYMA;
use perfSONAR_PS::NPToolkit::Config::TracerouteMA;
use perfSONAR_PS::NPToolkit::Config::SNMPMA;
use perfSONAR_PS::NPToolkit::Config::hLS;
use perfSONAR_PS::NPToolkit::Config::LSRegistrationDaemon;

# These are the defaults for the current NPToolkit
my %defaults = ( administrative_info_file => "/opt/perfsonar_ps/toolkit/etc/administrative_info", );

=head2 init({ administrative_info_file => 0 })

Initializes the client. Returns 0 on success and -1 on failure. The
administrative_info_file, if specified, should point to the file that gets read/written
by the module.

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { administrative_info_file => 0, } );

    # Initialize the defaults
    $self->{SITE_INFO_FILE} = $defaults{administrative_info_file};

    # Override any
    $self->{SITE_INFO_FILE} = $parameters->{administrative_info_file} if ( $parameters->{administrative_info_file} );

    my $res = $self->reset_state();
    if ( $res != 0 ) {
        return $res;
    }

    return 0;
}

=head2 save({ restart_services => 0 })
    Saves the configuration to disk. All the perfSONAR services depend way on
    the information configured here. The NDT and NPAD configurations are
    updated here as well.
=cut

sub save {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { restart_services => 0, } );

    my $administrative_info_output = $self->generate_administrative_info_file();

    my $res;

    $res = save_file( { file => $self->{SITE_INFO_FILE}, content => $administrative_info_output } );
    if ( $res == -1 ) {
        return (-1, "Problem saving administrative information");
    }

    my @keywords = keys %{ $self->{KEYWORDS} };

    my $ndt_config = perfSONAR_PS::NPToolkit::Config::NDT->new();
    if ( $ndt_config->init() != 0 ) {
        return (-1, "Couldn't initialize NDT configuration");
    }
    my $npad_config = perfSONAR_PS::NPToolkit::Config::NPAD->new();
    if ( $npad_config->init() != 0 ) {
        return (-1, "Couldn't initialize NPAD configuration");
    }

    my $pinger_config = perfSONAR_PS::NPToolkit::Config::PingER->new();
    if ( $pinger_config->init() != 0 ) {
        return (-1, "Couldn't initialize PingER configuration");
    }

    my $psb_ma_config = perfSONAR_PS::NPToolkit::Config::perfSONARBUOYMA->new();
    if ( $psb_ma_config->init() != 0 ) {
        return (-1, "Couldn't initialize perfSONARBUOY-MA configuration");
    }

    my $snmp_ma_config = perfSONAR_PS::NPToolkit::Config::SNMPMA->new();
    if ( $snmp_ma_config->init() != 0 ) {
        return (-1, "Couldn't initialize perfSONARBUOY-MA configuration");
    }
    
    my $traceroute_ma_config = perfSONAR_PS::NPToolkit::Config::TracerouteMA->new();
    if ( $traceroute_ma_config->init() != 0 ) {
        return (-1, "Couldn't initialize Traceroute MA configuration");
    }

    my $ls_reg_daemon_config = perfSONAR_PS::NPToolkit::Config::LSRegistrationDaemon->new();
    if ( $ls_reg_daemon_config->init() != 0 ) {
        return (-1, "Couldn't initialize LS Registration Daemon configuration");
    }

    foreach my $service_config ($ndt_config, $npad_config) {
        $service_config->set_location( location => $self->generate_location_string() );
        $service_config->set_administrator_email( administrator_email => $self->{ADMINISTRATOR_EMAIL} );
        $service_config->set_administrator_name( administrator_name => $self->{ADMINISTRATOR_NAME} );
        $service_config->set_organization_name( organization_name => $self->{ORGANIZATION_NAME} );
        $res = $service_config->save({ restart_services => $parameters->{restart_services} });
        if ($res != 0) {
            return (-1, "Couldn't save or restart ".$service_config->get_service_name);
        }
    }

    foreach my $service_config ($pinger_config, $psb_ma_config, $snmp_ma_config, $traceroute_ma_config, $ls_reg_daemon_config) {
        $service_config->set_administrator_email( administrator_email => $self->{ADMINISTRATOR_EMAIL} );
        $service_config->set_administrator_name( administrator_name => $self->{ADMINISTRATOR_NAME} );
        $service_config->set_city( city => $self->{CITY} );
        $service_config->set_state( state => $self->{REGION} );
        $service_config->set_country( country => $self->{COUNTRY} );
        $service_config->set_zipcode( zipcode => $self->{ZIP_CODE} );
        $service_config->set_latitude( latitude => $self->{LATITUDE} );
        $service_config->set_longitude( longitude => $self->{LONGITUDE} );
        $service_config->set_organization_name( organization_name => $self->{ORGANIZATION_NAME} );
        $service_config->set_projects( projects => \@keywords );
        $res = $service_config->save({ restart_services => $parameters->{restart_services} });
        if ($res != 0) {
            return (-1, "Couldn't save or restart ".$service_config->get_service_name);
        }
    }
 
    return 0;
}

=head2 set_organization_name({ organization_name => 1 })
Sets the organization's name
=cut

sub set_organization_name {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { organization_name => 1, } );

    my $organization_name = $parameters->{organization_name};

    $self->{ORGANIZATION_NAME} = $organization_name;

    return 0;
}

=head2 set_administrator_name({ administrator_name => 1 })
Sets the administrator's name
=cut

sub set_administrator_name {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { administrator_name => 1, } );

    my $admin_name = $parameters->{administrator_name};

    $self->{ADMINISTRATOR_NAME} = $admin_name;

    return 0;
}

=head2 set_administrator_email({ administrator_email => 1 })
Sets the administrator's email 
=cut

sub set_administrator_email {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { administrator_email => 1, } );

    my $admin_email = $parameters->{administrator_email};

    $self->{ADMINISTRATOR_EMAIL} = $admin_email;

    return 0;
}

=head2 set_location({ location => 1 })
Sets the box's location
=cut

sub set_location {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { location => 1, } );

    my $location = $parameters->{location};

    $self->{LOCATION} = $location;

    return 0;
}

=head2 set_city({ city => 1 })
Sets the box's location- city
=cut

sub set_city {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { city => 1, } );

    my $value = $parameters->{city};

    $self->{CITY} = $value;

    return 0;
}


=head2 set_state({ state => 1 })
Sets the box's location- state
=cut

sub set_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { state => 1, } );

    my $value = $parameters->{state};

    $self->{REGION} = $value;

    return 0;
}

=head2 set_country({ country => 1 })
Sets the box's location- country
=cut

sub set_country {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { country => 1, } );

    my $value = $parameters->{country};

    $self->{COUNTRY} = $value;

    return 0;
}

=head2 set_zipcode({ zipcode => 1 })
Sets the box's location- zipcode
=cut

sub set_zipcode {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { zipcode => 1, } );

    my $value = $parameters->{zipcode};

    $self->{ZIP_CODE} = $value;

    return 0;
}

=head2 set_latitude({ latitude => 1 })
Sets the box's latitude
=cut

sub set_latitude {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { latitude => 1, } );

    my $value = $parameters->{latitude};

    $self->{LATITUDE} = $value;

    return 0;
}

=head2 set_longitude({ longitude => 1 })
Sets the box's longitude
=cut

sub set_longitude {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { longitude => 1, } );

    my $value = $parameters->{longitude};

    $self->{LONGITUDE} = $value;

    return 0;
}

=head2 generate_location_string({})
Generates a human-readable string with the location
=cut 
sub generate_location_string {
    my ( $self ) = @_;
    
    my @loc_fields = ( 'CITY', 'REGION', 'COUNTRY' );
    my $loc_string = "";
    foreach my $loc(@loc_fields){
        next if(!$self->{$loc});
        $loc_string .= ', ' if($loc_string);
        $loc_string .= $self->{$loc};
    }

    return $loc_string;
}

=head2 add_keyword ({ keyword => 1 })

Adds the specified keyword to the configuration. Returns 0 on success, -1 on
failure. No current failure conditions exist.

=cut

sub add_keyword {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { keyword => 1, } );

    $self->{KEYWORDS}->{ $parameters->{keyword} } = 1;

    return 0;
}

=head2 delete_keyword ({ keyword => 1 })

Deletes the specified keyword to the configuration. Returns 0 on success, -1 on
failure. No current failure conditions exist.

=cut

sub delete_keyword {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { keyword => 1, } );

    delete( $self->{KEYWORDS}->{ $parameters->{keyword} } );

    return 0;
}

=head2 get_keywords ({})

Returns the list of currently configured keywords as an array. 

=cut

sub get_keywords {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my @keywords = keys %{ $self->{KEYWORDS} };

    return \@keywords;
}

=head2 get_administrator_name ({})
Returns the administrator's name
=cut

sub get_administrator_name {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{ADMINISTRATOR_NAME};
}

=head2 get_administrator_email ({})
Returns the administrator's email
=cut

sub get_administrator_email {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{ADMINISTRATOR_EMAIL};
}

=head2 get_organization_name ({})
Returns the organization's name
=cut

sub get_organization_name {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{ORGANIZATION_NAME};
}

=head2 get_location ({})
Returns the node's configured location
=cut

sub get_location {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{LOCATION};
}


=head2 get_city ({})
Returns the node's configured city
=cut

sub get_city {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{CITY};
}


=head2 get_state ({})
Returns the node's configured state
=cut

sub get_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{REGION};
}

=head2 get_country ({})
Returns the node's configured country
=cut

sub get_country {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{COUNTRY};
}

=head2 get_zipcode ({})
Returns the node's configured zipcode
=cut

sub get_zipcode {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{ZIP_CODE};
}

=head2 get_latitude ({})
Returns the node's configured latitude
=cut

sub get_latitude {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{LATITUDE};
}

=head2 get_longitude ({})
Returns the node's configured location
=cut

sub get_longitude {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{LONGITUDE};
}



=head2 last_modified()
    Returns when the site information was last saved.
=cut

sub last_modified {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my ($mtime) = (stat ( $self->{SITE_INFO_FILE} ) )[9];

    return $mtime;
}

=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
=cut

sub reset_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my ( $status, $res ) = read_administrative_info_file( { file => $self->{SITE_INFO_FILE} } );
    if ( $status == 0 ) {
        $self->{ORGANIZATION_NAME}   = $res->{organization_name};
        $self->{ADMINISTRATOR_EMAIL} = $res->{administrator_email};
        $self->{ADMINISTRATOR_NAME}  = $res->{administrator_name};
        $self->{LOCATION}            = $res->{location};
        $self->{KEYWORDS}            = $res->{keywords};
        $self->{CITY}            	 = $res->{city};
        $self->{REGION}           	 = $res->{state};
        $self->{COUNTRY}             = $res->{country};
        $self->{ZIP_CODE}             = $res->{zipcode};
        $self->{LATITUDE}            = $res->{latitude};
        $self->{LONGITUDE}           = $res->{longitude};
    }

    return 0;
}

=head2 read_administrative_info_file ({ file => 1 })

Reads the site.info file specified in the parameters and returns a hash containing administrator_email, keywords, organization_name, administrator_name and location as keys.

=cut

sub read_administrative_info_file {
    my $parameters = validate( @_, { file => 1, } );

    unless ( open( SITE_INFO_FILE, $parameters->{file} ) ) {
        my %info     = ();
        my %keywords = ();
        $info{keywords} = \%keywords;
        return ( 0, \%info );
    }

    my $administrator_name;
    my $organization_name;
    my $location;
    my $email_user;
    my $email_host;
    my $administrator_email;
    my $city;
    my $state;
    my $country;
    my $zipcode;
    my $latitude;
    my $longitude;
    my %keywords = ();

    while ( <SITE_INFO_FILE> ) {
        chomp;
        my ( $variable, $value ) = split( '=' );
        $value =~ s/^\s+//;
        $value =~ s/\s+$//;

        if ( $variable eq "full_name" ) {
            $administrator_name = $value;
        }
        elsif ( $variable eq "site_name" ) {
            $organization_name = $value;
        }
        elsif ( $variable eq "site_location" ) {
            $location = $value;
        }
        elsif ( $variable eq "email_usr" ) {
            $email_user = $value;
        }
        elsif ( $variable eq "email_hst" ) {
            $email_host = $value;
        }
        elsif ( $variable eq "administrator_email" ) {
            $administrator_email = $value;
        }
        elsif ( $variable eq "site_project" ) {
            $keywords{$value} = 1;
        }elsif ( $variable eq "city" ) {
            $city = $value;
        }elsif ( $variable eq "state" ) {
            $state = $value;
        }elsif ( $variable eq "country" ) {
            $country = $value;
        }elsif ( $variable eq "zipcode" ) {
            $zipcode = $value;
        }elsif ( $variable eq "latitude" ) {
            $latitude = $value;
        }elsif ( $variable eq "longitude" ) {
            $longitude = $value;
        }
    }

    unless ( $administrator_email ) {
        if ( $email_host and $email_user ) {
            $administrator_email = $email_user . "@" . $email_host;
        }
    }
    close( SITE_INFO_FILE );

    my %info = (
        administrator_email => $administrator_email,
        keywords            => \%keywords,
        organization_name   => $organization_name,
        administrator_name  => $administrator_name,
        location            => $location,
        city            	=> $city,
        state            	=> $state,
        country            	=> $country,
        zipcode				=> $zipcode,
        latitude			=> $latitude,
        longitude			=> $longitude
    );

    return ( 0, \%info );
}

=head2 has_admin_info({})

Returns 1 if admin info is present and 0 if not.

=cut

sub has_admin_info{
	my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );
    
    return ($self->{ADMINISTRATOR_NAME} && $self->{ORGANIZATION_NAME} && $self->{ADMINISTRATOR_EMAIL} && $self->{LOCATION});
	
}


=head2 generate_administrative_info_file({})

Takes the current configuration for the module and generates the content for the site.info file.

=cut

sub generate_administrative_info_file {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    # The chosen names for this file are quite stupid, but retained for
    # backward compatibility.

    my $output = "";

    $output .= "full_name=" . $self->{ADMINISTRATOR_NAME} . "\n";
    $output .= "site_name=" . $self->{ORGANIZATION_NAME} . "\n";
    $output .= "site_location=" . $self->{LOCATION} . "\n";
    foreach my $keyword ( keys %{ $self->{KEYWORDS} } ) {
        $output .= "site_project=" . $keyword . "\n";
    }
    $output .= "administrator_email=" . $self->{ADMINISTRATOR_EMAIL} . "\n";
	$output .= "city=" . $self->{CITY} . "\n";
	$output .= "state=" . $self->{REGION} . "\n";
	$output .= "country=" . $self->{COUNTRY} . "\n";
	$output .= "zipcode=" . $self->{ZIP_CODE} . "\n";
	$output .= "latitude=" . $self->{LATITUDE} . "\n";
	$output .= "longitude=" . $self->{LONGITUDE} . "\n";
    return $output;
}

=head2 save_state()
    Saves the current state of the module as a string. This state allows the
    module to be recreated later.
=cut

sub save_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %state = (
        administrative_info_file    => $self->{SITE_INFO_FILE},
        admin_name        => $self->{ADMINISTRATOR_NAME},
        admin_email       => $self->{ADMINISTRATOR_EMAIL},
        organization_name => $self->{ORGANIZATION_NAME},
        location          => $self->{LOCATION},
        keywords          => $self->{KEYWORDS},
        city			  => $self->{CITY},
        state			  => $self->{REGION},
        country			  => $self->{COUNTRY},
        zipcode			  => $self->{ZIP_CODE},
        latitude		  => $self->{LATITUDE},
        longitude		  => $self->{LONGITUDE},
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

    $self->{SITE_INFO_FILE} = $state->{'administrative_info_file'}, $self->{ADMINISTRATOR_NAME} = $state->{'admin_name'}, $self->{ADMINISTRATOR_EMAIL} = $state->{'admin_email'}, $self->{ORGANIZATION_NAME} = $state->{'organization_name'}, $self->{LOCATION} = $state->{'location'},
        $self->{KEYWORDS} = $state->{'keywords'},
        $self->{CITY} = $state->{'city'},$self->{REGION} = $state->{'state'},$self->{COUNTRY} = $state->{'country'}, $self->{ZIP_CODE} = $state->{'zipcode'},
        $self->{LATITUDE} = $state->{'latitude'}, $self->{LONGITUDE} = $state->{'longitude'},

        $self->{LOGGER}->debug( "State: " . Dumper( $state ) );
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

