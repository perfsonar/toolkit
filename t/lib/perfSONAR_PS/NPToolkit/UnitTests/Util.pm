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

our @EXPORT_OK = qw( test_health positive_number nonnegative_number test_result hash_to_parameters compare_PStests );

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

    # disable logging
    Log::Log4perl->easy_init( {level => 'OFF'} );

    is_deeply($result, $expected, $description);

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
