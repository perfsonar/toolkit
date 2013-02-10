package perfSONAR_PS::NPToolkit::Config::Base;

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::Base;

=head1 DESCRIPTION

This module provides the base for all of the NPToolkit::Config modules. The
provided functions are common to all the NPToolkit::Config modules, and must be
over-ridden by them. The semantics of the functions must be the same across all
modules.

=cut

use Log::Log4perl qw(get_logger :nowarn);
use Params::Validate qw(:all);

use fields 'LOGGER';

sub new {
    my ( $package, @params ) = @_;
    my $parameters = validate( @params, { saved_state => 0, } );

    my $self = fields::new( $package );

    $self->{LOGGER} = get_logger( $package );

    if ( $parameters->{saved_state} ) {
        $self->restore_state( { state => $parameters->{saved_state} } );
    }

    return $self;
}

=head2 init()
    Initializes the module.
=cut

sub init {
    return 0;
}

=head2 save_state()
    Saves the current state of the module as a string. This state allows the
    module to be recreated later.
=cut

sub save_state {
    die( "This function must be overridden" );
}

=head2 restore_state({ state => \$state })
    Restores the modules state based on a string provided by the "save_state"
    function above.
=cut

sub restore_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { state => 1, } );

    die( "This function must be overridden" );
}

=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
=cut

sub reset_state {
    die( "This function must be overridden" );
}

=head2 save({ restart_services => $restart_services })
    Saves the specified configuration to disk. The services can be restarted by
    specifying the "restart_services" parameter as 1. 
=cut

sub save {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { restart_services => 0, } );

    die( "This function must be overridden" );
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
