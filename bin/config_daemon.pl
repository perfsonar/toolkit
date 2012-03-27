#!/usr/bin/perl

use strict;
use warnings;

=head1 NAME

toolkit_config_daemon.pl - Registers services (e.g. daemons such as owamp,
bwctl) into the global information service.

=head1 DESCRIPTION

This daemon reads a configuration file consisting of sites and the services
those sites are running. It will then check those services and register them
with the specified lookup service.

=cut

use FindBin qw($Bin);
use lib "$Bin/../lib";

use perfSONAR_PS::Common;
use perfSONAR_PS::Utils::Daemon qw/daemonize setids lockPIDFile unlockPIDFile/;
use perfSONAR_PS::Utils::Host qw(get_ips);
use perfSONAR_PS::NPToolkit::ConfigManager::ConfigDaemon;

use Getopt::Long;
use Config::General;
use Log::Log4perl qw/:easy/;

# set the process name
$0 = "toolkit_config_daemon.pl";

my @child_pids = ();

$SIG{INT}  = \&signalHandler;
$SIG{TERM} = \&signalHandler;

my $CONFIG_FILE;
my $LOGOUTPUT;
my $LOGGER_CONF;
my $PIDFILE;
my $DEBUGFLAG;
my $HELP;
my $RUNAS_USER;
my $RUNAS_GROUP;

my ( $status, $res );

$status = GetOptions(
    'config=s'  => \$CONFIG_FILE,
    'output=s'  => \$LOGOUTPUT,
    'logger=s'  => \$LOGGER_CONF,
    'pidfile=s' => \$PIDFILE,
    'verbose'   => \$DEBUGFLAG,
    'user=s'    => \$RUNAS_USER,
    'group=s'   => \$RUNAS_GROUP,
    'help'      => \$HELP
);

if ( not $CONFIG_FILE ) {
    print "Error: no configuration file specified\n";
    exit( -1 );
}

my %conf = Config::General->new( $CONFIG_FILE )->getall();

if ( not $PIDFILE ) {
    $PIDFILE = $conf{"pid_file"};
}

if ( not $PIDFILE ) {
    $PIDFILE = "/var/run/toolkit_config_daemon.pid";
}

( $status, $res ) = lockPIDFile( $PIDFILE );
if ( $status != 0 ) {
    print "Error: $res\n";
    exit( -1 );
}

my $fileHandle = $res;

my $logger;
if ( not defined $LOGGER_CONF or $LOGGER_CONF eq q{} ) {
    use Log::Log4perl qw(:easy);

    my $output_level = $INFO;
    if ( $DEBUGFLAG ) {
        $output_level = $DEBUG;
    }

    my %logger_opts = (
        level  => $output_level,
        layout => '%d (%P) %p> %F{1}:%L %M - %m%n',
    );

    if ( defined $LOGOUTPUT and $LOGOUTPUT ne q{} ) {
        $logger_opts{file} = $LOGOUTPUT;
    }

    Log::Log4perl->easy_init( \%logger_opts );
    $logger = get_logger( "perfSONAR_PS" );
}
else {
    use Log::Log4perl qw(get_logger :levels);

    my $output_level = $INFO;
    if ( $DEBUGFLAG ) {
        $output_level = $DEBUG;
    }

    my %logger_opts = (
        level  => $output_level,
        layout => '%d (%P) %p> %F{1}:%L %M - %m%n',
    );

    if ( $LOGOUTPUT ) {
        $logger_opts{file} = $LOGOUTPUT;
    }

    Log::Log4perl->init( $LOGGER_CONF );
    $logger = get_logger( "perfSONAR_PS" );
    $logger->level( $output_level ) if $output_level;
}

# Before daemonizing, set die and warn handlers so that any Perl errors or
# warnings make it into the logs.
my $insig = 0;
$SIG{__WARN__} = sub {
    $logger->warn("Warned: ".join( '', @_ ));
    return;
};

$SIG{__DIE__} = sub {                       ## still dies upon return
	die @_ if $^S;                      ## see perldoc -f die perlfunc
	die @_ if $insig;                   ## protect against reentrance.
	$insig = 1;
	$logger->error("Died: ".join( '', @_ ));
	$insig = 0;
	return;
};

unless ( $conf{"port"} ) {
    $logger->error( "No port defined" );
    exit( -1 );
}

my $config_daemon = perfSONAR_PS::NPToolkit::ConfigManager::ConfigDaemon->new();
($status, $res) = $config_daemon->init({
                                          address        => $conf{"address"},
                                          port           => $conf{"port"},
                                          access_control => $conf{"access"},
                                      });
if ($status != 0) {
    $logger->error("Problem starting up configuration daemon: $res");
    exit( -1 );
}

if ( not $DEBUGFLAG ) {
    ( $status, $res ) = daemonize();
    if ( $status != 0 ) {
        $logger->error( "Couldn't daemonize: " . $res );
        exit( -1 );
    }
}

unlockPIDFile( $fileHandle );

# Never returns
$config_daemon->run();

exit( 0 );

=head2 killChildren

Kills all the children for this process off. It uses global variables
because this function is used by the signal handler to kill off all
child processes.

=cut

sub killChildren {
    foreach my $pid ( @child_pids ) {
        kill( "SIGINT", $pid );
    }

    return;
}

=head2 signalHandler

Kills all the children for the process and then exits

=cut

sub signalHandler {
    killChildren;
    exit( 0 );
}

__END__

=head1 SEE ALSO

L<FindBin>, L<Getopt::Long>, L<Config::General>, L<Log::Log4perl>,
L<perfSONAR_PS::Common>, L<perfSONAR_PS::Utils::Daemon>,
L<perfSONAR_PS::Utils::Host>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: daemon.pl 4015 2010-04-07 16:04:22Z aaron $

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

Copyright (c) 2009, Internet2

All rights reserved.

=cut
