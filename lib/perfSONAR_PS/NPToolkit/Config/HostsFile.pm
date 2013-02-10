package perfSONAR_PS::NPToolkit::Config::HostsFile;

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::HostsFile

=head1 DESCRIPTION

Module for verifying and replacing the system hosts file (/etc/hosts).

=cut

use base 'perfSONAR_PS::NPToolkit::Config::Base';

use fields 'HOSTS_FILE';

use Params::Validate qw(:all);
use Storable qw(store retrieve freeze thaw dclone);
use Net::DNS;
use Socket;
use Socket6;
use Socket::GetAddrInfo qw( :newapi getaddrinfo );
use IO::Socket;
use Net::IP qw( ip_normalize );
use Data::Validate::IP qw(is_ipv4 is_ipv6);

use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw( save_file restart_service );
use perfSONAR_PS::NPToolkit::Config::ExternalAddress;

# These are the defaults for the current NPToolkit
my %defaults = ( hosts_file => "/etc/hosts", );

=head2 init({ external_address_file => 0 })

Initializes the client. Returns 0 on success and -1 on failure. The
hosts_file parameter can be specified to set which file the module
should use for reading/writing the configuration.

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { hosts_file => 0, } );

    # Initialize the defaults
    $self->{HOSTS_FILE} = $defaults{hosts_file};

    # Override any
    $self->{HOSTS_FILE} = $parameters->{hosts_file} if ( $parameters->{hosts_file} );
    
    #doesn't do anything, but keep here in case some day it does.
    my $res = $self->reset_state();
    if ( $res != 0 ) {
        return $res;
    }

    return 0;
}

=head2 compare_to_dns()

Compares results returned by DNS with those from getaddrinfo, which presumably
uses /etc/hosts.
=cut
sub compare_to_dns {
    my $res = Net::DNS::Resolver->new;
    my $v4Address = q{};
    my $v6Address = q{};
    my %dns_results = ();
    
    #get the local addresses from the external_addresses file
    my $external_address_config = perfSONAR_PS::NPToolkit::Config::ExternalAddress->new();
    if ( $external_address_config->init() == 0 ) {
        $v4Address = $external_address_config->get_primary_ipv4({});
        $v6Address = $external_address_config->get_primary_ipv6({});
    }
    
    #Lookup addresses in DNS
    if($v4Address && !is_ipv4($v4Address)){
        my $query = $res->search($v4Address, "A");
        if($query){
            my %tmp_results = ();
            foreach my $rr ($query->answer) {
                if($rr->type eq "A"){
                    $tmp_results{ip_normalize($rr->address)} = 1;
                }
            }
            $dns_results{$v4Address} = \%tmp_results;
        }
    }
    if($v6Address && !is_ipv6($v6Address)){
        my $query6 = $res->search($v6Address, "AAAA");
        if($query6){
            my %tmp_results = ();
            #handle case where same name for v4 and v6
            %tmp_results = %{ $dns_results{$v6Address} } if($dns_results{$v6Address});
            foreach my $rr ($query6->answer) {
                if($rr->type eq "AAAA"){
                    $tmp_results{ip_normalize($rr->address)} = 1;
                }
            }
            $dns_results{$v6Address} = \%tmp_results;
        }
    }
    
    #Lookup up addresses using getaddrinfo (will hit /etc/hosts)
    foreach my $ext_address(keys %dns_results){
        my %hints = ( socktype => SOCK_STREAM, family => AF_UNSPEC );
        my ( $err, @res ) = getaddrinfo( $ext_address, "www", \%hints );
        while( my $ai = shift @res ){
            if($ai->{family} == AF_INET){
                my ($port, $ip_string) = unpack_sockaddr_in( $ai->{addr} );
                $dns_results{$ext_address}->{ip_normalize(inet_ntoa($ip_string))} |= 2;
            }elsif($ai->{family} == AF_INET6){
                my ($port, $ip_string) = unpack_sockaddr_in6( $ai->{addr} );
                $dns_results{$ext_address}->{ip_normalize(inet_ntop(AF_INET6, $ip_string))} |= 2;
            }
        }
    }
    
    #Make sure everything you saw in DNS you also saw from getaddrinfo and vice versa
    foreach my $addr_key(keys %dns_results){
        foreach my $ip_key(keys %{$dns_results{$addr_key}}){
            #print "$addr_key $ip_key ". $dns_results{$addr_key}->{$ip_key} . "\n";
            if($dns_results{$addr_key}->{$ip_key} != 3){
                return 0;
                last;
            }
        }
    }
    
    return 1;
}

=head2 save({ restart_services => 0 })
    Saves the configuration to disk. There are no services to restart, the option 
    is supported for compatibility reasons.
=cut

sub save {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { restart_services => 0, } );
    
    my $hosts_file_content = "# Do not remove the following line, or various programs\n";
    $hosts_file_content .= "# that require network functionality will fail.\n";
    $hosts_file_content .= "127.0.0.1		localhost.localdomain localhost\n";
    $hosts_file_content .= "::1			localhost6.localdomain6 localhost6\n";

    my $res = save_file( { file => $self->{HOSTS_FILE}, content => $hosts_file_content } );
    if ( $res == -1 ) {
        return (-1, "Problem saving hosts file");
    }

    return 0;
}

=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
=cut

sub reset_state {
    return 0;
}

=head2 save_state()
    Saves the current state of the module as a string. This state allows the
    module to be recreated later.
=cut

sub save_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %state = ();

    my $str = freeze( \%state );

    return $str;
}

=head2 restore_state({ state => \$state })
    Restores the modules state based on a string provided by the "save_state"
    function above.
=cut

sub restore_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { state => 1, } );

    my $state = thaw( $parameters->{state} );

    return;
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

Andy Lake, andy@es.net
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
