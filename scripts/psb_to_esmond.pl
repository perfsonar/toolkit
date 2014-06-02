#!/usr/bin/perl -w

use strict;

our $VERSION = 3.4;

=head1 NAME

psb_to_esmond.pl - Migrates OWAMP, BWCTL, and traceroute data from old MAs to esmond

=head1 DESCRIPTION

This script queries the mysql databases of the old MAs and then uses the REST interface to register the data

=cut

use FindBin;
use lib "$FindBin::Bin/../lib";

use Data::Validate::IP qw(is_ipv4 is_ipv6);
use DBI;
use Getopt::Long;
use Log::Log4perl qw/:easy/;
use Time::Local;
use OWP::Conf;
use Math::Int64 qw(uint64 uint64_to_number);
use POSIX;
use perfSONAR_PS::Client::Esmond::Metadata;
use perfSONAR_PS::Client::Esmond::ApiFilters;
use perfSONAR_PS::Config::OWP::Conf;
use perfSONAR_PS::Utils::Daemon qw/daemonize setids lockPIDFile unlockPIDFile/;
use perfSONAR_PS::Utils::DNS qw(resolve_address);

# set the process name
$0 = "psb_to_esmond.pl";

#var definitions
my $DEFAULT_DB_HOST = 'localhost';
my %OW_TYPES = ( 'owamp' => 'OWP', 'bwctl' => 'BW', 'traceroute' => "TRACE");
my %DEFAULT_DB_NAMES = (
    'owamp' => 'owamp',
    'bwctl' => 'bwctl',
    'traceroute' => 'traceroute_ma',
);

#Set option default
my $owdays = 30;
my $bwmonths = 6;
my $tracedays = 30;
my @dbtypes = ('bwctl', 'owamp', 'traceroute');
my $dbuser = "root";
my $dbpassword = "";
my $dbhost= $DEFAULT_DB_HOST;
my $help = 0;
my $owmesh_dir = "";
my $verbose = 0;
my $mauser = 'perfsonar';
my $mapassword = '';
my $maurl = 'http://localhost/esmond/perfsonar/archive/';
my $state_file = 'ps_to_esmond.state';
my $logfile ;
my $pidfile = "/var/run/psb_to_esmond.pid";
my $runas_user = "perfsonar";
my $runas_group = "perfsonar";
my $daemonize = 0;
#Retrieve options
my $result = GetOptions (
    "h|help"   => \$help,
    "owdays=i" =>\$owdays,
    "bwmonths=i" =>\$bwmonths,
    "tracedays=i" =>\$tracedays,
    "owmesh-dir=s" => \$owmesh_dir,
    "dbtype=s@" => \@dbtypes,
    "dbuser=s" => \$dbuser,
    "dbpassword=s" => \$dbpassword,
    "dbhost=s" => \$dbhost,
    "mauser=s" => \$mauser,
    "mapassword=s" => \$mapassword,
    "maurl=s" => \$maurl,
    "statefile=s" => \$state_file,
    "v|verbose" => \$verbose,
    'pidfile=s' => \$pidfile,
    'user=s'    => \$runas_user,
    'group=s'   => \$runas_group,
    "d|daemonize"   => \$daemonize,
    "l|logfile=s" => \$logfile,
);

# Error handling for options
if( !$result ){
    &usage();
    exit 1;
}

# print help if help option given
if( $help ){
    &usage();
    exit 0;
}

my $pidFileHandle;
if($daemonize){
    #Lock PID File
    my( $status, $res ) = lockPIDFile( $pidfile );
    if ( $status != 0 ) {
        print STDERR "Error: $res\n";
        exit( -1 );
    }
    $pidFileHandle = $res;
    
    #change user and group
    if ( setids( USER => $runas_user, GROUP => $runas_group ) != 0 ) {
        print STDERR "Error: Couldn't drop privileges\n";
        exit( -1 );
    }
}

#Create logger
my %logger_opts = (
    level  => $INFO,
    layout => '%d (%P) %p> %F{1}:%L %M - %m%n',
);
$logger_opts{file} = $logfile if($logfile);
Log::Log4perl->easy_init( \%logger_opts );
my $logger = get_logger( "perfSONAR_PS" );

#load previous state
my $state = &load_state_file($state_file);
$SIG{INT} = \&signal_handler;
$SIG{TERM} = \&signal_handler;

#set ma user and password
my $ma_filters = new perfSONAR_PS::Client::Esmond::ApiFilters(
    'auth_username' => $mauser, 
    'auth_apikey' => $mapassword
);

#daemonize
if ( $daemonize ) {
    my ( $status, $res ) = daemonize();
    if ( $status != 0 ) {
        print STDERR "Couldn't daemonize: " . $res ;
        exit( -1 );
    }
    
    unlockPIDFile( $pidFileHandle );
}

#Determine tables to clean
foreach my $dbtype(@dbtypes){
    # open owmesh.conf
    my $dbname = $DEFAULT_DB_NAMES{$dbtype};
    unless($dbname){
        print STDERR "Unrecognized DB type $dbtype. Ignoring.";
        next;
    }
    if($owmesh_dir){
        my $owmesh_type = $OW_TYPES{$dbtype};
        my %defaults = (
            DBHOST  => $DEFAULT_DB_HOST,
            CONFDIR => $owmesh_dir
        );
        my $conf = new perfSONAR_PS::Config::OWP::Conf( %defaults );
        $dbuser = $conf->must_get_val( ATTR => 'CentralDBUser', TYPE => $owmesh_type );
        $dbpassword = $conf->must_get_val( ATTR => 'CentralDBPass', TYPE => $owmesh_type );
        $dbhost = $conf->get_val( ATTR => 'CentralDBHost', TYPE => $owmesh_type ) || $DEFAULT_DB_HOST;
        $dbname = $conf->must_get_val( ATTR => 'CentralDBName', TYPE => $owmesh_type );
    }

    eval{
        my $dbh = DBI->connect("DBI:mysql:$dbname;host=$dbhost", $dbuser, $dbpassword) or die $DBI::errstr;
        if($dbtype eq "owamp"){
            my $exp_time = time - 86400*$owdays;
            &convert_owamp($dbh, $exp_time, $maurl, $ma_filters, $state);
        }elsif($dbtype eq "bwctl"){
            my $exp_time = time - 86400*$bwmonths*31;
            &convert_bwctl($dbh, $exp_time, $maurl, $ma_filters, $state);
        }elsif($dbtype eq "traceroute"){
            my $exp_time = time - 86400*$tracedays;
            &convert_traceroute($dbh, $exp_time, $maurl, $ma_filters, $state);
        }
        $dbh->disconnect();
    };
    if($@){
        $logger->error($@);
    }
}

#save_state
save_state_file($state_file, $state);

#Finish up
print "Done\n";
exit 0;

###############################################################################
# OWAMP Subroutines
###############################################################################
sub convert_owamp {
    my ($dbh, $exp_time, $maurl, $filters, $state) = @_;
    
    my $date_sth = $dbh->prepare("SELECT year, month, day FROM DATES") or die $dbh->errstr;
    $date_sth->execute() or die $date_sth->errstr;
    while(my $date_row = $date_sth->fetchrow_arrayref){
        my $table_time = timelocal(59, 59, 23, $date_row->[2] , $date_row->[1] - 1, $date_row->[0] - 1900);
        next if($table_time < $exp_time || ($state->{'owamp'} && $table_time < $state->{'owamp'}->{'date'}));
        if($state->{'owamp'}){
            $state->{'owamp'}->{'test'} = undef unless($table_time == $state->{'owamp'}->{'date'});
            $state->{'owamp'}->{'date'} = $table_time;
        }
        my $table_prefix = sprintf("%04d%02d%02d", @{$date_row});
        $logger->info(sprintf("Adding data from %04d-%02d-%02d\n", @{$date_row}));
        my %ma_key_map = (); 
    
        #get test specs
        $logger->info("Finding test specs....[START]\n");
        my %tspec_map = ();
        my $tspec_sth = $dbh->prepare("SELECT tspec_id, num_sample_packets, wait_interval, dscp, bucket_width FROM ${table_prefix}_TESTSPEC") or die $dbh->errstr;
        $tspec_sth->execute() or die $tspec_sth->errstr;
        while(my $tspec_row = $tspec_sth->fetchrow_arrayref){
            $tspec_map{$tspec_row->[0]} = {
                'time-duration' => $tspec_row->[1] * $tspec_row->[2],
                'ip-tos' => $tspec_row->[3],
                'sample-size' =>  $tspec_row->[1],
                'sample-bucket-width' => $tspec_row->[4]
            }
        }
        $logger->info("Finding test specs....[END]\n");
    
        #Get node addresses
        $logger->info("Finding nodes....[START]\n");
        my %node_map = ();
        my $node_sth = $dbh->prepare("SELECT node_id, addr FROM ${table_prefix}_NODES") or die $dbh->errstr;
        $node_sth->execute() or die $node_sth->errstr;
        while(my $node_row = $node_sth->fetchrow_arrayref){
            $node_map{$node_row->[0]} = $node_row->[1];
        }
        $logger->info("Finding nodes....[END]\n");
    
        #get database data
        my $metadata;
        my $histogram = {};
        my $prev_test = '';
        my $prev_si = '';
        my $prev_ts = '';
        my $prev_row = '';
        my $bulk_post;
        $logger->info("Finding delay data....[START]\n");
        my $delay_sql = "SELECT delay.send_id, delay.recv_id, delay.tspec_id, delay.si, delay.bucket_width, delay.basei, delay.i, delay.n, data.stimestamp, data.sent, data.lost, data.dups, data.maxerr FROM ${table_prefix}_DELAY AS delay INNER JOIN ${table_prefix}_DATA AS data ON delay.send_id=data.send_id AND delay.recv_id=data.recv_id AND delay.tspec_id=data.tspec_id AND delay.si=data.si AND delay.ei=data.ei ";        
        $delay_sql .= "WHERE delay.send_id > ? OR (delay.send_id = ? AND delay.recv_id > ?) OR (delay.send_id = ? AND delay.recv_id = ? AND delay.tspec_id > ?) " if($state->{'owamp'}->{'test'});
        $delay_sql .= "ORDER BY delay.send_id, delay.recv_id, delay.tspec_id, delay.si";
        my $delay_sth = $dbh->prepare($delay_sql) or die $dbh->errstr;
        if($state->{'owamp'}->{'test'}){
            my @test_parts = split '\.', $state->{'owamp'}->{'test'};
            die "OWAMP test id from state file is invalid: " . $state->{'owamp'}->{'test'} if (@test_parts != 3);
            $delay_sth->bind_param(1, $test_parts[0]);
            $delay_sth->bind_param(2, $test_parts[0]);
            $delay_sth->bind_param(3, $test_parts[1]);
            $delay_sth->bind_param(4, $test_parts[0]);
            $delay_sth->bind_param(5, $test_parts[1]);
            $delay_sth->bind_param(6, $test_parts[2]);
        }
        $delay_sth->execute() or die $delay_sth->errstr;
        $logger->info("Finding delay data....[END]\n");
        while(my $delay_row = $delay_sth->fetchrow_arrayref){ 
            my $cur_test = $delay_row->[0] . '.' . $delay_row->[1] . '.' . $delay_row->[2]; 
            
            # look at metadata and register if we are done with test
            if($prev_test ne $cur_test){
                # submit data if there was a previous test
                if($prev_test){
                    $logger->info("Sending delay data for $prev_test....[START]\n");
                    add_owamp_data($prev_row, $bulk_post, $histogram) if(keys %{$histogram} > 0);
                    $histogram = {};
                    $bulk_post->post_data();
                    if ($bulk_post->error()){
                        die "Error posting $prev_test" . $bulk_post->error() . "\n";
                    }
                    $state->{'owamp'} = {} unless($state->{'owamp'});
                    $state->{'owamp'}->{'date'} = $table_time;
                    $state->{'owamp'}->{'test'} = $prev_test;
                    $logger->info("Sending delay data for $prev_test....[END]\n");
                }
            
                #build metadata for new test
                $logger->info("Sending metadata....[START]\n");
                my $source = $node_map{$delay_row->[0]};
                unless($source){
                    $logger->error("Unable to find source node with id " . $delay_row->[0] . "\n");
                    next;
                }
                my $dest = $node_map{$delay_row->[1]};
                unless($dest){
                    $logger->error("Unable to find dest node with id " . $delay_row->[1] . "\n");
                    next;
                }
                my ($source_ip, $dest_ip) = &convert_to_ips($source, $dest);
                unless($source_ip && $dest_ip){
                    $logger->info("Sending metadata....[SKIP]\n");
                    next;
                }
                
                my $tspec = $tspec_map{$delay_row->[2]};
                unless($tspec){
                    $logger->error("Unable to find test spec with id " . $delay_row->[2] . "\n");
                    next;
                }
                $metadata = new perfSONAR_PS::Client::Esmond::Metadata(url => $maurl, filters => $filters);
                $metadata->subject_type('point-to-point');
                $metadata->tool_name('powstream');
                $metadata->source($source_ip);
                $metadata->destination($dest_ip);
                $metadata->input_source($source);
                $metadata->input_destination($dest);
                $metadata->measurement_agent($source_ip);#TODO: set this correctly
                foreach my $meta_field(keys %{$tspec}){
                    $metadata->set_field($meta_field, $tspec->{$meta_field}) if($tspec->{$meta_field});
                }
                $metadata->add_event_type('histogram-owdelay');
                $metadata->add_event_type('histogram-ttl');
                $metadata->add_event_type('packet-loss-rate');
                $metadata->add_event_type('time-error-estimates');
                $metadata->add_event_type('packet-duplicates');
                $metadata->add_event_type('packet-count-sent');
                $metadata->add_event_type('packet-count-lost');
                $metadata->add_event_type('failures');
                $metadata->add_summary_type('histogram-owdelay', 'aggregation', 300);
                $metadata->add_summary_type('histogram-owdelay', 'aggregation', 3600);
                $metadata->add_summary_type('histogram-owdelay', 'aggregation', 86400);
                $metadata->add_summary_type('histogram-owdelay', 'statistics', 0);
                $metadata->add_summary_type('histogram-owdelay', 'statistics', 300);
                $metadata->add_summary_type('histogram-owdelay', 'statistics', 3600);
                $metadata->add_summary_type('histogram-owdelay', 'statistics', 86400);
                $metadata->add_summary_type('histogram-ttl', 'aggregation', 300);
                $metadata->add_summary_type('histogram-ttl', 'aggregation', 3600);
                $metadata->add_summary_type('histogram-ttl', 'aggregation', 86400);
                $metadata->add_summary_type('histogram-ttl', 'statistics', 0);
                $metadata->add_summary_type('histogram-ttl', 'statistics', 300);
                $metadata->add_summary_type('histogram-ttl', 'statistics', 3600);
                $metadata->add_summary_type('histogram-ttl', 'statistics', 86400);
                $metadata->add_summary_type('packet-loss-rate', 'aggregation', 300);
                $metadata->add_summary_type('packet-loss-rate', 'aggregation', 3600);
                $metadata->add_summary_type('packet-loss-rate', 'aggregation', 86400);
                $metadata->post_metadata();
                $logger->info("Sending metadata....[END]\n");
                if($metadata->error()){
                    $logger->error("Error posting metadata to MA: " . $metadata->error() . "\n");
                    next;
                }
                $ma_key_map{$cur_test} = $metadata;
                $bulk_post = $metadata->generate_event_type_bulk_post();
                $prev_si = '';
            }
        
            #new histogram if new time
            if($prev_si && $prev_si ne $delay_row->[3]){
                add_owamp_data($delay_row, $bulk_post, $histogram);
                $histogram = {};
            }
        
            #update histogram
            my $bucket = 1000 * ($delay_row->[5] + $delay_row->[6]) * $delay_row->[4]; #bucket in ms
            $histogram->{sprintf("%.2f", $bucket)} = $delay_row->[7];
        
            #set variables for next iteration
            $prev_test = $cur_test;
            $prev_row = $delay_row;
            $prev_si = $delay_row->[3];
            $prev_ts = $delay_row->[8];
        }
        #post any remaining data
        $logger->info("Sending rest of data....[START]\n");
        if($bulk_post){
            add_owamp_data($prev_row, $bulk_post, $histogram) if(keys %{$histogram} > 0);
            $bulk_post->post_data();
            $state->{'owamp'} = {} unless($state->{'owamp'});
            $state->{'owamp'}->{'date'} = $table_time;
            $state->{'owamp'}->{'test'} = $prev_test;
        }
        $logger->info("Sending rest of data....[END]\n");
    }
}

sub add_owamp_data {
    my ($delay_row, $bulk_post, $histogram) = @_;
    
    my $ts = owptime2time($delay_row->[8]);
    $bulk_post->add_data_point('histogram-owdelay', $ts, $histogram);
    $bulk_post->add_data_point('packet-loss-rate', $ts, {'numerator' => $delay_row->[10], 'denominator' => $delay_row->[9]}) if($delay_row->[9] > 0);
    $bulk_post->add_data_point('packet-count-sent', $ts, $delay_row->[9]);
    $bulk_post->add_data_point('packet-count-lost', $ts, $delay_row->[10]);
    $bulk_post->add_data_point('packet-duplicates', $ts, $delay_row->[11]);
    $bulk_post->add_data_point('time-error-estimates', $ts, $delay_row->[12]);
}

###############################################################################
# BWCTL Subroutines
###############################################################################
sub convert_bwctl {
    my ($dbh, $exp_time, $maurl, $filters, $state) = @_;
    
    my $date_sth = $dbh->prepare("SELECT year, month FROM DATES") or die $dbh->errstr;
    $date_sth->execute() or die $date_sth->errstr;
    while(my $date_row = $date_sth->fetchrow_arrayref){
        my $table_time = timelocal(59, 59, 23, 1 , $date_row->[1] - 1, $date_row->[0] - 1900);
        next if($table_time < $exp_time || ($state->{'bwctl'} && $table_time < $state->{'bwctl'}->{'date'}));
        if($state->{'bwctl'}){
            $state->{'bwctl'}->{'test'} = undef unless($table_time == $state->{'bwctl'}->{'date'});
            $state->{'bwctl'}->{'date'} = $table_time;
        }
        my $table_prefix = sprintf("%04d%02d", @{$date_row});
        $logger->info(sprintf("Adding data from %04d-%02d\n", @{$date_row}));
        my %ma_key_map = (); 
        
        #get test specs
        $logger->info("Finding test specs....[START]\n");
        my %tspec_map = ();
        my $tspec_sth = $dbh->prepare("SELECT tspec_id, duration, len_buffer, window_size, tos, parallel_streams, udp, udp_bandwidth FROM ${table_prefix}_TESTSPEC") or die $dbh->errstr;
        $tspec_sth->execute() or die $tspec_sth->errstr;
        while(my $tspec_row = $tspec_sth->fetchrow_arrayref){
            $tspec_map{$tspec_row->[0]} = {
                'time-duration' => $tspec_row->[1],
                'bw-buffer-size' => $tspec_row->[2],
                'tcp-window-size' => $tspec_row->[3],
                'ip-tos' => $tspec_row->[4],
                'bw-parallel-streams' => $tspec_row->[5],
                'ip-transport-protocol' => ($tspec_row->[6] ? 'udp' : 'tcp'),
                'bw-parallel-streams' => $tspec_row->[7],
            }
        }
        $logger->info("Finding test specs....[END]\n");
        
        #Get node addresses
        $logger->info("Finding nodes....[START]\n");
        my %node_map = ();
        my $node_sth = $dbh->prepare("SELECT node_id, addr FROM ${table_prefix}_NODES") or die $dbh->errstr;
        $node_sth->execute() or die $node_sth->errstr;
        while(my $node_row = $node_sth->fetchrow_arrayref){
            $node_map{$node_row->[0]} = $node_row->[1];
        }
        $logger->info("Finding nodes....[END]\n");
        
        #get database data
        my $metadata;
        my $prev_test = '';
        my $bulk_post;
        $logger->info("Finding throughput data....[START]\n");
        my $data_sql = "SELECT send_id, recv_id, tspec_id, timestamp, throughput, lost, sent FROM ${table_prefix}_DATA ";
        $data_sql .= "WHERE send_id > ? OR (send_id = ? AND recv_id > ?) OR (send_id = ? AND recv_id = ? AND tspec_id > ?) " if($state->{'bwctl'}->{'test'});
        $data_sql .= "ORDER BY send_id, recv_id, tspec_id";
        my $data_sth = $dbh->prepare($data_sql) or die $dbh->errstr;
        if($state->{'bwctl'}->{'test'}){
            my @test_parts = split '\.', $state->{'bwctl'}->{'test'};
            die "BWCTL test id from state file is invalid: " . $state->{'bwctl'}->{'test'} if (@test_parts != 3);
            $data_sth->bind_param(1, $test_parts[0]);
            $data_sth->bind_param(2, $test_parts[0]);
            $data_sth->bind_param(3, $test_parts[1]);
            $data_sth->bind_param(4, $test_parts[0]);
            $data_sth->bind_param(5, $test_parts[1]);
            $data_sth->bind_param(6, $test_parts[2]);
        }
        $data_sth->execute() or die $data_sth->errstr;
        $logger->info("Finding throughput data....[END]\n");
        while(my $data_row = $data_sth->fetchrow_arrayref){ 
            my $cur_test = $data_row->[0] . '.' . $data_row->[1] . '.' . $data_row->[2]; 
            
             # look at metadata and register if we are done with test
            if($prev_test ne $cur_test){
                # submit data if there was a previous test
                if($prev_test){
                    $logger->info("Sending throughput data for $prev_test....[START]\n");
                    $bulk_post->post_data();
                    if ($bulk_post->error()){
                        die "Error posting $prev_test" . $bulk_post->error() . "\n";
                    }
                    $state->{'bwctl'} = {} unless($state->{'bwctl'});
                    $state->{'bwctl'}->{'date'} = $table_time;
                    $state->{'bwctl'}->{'test'} = $prev_test;
                    $logger->info("Sending throughput data for $prev_test....[END]\n");
                }
                $prev_test = '';#reset so if we have to skip current test we don't re-post
                
                #build metadata for new test
                $logger->info("Sending metadata....[START]\n");
                my $source = $node_map{$data_row->[0]};
                unless($source){
                    $logger->error("Unable to find source node with id " . $data_row->[0] . "\n");
                    next;
                }
                my $dest = $node_map{$data_row->[1]};
                unless($dest){
                    $logger->error("Unable to find dest node with id " . $data_row->[1] . "\n");
                    next;
                }
                my ($source_ip, $dest_ip) = &convert_to_ips($source, $dest);
                unless($source_ip && $dest_ip){
                    $logger->info("Sending metadata....[SKIP]\n");
                    next;
                }
                
                my $tspec = $tspec_map{$data_row->[2]};
                unless($tspec){
                    $logger->error("Unable to find test spec with id " . $data_row->[2] . "\n");
                    next;
                }
                $metadata = new perfSONAR_PS::Client::Esmond::Metadata(url => $maurl, filters => $filters);
                $metadata->subject_type('point-to-point');
                $metadata->tool_name('bwctl/iperf');
                $metadata->source($source_ip);
                $metadata->destination($dest_ip);
                $metadata->input_source($source);
                $metadata->input_destination($dest);
                $metadata->measurement_agent($source_ip);#TODO: set this correctly
                foreach my $meta_field(keys %{$tspec}){
                    $metadata->set_field($meta_field, $tspec->{$meta_field}) if($tspec->{$meta_field});
                }
                $metadata->add_event_type('throughput');
                $metadata->add_event_type('failures');
                if($tspec->{'ip-transport-protocol'} eq 'udp'){
                    $metadata->add_event_type('packet-loss-rate');
                    $metadata->add_event_type('packet-count-sent');
                    $metadata->add_event_type('packet-count-lost');
                }
                $metadata->add_summary_type('throughput', 'average', 86400);
                $metadata->post_metadata();
                $logger->info("Sending metadata....[END]\n");
                if($metadata->error()){
                    $logger->error("Error posting metadata to MA: " . $metadata->error() . "\n");
                    next;
                }
                $ma_key_map{$cur_test} = $metadata;
                $bulk_post = $metadata->generate_event_type_bulk_post();
            }
        
            my $ts = owptime2time($data_row->[3]);
            $bulk_post->add_data_point('throughput', $ts, sprintf("%d", $data_row->[4]));
            if($tspec_map{$data_row->[2]}->{'ip-transport-protocol'} eq 'udp'){
                $bulk_post->add_data_point('packet-loss-rate', $ts, {'numerator' => $data_row->[5], 'denominator' => $data_row->[6]}) if($data_row->[6] > 0);
                $bulk_post->add_data_point('packet-count-sent', $ts, $data_row->[6]) if(defined $data_row->[6]);
                $bulk_post->add_data_point('packet-count-lost', $ts, $data_row->[5]) if(defined $data_row->[5]);
            }

            #set variables for next iteration
            $prev_test = $cur_test;
        }
    }
}

###############################################################################
# Traceroute Subroutines
###############################################################################
sub convert_traceroute {
    my ($dbh, $exp_time, $maurl, $filters, $state) = @_;
    
    my $date_sth = $dbh->prepare("SELECT year, month, day FROM DATES") or die $dbh->errstr;
    $date_sth->execute() or die $date_sth->errstr;
    while(my $date_row = $date_sth->fetchrow_arrayref){
        my $table_time = timelocal(59, 59, 23, $date_row->[2] , $date_row->[1] - 1, $date_row->[0] - 1900);
        next if($table_time < $exp_time || ($state->{'traceroute'} && $table_time < $state->{'traceroute'}->{'date'}));
        if($state->{'traceroute'}){
            $state->{'traceroute'}->{'test'} = undef unless($table_time == $state->{'traceroute'}->{'date'});
            $state->{'traceroute'}->{'date'} = $table_time;
        }
        my $table_prefix = sprintf("%04d%02d%02d", @{$date_row});
        $logger->info(sprintf("Adding data from %04d-%02d-%02d\n", @{$date_row}));
        my %ma_key_map = (); 
        
        #get test specs
        $logger->info("Finding test specs....[START]\n");
        my %tspec_map = ();
        my $tspec_sth = $dbh->prepare("SELECT subjKey, src, dst, firstTTL, maxTTL, pause, packetSize FROM ${table_prefix}_TESTSPEC") or die $dbh->errstr;
        $tspec_sth->execute() or die $tspec_sth->errstr;
        while(my $tspec_row = $tspec_sth->fetchrow_arrayref){
            $tspec_map{$tspec_row->[0]} = {
                'src' => $tspec_row->[1],
                'dst' => $tspec_row->[2],
                'trace-first-ttl' => $tspec_row->[3],
                'trace-max-ttl' => $tspec_row->[4],
                'time-probe-interval' => $tspec_row->[5],
                'ip-packet-size' => $tspec_row->[6],
            }
        }
        $logger->info("Finding test specs....[END]\n");
        
        
        #get database data
        my $metadata;
        my $prev_test = '';
        my $prev_meas = '';
        my $prev_ts = '';
        my $packet_trace = [];
        my $bulk_post;
        $logger->info("Finding traceroute data....[START]\n");
        my $data_sql = "SELECT m.testspec_key, m.id, m.timestamp, h.ttl, h.queryNum, h.addr, h.delay FROM ${table_prefix}_MEASUREMENT AS m INNER JOIN ${table_prefix}_HOPS AS h ON m.id=h.measurement_id ";
        $data_sql .= "WHERE STRCMP(m.testspec_key, ?) = 1 " if($state->{'traceroute'}->{'test'});
        $data_sql .= "ORDER BY m.testspec_key, m.id, h.ttl, h.queryNum";
        my $data_sth = $dbh->prepare($data_sql) or die $dbh->errstr;
        $data_sth->bind_param(1, $state->{'traceroute'}->{'test'})  if($state->{'traceroute'}->{'test'});
        $data_sth->execute() or die $data_sth->errstr;
        $logger->info("Finding traceroute data....[END]\n");
        while(my $data_row = $data_sth->fetchrow_arrayref){ 
            my $cur_test = $data_row->[0]; 
                        
            # look at metadata and register if we are done with test
            if($prev_test ne $cur_test){
                # submit data if there was a previous test
                if($prev_test){
                    $logger->info("Sending traceroute data for $prev_test....[START]\n");
                    $bulk_post->add_data_point('packet-trace', $prev_ts, $packet_trace);
                    $bulk_post->post_data();
                    if ($bulk_post->error()){
                        die "Error posting $prev_test" . $bulk_post->error() . "\n";
                    }
                    $state->{'traceroute'} = {} unless($state->{'traceroute'});
                    $state->{'traceroute'}->{'date'} = $table_time;
                    $state->{'traceroute'}->{'test'} = $prev_test;
                    $packet_trace = [];
                    $logger->info("Sending traceroute data for $prev_test....[END]\n");
                }
                $prev_test = '';#reset so if we have to skip current test we don't re-post
                
                my $tspec = $tspec_map{$data_row->[0]};
                unless($tspec){
                    $logger->error("Unable to find test spec with id " . $data_row->[2] . "\n");
                    next;
                }
                
                #build metadata for new test
                $logger->info("Sending metadata....[START]\n");
                my $source =  $tspec->{'src'};
                my $dest = $tspec->{'dst'};
                my ($source_ip, $dest_ip) = &convert_to_ips($source, $dest);
                unless($source_ip && $dest_ip){
                    $logger->info("Sending metadata....[SKIP]\n");
                    next;
                }
                
                
                $metadata = new perfSONAR_PS::Client::Esmond::Metadata(url => $maurl, filters => $filters);
                $metadata->subject_type('point-to-point');
                $metadata->tool_name('psscheduler/traceroute');
                $metadata->source($source_ip);
                $metadata->destination($dest_ip);
                $metadata->input_source($source);
                $metadata->input_destination($dest);
                $metadata->measurement_agent($source_ip);#TODO: set this correctly
                foreach my $meta_field(keys %{$tspec}){
                    $metadata->set_field($meta_field, $tspec->{$meta_field}) if($meta_field ne 'src' && $meta_field ne 'dst' && $tspec->{$meta_field});
                }
                $metadata->add_event_type('packet-trace');
                $metadata->add_event_type('failures');
                $metadata->post_metadata();
                $logger->info("Sending metadata....[END]\n");
                if($metadata->error()){
                    $logger->error("Error posting metadata to MA: " . $metadata->error() . "\n");
                    next;
                }
                $ma_key_map{$cur_test} = $metadata;
                $bulk_post = $metadata->generate_event_type_bulk_post();
            }
            
            #start a new packet trace
            my $ts = $data_row->[2];
            if($prev_meas && $prev_meas != $data_row->[1]){
                $bulk_post->add_data_point('packet-trace', $ts, $packet_trace);
                $packet_trace = [];
            }
            
            #add hop to packet trace
            if($data_row->[5] =~ /^error/){
                push @{$packet_trace}, {
                    'ttl' =>  $data_row->[3],
                    'query' =>  $data_row->[4],
                    'success' =>  0,
                    'error-message' => $data_row->[5],
                    'ip' =>  undef,
                    'rtt' =>  undef,
                    'mtu' =>  undef,
                };
            }else{
                push @{$packet_trace}, {
                    'ttl' =>  $data_row->[3],
                    'query' =>  $data_row->[4],
                    'success' =>  1,
                    'error-message' =>  undef,
                    'ip' =>  $data_row->[5],
                    'rtt' =>  $data_row->[6],
                    'mtu' =>  undef,
                };
            }

            #set variables for next iteration
            $prev_test = $cur_test;
            $prev_meas = $data_row->[1];
            $prev_ts = $ts;
        }
        if($bulk_post){
            $logger->info("Sending remaining data....[START]\n");
            $bulk_post->add_data_point('packet-trace', $prev_ts, $packet_trace);
            $bulk_post->post_data();
            if ($bulk_post->error()){
                die "Error posting $prev_test" . $bulk_post->error() . "\n";
            }
            $state->{'traceroute'} = {} unless($state->{'traceroute'});
            $state->{'traceroute'}->{'date'} = $table_time;
            $state->{'traceroute'}->{'test'} = $prev_test;
            $packet_trace = [];
            $logger->info("Sending remaining data....[END]\n");
        }
    }
}


###############################################################################
# General Subroutines
###############################################################################
sub load_state_file {
    my $file = shift;
    my %state = ();
    if (-e $file) {
        open FIN, "< $file" or die "Unable to open $file: $@";
        while(<FIN>){
            chomp;
            my @cols = split ' ', $_;
            next unless @cols >= 2;
            $state{$cols[0]} = {'date' => $cols[1]};
            $state{$cols[0]} ->{'test'} = $cols[2] if( @cols >= 3);
        }
        close FIN;
    }else{
        #create empty file
        &save_state_file($file, $state);
    }
    
    return \%state;
}

sub save_state_file {
    my ($file, $state) = @_;
    my %state = ();
    
    $logger->info("Saving state file....[START]\n");
    open FOUT, "> $file" or die "Unable to open $file: $@";
    foreach my $type(keys %{$state}){
        if($state->{$type}->{'date'}){
            print FOUT "$type " . $state->{$type}->{'date'} . ($state->{$type}->{'test'} ? " " . $state->{$type}->{'test'} : '') . "\n";
        }
    }
    close FOUT;
    $logger->info("Saving state file....[END]\n");
}

sub convert_to_ips {
    my ($src, $dst) = @_;
    
    my $src_ip;
    my $dst_ip;
    my $src_addr_map = &build_addr_map($src);
    my $dst_addr_map = &build_addr_map($dst);
    
    if($src_addr_map->{'ipv6'} && $dst_addr_map->{'ipv6'}){
        $src_ip = $src_addr_map->{'ipv6'};
        $dst_ip = $dst_addr_map->{'ipv6'};
    }elsif($src_addr_map->{'ipv4'} && $dst_addr_map->{'ipv4'}){
        $src_ip = $src_addr_map->{'ipv4'};
        $dst_ip = $dst_addr_map->{'ipv4'};
    }else{
        #if a mismatch, probably DNS changed so skip
        $logger->warn("Source and destination address types don't match. Skipping $src to $dst.\n");
    }
    
    return ($src_ip, $dst_ip);
}

sub signal_handler {
    save_state_file($state_file, $state);
    exit 1;
}

sub build_addr_map {
    my $addr = shift;
    
    my %addr_map = ();
    
    if( is_ipv4($addr) ){
       $addr_map{'ipv4'} = $addr;
    }elsif( is_ipv6($addr) ){
       $addr_map{'ipv6'} = $addr;
    }else{
        #if not ipv4 or ipv6 then assume a hostname
        my @addresses = resolve_address($addr);
        for(my $i =0; $i < @addresses; $i++){
            if( is_ipv4($addresses[$i])){
                $addr_map{'ipv4'} = $addresses[$i];
            }elsif( is_ipv6($addresses[$i])){
                $addr_map{'ipv6'} = $addresses[$i];
            }
        }
    }
    
    return \%addr_map;
    
}

sub owptime2time{
        my $JAN_1970 = 0x83aa7e80; # offset in seconds
        my $scale = uint64(2)**32;
        my $bigtime =uint64($_[0]);
        $bigtime /= $scale;
        return uint64_to_number($bigtime - $JAN_1970 );
}

sub usage() {
    print "clean_pSB_db.pl <options>\n";
    print "    -h,--help                            displays this message.\n";
    print "    --maxdays days                       maximum age (in days) of data to keep in database. Not valid for bwctl databases. Defaults to 90.\n";
    print "    --maxmonths months                   maximum number of months to keep in database. Must be used for bwctl databases. Defaults to 3.\n";
    print "    --dbtype type                        Indicates type of data in database. Valid value are 'owamp', 'bwctl', and 'traceroute'. Defaults to 'owamp'.\n";
    print "    --dbuser user                        name of database user. Defaults to root.\n";
    print "    --dbpassword password                password to access database. Defaults to empty string.\n";
    print "    --dbhost host                        database host to access. Defaults to localhost.\n";
    print "    --owmesh-dir dir                     location of owmesh.conf file with database username and password.\n";
    print "                                         overrides dbuser, dbpassword, and dbhost.\n";
    print "    --verbose                            increase amount of output from program\n";
}

__END__

=head1 SEE ALSO
L<DBI>, L<Getopt::Long>, L<Time::Local>, L<POSIX>,
L<perfSONAR_PS::Config::OWP::Conf>

To join the 'perfSONAR Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS git repository is located at:

  https://code.google.com/p/perfsonar-ps/

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: perfSONARBUOY.pm 4030 2010-05-14 15:06:51Z alake $

=head1 AUTHOR

Andy Lake, andy@es.net

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

Copyright (c) 2007-2014, Internet2

All rights reserved.

=cut
