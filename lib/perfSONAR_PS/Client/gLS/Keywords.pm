package perfSONAR_PS::Client::gLS::Keywords;

use strict;
use warnings;

our $VERSION = 3.2;

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
use perfSONAR_PS::Client::gLS;

=head2 new( $package, { hints_url => 0, hints_file => 0, cache_directory => 0 } )

Create new object.

=cut

sub new {
    my ( $package, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            hints_url       => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF | Params::Validate::SCALAR, optional => 1 },
            hints_file      => { type => Params::Validate::SCALAR | Params::Validate::UNDEF,                              optional => 1 },
            cache_directory => { type => Params::Validate::SCALAR | Params::Validate::UNDEF,                              optional => 1 },
        }
    );

    my $self = fields::new( $package );

    $self->{LOGGER} = get_logger( $package );

    if ( $parameters->{cache_directory} ) {
        $self->{CACHE_DIRECTORY} = $parameters->{cache_directory};
    }
    else {
        $self->{GLS_CLIENT} = perfSONAR_PS::Client::gLS->new( { url => $parameters->{hints_url}, file => $parameters->{hints_file} } );
    }

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

    my $res = open( CACHE, "<", $self->{CACHE_DIRECTORY} . "/list.hls" );

    return (-1, "Couldn't open keyword cache") unless ( $res );

    my %keywords = ();

    while ( <CACHE> ) {
        chomp;
        my @fields = split( /\|/ );

        next unless ( $fields[4] );

        my @keywords = split( /,/, $fields[4] );
        foreach my $keyword ( @keywords ) {
            $keywords{$keyword} = 0 unless ( $keywords{$keyword} );

            $keywords{$keyword}++;
        }
    }
    close( CACHE );

    my ( $mtime ) = ( stat( $self->{CACHE_DIRECTORY}."/list.hls" ) )[9];

    return (0, { time => $mtime, keywords => \%keywords });
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

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2010, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
