package perfSONAR_PS::NPToolkit::Config::perfSONARBUOYMA;

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::perfSONARBUOYMA

=head1 DESCRIPTION

Module for reading/writing commonly configured aspects of the perfSONARBUOY MA.
Currently, the external address, site location and site name are configurable.

=cut

use Template;

use base 'perfSONAR_PS::NPToolkit::Config::pSPSServiceDaemon';

use Params::Validate qw(:all);

# These are the defaults for the current NPToolkit
my %defaults = (
    config_file  => "/opt/perfsonar_ps/perfsonarbuoy_ma/etc/daemon.conf",
    service_name => "perfsonarbuoy_ma",
);

=head2 init({ config_file => 0, service_name => 0 })

XXX

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            config_file  => 0,
            service_name => 0,
        }
    );

    my $config_file  = $defaults{config_file};
    my $service_name = $defaults{service_name};

    $config_file  = $parameters->{config_file} if ($parameters->{config_file});
    $service_name = $parameters->{service_name} if ($parameters->{service_name});
    return $self->SUPER::init({ config_file => $config_file, service_name => $service_name });
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
