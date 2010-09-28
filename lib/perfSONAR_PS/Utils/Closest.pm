package perfSONAR_PS::Utils::Closest;

use strict;
use warnings;

use Params::Validate;

use base 'Exporter';

our @EXPORT_OK = qw( find_closest_servers );

use Net::Ping;
use Log::Log4perl qw(get_logger);

sub find_closest_servers {
    my $parameters = validate(
        @_,
        {
            servers        => 1,
            maximum_number => 0,
        }
    );

    my $logger = get_logger("perfSONAR_PS::Utils::Closest");

    my $ping = Net::Ping->new("external");
    $ping->hires();

    my @results = ();

    foreach my $server ( @{ $parameters->{servers} } ) {
        my ( $ret, $duration, $ip ) = $ping->ping( $server, 2 );
        unless ( $ret ) {
            $logger->debug("Didn't receive response from $server");
            next;
	}
	$logger->debug("Server $server took $duration seconds");
        push @results, { address => $server, rtt => $duration };
    }

    @results = sort { $a->{rtt} <=> $b->{rtt} } @results;

    # make sure we only grab the maximum number

    unless ( $parameters->{maximum_number} ) {
        return ( 0, \@results );
    }
    else {
        my @retval = ();

        for ( my $i = 0; $i < $parameters->{maximum_number} and $i < scalar( @results ); $i++ ) {
            push @retval, $results[$i];
        }

        return ( 0, \@retval );
    }
}

1;
