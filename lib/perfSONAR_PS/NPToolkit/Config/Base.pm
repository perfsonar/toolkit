package perfSONAR_PS::NPToolkit::Config::Base;

use strict;
use warnings;

our $VERSION = 3.1;

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

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

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

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
