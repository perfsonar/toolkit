package perfSONAR_PS::NPToolkit::Config::NPAD;

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::NPAD

=head1 DESCRIPTION

Module for configuring the displayed NPAD index page. Longer term, This should
get extended to configure all aspects of NDT configuration. Currently, there's
no way to re-read the current configuration so this simply overwrites what is
currently in place. This uses a template file (diag_form_html.tmpl) to create
the new diag_form.html.

=cut

use Template;

use base 'perfSONAR_PS::NPToolkit::Config::Base';

use fields 'DIAG_FORM_HTML_FILE', 'DIAG_FORM_HTML_TEMPLATE', 'ADMINISTRATOR_NAME', 'ADMINISTRATOR_EMAIL', 'ORGANIZATION_NAME', 'LOCATION';

use Params::Validate qw(:all);
use Storable qw(store retrieve freeze thaw dclone);
use Data::Dumper;
use File::Basename qw(dirname basename);

use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw( save_file restart_service );

# These are the defaults for the current NPToolkit
my %defaults = (
    diag_form_html_file     => "/var/lib/npad/diag_form.html",
    diag_form_html_template => "/opt/perfsonar_ps/toolkit/templates/config/diag_form_html.tmpl",
);

=head2 init({ diag_form_html_file => 0, diag_form_html_template => 0 })

Initializes the client. Returns 0 on success and -1 on failure. The
diag_form_html_template should point to the file that gets written by the
module, and diag_form_html_template should point to the template used to
generate the diag_form.html file.

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            diag_form_html_file     => 0,
            diag_form_html_template => 0,
        }
    );

    # Initialize the defaults
    $self->{DIAG_FORM_HTML_FILE}     = $defaults{diag_form_html_file};
    $self->{DIAG_FORM_HTML_TEMPLATE} = $defaults{diag_form_html_template};

    # Override any
    $self->{DIAG_FORM_HTML_FILE}     = $parameters->{diag_form_html_file}     if ( $parameters->{diag_form_html_file} );
    $self->{DIAG_FORM_HTML_TEMPLATE} = $parameters->{diag_form_html_template} if ( $parameters->{diag_form_html_template} );

    my $res = $self->reset_state();
    if ( $res != 0 ) {
        return $res;
    }

    return 0;
}

=head2 save({ restart_services => 0 })
    Saves the configuration to disk. NPAD will simply read in the new file so
    the restart_services parameter isn't needed.
=cut

sub save {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { restart_services => 0, } );

    my $diag_form_html_output = $self->generate_diag_form_html_file();

    my $res;

    $res = save_file( { file => $self->{DIAG_FORM_HTML_FILE}, content => $diag_form_html_output } );
    if ( $res == -1 ) {
        return -1;
    }

    if ( $parameters->{restart_services} ) {

        # This current just updates the html so there's no need to
        # actually restart NPAD.

        #        $res = restart_service({ name => "npad" });
        #        if ($res == -1) {
        #            return -1;
        #        }
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

sub get_service_name {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { } );

    return "npad";
}

=head2 last_modified()
    Returns when the site information was last saved.
=cut

sub last_modified {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my ($mtime) = (stat ( $self->{DIAG_FORM_HTML_FILE} ) )[9];

    return $mtime;
}

=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
=cut

sub reset_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    # This information isn't saved currently, so we'd have to read it from the
    # html. Since our only use-case right only ever writes it, we'll ignore
    # this for now.
    $self->{ORGANIZATION_NAME}   = undef;
    $self->{ADMINISTRATOR_EMAIL} = undef;
    $self->{ADMINISTRATOR_NAME}  = undef;
    $self->{LOCATION}            = undef;

    return 0;
}

=head2 generate_diag_form_html_file({})
Takes the configured values and the configured template and generates a string
containing the contents of the diag_form.html file.
=cut

sub generate_diag_form_html_file {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %vars = ();

    my ( $email_username, $email_domain ) = split( '@', $self->{ADMINISTRATOR_EMAIL} );

    $vars{organization_name}            = $self->{ORGANIZATION_NAME};
    $vars{administrator_email}          = $self->{ADMINISTRATOR_EMAIL};
    $vars{administrator_email_domain}   = $email_domain;
    $vars{administrator_email_username} = $email_username;
    $vars{administrator_name}           = $self->{ADMINISTRATOR_NAME};
    $vars{location}                     = $self->{LOCATION};

    my $output;

    my $template_dir  = dirname( $self->{DIAG_FORM_HTML_TEMPLATE} );
    my $template_file = basename( $self->{DIAG_FORM_HTML_TEMPLATE} );

    my $tt = Template->new( INCLUDE_PATH => $template_dir ) or die( "Couldn't initialize template toolkit" );
    $tt->process( $template_file, \%vars, \$output ) or die $tt->error();

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
        diag_form_html_file     => $self->{DIAG_FORM_HTML_FILE},
        diag_form_html_template => $self->{DIAG_FORM_HTML_TEMPLATE},
        admin_name              => $self->{ADMINISTRATOR_NAME},
        admin_email             => $self->{ADMINISTRATOR_EMAIL},
        organization_name       => $self->{ORGANIZATION_NAME},
        location                => $self->{LOCATION},
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

    $self->{DIAG_FORM_HTML_FILE}     = $state->{diag_form_html_file};
    $self->{DIAG_FORM_HTML_TEMPLATE} = $state->{diag_form_html_template};
    $self->{ADMINISTRATOR_NAME}      = $state->{'admin_name'}, $self->{ADMINISTRATOR_EMAIL} = $state->{'admin_email'}, $self->{ORGANIZATION_NAME} = $state->{'organization_name'}, $self->{LOCATION} = $state->{'location'},

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
