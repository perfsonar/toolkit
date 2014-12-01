package OWP::Helper;

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

Helper.pm - Library used to verify tests.

=head1 DESCRIPTION

Library used to verify tests.

=cut

require Exporter;
use vars qw(@ISA @EXPORT $VERSION);

@ISA    = qw(Exporter);
@EXPORT = qw(owpverify_args print_hash split_addr);

$OWP::REVISION = '$Id$';
$VERSION       = '1.0';

sub owpverify_args {
    my ( $allowed, $must, %args ) = @_;
    my %allowed;

    foreach ( @$allowed ) {
        next if !defined $_;
        tr/a-z/A-Z/;
        $allowed{$_} = 1;
    }
    foreach ( @$must ) {
        next if !defined $_;
        tr/a-z/A-Z/;
        $allowed{$_} = 1;
    }

    foreach ( keys %args ) {
        my $name = $_;
        $name =~ tr/a-z/A-Z/;

        if ( !defined( $allowed{$name} ) ) {
            my ( $pack, $fname, $line, $sub ) = caller( 1 );
            warn "$fname\:$line -- $pack\:\:$sub\: Invalid arg $name\n";
            return undef;
        }

        if ( $name ne $_ ) {
            $args{$name} = $args{$_};
            delete $args{$_};
        }
    }

    foreach ( @$must ) {
        next if exists $args{$_};

        my ( $pack, $fname, $line, $sub ) = caller( 1 );
        warn "$fname\:$line -- $pack\:\:$sub\: Missing required arg $_\n";
        return undef;
    }

    my @args = %args;
    return @args;
}

sub print_hash {
    my ( $name, %hash ) = @_;
    my $key;

    foreach $key ( sort keys( %hash ) ) {
        warn "\$$name\{$key\}:\t$hash{$key}\n";
    }
}

#
# XXX: unit test eventually...
# Test cases:
#   [2001:468:1:12::16:98]:8725
#   2001:468:1:12::16:98
#   [2001:468:1:12::16:98]
#   192.168.1.1
#   192.168.1.1:1234
#   [192.168.1.1]:1234
#   nonsense.org
#   nonsense.org:87632
#   nonsense.org:8763292837492847
sub split_addr {
    my ( $fulladdr ) = @_;

    my ( $cnt, $addr, $port );

    $_ = $fulladdr;

    # any spaces is an error
    if ( ( $cnt = tr/ \t\n\r\f// ) > 0 ) {
        warn "split_addr(): Address \"$fulladdr\" contains $cnt whitespace chars";
        return ( undef, undef );
    }

    # full brackets
    if ( ( $addr, $port ) = /^\[([^\]]*)\]\:(\d*)$/ ) {
        ;
    }

    # brackets - no port
    elsif ( ( $addr ) = /^\[([^\]]*)\]$/ ) {
        ;
    }

    # no brackets, more than one ':' indicates bare v6 - no port
    elsif ( ( tr/:/:/ ) > 1 ) {
        $addr = $fulladdr;
    }

    # hostname with
    elsif ( ( $addr, $port ) = /^([^:]*)\:(\d*)$/ ) {
        ;
    }
    else {
        $addr = $fulladdr;
    }

    if ( defined( $port ) ) {
        if ( ( length( $port ) < 1 ) || ( $port == 0 ) ) {
            undef $port;
        }
        elsif ( $port > 65535 ) {
            warn "split_addr(): Address \"$fulladdr\" specifies an invalid port value \"$port\"";
            return ( undef, undef );
        }
    }

    return ( $addr, $port );
}

__END__

=head1 SEE ALSO

L<>, 

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS git repository is located at:

  https://code.google.com/p/perfsonar-ps/

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

Jeff Boote, boote@internet2.edu

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

Copyright (c) 2007-2010, Internet2

All rights reserved.

=cut
