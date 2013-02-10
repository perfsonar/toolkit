package perfSONAR_PS::NPToolkit::ConfigManager::ConfigClient;

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

perfSONAR_PS::NPToolkit::ConfigManager::ConfigClient

=head1 DESCRIPTION

TBD

=head1 API

=cut

use RPC::XML::Client;
use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger :nowarn);
use Data::Dumper;

use fields 'CLIENT', 'LOGGER';

sub new {
    my ( $class ) = @_;

    my $self = fields::new( $class );

    $self->{LOGGER} = get_logger( $class );

    return $self;
}

=head2 init({ url => 1 })

TBD

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            url => 1,
        }
    );

    my $url    = $parameters->{url};

    my ($status, $res);

    $res = RPC::XML::Client->new($url);
    unless (ref $res) {
        my $msg = "Couldn't allocate RPC::XML client: " . $res;
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }
    $self->{CLIENT} = $res;

    return (0, "");
}

=head2 saveFile({ filename => 1, content => 1 })

Save the specified content into the specified file.

=cut

sub saveFile {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            filename => 1,
            content  => 1,
        }
    );

    my $filename = $parameters->{filename};
    my $content  = $parameters->{content};

    my $res = $self->{CLIENT}->simple_request("writeFile", $filename, $content);
    unless (defined $res) {
        my $msg = "Problem writing file $filename: ".$RPC::XML::ERROR;
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }
    elsif (ref($res) eq "HASH" and $res->{faultCode}) {
        my $msg = "Problem writing file $filename: ".$res->{faultString};
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    return (0, "");
}

=head2 restartService ({ name => 1 })

Restarts the specified service. 

=cut

sub restartService {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name           => 1,
            ignoreEnabled => 1,
        }
    );

    my $name           = $parameters->{name};
    my $ignoreEnabled  = RPC::XML::boolean->new($parameters->{ignoreEnabled});

    my $res = $self->{CLIENT}->simple_request("restartService", $name, $ignoreEnabled);
    unless (defined $res) {
        my $msg = "Problem restarting service $name: ".$RPC::XML::ERROR;
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }
    elsif (ref $res eq "HASH" and $res->{faultCode}) {
        my $msg = "Problem restarting service $name: ".$res->{faultString};
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }


    return (0, "");
}

=head2 startService ({ name => 1 })

Starts the specified service. 

=cut

sub startService {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name           => 1,
            ignoreEnabled => 1,
        }
    );

    my $name           = $parameters->{name};
    my $ignoreEnabled  = RPC::XML::boolean->new($parameters->{ignoreEnabled});

    my $res = $self->{CLIENT}->simple_request("startService", $name, $ignoreEnabled);
    unless (defined $res) {
        my $msg = "Problem starting service $name: ".$RPC::XML::ERROR;
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }
    elsif (ref $res eq "HASH" and $res->{faultCode}) {
        my $msg = "Problem starting service $name: ".$res->{faultString};
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    return (0, "");
}

=head2 stopService ({ name => 1 })

Stops the specified service. 

=cut

sub stopService {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name           => 1,
            ignoreEnabled => 1,
        }
    );

    my $name           = $parameters->{name};
    my $ignoreEnabled  = RPC::XML::boolean->new($parameters->{ignoreEnabled});

    my $res = $self->{CLIENT}->simple_request("stopService", $name, $ignoreEnabled);
    unless (defined $res) {
        my $msg = "Problem stopping service $name: ".$RPC::XML::ERROR;
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }
    elsif (ref $res eq "HASH" and $res->{faultCode}) {
        my $msg = "Problem stopping service $name: ".$res->{faultString};
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    return (0, "");
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
