package perfSONAR_PS::NPToolkit::UnitTests::Router;

use fields qw( authenticated error_code error_message );

=head1 NAME
perfSONAR_PS::NPToolkit::UnitTests::Router - Fake Router class for init tests
=head1 DESCRIPTION
This module provides methods for writing unit tests
=cut

use strict;
use warnings;

our $VERSION = 3.6;

use base 'Exporter';
use FindBin qw($Bin);
use Log::Log4perl qw(:easy);
use Test::More;
use Config::General;
use Params::Validate qw(:all);

#our @EXPORT_OK = qw( test_ls_record );

sub new {
    my ( $class, @params ) = @_;

    my $self = fields::new( $class );

    Log::Log4perl->easy_init( {level => 'OFF'} );
    # PARAMETERS
    # config_file is required
    # regular_testing_config_file is optional, even if load_regular_testing is specified
    # load_regular_testing is optional
        # if 1, load regular testing config
        # if 0 or not specified, do not load the regular testing config
    my $parameters = validate(
        @params,
        {
            authenticated => 0,
            error_message => 0,
            error_code => 0,
        }
    );

    $self->{'authenticated'} = 0;
    if ( $parameters->{'authenticated'} ) {
        $self->{'authenticated'} = 1;
    }

    return $self;
}

sub call_method {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            method => 1,
            authenticated => 0,
            error_message => 0,
            error_code => 0,
        }
    );
    my $method = $parameters->{'method'};
    return &$method($self);

}

sub set_authenticated {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            authenticated => 1,
        }
    );
    $self->{'authenticated'} = $parameters->{'authenticated'};
    return $self->{'authenticated'};

}


1;


