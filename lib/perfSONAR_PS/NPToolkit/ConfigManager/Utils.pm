package perfSONAR_PS::NPToolkit::ConfigManager::Utils;

use strict;
use warnings;

our $VERSION = 3.1;

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);

=head1 NAME

perfSONAR_PS::NPToolkit::ConfigManager::Utils

=head1 DESCRIPTION

A module that exports functions for saving files and restarting services. In
the future, this may talk with a configuration daemon, but for now, it provides
a uniform API that all the models use.

=head1 API

=cut

use perfSONAR_PS::NPToolkit::Config::Services;
use perfSONAR_PS::NPToolkit::ConfigManager::ConfigClient;

use base 'Exporter';

our @EXPORT_OK = qw( save_file restart_service stop_service start_service );

my $default_url = "http://localhost:9000/";

=head2 save_file({ file => 1, content => 1 })

Save the specified content into the specified file.

=cut

sub save_file {
    my $parameters = validate(
        @_,
        {
            file    => 1,
            content => 1,
        }
    );

    my $file    = $parameters->{file};
    my $content = $parameters->{content};

    my ($status, $res);

    my $client = perfSONAR_PS::NPToolkit::ConfigManager::ConfigClient->new();
    ($status, $res) = $client->init({ url => $default_url });
    if ($status != 0) {
        return -1;
    }

    ($status, $res) = $client->saveFile({ filename => $file, content => $content });
    if ($status != 0) {
        return -1;
    }

    return 0;
}

=head2 restart_service ({ name => 0 })

Restarts the specified service. The service can either be a named service (e.g.
'hls') in which case the service's init script will be looked up, or a direct
init script. The current code then does a "sudo" restart of the service.

=cut

sub restart_service {
    my $parameters = validate(
        @_,
        {
            name => 0,
        }
    );

    my $name    = $parameters->{name};

    my ($status, $res);

    my $client = perfSONAR_PS::NPToolkit::ConfigManager::ConfigClient->new();
    ($status, $res) = $client->init({ url => $default_url });
    if ($status != 0) {
        return -1;
    }

    ($status, $res) = $client->restartService({ name => $name, ignoreEnabled => 0 });
    if ($status != 0) {
        return -1;
    }

    return 0;
}

=head2 stop_service ({ name => 0 })

Stops the specified service. The service can either be a named service (e.g.
'hls') in which case the service's init script will be looked up, or a direct
init script. The current code then does a "sudo" stop of the service.

=cut

sub stop_service {
    my $parameters = validate(
        @_,
        {
            name => 0,
        }
    );

    my $name    = $parameters->{name};

    my ($status, $res);

    my $client = perfSONAR_PS::NPToolkit::ConfigManager::ConfigClient->new();
    ($status, $res) = $client->init({ url => $default_url });
    if ($status != 0) {
        return -1;
    }

    ($status, $res) = $client->stopService({ name => $name, ignoreEnabled => 0 });
    if ($status != 0) {
        return -1;
    }

    return 0;
}

=head2 start_service ({ name => 0 })

Starts the specified service. The service can either be a named service (e.g.
'hls') in which case the service's init script will be looked up, or a direct
init script. The current code then does a "sudo" start of the service.

=cut

sub start_service {
    my $parameters = validate(
        @_,
        {
            name => 0,
        }
    );

    my $name    = $parameters->{name};

    my ($status, $res);

    my $client = perfSONAR_PS::NPToolkit::ConfigManager::ConfigClient->new();
    ($status, $res) = $client->init({ url => $default_url });
    if ($status != 0) {
        return -1;
    }

    ($status, $res) = $client->startService({ name => $name, ignoreEnabled => 0 });
    if ($status != 0) {
        return -1;
    }

    return 0;
}

1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

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

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
