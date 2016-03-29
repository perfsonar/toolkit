package perfSONAR_PS::NPToolkit::UnitTests::Util;

use fields qw( authenticated error_code error_message );

=head1 NAME
perfSONAR_PS::NPToolkit::UnitTests::Util - Utility class for unit tests
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
use Scalar::Util qw(looks_like_number);

our @EXPORT_OK = qw( test_health positive_number nonnegative_number );

sub test_health {
    my $values = @_;

}

sub positive_number {
    my $value = shift;
    if ( looks_like_number($value) && $value > 0 ) {
        return 1;
    }
    return 0;
}

sub nonnegative_number {
    my $value = shift;
    if ( looks_like_number($value) && $value >= 0 ) {
        return 1;
    }
    return 0;
}

1;
