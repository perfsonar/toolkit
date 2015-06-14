package perfSONAR_PS::Client::gLS::Keywords;

use strict;
use warnings;

our $VERSION = 3.3;

use fields 'GLS_CLIENT', 'CACHE_DIRECTORY', 'LOGGER';

=head1 NAME

perfSONAR_PS::Client::gLS::Keywords

=head1 DESCRIPTION

API for retrieving the set of keywords from the lookup service infrastructure.
Currently, it only supports looking up keywords from the cache, but in the
future, this could be modified to do live lookups.

=cut

use Log::Log4perl qw( get_logger );
use Params::Validate qw( :all );
use English qw( -no_match_vars );
use LWP::Simple;
use Net::Ping;
use XML::LibXML;
use Digest::MD5 qw(md5_hex);

use perfSONAR_PS::Utils::ParameterValidation;

=head2 new( $package, { hints_url => 0, hints_file => 0, cache_directory => 0 } )

Create new object.

=cut

sub new {
    my ( $package, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            cache_directory => { type => Params::Validate::SCALAR | Params::Validate::UNDEF,                              optional => 0 },
        }
    );

    my $self = fields::new( $package );

    $self->{LOGGER} = get_logger( $package );
    $self->{CACHE_DIRECTORY} = $parameters->{cache_directory};

    return $self;
}

=head2 get_keywords({})

Returns a list of known keywords. This list may not be exhaustive, but should
be useful enough for common use-cases.

=cut

sub get_keywords {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    my $keywords;

    if ( $self->{CACHE_DIRECTORY} ) {
        return $self->get_cached_keywords();
    } else {
        return (-1, "No cache directory available");
    }
}

=head2 get_cached_keywords({})

Returns a list of known keywords gathered from the gLS caching infrastructure.
The keywords are returned as a hash with the keys representing the individual
keywords and the values representing how many services have those keywords.
Currently, the services counted only consist of the hLSes.

=cut

sub get_cached_keywords {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    my $res = open( CACHE, "<", $self->{CACHE_DIRECTORY} . "/list.keywords" );

    return (-1, "Couldn't open keyword cache") unless ( $res );

    my %keywords = ();

    while ( <CACHE> ) {
        chomp;
        my @fields = split( /\|/ );

        next unless ( $fields[1] );

        $keywords{$fields[1]} = 0 unless ( $keywords{$fields[1]} );
        #Add line below back to get word cloud effect
        #$keywords{$fields[1]}++;
    }
    close( CACHE );

    my ( $mtime ) = ( stat( $self->{CACHE_DIRECTORY}."/list.keywords" ) )[9];

    return (0, { time => $mtime, keywords => \%keywords });
}

1;

__END__

=head1 SEE ALSO

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