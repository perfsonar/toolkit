package perfSONAR_PS::NPToolkit::Config::PSConfigParser;
#BaseAgent.pm (perfSONAR_PS/PSConfig/ )

use Mouse;

use CHI;
use Data::Dumper;
#use Data::Structure::Util qw( unbless );
use Data::Validate::Domain qw(is_hostname);
use Data::Validate::IP qw(is_ipv4 is_ipv6 is_loopback_ipv4);
use Net::CIDR qw(cidrlookup);
use File::Basename;
use JSON qw/ from_json /;
use Log::Log4perl qw(get_logger);
use URI;
use Params::Validate qw(:all);

use perfSONAR_PS::Common qw(genuid);

use perfSONAR_PS::Client::PSConfig::ApiConnect;
use perfSONAR_PS::Client::PSConfig::ApiFilters;
use perfSONAR_PS::Client::PSConfig::Archive;
use perfSONAR_PS::Client::PSConfig::Config;

use perfSONAR_PS::Client::PSConfig::Parsers::TaskGenerator;
#use perfSONAR_PS::PSConfig::ArchiveConnect;
#use perfSONAR_PS::Utils::Logging;
#use perfSONAR_PS::PSConfig::RequestingAgentConnect;
#use perfSONAR_PS::PSConfig::TransformConnect;
#use perfSONAR_PS::Utils::DNS qw(resolve_address reverse_dns);
#use perfSONAR_PS::Utils::Host qw(get_ips);
#use perfSONAR_PS::Utils::ISO8601 qw/duration_to_seconds/;

our $VERSION = 4.1;


has 'config_file' => (is => 'rw', isa => 'Str', default => '/etc/perfsonar/psconfig/pscheduler.d/toolkit-webui.json');
has 'test_config_defaults_file' => (is => 'rw', isa => 'Str', default => '/etc/perfsonar/psconfig/pscheduler.d/toolkit-webui.json');
has 'default_test_parameters' => (is => 'rw', isa => 'HashRef|Undef', writer => '_set_default_test_parameters');
has 'psconfig' => (is => 'rw', isa => 'perfSONAR_PS::Client::PSConfig::Config', default => sub { new perfSONAR_PS::Client::PSConfig::Config(); });


has 'task_name' => (is => 'rw', isa => 'Str');
has 'match_addresses' => (is => 'rw', isa => 'ArrayRef[Str]', default => sub {[]});
has 'pscheduler_url' => (is => 'rw', isa => 'Str');
has 'default_archives' => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::Client::PSConfig::Archive]', default => sub { [] });
has 'use_psconfig_archives' => (is => 'rw', isa => 'Bool', default => sub { 1 });
has 'bind_map' => (is => 'rw', isa => 'HashRef', default => sub { {} });

#read-only
###Updated whenever an error occurs
has 'error' => (is => 'ro', isa => 'Str|Undef', writer => '_set_error');
###Updated on call to start()
has 'started' => (is => 'ro', isa => 'Bool', writer => '_set_started');
has 'task' => (is => 'ro', isa => 'perfSONAR_PS::Client::PSConfig::Task|Undef', writer => '_set_task');
has 'group' => (is => 'ro', isa => 'perfSONAR_PS::Client::PSConfig::Groups::BaseGroup|Undef', writer => '_set_group');
has 'schedule' => (is => 'ro', isa => 'perfSONAR_PS::Client::PSConfig::Schedule|Undef', writer => '_set_schedule');
has 'tools' => (is => 'ro', isa => 'ArrayRef[Str]|Undef', writer => '_set_tools');
has 'priority' => (is => 'ro', isa => 'Int', writer => '_set_priority');
has 'test' => (is => 'ro', isa => 'perfSONAR_PS::Client::PSConfig::Test|Undef', writer => '_set_test');
##Updated each call to next()
has 'expanded_test' => (is => 'ro', isa => 'HashRef|Undef', writer => '_set_expanded_test');
has 'expanded_archives' => (is => 'ro', isa => 'ArrayRef|Undef', writer => '_set_expanded_archives');
has 'expanded_contexts' => (is => 'ro', isa => 'ArrayRef|Undef', writer => '_set_expanded_contexts');
has 'expanded_reference' => (is => 'ro', isa => 'HashRef|Undef', writer => '_set_expanded_reference');
has 'scheduled_by_address' => (is => 'ro', isa => 'perfSONAR_PS::Client::PSConfig::Addresses::BaseAddress|Undef', writer => '_set_scheduled_by_address');
has 'addresses' => (is => 'ro', isa => 'ArrayRef[perfSONAR_PS::Client::PSConfig::Addresses::BaseAddress]|Undef', writer => '_set_addresses');
#
#has 'toolkit_tests' => (is => 'rw', isa => 'ArrayRef[]', default => sub {[]});



#private
has '_match_addresses_map' => (is => 'ro', isa => 'HashRef|Undef', writer => '_set_match_addresses_map');


sub new {
    my ($self, @params) = @_;
    #print("\nJovana: konstruktor\n");
    #print("\n\n\n\ndefaults parametar " . Dumper(@params) . "\n\n\n");
    my $parameters = validate(@params, { test_config_defaults_file => 1, config_file => 1 });
    $self->test_config_defaults_file($parameters->{test_config_defaults_file});
    $self->config_file($parameters->{config_file});
    #print("\n\n\n\ndefaults " . $self->test_config_defaults_file . "\n\n\n");
    #print ("\n\nKONSTRUKTOR\n" . Dumper(@params) . "\n");
    #print ("\n\nKONSTRUKTOR\n" . Dumper($parameters->{test_config_defaults_file}) . "\n");
}

sub init {
    # my ( $class, @params ) = @_;
    my ( $self, $params) = @_;
    #print("\n\n\n\ninit parametar " . Dumper($params) . "\n\n\n");
    #print("\n\n\n\nmy parametar " . $self->config_file . "\n\n\n");
    #print("\n\n\n\nmy parametar " . $self->test_config_defaults_file . "\n\n\n");

    my $conf_obj = Config::General->new( -ConfigFile => $self->test_config_defaults_file );
    my %conf = $conf_obj->getall;
    $self->_set_default_test_parameters(\%conf);
    #my $config_file = $params if $params;

    $self->config_file("/etc/perfsonar/psconfig/pscheduler.d/toolkit-webui.json");
    #print ("init parametar " . $self->config_file . "\n");

    my $json_text = do {
        open(my $json_fh, "<:encoding(UTF-8)", $self->config_file)
 	    or die("Can't open \"$self->config_file\": $!\n");
        local $/;
     	<$json_fh>
    };
    
    my $json = JSON->new;
    my $data = $json->decode($json_text);
    # my $config_obj = from_json($config_json);

    ##print ("init json " . $data . "\n");
    #######
    ### Initialize psconfig
    ##########
    my $psconfig = new perfSONAR_PS::Client::PSConfig::Config(data => $data);
    $self->psconfig($psconfig);
    ##is($psconfig->validate(), 0);
    ##
#    my $config_file = $self->config_file();

#    my $self = fields::new( $class );

#    $self->config_file('/etc/perfsonar/psconfig/pscheduler.d/toolkit-webui.json'); # $config_file);
    # $self->config_file($config_file);
    # #print ("init self " . $self->config_file . "\n\t " . Dumper($self->psconfig) . "\n");
}

=head2  map_psconfig_tasks_to_toolkit_UI
    Maps data (expanded tasks and tests) read from psConfig JSON to JSON needed by toolkit UI. 
=cut

sub map_psconfig_tasks_to_toolkit_UI() {
    my $self = shift;
    my @tasks = $self->_run_handle_psconfig();
    
    #my $tests = {};

    #foreach my $task_name(@{$tasks}) {
#    print("Taskova ima " . scalar @tasks . "\n");
#    foreach my $task(@tasks) {
#	print("JOVANA: " . Dumper($task) . "\n");
	# print("JOVANA: " . "\n");
#    }
    my $tests = [];
    my $brojac = 0;
    foreach my $task(@tasks) {
        $brojac = $brojac + 1;
#	print("Task_" . $brojac . ":" . Dumper($task) . "\n");
#next;
	next unless ref $task eq ref {};
        my $test = {};
	my $parameters = {};
	#print ("JOVANA expected hash " . Dumper($task));
	my $task_name = $task->{name};
	my $task_tool = $task->{tools};
	my $task_value = $task->{details};
	my $task_type = $task->{type};
#	if ($task->{type} eq 'latencybg') {
#            $task_type = 'powstream';
#	} elsif ($task->{type} eq 'throughput') {
#            $task_type = 'bwctl';
#	} elsif ($task->{type} eq 'trace') {
#            $task_type = 'bwtraceroute';
#	} elsif ($task->{type} eq 'rtt') {
	#jovana: gde se mapira u pinger???
#            $task_type = 'pinger';
#	} elsif ($task->{type} eq 'rtt') {
#            $task_type = 'bwping';
#	} elsif ($task->{type} eq 'latency') {
#            $task_type = 'bwping/owamp';
#	} elsif ($task->{type} eq 'simplestream') {
#            $task_type = 'simplestream';
#	} else {
#            $task_type = $task->{type};
#	}
	#print("ps_tasks " . Dumper(@pscheduler_tasks) . "\n\n");
		#foreach my $pscheduler_task(@pscheduler_tasks) {
		#}



	$test->{description} = $task_name; 
#	print('JOVANA JOVANA JOVANA mapped task type ' . $task_type);
	$test->{type} = $task_type;
	$parameters->{tool} = $task_tool if $task_tool;
	$parameters->{ttl} = $task->{ttl} if $task->{ttl};
	$parameters->{packet_interval} = $task->{packet_interval} if $task->{packet_interval};
	$parameters->{packet_size} = $task->{packet_size} if $task->{packet_size};
	$parameters->{packet_count} = $task->{packet_count} if $task->{packet_count};
	$parameters->{packet_padding} = $task->{packet_padding} if $task->{packet_padding};
	$parameters->{tos_bits} = $task->{tos_bits} if $task->{tos_bits};
	if ($task_type eq 'throughput') {
	    $parameters->{protocol} = $task->{protocol};
        }
	$parameters->{duration} = $task->{duration} if $task->{duration};
	$parameters->{test_interval} = $task->{test_interval} if $task->{test_interval};
	$test->{disabled} = undef;
	$test->{added_by_mesh} = undef;
	$test->{id} = $task->{id} ;
	$test->{test_id} = $task->{test_id} ;
	#JOVANA ovo treba da postane IP ili 127.0.0.1
	$parameters->{local_interface} = $task->{local_interface}; #undef;
	$test->{parameters} = $parameters;
	$test->{members} = $task->{members};
	#foreach my $member(@members) {
		#my %member_hash = ();
		#$member_hash{id} = $member->{id};
		#    push @members, $member;
		#}
	push @$tests, $test;
	$brojac++;
    }    

    #my @tests_1 = ();
    #return @tests_1;
#print(Dumper($tests));
    return $tests;

}

=head2 get_test_configuration
    Acquires data needed by Toolkit UI and puts it in a single JSON object. 
    The JSON object has only three properties: test_configuration and test_defaults and status.
=cut

sub get_test_configuration {
#    my ($self, $params) = @_;
#    print("JOVANA get_test_configuration " . Dumper(@_));
    my $self = shift;
    #my @tasks = $self->_run_handle_psconfig();
    #$self->log_debug("JOVANA get_testing_config Tasks: " . Dumper(@tasks));  
    #print("JOVANA get_testing_config Tasks: " . Dumper(@tasks));  
    my $tests = [];
#    my $test_defaults;
#    $test_defaults->{type}->{'bwctl/throughput'}->{window_size} = "0";
#    $test_defaults->{type}->{'bwctl/throughput'}->{local_interface} = "default";
#    $test_defaults->{type}->{'bwctl/throughput'}->{tos_bits} = "0";
#    $test_defaults->{type}->{'bwctl/throughput'}->{duration} = "20";
#    $test_defaults->{type}->{'bwctl/throughput'}->{tools} = "iperf3,iperf";
#    $test_defaults->{type}->{'bwctl/throughput'}->{protocol} = "tcp";
#    $test_defaults->{type}->{'bwctl/throughput'}->{test_interval} = "21600";

#    $test_defaults{"type"}{"pinger"}{"local_interface"} = "default";
#    $test_defaults{"type"}{"pinger"}{"packet_interval"} = "1";
#    $test_defaults{"type"}{"pinger"}{"packet_size"} = "1000";
#    $test_defaults{"type"}{"pinger"}{"test_interval"} = "300";
#    $test_defaults{"type"}{"pinger"}{"packet_count"} = "10";
    
#    $test_defaults{"type"}{"traceroute"}{"test_interval"} = "600";
#    $test_defaults{"type"}{"traceroute"}{"tool"} = "traceroute,tracepath";
#    $test_defaults{"type"}{"traceroute"}{"max_ttl"} = null;
#    $test_defaults{"type"}{"traceroute"}{"first_ttl"} = null;
#    $test_defaults{"type"}{"traceroute"}{"local_interface"} = "default";    
#    $test_defaults{"type"}{"traceroute"}{"packet_size"} = "40";
       
#    $test_defaults{"type"}{"owamp"}{"packet_padding"} = "0";
#    $test_defaults{"type"}{"owamp"}{"packet_interval"} = "0.1";
#    $test_defaults{"type"}{"owamp"}{"local_interface"} = "default";

    my $status_vars = {};
    $status_vars->{network_percent_used}    = "0";
    $status_vars->{hosts_file_matches_dns}  = "null";
    $status_vars->{owamp_ports}             = "0";
    $status_vars->{owamp_port_range}        = "null";
    $status_vars->{owamp_port_usage}        = "0";
    $status_vars->{owamp_tests}             = "0";
    $status_vars->{pinger_tests}            = "0";
    $status_vars->{throughput_tests}        = "0";
    $status_vars->{traceroute_tests}        = "0";

#    return {
#	test_configuration => {},
#	status => $status_vars,
#	test_defaults => $test_defaults
#    };


    my $test_configuration = $self->map_psconfig_tasks_to_toolkit_UI();

    return {
        test_configuration => ($test_configuration),
	status => $status_vars,
	test_defaults => $self->default_test_parameters #{} #$test_defaults
    };

}

# JOVANA: potrebna za reset
#
sub parse_psconfig_testing_config {
    my($self, $params) = @_;
    my $test_configuration = $self->map_psconfig_tasks_to_toolkit_UI();
    #return { 0, "" };
    #return { 0, $test_configuration };
    return ( 0, $test_configuration );
}

=head2 _run_handle_psconfig save
    Reads data from psConfig JSON file, expands it using TaskGenerator like Agents do and extracts data needed by Toolkit UI. 
=cut

sub _run_handle_psconfig {
    my($self, $agent_conf, $remote) = @_;
    my $psconfig = $self->psconfig;
    #print("JOVANA _run_handle_psconfig pocetak\n"); 
    #Init variables
    my $configure_archives = 0; #make sure defined
    if(!$remote){
        #configure archives if not from a remote source
        $configure_archives = 1;
    }elsif($remote && $remote->configure_archives()){
        #configure archives if from a remote source and said it is ok
        $configure_archives = 1;
    }
    
    my @psconfig_tasks = [];
    my $brojac = 1;

    my @group_names =  @{$psconfig->group_names()};
    my %exclude_ip_addresses;
    for my $group_name (@group_names) {
	    my $jovana_ip = substr $group_name, (rindex($group_name, "_") + 1);
	    $exclude_ip_addresses{$jovana_ip} = undef;
	    #print("$group_name $jovana_ip\n");
    }

    #walk through tasks
    #print("JOVANA taskova ima " . scalar(@{$psconfig->task_names()}) . "\n");
    foreach my $task_name(@{$psconfig->task_names()}){
	    #print("================================================================\n");
	    #print("================================================================\n");
        my $task = $psconfig->task($task_name);
        next if(!$task || $task->disabled());

	my $task_group = $task->group_ref();
	my $local_interface_ip;
       	if ($task_group) {
	    my $last_index = rindex($task_group, "_");
	    if ($last_index > 0) { 
                $local_interface_ip = substr($task_group, $last_index + 1);
            } else {
                $local_interface_ip = 'default';
	    }
        } else {
            $local_interface_ip = 'default';
	}

	#print("Local interface for task_name $task_name " . $local_interface_ip . " (group: " . $task_group . ")\n");
#JOVANA	
#        $self->logf->global_context()->{'task_name'} = $task_name;
	#print ("JOVANA: " . Dumper($task) . "\n");
        my $toolkit_ui_taskname = $task->{data}->{_meta}->{"display-name"};
	my $psconfig_schedule_name = $task->{data}->{schedule};
	my $psconfig_schedule = $psconfig->schedule($psconfig_schedule_name);
	if ($psconfig_schedule and $psconfig_schedule->{data} and $psconfig_schedule->{data}->{repeat}) {
	    $psconfig_schedule = $psconfig_schedule->{data}->{repeat};
	    my $interval_length = length($psconfig_schedule) - 3;
	    $psconfig_schedule = substr($psconfig_schedule, 2, $interval_length);
        }

	#my $psconfig_schedule_name = $task->schedule_ref();
	#my $psconfig_schedule = $psconfig->schedule($psconfig_schedule_name);
	my @task_tools_array = @{$task->tools()} if $task->tools();
	my $toolkit_ui_tool = "";
	if (@task_tools_array)  {
	    $toolkit_ui_tool = join(",", @task_tools_array);
	}
#	foreach my $task_tool(@task_tools_array) {
#            $toolkit_ui_tool = $toolkit_ui_tool . "," .$task_tool;
	    #print ("JOVANA: $toolkit_ui_taskname " . Dumper(@task_tools_array) . "\n");
#	}
#	print ("JOVANA: $toolkit_ui_taskname [$toolkit_ui_tool] " . Dumper($psconfig_schedule) . "\n");
	    #print ("JOVANA: $toolkit_ui_taskname psconfig_schedule " . Dumper($psconfig_schedule) . "\n");
	#print ("JOVANA: $toolkit_ui_taskname " . Dumper($task->tools()) . "\n");
	#print ("JOVANA: $toolkit_ui_taskname " . (ref $task->tools() eq 'ARRAY') . "\n");
        my $tg = new perfSONAR_PS::Client::PSConfig::Parsers::TaskGenerator(
            psconfig => $psconfig,
#JOVANA	    
#            pscheduler_url => $self->pscheduler_url(),
            task_name => $task_name,
            match_addresses => $self->match_addresses(),
            default_archives => $self->default_archives(),
            use_psconfig_archives => $configure_archives,
#JOVANA	    
#            bind_map => $agent_conf->pscheduler_bind_map()
            bind_map => {} #$agent_conf->pscheduler_bind_map()
        );
        unless($tg->start()){
#             $logger->error($self->logf()->format("Error initializing task iterator: " . $tg->error()));
             return;
        }
        my @pair;
	my @task_generator_pscheduler_tasks = ();
	my $task_type;
	my $psconfig_test_ip_v4;
	my $psconfig_test_ip_v6;
	my $psconfig_test_duration;
	my $psconfig_test_zero_copy;
	my $psconfig_test_udp = 0;
	my $psconfig_test_window_size;
	my $psconfig_test_tos_bits;
	my $psconfig_test_streams;
	my $psconfig_test_single_ended;
	my $psconfig_test_omit_interval;
	my $psconfig_test_bandwidth;
	my $psconfig_test_ttl;
	my $psconfig_test_packet_count;
	my $psconfig_test_packet_interval;
	my $psconfig_test_packet_size;
	my $psconfig_test_packet_padding;
	my @members = ();
	my $jovana_brojac = 0;
	my %members_hash;
        while(@pair = $tg->next()){
            #check for errors expanding task
            if($tg->error()){
#                $logger->error($tg->error());
                next;
            }
	    ## treba skupljati sve adrese u hash i onda postaviti sender i receiver
	    $jovana_brojac++;
            #build pscheduler
            my $psc_task = $tg->pscheduler_task();
	    $task_type = $psc_task->test_type();
	    # task and test have the same name
	    my $test_spec = $psc_task->test_spec();
	    #print($toolkit_ui_taskname . " test_spec " . Dumper($test_spec) . "\n");
	    if ($test_spec->{'bandwidth'}) {
                $psconfig_test_bandwidth = int($test_spec->{'bandwidth'});	
            }  
            $psconfig_test_omit_interval = $test_spec->{'omit'};	
	    if ($test_spec->{'omit'}) {
	        my $psconfig_test_omit_interval_length = length($psconfig_test_omit_interval) - 3; #PT...S
                $psconfig_test_omit_interval = substr($psconfig_test_omit_interval, 2, $psconfig_test_omit_interval_length);	
            }  
	    if ($test_spec->{'single-ended'}) {
                $psconfig_test_single_ended = int($test_spec->{'single-ended'});	
            }  
	    if ($test_spec->{'parallel'}) {
                $psconfig_test_streams = int($test_spec->{'parallel'});	
            }  
	    if ($test_spec->{'ip-tos'}) {
                $psconfig_test_tos_bits = int($test_spec->{'ip-tos'});	
            }  
	    if ($test_spec->{'window-size'}) {
                $psconfig_test_window_size = int($test_spec->{'window-size'});	
            }  
	    if ($test_spec->{'udp'}) {
                $psconfig_test_udp = int($test_spec->{'udp'});	
            }  
	    if ($test_spec->{'zero-copy'}) {
                $psconfig_test_zero_copy = int($test_spec->{'zero-copy'});	
            }  
	    if ($test_spec->{'ip-version'} eq '4') {
                $psconfig_test_ip_v4 = int(1);	
            } else {
                $psconfig_test_ip_v4 = int(0);	
	    }
	    if ($test_spec->{'ip-version'} eq '6') {
                $psconfig_test_ip_v6 = int(1);	
            } else {
                $psconfig_test_ip_v6 = int(0);	
            }  
	    if ($test_spec->{'ttl'}) {
                $psconfig_test_ttl = "$test_spec->{'ttl'}";	
            }  
	    if ($test_spec->{'packet-padding'}) {
                $psconfig_test_packet_padding = "$test_spec->{'packet-padding'}";	
            }  
	    if ($test_spec->{'packet-size'}) {
                $psconfig_test_packet_size = "$test_spec->{'packet-size'}";	
            }  
	    if ($test_spec->{'packet-interval'}) {
                $psconfig_test_packet_interval = "$test_spec->{'packet-interval'}";	
            }  
	    if ($test_spec->{'packet-count'}) {
                $psconfig_test_packet_count = "$test_spec->{'packet-count'}";	
            }  
	    #print($toolkit_ui_taskname . " $psconfig_test_packet_padding test_spec.padding " . $test_spec->{'packet-padding'} . "\n");
	    #print($toolkit_ui_taskname . " $psconfig_test_packet_interval test_spec.interval " . $test_spec->{'packet-interval'} . "\n");
	    $psconfig_test_duration = $test_spec->{duration};
	    if ($psconfig_test_duration) {
	        my $psconfig_test_duration_length = length($psconfig_test_duration) - 3; #PT...S
	        $psconfig_test_duration = substr($psconfig_test_duration, 2, $psconfig_test_duration_length);
            }
	    #print("$toolkit_ui_taskname $jovana_brojac psc_task->test_spec " . Dumper($test_spec) . "\n");
	    #foreach my $key (keys %test) {	  
	    #    print("psc_task.data{test}{$key} " . $test{$key} . "\n");
	    #}
	    #print("psc_task " . Dumper($psc_task) . "\n");
	    #print("psc_task->test_type() " . $psc_task->test_type() . "\n");
            unless($psc_task){
#                $logger->error($self->logf()->format("Error converting task to pscheduler: " . $tg->error()));
                next;
            }
	    my $source_address = $test_spec->{'source'};
	    unless (exists $exclude_ip_addresses{$source_address}) {
                $members_hash{$source_address}{sender} = 1;
    		my $source_id = genuid();
    		my $member_source_id = "member." . $source_id;
    		$members_hash{$source_address}{id} = $member_source_id;
    		$members_hash{$source_address}{member_id} = $source_id;
    		$members_hash{$source_address}{address} = $test_spec->{'source'};
    		$members_hash{$source_address}{test_ipv4} = $psconfig_test_ip_v4;
    		$members_hash{$source_address}{test_ipv6} = $psconfig_test_ip_v6;
            }

            my $destination_address = $test_spec->{'dest'};
	    unless (exists $exclude_ip_addresses{$destination_address}) {
    		$members_hash{$destination_address}{receiver} = 1;
    		my $destination_id = genuid();
    		my $member_destination_id = "member." . $destination_id;
    		$members_hash{$destination_address}{id} = $member_destination_id;
    		$members_hash{$destination_address}{member_id} = $destination_id;
    		$members_hash{$destination_address}{address} = $test_spec->{'dest'};
    		$members_hash{$destination_address}{test_ipv4} = $psconfig_test_ip_v4;
    		$members_hash{$destination_address}{test_ipv6} = $psconfig_test_ip_v6;
            }
	    push(@task_generator_pscheduler_tasks, $psc_task);

        } 
        $tg->stop();
	    foreach my $key (%members_hash) {
		unless ($members_hash{$key}) {
			next;
		}
		#print("************************************\n");
		#print("JOVANA member $key " . Dumper($members_hash{$key}) . "\n");
		#print("************************************\n");
		push(@members, $members_hash{$key});
	    }
	#print("pscheduler_tasks" . Dumper(@task_generator_pscheduler_tasks) . "\n\n");
	my $jovana_test_id = genuid();
	my $jovana_id = "test." . $jovana_test_id;
        my $jovana_task = {};
        $jovana_task->{name} = $toolkit_ui_taskname;
	$jovana_task->{id} = $jovana_id;
	$jovana_task->{test_id} = $jovana_test_id;
	$jovana_task->{test_interval} = $psconfig_schedule;
        $jovana_task->{tools} = $toolkit_ui_tool;
	$jovana_task->{type} = $task_type;
	$jovana_task->{duration} = $psconfig_test_duration;
	$jovana_task->{ttl} = $psconfig_test_ttl if defined $psconfig_test_ttl;
	#print($toolkit_ui_taskname . " J " . $psconfig_test_packet_padding . "\n");
	#print($toolkit_ui_taskname . " J " . $psconfig_test_packet_interval . "\n");
	$jovana_task->{packet_count} = $psconfig_test_packet_count if defined $psconfig_test_packet_count;
	$jovana_task->{packet_interval} = $psconfig_test_packet_interval if defined $psconfig_test_packet_interval;
	$jovana_task->{packet_size} = $psconfig_test_packet_size if defined $psconfig_test_packet_size;
	$jovana_task->{packet_padding} = $psconfig_test_packet_padding if defined $psconfig_test_packet_padding;
	$jovana_task->{zero_copy} = $psconfig_test_zero_copy if defined $psconfig_test_zero_copy;
	$jovana_task->{window_size} = $psconfig_test_window_size if defined $psconfig_test_window_size;
	$jovana_task->{tos_bits} = $psconfig_test_tos_bits if defined $psconfig_test_tos_bits;
	$jovana_task->{streams} = $psconfig_test_streams if defined $psconfig_test_streams;
	$jovana_task->{single_ended} = $psconfig_test_single_ended if defined $psconfig_test_single_ended;
	$jovana_task->{omit_interval} = $psconfig_test_omit_interval if defined $psconfig_test_omit_interval;
	if ($psconfig_test_udp) {
            $jovana_task->{protocol} = "udp";
	    $jovana_task->{udp_bandwidth} = $psconfig_test_bandwidth if defined $psconfig_test_bandwidth;
        } else {
	    $jovana_task->{protocol} = "tcp";
	    $jovana_task->{tcp_bandwidth} = $psconfig_test_bandwidth if defined $psconfig_test_bandwidth;
	}
        $jovana_task->{members} = \@members;
	$jovana_task->{local_interface} = $local_interface_ip;
	$jovana_task->{disabled} = undef; # null;
	$jovana_task->{added_by_mesh} = undef; # null;



	    #push(@psconfig_tasks, {$task_name, $psc_task});
	    #ne postoji $self->task_manager()
	    #$self->task_manager()->add_task(task => $psc_task);
            #log task to task log. Do here because even if was not added, want record that
            # it is a task that this host manages
#            $task_logger->info($self->logf()->format_task($psc_task));
        
	#print("JOVANA: brojac $brojac " . Dumper($jovana_task) . "\n");
	push(@psconfig_tasks, $jovana_task);
	$brojac++;
    }
#    $logger->debug($self->logf()->format('Successfully processed task.'));
#
#    foreach my $task_name_jovana(@{$psconfig->task_names()}){
#        print("J: " . $task_name_jovana  . "\n");
#    }

    #print("psconfig_tasks ima " . scalar @psconfig_tasks . " brojac $brojac\n");
    #print("*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-\n");
    return @psconfig_tasks;
}

=begin comment
sub get_toolkit_test() {
    my $self = shift;    

    my %toolkit_test = ();
    $toolkit_test{'description'} = $self->task()->map_name();
    my @target = ();



    $toolkit_test{'target'} = @target;
    my %parameters = ();

    print("self->schedule ".Dumper($self->schedule())."\n");
    my %schedule = ();
    if ($self->schedule() && (ref($self->schedule()) eq 'perfSONAR_PS::RegularTesting::Schedulers::RegularInterval')) {
	$schedule{'interval'} = $self->schedule()->interval();       
        $schedule{'type'} = "regular_intervals";
    } elsif ($self->schedule() && (ref($self->schedule()) eq 'perfSONAR_PS::RegularTesting::Schedulers::TimeBasedSchedule')) {
        $schedule{'type'} = "test_schedule";
    } elsif ($self->schedule() && (ref($self->schedule()) eq 'perfSONAR_PS::RegularTesting::Schedulers::Streaming')) {
        $schedule{'type'} = "streaming";   
    }
    $toolkit_test{'schedule'} = %schedule;
    print("mapped toolkit_test ".Dumper(%toolkit_test)."\n\n");
    return %toolkit_test;
}

sub expand_task {
    my $self = shift;
    #clear out stuff set each next iteration
    $self->_reset();
    
    #find the next test we have to run
    my $scheduled_by = $self->task()->scheduled_by() ?  $self->task()->scheduled_by() : 0;
    my @addrs;
    my $matched = 1;
    my $flip = 0;
    my $scheduled_by_addr;
    #print("expand_task 1\n");
    #print("expand_task group ref ".ref($self->group())."\n");
    #print("expand_task group address_queue ".Dumper($self->group()->_address_queue())."\n");
    ##print("expand_task group ".Dumper($self->group())."\n");
    ##print("expand_task group->meta ".Dumper($self->group()->meta));
    ##print("expand_task group->next ".Dumper($self->group()->next())."\n");
#    return;
    #JOVANA: ovde treba $self->group da postane niz od jednog clana
    #	    if ($self->group() && @{$self->group()}) {
    #            $self->_set_tools($tools);
    #	    }
    #while(@addrs = $self->group()->next()){
    #while(@addrs = $self->group()->data()){
    if(@addrs = $self->group()->next()){
	#print("expanding_task 1.1 @addrs\n\tscheduled_by ".$scheduled_by."\n");
	#print("expanding_task 1.2 ".Dumper(@addrs)."\n");
        #validate scheduled by
        if($scheduled_by >= @addrs){
            print("The scheduled-by property for task  " . $self->task_name() . " is too big. It is set to $scheduled_by but must not be bigger than " . @addrs);
            $self->_set_error("The scheduled-by property for task  " . $self->task_name() . " is too big. It is set to $scheduled_by but must not be bigger than " . @addrs);
            return;
        }
        
        #check if disabled
        my $disabled = 0;
        foreach my $addr(@addrs){
            if($self->_is_disabled($addr)){
                $disabled = 1;
                last;
            }
        }
        next if($disabled);
        
        #get the scheduled-by address
        $scheduled_by_addr = $addrs[$scheduled_by];
        #if the default scheduled-by address is no-agent, pick first address that is not no-agent
        my $has_agent = 0;
        my $needs_flip = 0; #local var so don't leak non-matching address flip value to matching address
        if($self->_is_no_agent($scheduled_by_addr)){
            $needs_flip = 1;
            foreach my $addr(@addrs){
                if(!$self->_is_no_agent($addr)){
                    $scheduled_by_addr = $addr;
                    $has_agent = 1;
                    last;
                }
            }
        }else{
            $has_agent = 1;
        }
        
        #if the address responsible for scheduling matches us, exit loop, otherwise keep looking
	#if($has_agent && $self->_is_matching_address($scheduled_by_addr)){
	#    $matched = 1;
	#    $flip = $needs_flip;
	#    last;
	#}  
    }
    #print("expand_task 2\n");
    
    #if no match, then exit
    unless($matched){
	#print("unless(matched)\n");
	return;
    }
    #print("expand_task 3\n");
    
    #set addresses
    #print("ref addrs ".ref(\@addrs)."\n");
    $self->_set_addresses(\@addrs);
    #print("self->addrs ".Dumper($self->addresses())."\n");
    
    ##
    #create object to be queried by jq template vars
    my $archives = $self->_get_archives($scheduled_by_addr);
    if($self->error()){
         #print("Error (archives) ".$self->error());
         return $self->_handle_next_error(\@addrs, $self->error());
    }
    my $hosts = $self->_get_hosts();
    if($self->error()){
         return $self->_handle_next_error(\@addrs, $self->error());
    }
    #my $contexts = [];
    #my $jq_obj = $self->_jq_obj($archives, $hosts, $contexts);
    ## end jq obj
    
    #init template so we can start expanding variables
    my $template = new perfSONAR_PS::Client::PSConfig::Parsers::Template(
        groups => \@addrs,
        scheduled_by_address => $scheduled_by_addr,
        flip => $flip
	#jq_obj => $jq_obj
    );
    
    #set scheduled_by_address for this iteration
    $self->_set_scheduled_by_address($scheduled_by_addr);
    
    #expand test spec
    #print("expanding test:" . $self->test);
    my $test = $template->expand($self->test()->data());
    if($test){
        $self->_set_expanded_test($test);
    }else{
        #print("Error expanding test specification: " . $template->error());
        return $self->_handle_next_error(\@addrs, "Error expanding test specification: " . $template->error());
    }

    #expand archivers
    my $expanded_archives = [];
    foreach my $archive(@{$archives}){
        my $expanded_archive = $template->expand($archive);
        unless($expanded_archive){
            return $self->_handle_next_error(\@addrs, "Error expanding archives: " . $template->error());
        }
        push @{$expanded_archives}, $expanded_archive;
    }
    $self->_set_expanded_archives($expanded_archives);

    #expand reference
    my $reference;
    if($self->task()->reference()){
        $reference = $template->expand($self->task()->reference());
        if($reference){
            $self->_set_expanded_reference($reference);
        }else{
            #print("Error expanding reference: " . $template->error());
            return $self->_handle_next_error(\@addrs, "Error expanding reference: " . $template->error());
        }
    }

    #return the matching address set

}

sub _is_no_agent{
    ##
    # Checks if address or host has no-agent set. If either has it set then it 
    # will be no-agent.
    my ($self, $address) = @_;
    
    #return undefined if no address given
    unless($address){
        return;
    }
    
    #check address no_agent
    #if($address->_is_no_agent()){
    #    return 1;
    #}
    
    #check host no_agent
    #my $host;
    #if($address->can('host_ref') && $address->host_ref()){
    #    $host = $self->psconfig()->host($address->host_ref());
    #}elsif($address->_parent_host_ref()){
    #    $host = $self->psconfig()->host($address->_parent_host_ref());
    #}
    
    #if($host && $host->no_agent()){
    #    return 1;
    #}
    
    return 0;
}

sub _get_archives{
    my ($self, $address, $template) = @_;
    
    my @archives = ();
    unless($address){
        return \@archives;
    }
    
    #init some values
    my $task = $self->task();
    my $psconfig = $self->psconfig();
    my %archive_tracker = ();
    
    #configuring archives from psconfig if allowed
    if($self->use_psconfig_archives()){
        my $host;
        if($address->can('host_ref') && $address->host_ref()){
            $host = $self->psconfig()->host($address->host_ref());
        }elsif($address->_parent_host_ref()){
            $host = $self->psconfig()->host($address->_parent_host_ref());
        }
        my @archive_refs = ();
        push @archive_refs, @{$task->archive_refs()} if($task->archive_refs());
        push @archive_refs, @{$host->archive_refs()} if($host && $host->archive_refs());
        #iterate through archives skipping duplicates
        foreach my $archive_ref(@archive_refs){
            #get archive obj
            my $archive = $psconfig->archive($archive_ref);
            unless($archive){
                $self->_set_error("Unable to find archive defined in task: $archive_ref");
                return;
            }
            #check if duplicate
            my $checksum = $archive->checksum();
            next if($archive_tracker{$checksum}); #skip duplicates
            #if made it here, add to the list
            $archive_tracker{$checksum} = 1;
            push @archives, $archive->data();
        }
    }
    
    #configure default archives
    foreach my $archive(@{$self->default_archives()}){
        #check if duplicate
        my $checksum = $archive->checksum();
        next if($archive_tracker{$checksum}); #skip duplicates
        #if made it here, add to the list
        $archive_tracker{$checksum} = 1;
        push @archives, $archive->data();
    }
    
    return \@archives;
    
}

sub _get_hosts{
    ##
    # Get hosts for each address.
    my ($self) = @_;
    
    #iterate addresses
    my $hosts = [];
    foreach my $address(@{$self->addresses()}){
        #check host no_agent
        my $host;
        if($address->can('host_ref') && $address->host_ref()){
            $host = $self->psconfig()->host($address->host_ref());
        }elsif($address->_parent_host_ref()){
            $host = $self->psconfig()->host($address->_parent_host_ref());
        }
        if($host){
            push @{$hosts}, $host->data();
        }else{
            push @{$hosts}, {}; #push empty object to keep indices consistent
        }
    }
        
    return $hosts;
}


sub _is_disabled{
    ##
    # Checks if address or host has disabled set. If either has it set then it 
    # will be disabled.
    my ($self, $address) = @_;
    
    #return undefined if no address given
    unless($address){
        return;
    }
    
    #check address disabled
    #if($address->_is_disabled()){
    #    return 1;
    #}
    
    #check host disabled
    #my $host;
    #if($address->can('host_ref') && $address->host_ref()){
    #    $host = $self->psconfig()->host($address->host_ref());
    #}elsif($address->_parent_host_ref()){
    #    $host = $self->psconfig()->host($address->_parent_host_ref());
    #}
    
    #if($host && $host->disabled()){
    #    return 1;
    #}
    
    return 0;
}


sub _reset {
    my ($self) = @_;
    
    $self->_set_error(undef);
    $self->_set_expanded_test(undef);
    $self->_set_expanded_archives(undef);
    $self->_set_expanded_contexts(undef);
    $self->_set_expanded_reference(undef);
    $self->_set_scheduled_by_address(undef);
    $self->_set_addresses(undef);
}
 

sub init1 {
    # my ( $class, @params ) = @_;
    my ( $self, $params) = @_;
    my $config_file = $params if $params;

#    my $self = fields::new( $class );

    #print ("konstruktor " . $config_file . "\n");
    $self->config_file('/etc/perfsonar/psconfig/pscheduler.d/toolkit-webui.json'); # $config_file);
    # $self->config_file($config_file);
   
}

sub _read_config_file {
    my ($self, $psconfig_client, $transform) = @_;
#    my $class = shift;
    #my ($self, $psconfig_client) = @_;
	my $ja = new perfSONAR_PS::NPToolkit::Config::PSConfigParser;
	$ja->init("/etc/perfsonar/psconfig/pscheduler.d/toolkit-webui.json");

    #print "JOVANA: " . $ja->config_file();



    if (0) {
        my $abs_file = $self->config_file();

        my $log_ctx = {"template_file" => $abs_file};
	# $logger->debug($self->logf()->format("Loading include file $abs_file", $log_ctx));
        #create client
        my $psconfig_client = new perfSONAR_PS::Client::PSConfig::ApiConnect(
            url => $abs_file
        );

#        my $processed_psconfig = $self->_process_psconfig($psconfig_client);
#        return $processed_psconfig;
        return $psconfig_client;
    }
}
=end comment
=cut
__PACKAGE__->meta->make_immutable;

1;

