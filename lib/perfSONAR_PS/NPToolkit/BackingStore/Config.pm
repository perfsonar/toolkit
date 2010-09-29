package perfSONAR_PS::NPToolkit::BackingStore::Config;

use strict;
use warnings;

our $VERSION = 3.2;

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);

=head1 NAME

perfSONAR_PS::NPToolkit::BackingStore::Config;

=head1 DESCRIPTION

TBD

=cut

use base 'Exporter';

our @EXPORT_OK = qw( parse_config );

sub parse_config {
    my $parameters = validate( @_, {
            base_config_file => 1,
            config_directory => 1,
            });

    my $conf_file = $parameters->{base_config_file};
    my $conf_directory = $parameters->{config_directory};

    my $config = new Config::General( $conf_file );
    my %conf   = $config->getall;

    opendir(CONF_DIRECTORY, $conf_directory);
    my @config_files = readdir(CONF_DIRECTORY);
    closedir(CONF_DIRECTORY);

    foreach my $curr_conf_file (@config_files) {
        next unless ($curr_conf_file =~ /\.conf$/);

        my $curr_conf = Config::General->new( $conf_directory."/".$curr_conf_file );
        my %current_conf   = $curr_conf->getall;

        foreach my $key (keys %current_conf) {
            if ($conf{$key}) {
                unless (ref $conf{$key} eq "ARRAY") {
                    $conf{$key} = [ $conf{$key} ];
                }

                if (ref $current_conf{$key} eq "ARRAY") {
                    push @{ $conf{$key} }, @{ $current_conf{$key} };
                }
                else {
                    push @{ $conf{$key} }, $current_conf{$key};
                }
            }
            else {
                $conf{$key} = $current_conf{$key};
            }
        }
    }

    return (0, \%conf);
}

__END__

=head1 SEE ALSO

L<Config::General>, L<FindBin>

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

Copyright (c) 2004-2010, Internet2 and the University of Delaware

All rights reserved.

=cut
