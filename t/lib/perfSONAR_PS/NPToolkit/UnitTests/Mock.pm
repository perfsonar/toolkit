package perfSONAR_PS::NPToolkit::UnitTests::Mock;

#use fields qw( );

=head1 NAME
perfSONAR_PS::NPToolkit::UnitTests::Mock - Mock functions for unit tests
=head1 DESCRIPTION
This module provides mock functions for unit tests
=cut

use strict;
use warnings;

our $VERSION = 3.6;

use base 'Exporter';
#use FindBin qw($Bin);
use Log::Log4perl qw(:easy);
use Config::General;
use Params::Validate qw(:all);
use Data::Dumper;

our @EXPORT_OK = qw( save_file_mock success_value );

sub succeed_value {
    my $success = shift;
    #$success = shift;
    warn "success: $success";
    return $success;
}

# override the saveFile method
# return 0 if successful, -1 if unsuccessful
sub save_file_mock {
    my $success = shift;
    my $self = shift;
    my $parameters = validate(
        @_,
        {
            filename => 1,
            content  => 1,
        }
    );

    return -1 unless $success;

    my $filename    = $parameters->{filename};
    my $contents = $parameters->{content};
    warn "filename: $filename; save_success: $success";

    # return an error if filename contains '..' or stars with '/'
    # as this means it's attempting to write to a parent directory
    if ( $filename =~ m|\.\.| or $filename =~ m|^/| ) {
        warn "Error: filename attempts to write a parent directory";
        return (-1, "Error: unit test attempts to write a parent directory");
    }

    my ($status, $res);

    unless (open( FILE, ">:utf8", $filename ) ) {
        my $msg = "Couldn't write $filename: $@";
        return -1;
    }

    print FILE $contents;
    close( FILE );

    return 0;
}


1;
