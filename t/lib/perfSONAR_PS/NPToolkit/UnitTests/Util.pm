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
use Test::Deep;
use Config::General;
use Params::Validate qw(:all);
use Scalar::Util qw(looks_like_number);
use Data::Dumper;

# Set the GEO_RANGE constant, which is used to test for geoip values within a certain threshold (in degrees)
use constant GEO_RANGE => 1;

our @EXPORT_OK = qw( test_health positive_number nonnegative_number test_result hash_to_parameters compare_PStests geo_range );

sub test_health {
    my $values = @_;

}

my $current_expected_geo_value;

sub geo_range {
    my ( $value, $expected ) = @_;
    if ( not defined $expected ) { 
        $expected = $current_expected_geo_value;
    }
    if ( $value < $expected + GEO_RANGE and
         $value > $expected - GEO_RANGE ) {
        return 1;
    }
    return 0;

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

    my @geoip_fields = (
        'latitude',
        'longitude',
        'time_zone',
        #'state',
        #'city',
        #'code'
    );

    # disable logging
    Log::Log4perl->easy_init( {level => 'OFF'} );


    # check geoip values manually

    while ( my ($key, $val ) = each %$result ) {
        my $exp_val = $expected->{ $key };
        $current_expected_geo_value = $exp_val;
        if ( $key eq 'latitude' or $key eq 'longitude' ) {
            cmp_deeply( $val, code(\&geo_range) );
        } elsif ( $key eq 'time_zone' ) {
            # we only care about the first("continent") portion in the format Continent/City or Continent/State/City or similar
            $exp_val =~ m|^([^/]+)/|;
            my $exp_cont = $1;
            $val =~ m|^([^/]+)/|;
            my $cont_val = $1;
            is ( $exp_cont, $exp_cont, "Continient for Time Zone is as expected" );

        }

        #methods(name => "John", phone => "55378008"),


    }

    # create copies of results/expected as we are about to delete the geop values

    my $res_copy = \%$result;
    my $exp_copy = \%$expected;


    foreach my $field ( @geoip_fields ) {
        delete $res_copy->{ $field };
        delete $exp_copy->{ $field };
    }


    #is_deeply($result, $expected, $description);
    cmp_deeply($res_copy, $exp_copy, $description);

    # ignore these
    # time_zone
    # latitude
    # longitude
    # state_abbr
    # state
    # city
    # code
    # country
    # country_full
    

}

# Takes a hashref of variables to set and converts it to the format taken by
# the webservice libraries
sub hash_to_parameters {
    my ( $values ) = @_;
    my $parameters = {};

    # disable logging
    Log::Log4perl->easy_init( {level => 'OFF'} );
    while ( my ( $key, $value ) = each ( %$values ) ) { 
        $parameters->{$key}->{is_set} = 1;
        $parameters->{ $key }->{'value'} = $value;
    }
    return $parameters;
}

# Compares hashes for perfSonar tests to expected hashes, not expecting the order of elements to match. 
# Inputs should be array-references (arrays of tests from $data->{'test_configuration'}).
# All the expected tests and their parameters need to be present in the data with matching values.
# Any values that are not expected to match should be removed, along with their keys, from the $expected_tests hash.
# Any extra info in the test data won't cause a fail.
sub compare_PStests {
    my ( $tests, $expected_tests ) = @_;

    foreach my $expected_test (@$expected_tests) {

        # identify tests by their descriptions
        my $expected_desc = $expected_test->{'description'};

        # find the current expected test in the data
        my $found = 0;
        foreach my $test (@$tests) {
            if ($test->{'description'} eq $expected_desc ) {
                $found = 1;

                while (my ($key, $expected_value) = each %$expected_test ) {
                    next if (ref($expected_value));
                    is($test->{$key}, $expected_value, "$key - in Test <$expected_desc>");
                }

                # check for expected test parameters
                my $expected_params = $expected_test->{'parameters'};
                my $params = $test->{'parameters'};

                while (my ($key, $expected_value) = each %$expected_params) {
                    ##warn ("comparing ".$key.": ".$params->{$key}." = ".$expected_value."        ");
                    is($params->{$key}, $expected_value, "$key - in Test <$expected_desc>");
                }

                # check for expected test members
                my $expected_members = $expected_test->{'members'};
                my $members = $test->{'members'};

                foreach my $expected_member (@$expected_members) {
                    # find this expected member
                    my $mfound = 0;
                    foreach my $member (@$members) {
                        my $expected_mem_desc = $expected_member->{'description'};
                        if ($member->{'description'} eq $expected_mem_desc) {
                            $mfound = 1;
                            # check the member info
                            while (my ($key, $expected_value) = each %$expected_member) {
                                #warn ('comparing member '.$key.': '.$member->{$key}." == ".$expected_value."        ") if $member->{$key}  ne $expected_value;
                                is($member->{$key}, $expected_value, "$key - in Member <$expected_mem_desc>");
                            }
                        }
                    }
                    is($mfound, 1, "Find Member <$expected_member->{'description'}> in Test <$expected_desc>");
                }
                # go to next expected test
                last;
            }
        }
        is($found, 1, "Find Test <$expected_desc>");
    }

}
1;
