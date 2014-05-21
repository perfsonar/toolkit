package perfSONAR_PS::Utils::GeoIp;

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME
 
 perfSONAR_PS::Utils::GeoIp
 
=head1 DESCRIPTION
 
 A module that provides utility methods to resolve location based on IPaddress
 =head1 API
 
=cut

use base 'Exporter';
use LWP::Simple;
use JSON;


our @EXPORT_OK = qw( ipToLatLong );

my $GEOIPSERVICE_URL_PREFIX = "http://freegeoip.net/json/";
my $LATITUDE = "latitude";
my $LONGITUDE = "longitude";

=head2 resolve_address ($name)
 
 Resolve an ip address to a Lat,Long.
 
=cut

sub ipToLatLong {
    
    my ( $ip ) = @_;
    
    my $result = ();
    if ($ip) {
        my $url = $GEOIPSERVICE_URL_PREFIX . "";
        my $content = get($url);
        if (defined $content){
            my $json = decode_json($content);
            $result->{$LATITUDE} = $json->{$LATITUDE};
            $result->{$LONGITUDE} = $json->{$LONGITUDE};
        }else{
           $result->{$LATITUDE} = "";
            $result->{$LATITUDE} = "";
        }
    }
    
    
    return $result;
}

1;

__END__

=head1 SEE ALSO
 
 To join the 'perfSONAR Users' mailing list, please visit:
 
 https://mail.internet2.edu/wws/info/perfsonar-user
 
 The perfSONAR-PS git repository is located at:
 
 https://code.google.com/p/perfsonar-ps/
 
 Questions and comments can be directed to the author, or the mailing list.
 Bugs, feature requests, and improvements can be directed here:
 
 http://code.google.com/p/perfsonar-ps/issues/list
 
 =head1 VERSION
 
 $Id: GeoIp.pm 5533 2013-02-10 06:28:27Z asides $
 
 =head1 AUTHOR
 
 Sowmya Balasubramanian, sowmya@es.net
 
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
 
 Copyright (c) 2008-2009, Internet2
 
 All rights reserved.
 
 =cut

# vim: expandtab shiftwidth=4 tabstop=4
