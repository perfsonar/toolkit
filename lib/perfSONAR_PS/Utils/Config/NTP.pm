package perfSONAR_PS::Utils::Config::NTP;

use strict;
use warnings;

use Params::Validate;

use base 'Exporter';

our @EXPORT_OK = qw( ntp_conf_read ntp_conf_read_file );

sub ntp_conf_read_file {
    my $parameters = validate( @_, { file => 1, } );

    unless ( open( NTP_CONF_FILE, $parameters->{file} ) ) {
        return ( -1, "Couldn't open file: " . $parameters->{file} );
    }

    my @lines = <NTP_CONF_FILE>;

    close( NTP_CONF_FILE );

    return ntp_conf_read( { lines => \@lines } );
}

sub ntp_conf_read {
    my $parameters = validate( @_, { lines => 1, } );

    my @servers = ();

    foreach my $line ( @{ $parameters->{lines} } ) {
        chomp( $line );

        if ( $line =~ /^\s*server\s*([^ ]+)/ ) {
            push @servers, $1;
        }
    }

    return ( 0, \@servers );
}

1;
