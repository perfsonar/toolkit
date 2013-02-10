package perfSONAR_PS::NPToolkit::ConfigManager::ConfigDaemon;

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

perfSONAR_PS::NPToolkit::ConfigManager::ConfigDaemon

=head1 DESCRIPTION

TBD

=cut

use Net::Server;
use RPC::XML::Server;
use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger :nowarn);
use Data::Dumper;

use perfSONAR_PS::NPToolkit::Config::Services;

use fields 'DAEMON', 'LOGGER', 'ACCESS_CONTROL';

sub new {
    my ( $class ) = @_;

    my $self = fields::new( $class );

    $self->{LOGGER} = get_logger( $class );

    return $self;
}

=head2 init({ address => 0, port => 1 })

TBD

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            address        => 0,
            port           => 1,
            access_control => 1,
        }
    );

    my $address        = $parameters->{address};
    my $port           = $parameters->{port};
    my $access_control = $parameters->{access_control};

    $self->{ACCESS_CONTROL} = $access_control;

    $self->{DAEMON} = RPC::XML::Server->new(host => $address, port => $port);
    unless (ref $self->{DAEMON}) {
        return (-1, $self->{DAEMON});
    }

    $self->{DAEMON}->add_method({
            name => "writeFile",
            code => sub {
                        return $self->writeFile({
                                                filename => $_[1],
                                                contents => $_[2]
                                                });
                     },
            signature => ['string string string']
    });
    $self->{DAEMON}->add_method({
            name => "restartService",
            code => sub {
                        return $self->restartService({
                                                name => $_[1],
                                                ignoreEnabled => $_[2],
                                                });
                     },
            signature => ['string string boolean']
    });
    $self->{DAEMON}->add_method({
            name => "startService",
            code => sub {
                        return $self->startService({
                                                name => $_[1],
                                                ignoreEnabled => $_[2],
                                                });
                     },
            signature => ['string string boolean']
    });
    $self->{DAEMON}->add_method({
            name => "stopService",
            code => sub {
                        return $self->stopService({
                                                name => $_[1],
                                                ignoreEnabled => $_[2],
                                                });
                     },
            signature => ['string string boolean']
    });

    return (0, "");
}

=head2 writeFile({ file_name => 1, file_contents => 1 })
    Handles the given configuration daemon request.
=cut

sub writeFile {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            filename   => 1,
            contents   => 1,
        }); 

    my $filename = $parameters->{filename};
    my $contents = $parameters->{contents};

    unless ($self->{ACCESS_CONTROL}->{file}->{$filename}) {
        $self->{LOGGER}->error("Couldn't write file $filename: unknown file");
        die("Access denied");
    }

    unless ($self->{ACCESS_CONTROL}->{file}->{$filename}->{write}) {
        $self->{LOGGER}->error("Couldn't write file $filename: write permission denied");
        die("Access denied");
    }

    open( FILE, ">", $filename ) or die("Couldn't write $filename");
    print FILE $contents;
    close( FILE );

    return "";
}

=head2 restartService({ name => 1 })
    Restarts the specified service.
=cut
sub restartService {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name => 1,
            ignoreEnabled => 1,
        }); 

    my $name          = $parameters->{name};
    my $ignoreEnabled = $parameters->{ignoreEnabled};

    my ($status, $res);

    my $services_conf = perfSONAR_PS::NPToolkit::Config::Services->new();
    $services_conf->init();

    unless ($self->{ACCESS_CONTROL}->{service}->{$name}) {
        die("Access denied: no service $name in list");
    }

    unless ($self->{ACCESS_CONTROL}->{service}->{$name}->{restart}) {
        die("Access denied: no restart option for $name");
    }

    my $service_info = $services_conf->lookup_service( { name => $name } );
    unless ($service_info) {
        my $msg = "Invalid service: $name";
        $self->{LOGGER}->error($msg);
        die($msg);
    }

    unless ($ignoreEnabled or $service_info->{enabled}) {
        return "";
    }

    my @service_names = ();

    if ( ref $service_info->{service_name} eq "ARRAY" ) {
        foreach my $service_name ( @{ $service_info->{service_name} } ) {
            push @service_names, $service_name;
        }
    }
    else {
        push @service_names, $service_info->{service_name};
    }
 
    foreach my $service_name ( @service_names ) {
        # XXX: hack so that during a save, it doesn't stop apache in the middle.
        # Really needs a better way of doing it.
        my $restart_cmd = "restart";
        $restart_cmd = "reload" if ($service_name =~ /httpd/);

        my $cmd = "service " . $service_name . " " .$restart_cmd ." &> /dev/null";
        $self->{LOGGER}->debug($cmd);
        system( $cmd );
    }

    return "";
}

=head2 startService({ name => 1 })
    Starts the specified service.
=cut
sub startService {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name => 1,
            ignoreEnabled => 1,
        }); 

    my $name          = $parameters->{name};
    my $ignoreEnabled = $parameters->{ignoreEnabled};

    my ($status, $res);

    my $services_conf = perfSONAR_PS::NPToolkit::Config::Services->new();
    $services_conf->init();

    unless ($self->{ACCESS_CONTROL}->{service}->{$name}) {
        die("Access denied");
    }

    unless ($self->{ACCESS_CONTROL}->{service}->{$name}->{start}) {
        die("Access denied");
    }

    my $service_info = $services_conf->lookup_service( { name => $name } );
    unless ($service_info) {
        my $msg = "Invalid service: $name";
        $self->{LOGGER}->error($msg);
        die($msg);
    }

    unless ($ignoreEnabled or $service_info->{enabled}) {
        return "";
    }

    my @service_names = ();

    if ( ref $service_info->{service_name} eq "ARRAY" ) {
        foreach my $service_name ( @{ $service_info->{service_name} } ) {
            push @service_names, $service_name;
        }
    }
    else {
        push @service_names, $service_info->{service_name};
    }
 
    foreach my $service_name ( @service_names ) {
        my $cmd = "service " . $service_name . " start &> /dev/null";
        $self->{LOGGER}->debug($cmd);
        system( $cmd );
    }

    return "";
}

=head2 stopService({ name => 1 })
    Stops the specified service.
=cut
sub stopService {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name => 1,
            ignoreEnabled => 1,
        }); 

    my $name          = $parameters->{name};
    my $ignoreEnabled = $parameters->{ignoreEnabled};

    my ($status, $res);

    my $services_conf = perfSONAR_PS::NPToolkit::Config::Services->new();
    $services_conf->init();

    unless ($self->{ACCESS_CONTROL}->{service}->{$name}) {
        die("Access denied");
    }

    unless ($self->{ACCESS_CONTROL}->{service}->{$name}->{stop}) {
        die("Access denied");
    }

    my $service_info = $services_conf->lookup_service( { name => $name } );
    unless ($service_info) {
        my $msg = "Invalid service: $name";
        $self->{LOGGER}->error($msg);
        die($msg);
    }

#    stop no matter what since stopping a non-enabled service doesn't matter
#    unless ($ignoreEnabled or $service_info->{enabled}) {
#        return "";
#    }

    my @service_names = ();

    if ( ref $service_info->{service_name} eq "ARRAY" ) {
        foreach my $service_name ( @{ $service_info->{service_name} } ) {
            push @service_names, $service_name;
        }
    }
    else {
        push @service_names, $service_info->{service_name};
    }
 
    foreach my $service_name ( @service_names ) {
        my $cmd = "service " . $service_name . " stop &> /dev/null";
        $self->{LOGGER}->debug($cmd);
        system( $cmd );
    }

    return "";
}

=head2 run({ })
    Starts the daemon processing.
=cut
sub run {
    my ( $self, @params ) = @_;
    my $parameters = validate(@params, {}); 


    $self->{DAEMON}->server_loop;
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
