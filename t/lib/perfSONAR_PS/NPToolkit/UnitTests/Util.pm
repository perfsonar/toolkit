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
use Data::Dumper;

our @EXPORT_OK = qw( test_health positive_number nonnegative_number test_result hash_to_parameters );

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

sub test_result {
    my ( $result, $expected, $description ) = @_;
    $description = "Test result data is as expected" if not defined $description or $description eq '';
    #my ($result, $expected, $extra_conf) = @_;

    # disable logging
    Log::Log4perl->easy_init( {level => 'OFF'} );

    #build basic config
    #my %conf = ();
    #$conf{'ls_instance'} =  TEST_LS_INSTANCE;
    #$conf{'client_uuid_file'} = TEST_CLIENT_UUID_FILE;
    #$conf{'ls_key_db'} = TEST_KEY_DB;
    #$conf{'allow_internal_addresses'} = 1; #increase autodetection chances
    #foreach my $opt(keys %{ $extra_conf }){
    #    $conf{$opt} = $extra_conf->{$opt};
    #}
    ##test_init
    #ok($record->init(\%conf) == 0, "service init");

    is_deeply($result, $expected, $description);

    # use Data::Dumper;
    # print Dumper($registration);

}

# Takes a hashref of variables to set and converts it to the format taken by
# the webservice libraries
sub hash_to_parameters {
    my ( $values ) = @_;
    my $parameters = {};
    warn "values:\n" . Dumper $values;

    # disable logging
    Log::Log4perl->easy_init( {level => 'OFF'} );
    while ( my ( $key, $value ) = each ( %$values ) ) { 
        my $row = {};

        $parameters->{$key}->{is_set} = 1;
        $parameters->{ $key }->{'value'} = $value;
        #$row->{$key}->{is_set} = 1;
        #$row->{ $key }->{'value'} = $value;

        #push @$parameters, $row;
    }
    warn "parameters:\n" . Dumper $parameters;
    return $parameters;
}

1;
