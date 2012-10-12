package perfSONAR_PS::NPToolkit::WebAdmin::MaDDash;

use strict;
use warnings;

our $VERSION = 3.2;

=head1 NAME

perfSONAR_PS::NPToolkit::WebAdmin::MaDDash;

=head1 DESCRIPTION

Module for reading/writing commonly configured aspects of the PingER.
Currently, the external address, site location and site name are configurable.

=cut

use JSON;
use Moose;
use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);

my $logger = get_logger(__PACKAGE__);

has 'maddash_url'         => (is => 'rw', isa => 'Str');

sub get_dashboards {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { });

    my $url = $self->maddash_url."/maddash/dashboards";

    return do_get({ url => $url });
}

sub get_grid {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { uri => 1 });
    my $uri = $parameters->{uri};

    my $url = $self->maddash_url."/".$uri;
    return do_get({ url => $url });
}

sub get_check {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { uri => 1 });
    my $uri = $parameters->{uri};

    my $url = $self->maddash_url."/".$uri;
    return do_get({ url => $url });
}

sub do_get {
    my @args = @_;
    my $parameters   = validate( @args, { url => 0 });
    my $url          = $parameters->{url};

    my $stime = time;

    $logger->debug("Sending GET to $url");

    my $ua = LWP::UserAgent->new();

    my $req = HTTP::Request->new(GET => $url);

    # Pass request to the user agent and get a response back
    my $res = $ua->request($req);

    my $etime = time;

    $logger->debug("Time to GET $url: ".($etime-$stime)." seconds");

    # Check the outcome of the response
    if ($res->is_success) {
        my $retval = JSON->new->decode($res->content);
        use Data::Dumper;
        $logger->debug("GET returned: ".Dumper($retval));
        return $retval;
    }
    else {
        $logger->debug("GET failed: ".$res->status_line);
        return;
    }
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
