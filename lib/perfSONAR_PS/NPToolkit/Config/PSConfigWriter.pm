package perfSONAR_PS::NPToolkit::Config::PSConfigWriter;
#BaseAgent.pm (perfSONAR_PS/PSConfig/ )

use Mouse;

use CHI;
use Data::Dumper;
use Data::Validate::Domain qw(is_hostname);
use Data::Validate::IP qw(is_ipv4 is_ipv6 is_loopback_ipv4);
use Net::CIDR qw(cidrlookup);
use File::Basename;
use JSON qw(from_json encode_json);
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

use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw( save_file restart_service stop_service );


our $VERSION = 4.1;


has 'psconfig_file' => (is => 'rw', isa => 'Str', default => '/etc/perfsonar/psconfig/pscheduler.d/toolkit-webui.json');
#has 'test_config_defaults_file' => (is => 'rw', isa => 'Str', default => '/etc/perfsonar/psconfig/pscheduler.d/toolkit-webui.json');
has 'test_config_defaults_file' => (is => 'rw', isa => 'Str', default => '/usr/lib/perfsonar/web-ng/etc/test_config_defaults.conf');
has 'default_test_parameters' => (is => 'rw', isa => 'HashRef|Undef', writer => '_set_default_test_parameters');
has 'psconfig' => (is => 'rw', isa => 'perfSONAR_PS::Client::PSConfig::Config', default => sub { new perfSONAR_PS::Client::PSConfig::Config(); });
has 'default_trace_test_parameters' => (is => 'ro', isa => 'HashRef', default => sub { { description => "perfSONAR Toolkit Default Traceroute Test", test_interval => 600 } });


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
has 'toolkit_tests' => (is => 'rw', isa => 'HashRef', default => sub { {} });
has 'members_without_trace_tests' => (is => 'rw', isa => 'HashRef', default => sub { {} });
#has 'member_ids_with_trace_tests' => (is => 'rw', isa => 'HahsRef', default => sub { {} });




#private
has '_match_addresses_map' => (is => 'ro', isa => 'HashRef|Undef', writer => '_set_match_addresses_map');


sub new {
    my ($self, @params) = @_;
    #print("\nJovana: konstruktor\n");
    #print("\n\n\n\ndefaults parametar " . Dumper(@params) . "\n\n\n");
    my $parameters = validate(@params, { test_config_defaults_file => 1, config_file => 1 });
    $self->test_config_defaults_file($parameters->{test_config_defaults_file});
    $self->psconfig_file($parameters->{config_file});
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

    $self->test_config_defaults_file('/usr/lib/perfsonar/web-ng/etc/test_config_defaults.conf');
    my $conf_obj = Config::General->new( -ConfigFile => $self->test_config_defaults_file );
    my %conf = $conf_obj->getall;
    $self->_set_default_test_parameters(\%conf);
    #my $config_file = $params if $params;

    $self->psconfig_file("/etc/perfsonar/psconfig/pscheduler.d/toolkit-webui.json");
    #print ("init parametar " . $self->config_file . "\n");

    my $json_text = do {
        open(my $json_fh, "<:encoding(UTF-8)", $self->psconfig_file)
 	    or die("Can't open \"$self->psconfig_file\": $!\n");
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

=head2  delete_all_psconfig_tests
    Deletes all tasks and tests from psConfig JSON file. 
=cut
sub delete_all_psconfig_tests {
    my ( $self ) = shift;
    my ($jovana_status, $jovana_res); 
    my %empty_hash = ( );
    my $empty_json = encode_json( \%empty_hash);

    $self->toolkit_tests( \%empty_hash );
    $self->members_without_trace_tests( \%empty_hash );

    ($jovana_status, $jovana_res) = save_file( {file => $self->psconfig_file, content => $empty_json });

    return ( 0, "" );    
}

=head2 save_psconfig_tasks
    Saves toolkit UI tests as tasks and tests in psConfig JSON file. 
=cut
sub save_psconfig_tasks {
    my ( $self, @params ) = @_;
    #return (-1, Dumper($self->toolkit_tests()));
    #my $parameters = validate( @params, { restart_services => 0, } );
#return (-1, Dumper($self->toolkit_tests()));

#save_file({file => '/var/lib/perfsonar/toolkit/gui-tasks.conf', content => $self->toolkit_tests });
#save_file({file => "/var/lib/perfsonar/toolkit/gui-tasks.conf", content => Dumper($self->{toolkit_tests}) });
#save_file({file => "/var/lib/perfsonar/toolkit/gui-tasks.conf", content => \@params });

    my ($jovana_psconfig_json, $jovana_error) = $self->generate_json_testing_config();
#return (-1, $self->psconfig_file);
    if ($jovana_error) {
	    #$self->{LOGGER}->error( "Couldn't format pSConfig template file: " . $jovana_error );
	    #return ( -1, "Couldn't format pSConfig template file" );
	    return ( -1, $jovana_error );
    }
    my ($jovana_status, $jovana_res); 
    #($jovana_status, $jovana_res) = save_file({file => $defaults{psconfig_file}, content => $jovana_psconfig_json});
    ($jovana_status, $jovana_res) = save_file({file => $self->psconfig_file, content => $jovana_psconfig_json});
    if ( $jovana_status == -1 ) {
	    return ( -1, "JOVANA: Couldn't save json configuration file" );
    }
    ######## JOVANA - kraj
    return ( 0, "" );
}

=head2 generate_json_testing_config
    Generates a string representation of the tests compliant to pSConfig JSON schema.
=cut
sub generate_json_testing_config {
    my ( $self, @params ) = @_;
   
    #return (Dumper($self->{toolkit_tests}), Dumper($self->{toolkit_tests})); 
    # jovana - pocetak
    # validacija parametara "po starom"
    my $parameters_old = validate( @params, { include_mesh_tests => 0, } );
    my $include_mesh_tests = $parameters_old->{include_mesh_tests};
    #$include_mesh_tests = 0 if (not defined $include_mesh_tests); 
#return (-1, "$include_mesh_tests");    
    # jovana - kraj

    #First validate this $config <- MeshConfig parsed to hash
    #convert tests ($config->{'test'}) to array if needed
#    unless(ref($config->{'test'}) eq 'ARRAY'){
#        $config->{'test'} = [ $config->{'test'} ];
#    }
#    #set to data (HashRef in BaseNode.pm)
#    $self->data($config);
#return (-1, Dumper($self->toolkit_tests()));
#return (-1, Dumper($self->toolkit_tests));

    
    #init translation
    my $psconfig = new perfSONAR_PS::Client::PSConfig::Config();
    
    #set description
    my $now=DateTime->now;
    $now->set_time_zone("UTC");
    my $iso_now = $now->ymd('-') . 'T' . $now->hms(':') . '+00:00';
    my $top_meta = {
        "psconfig-translation" => {
            "source-format" => 'mesh-config-tasks-conf',
            "time-translated" => $iso_now
        }
    };
    #set meta
    $psconfig->psconfig_meta($top_meta);

    # return (Dumper($self->{TESTS}), "JOVANA"); # jovana - kraj
    # return (join(',', @params), "JOVANA"); # jovana - kraj
    # return ($parameters, "JOVANA");
    
    # generisanje testova "po starom"; stari poziv procedure ($status, $res) = $self->generate_regular_testing_config(); 
    # jovana - pocetak
    my @tests = ();
    my $jovana_test_types = "";
    # Build test objects
    #foreach my $test_key (keys $self->{toolkit_tests} ) {
    while ( my ( $test_key, $test_desc ) = each %{ $self->toolkit_tests }) {
	#my $test_desc = $self->{toolkit_tests}->{$test_key};
	next unless $test_desc;
        my ($parameters, $schedule);
#return (-1, Dumper($test_desc));
        $jovana_test_types = $jovana_test_types . " (" . $test_desc->{type} . "/" . $test_desc->{added_by_mesh} . ")"; 

        next if ($test_desc->{added_by_mesh} and not $include_mesh_tests);

        if ($test_desc->{parameters}->{test_interval}) {
            $schedule = perfSONAR_PS::RegularTesting::Schedulers::RegularInterval->new();
            $schedule->interval($test_desc->{parameters}->{test_interval});
        }
        elsif ($test_desc->{parameters}->{test_schedule}) {
            $schedule = perfSONAR_PS::RegularTesting::Schedulers::TimeBasedSchedule->new();
            $schedule->time_slots($test_desc->{parameters}->{test_schedule});
        }
        else {
            $schedule = perfSONAR_PS::RegularTesting::Schedulers::Streaming->new();
        }

        if ($test_desc->{type} eq "latencybg") {
#return (-1, Dumper($test_desc));
            if ($schedule->type eq "streaming") {
                $parameters = perfSONAR_PS::RegularTesting::Tests::Powstream->new();
                my $resolution = $test_desc->{parameters}->{packet_count} * $test_desc->{parameters}->{packet_interval};
                $parameters->resolution($resolution);
            }
            else {
                $parameters = perfSONAR_PS::RegularTesting::Tests::BwpingOwamp->new();
                $parameters->packet_count($test_desc->{parameters}->{packet_count});
            }

            $parameters->packet_length($test_desc->{parameters}->{packet_padding}) if defined $test_desc->{parameters}->{packet_padding};
            $parameters->inter_packet_time($test_desc->{parameters}->{packet_interval}) if defined $test_desc->{parameters}->{packet_interval};
        }
        elsif ($test_desc->{type} eq "throughput") {
#return (-1, Dumper($test_desc));
            $parameters = perfSONAR_PS::RegularTesting::Tests::Bwctl->new();

            $parameters->tool($test_desc->{parameters}->{tool}) if defined $test_desc->{parameters}->{tool};
            $parameters->use_udp(1) if ($test_desc->{parameters}->{protocol} and $test_desc->{parameters}->{protocol} eq "udp");
            $parameters->duration($test_desc->{parameters}->{duration}) if defined $test_desc->{parameters}->{duration};
            $parameters->udp_bandwidth($test_desc->{parameters}->{udp_bandwidth}) if defined $test_desc->{parameters}->{udp_bandwidth};
            $parameters->buffer_length($test_desc->{parameters}->{buffer_length}) if defined $test_desc->{parameters}->{buffer_length};
            $parameters->window_size($test_desc->{parameters}->{window_size} * 1024 * 1024) if defined $test_desc->{parameters}->{window_size}; # convert to bps for the regular testing
            $parameters->packet_tos_bits($test_desc->{parameters}->{tos_bits}) if defined $test_desc->{parameters}->{tos_bits};
            $parameters->streams($test_desc->{parameters}->{streams}) if defined $test_desc->{parameters}->{streams};
            $parameters->omit_interval($test_desc->{parameters}->{omit_interval}) if defined $test_desc->{parameters}->{omit_interval};
            $parameters->zero_copy($test_desc->{parameters}->{zero_copy}) if defined $test_desc->{parameters}->{zero_copy};
            $parameters->single_ended($test_desc->{parameters}->{single_ended}) if defined $test_desc->{parameters}->{single_ended};
            $parameters->send_only($test_desc->{parameters}->{send_only}) if defined $test_desc->{parameters}->{send_only};
            $parameters->receive_only($test_desc->{parameters}->{receive_only}) if defined $test_desc->{parameters}->{receive_only};
        }
        elsif ($test_desc->{type} eq "rtt") {
#return (-1, Dumper($test_desc));
            $parameters = perfSONAR_PS::RegularTesting::Tests::Bwping->new();
            $parameters->packet_count($test_desc->{parameters}->{packet_count}) if $test_desc->{parameters}->{packet_count};
            $parameters->packet_length($test_desc->{parameters}->{packet_size}) if $test_desc->{parameters}->{packet_size};
            $parameters->packet_ttl($test_desc->{parameters}->{ttl}) if $test_desc->{parameters}->{ttl};
            $parameters->inter_packet_time($test_desc->{parameters}->{packet_interval}) if $test_desc->{parameters}->{packet_interval};
            $parameters->send_only(1);
        }
        elsif ($test_desc->{type} eq "trace") {
#return (-1, Dumper($test_desc));
            $parameters = perfSONAR_PS::RegularTesting::Tests::Bwtraceroute->new();
            $parameters->tool($test_desc->{parameters}->{tool}) if $test_desc->{parameters}->{tool};
            $parameters->packet_length($test_desc->{parameters}->{packet_size}) if defined $test_desc->{parameters}->{packet_size};
            $parameters->packet_first_ttl($test_desc->{parameters}->{first_ttl}) if defined $test_desc->{parameters}->{first_ttl};
            $parameters->packet_max_ttl($test_desc->{parameters}->{max_ttl}) if defined $test_desc->{parameters}->{max_ttl};
            $parameters->send_only(1);
       }
       else  {
#return (-1, "JJJJ" . Dumper($test_desc));
	    next;
        }
#print("JOVANA: " . $test_desc->{type});       
	$parameters->test_ipv4_ipv6(1);


        my @targets = ();
#return(Dumper($test_desc->{members}), Dumper($test_desc->{members}));		
        foreach my $member (@{$test_desc->{members}}) {
#return(Dumper($member), Dumper($member));		
            my $target = perfSONAR_PS::RegularTesting::Target->new();
            $target->address($member->{address});
            $target->description($member->{description}) if $member->{description};

            if ($member->{test_ipv4}) {
                my $override_parameters = $parameters->meta->new_object();
                $override_parameters->force_ipv4(1);
                $target->override_parameters($override_parameters);
            }
	    elsif ($member->{test_ipv6}) {
                my $override_parameters = $parameters->meta->new_object();
                $override_parameters->force_ipv6(1);
                $target->override_parameters($override_parameters);
            } 
	    else {
                my $override_parameters = $parameters->meta->new_object();
                $override_parameters->force_ipv4(1);
                $target->override_parameters($override_parameters);
            }

	    #JOVANA: sender i receiver su 1 ako je i send i receive
	    #if ($member->{sender}) {
	    if ($member->{send_only}) {
	        $target->override_parameters->send_only(1);
	    }

	    #if ($member->{receiver}) {
	    if ($member->{receive_only}) {
	        $target->override_parameters->receive_only(1);
	    }

            push @targets, $target;
        }

        my $test = perfSONAR_PS::RegularTesting::Test->new();
        $test->description($test_desc->{description}) if $test_desc->{description};
        $test->local_interface($test_desc->{parameters}->{local_interface}) if $test_desc->{parameters}->{local_interface};
        $test->local_address($test_desc->{parameters}->{local_interface}) if $test_desc->{parameters}->{local_interface};
        $test->disabled($test_desc->{disabled}) if $test_desc->{disabled};
        $test->schedule($schedule);
        $test->parameters($parameters);
        $test->targets(\@targets);

        $test->added_by_mesh(1) if $test_desc->{added_by_mesh};

        push @tests, $test;
    }

    #my @jovana_tests_dumped;
    my $jovana_tests_string = "Size:" .  scalar @tests . ":";
    foreach my $jovana_test (@tests) {
    	    my $jovana_test_string = Dumper($jovana_test);
	    $jovana_tests_string = $jovana_tests_string . "|" . $jovana_test_string;
    } 
#return (-1, "".$jovana_tests_size . ":" . join("-", @jovana_tests_dumped)); #, join("-", @jovana_tests_dumped));
#return (-1, "".$jovana_tests_string);
        
    
    # ??? gde su generisani default parametes ???? <-- u RegularTesting::Test su 
    #convert default parameters
    # 7. januar 2023. iz konf fajla su u $self->default_test_parameters 
    my $default_test_params = {};
    $default_test_params = $self->default_test_parameters();
    my $jovana_test_params = " default params for test types";
    # jovana: $self->data(){'default_parameters'} --> iterate @tests 
#    if($self->data()->{'default_parameters'}){
#        unless(ref($self->data()->{'default_parameters'}) eq 'ARRAY'){
#            $self->data()->{'default_parameters'} = [ $self->data()->{'default_parameters'} ];
#        }


######## JOVANA - mislim da je ovo glupost 7. januar 2023.
#                 pretpostavljam da je hteo da korisit default parametre koje posalje browser
#        foreach my $test_default_test_param(@tests){
#            my $default_test_param = $test_default_test_param->{'default_parameters'};
#            my $type = $default_test_param->{'type'};
#            next unless($type);
#            my $params = {};
#            foreach my $param_key(keys %{$default_test_param}){
#                next if($param_key eq 'type');
#                $params->{$param_key} = $default_test_param->{$param_key};
#            }
#            $default_test_params->{$type} = $params;
#
#	    $jovana_test_params = $jovana_test_params . " " . $type;
#        }
######## JOVANA - kraj 7. januar 2023.        
#    }
	# return ($jovana_test_params, "JOVANA");
       
	# return($jovana_test_types . $default_test_params, "JOVANA");
	# return($jovana_test_types . "|" . Dumper($jovana_test_params), "JOVANA");
    
    #iterate through tests and build psconfig tasks
    # jovana $self->data() --> @tests
    my $translator = new perfSONAR_PS::Client::PSConfig::Translators::MeshConfigTasks::Config();
    my $jovana_task_names = "Converted ";
    my $jovana_error = "";
    my $generated_json = "";

#return (-1, Dumper($tests[0]->{'parameters'}));
#return (-1, Dumper($tests[0]->{'parameters'}->{'type'}));
#return (-1, Dumper($tests[0]->{'parameters'}->type()));
#return (-1, Dumper($default_test_params));
#return (-1, Dumper(@tests));
    foreach my $test(@tests){
	#$jovana_task_names = $jovana_task_names . "(" . ($test->{'added_by_mesh'} && !$self->include_added_by_mesh()) . "|";
        #skip tests added by mesh
	#JOVANA: otkomentarisati
	#next if($test->{'added_by_mesh'} && !$self->include_added_by_mesh());
        
        #inherit default parameters
        next unless($test->{'parameters'});
        if($default_test_params->{$test->{'parameters'}->type()}){
            foreach my $param_key(keys %{$default_test_params->{$test->{'parameters'}->type()}}){
                next if($param_key eq 'type');
		unless ($test->{'parameters'}->{$param_key}) { 
                    $test->{'parameters'}->{$param_key} = $default_test_params->{$test->{'parameters'}->type()}->{$param_key};
	        }
            }
        }
	#$jovana_task_names = $jovana_task_names . ($test->{'description'} ? $test->{'description'} : "task") . ")";
        
        #build psconfig tasks
	##$translator->_jovana_convert_tasks($test, $psconfig);
	#$jovana_error = $jovana_error . "|JOVANA_RegularTesting|" . $translator->_jovana_convert_tasks($test, $psconfig);
	#$jovana_error = $jovana_error . "|" .  $translator->_jovana_convert_tasks($test, $psconfig); # join('-', $translator->_jovana_convert_tasks($test, $psconfig));
	#my $jovana_converted_tasks; 
	my $jovana_converted_tasks = $translator->_jovana_convert_tasks($test, $psconfig);
	$jovana_task_names = $jovana_task_names . "|" . Dumper($jovana_converted_tasks);
    }
#return(-1, $jovana_task_names);

#my @jovana_tests_dumped;
my $jovana_d_tests_string = "With defaults size:" .  scalar @tests . ":";
foreach my $jovana_d_test (@tests) {
    my $jovana_d_test_string = Dumper($jovana_d_test);
    $jovana_d_tests_string = $jovana_d_tests_string . "|" . $jovana_d_test_string;
} 
#return (-1, "".$jovana_tests_size . ":" . join("-", @jovana_tests_dumped)); #, join("-", @jovana_tests_dumped));
#return (-1, "".$jovana_d_tests_string);
        

    #return ($jovana_error, $jovana_error);
    #return $psconfig->json({"pretty" => 1, "canonical" => 1}) ;


    # return($jovana_task_names, "JOVANA");
    my $jovana_psconfig_tasks = $psconfig->task_names();
#return(-1, Dumper($jovana_psconfig_tasks));
    # return ("JOVANA ERROR: " . $jovana_error, "JOVANA") if ($jovana_error);
    # return (Dumper($psconfig), "JOVANa");
    
    #convert and save global archives
    #my $save_global_archives = 0;
#    if($save_global_archives){
#	my $global_archive_psconfig = new perfSONAR_PS::Client::PSConfig::Config();
#        my $global_archive_refs = {};
#        $self->_convert_measurement_archives($self->data(), $global_archive_psconfig, $global_archive_refs);
#        foreach my $global_archive_ref(keys %{$global_archive_refs}){
#            my $global_archive = $global_archive_psconfig->archive($global_archive_ref);
#            next unless($global_archive_ref);
#            $self->save_archive($global_archive, $global_archive_ref, {pretty => 1});
#        }
#    }
    
    #check if we actually have anything we converted - if all remote mesh we may not
    unless(@{$psconfig->task_names()}){
	return (0, "PSConfig kaze: " . $psconfig->error());
	# $self->{LOGGER}->error("Nothing to convert. This is not an error if all tests contain added_by_mesh. Ignore any errors above about malformed JSON string.");
        return (0, "JOVANA: Nothing to convert. This is not an error if all tests contain added_by_mesh. Ignore any errors above about malformed JSON string.");
    }
    
    #build pSConfig Object and validate
    my @errors = $psconfig->validate();
    if(@errors){
        my $err = "Generated PSConfig JSON is not valid. Encountered the following validation errors:\n\n";
        foreach my $error(@errors){
#            $err .= "   Node: " . $error->path . "\n";
#            $err .= "   Error: " . $error->message . "\n\n";
        }
	# $self->{LOGGER}->error($err);
        return (0, $err);
    }
    my $psconfig_json_jovana = $psconfig->json({"pretty" => 1, "canonical" => 1});  
#    return ($psconfig, "JOVANA_JOVANA");
    #return ($psconfig_json_jovana, "");
    #return (0, $psconfig_json_jovana);
    # ($result, $error)
    return ($psconfig_json_jovana, 0);


}

=head2 add_test_owamp({ mesh_type => 1, name => 0, description => 1, packet_padding => 1, packet_interval => 1, bucket_width => 1, loss_threshold => 1, session_count => 1, disabled => 0 })
    Adds a new OWAMP test to the list. mesh_type must be "star" as mesh tests
    aren't currently supported. 'name' can be used to give the test the name
    that will be used in the owmesh file which would be autogenerated
    otherwise. packet_padding, packet_interval, bucket_width, loss_threshold and
    session_count correspond to the pSB powstream test parameters. Returns (-1, $error_msg)
    on failure and (0, $test_id) on success.
=cut 

sub add_test_owamp {
	my ( $self, @params ) = @_;
	my $parameters = validate(
		@params,
		{
			name=>0,
			description=>1,
			packet_interval=>1,
			packet_count=>1,
			packet_padding => 1,
			loss_threshold => 0,
			session_count => 0,
			bucket_width => 0,
			test_interval => 0,
			test_schedule => 0,
			added_by_mesh => 0,
			local_interface => 0,
			disabled => 0,
			protocol => 0,
			members => 1,
		}
	);

        #$self->{LOGGER}->debug( "Adding owamp test" );
	
	my $test_id;
	do {
		$test_id = "test." . genuid();
	} while ( $self->{toolkit_tests}->{$test_id} );

        my %test = ();
        $test{id}= $test_id;
        $test{type}= "latencybg";
        $test{name}= $parameters->{name};
        $test{description} = $parameters->{description} if ( defined $parameters->{description} );
        $test{added_by_mesh} = $parameters->{added_by_mesh};
        $test{disabled} = $parameters->{disabled} if ( defined $parameters->{disabled} );
        my $members          = $parameters->{members};

        my %test_parameters = ();
        $test_parameters{packet_interval}= $parameters->{packet_interval}if ( defined $parameters->{packet_interval} );
        $test_parameters{loss_threshold}= $parameters->{loss_threshold}if ( defined $parameters->{loss_threshold} );
        $test_parameters{session_count}= $parameters->{session_count}if ( defined $parameters->{session_count} );
        $test_parameters{packet_count}= $parameters->{packet_count}if ( defined $parameters->{packet_count} );
        $test_parameters{packet_padding}= $parameters->{packet_padding}if ( defined $parameters->{packet_padding} );
        $test_parameters{bucket_width}= $parameters->{bucket_width}if ( defined $parameters->{bucket_width} );
        $test_parameters{test_interval}= $parameters->{test_interval}if ( defined $parameters->{test_interval} );
        $test_parameters{test_schedule}= $parameters->{test_schedule}if ( defined $parameters->{test_schedule} );
        $test_parameters{local_interface}= $parameters->{local_interface}if ( defined $parameters->{local_interface} );
        $test_parameters{local_address}= $parameters->{local_interface}if ( defined $parameters->{local_interface} );

        $test{parameters} = \%test_parameters;

	#my %tmp = ();
        #$test{members} = \%tmp;
        $test{members} = $members;

        $self->{toolkit_tests}->{$test_id} = \%test;

        foreach my $member (@{$members}){
	    next if exists($self->{members_without_trace_tests}->{$member->{address}});
		#next if exists($self->{members_without_trace_tests}->{"123"});
	    $self->{members_without_trace_tests}->{$member->{address}} = $member;
        }

        return ( 0, $test_id );
}

=head2 add_test_bwctl_throughput({ name => 0, description => 1, tool => 1, test_interval => 1, duration => 1, protocol => 1, udp_bandwidth => 0, buffer_length => 0, window_size => 0, report_interval => 0, test_interval_start_alpha => 0, tos_bits => 0, streams => 0, omit_interval => 0, zero_copy => 0, single_ended => 0, send_only, receive_only, disabled => 0 })
    Adds a new BWCTL throughput test to the list.  'name' can be used to give
    the test the name that will be used in the owmesh file which would be
    autogenerated otherwise. tool, test_interval, duration, protocol,
    udp_bandwidth, buffer_length, window_size, report_interval,
    test_interval_start_alpha, tos_bits, omit_interval, zero_copy, single_ended, send_only,
    receive_only  all correspond to the pSB throughput test parameters.
    Returns (-1, $error_msg) on failure and (0, $test_id) on success.
=cut

sub add_test_bwctl_throughput {
    my ( $self, @params ) = @_;
    #my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name                      => 0,
            description               => 1,
            tool                      => 1,
            test_interval             => 0,
            test_schedule             => 0,
            duration                  => 1,
            protocol                  => 1,
            udp_bandwidth             => 0,
            buffer_length             => 0,
            window_size               => 0,
            report_interval           => 0,
            test_interval_start_alpha => 0,
            added_by_mesh             => 0,
            tos_bits                  => 0,
            streams                   => 0,
            omit_interval             => 0,
            zero_copy                 => 0,
            single_ended              => 0,
            send_only                 => 0,
            receive_only              => 0,
            local_interface           => 0,
            disabled                  => 0,
            members                   => 0,
        }
    );

    #$self->{LOGGER}->debug( "Add bwctl: " . Dumper( $parameters ) );

    my $test_id;
    do {
        $test_id = "test." . genuid();
    } while ( $self->{toolkit_tests}->{$test_id} );

    my %test = ();
    $test{id}          = $test_id;
    $test{name}        = $parameters->{name};
    $test{description} = $parameters->{description};
    $test{type}        = "throughput";
    $test{added_by_mesh} = $parameters->{added_by_mesh};
    $test{disabled}      = $parameters->{disabled}  if ( defined $parameters->{disabled} );
    my $members          = $parameters->{members};

    my %test_parameters = ();
    $test_parameters{tool}                      = $parameters->{tool}                      if ( defined $parameters->{tool} );
    $test_parameters{test_interval}             = $parameters->{test_interval}             if ( defined $parameters->{test_interval} );
    $test_parameters{test_schedule}             = $parameters->{test_schedule}             if ( defined $parameters->{test_schedule} );
    $test_parameters{duration}                  = $parameters->{duration}                  if ( defined $parameters->{duration} );
    $test_parameters{protocol}                  = $parameters->{protocol}                  if ( defined $parameters->{protocol} );
    $test_parameters{udp_bandwidth}             = $parameters->{udp_bandwidth}             if ( defined $parameters->{udp_bandwidth} );
    $test_parameters{buffer_length}             = $parameters->{buffer_length}             if ( defined $parameters->{buffer_length} );
    $test_parameters{window_size}               = $parameters->{window_size}               if ( defined $parameters->{window_size} );
    $test_parameters{report_interval}           = $parameters->{report_interval}           if ( defined $parameters->{report_interval} );
    $test_parameters{test_interval_start_alpha} = $parameters->{test_interval_start_alpha} if ( defined $parameters->{test_interval_start_alpha} );
    $test_parameters{tos_bits}                  = $parameters->{tos_bits}                  if ( defined $parameters->{tos_bits} );
    $test_parameters{streams}                   = $parameters->{streams}                   if ( defined $parameters->{streams} );
    $test_parameters{omit_interval}             = $parameters->{omit_interval}             if ( defined $parameters->{omit_interval} );
    $test_parameters{zero_copy}                 = $parameters->{zero_copy}                 if ( defined $parameters->{zero_copy} );
    $test_parameters{single_ended}              = $parameters->{single_ended}              if ( defined $parameters->{single_ended} );
    $test_parameters{send_only}                 = $parameters->{send_only}                 if ( defined $parameters->{send_only} );
    $test_parameters{receive_only}              = $parameters->{receive_only}              if ( defined $parameters->{receive_only} );
    $test_parameters{local_interface} = $parameters->{local_interface} if ( defined $parameters->{local_interface} );
    $test_parameters{local_address}= $parameters->{local_interface} if ( defined $parameters->{local_interface} );

    $test{parameters} = \%test_parameters;

    #my %tmp = ();
    #$test{members} = \%tmp;
    $test{members} = $members;

    $self->{toolkit_tests}->{$test_id} = \%test;

    foreach my $member (@{$members}){
        next if exists($self->{members_without_trace_tests}->{$member->{address}});
        $self->{members_without_trace_tests}->{$member->{address}} = $member;
    }



    return ( 0, $test_id );
}

=head2 add_test_pinger({ description => 0, packet_size => 1, packet_count => 1, packet_interval => 1, test_interval => 1, test_offset => 1, ttl => 1, disabled => 0 })
    Adds a new ping test to the list. packet_size, packet_count,
    packet_interval, test_interval, test_offset, ttl all correspond to ping
    test parameters. Returns (-1, $error_msg) on failure and (0, $test_id) on
    success.
=cut

sub add_test_pinger {
	#my ( $self, @params, @members ) = @_;
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            description     => 0,
            packet_size     => 1,
            packet_count    => 1,
            packet_interval => 1,
            test_interval   => 1,
            test_schedule   => 0,
            test_offset     => 0,
            ttl             => 1,
            added_by_mesh   => 0,
            local_interface => 0,
            disabled        => 0,
	    members         => 1,
        }
    );

    my $description     = $parameters->{description};
    my $packet_interval = $parameters->{packet_interval};
    my $packet_count    = $parameters->{packet_count};
    my $packet_size     = $parameters->{packet_size};
    my $test_interval   = $parameters->{test_interval};
    my $test_schedule   = $parameters->{test_schedule};
    my $test_offset     = $parameters->{test_offset};
    my $ttl             = $parameters->{ttl};
    my $local_interface = $parameters->{local_interface};
    my $disabled        = $parameters->{disabled};
    my $members         = $parameters->{members};

    my $test_id;

    # Find an empty domain
    do {
        $test_id = "test." . genuid();
    } while ( $self->{toolkit_tests}->{$test_id} );

    #my %members   = ();
    my %test_info = (
        id          => $test_id,
        type        => "rtt",
        description => $description,
        added_by_mesh => $parameters->{added_by_mesh},
        disabled        => $disabled,
        parameters  => {
            packet_interval => $packet_interval,
            packet_count    => $packet_count,
            packet_size     => $packet_size,
            test_interval   => $test_interval,
            test_schedule   => $test_schedule,
            test_offset     => $test_offset,
            ttl             => $ttl,
            local_interface => $local_interface,
            local_address => $local_interface,
        },
        members => $members,
    );

    $self->{toolkit_tests}->{$test_id} = \%test_info;

    foreach my $member (@{$members}){
	    next if exists($self->{members_without_trace_tests}->{$member->{address}});
	    $self->{members_without_trace_tests}->{$member->{address}} = $member;
    }


    return ( 0, $test_id );
}

=head2 add_test_traceroute({ name => 0, description => 1, test_interval => 1, packet_size => 0, timeout => 0, waittime => 0, first_ttl => 0, max_ttl => 0, pause => 0, protocol => 0, disabled => 0 })
    Add a new traceroute test of type STAR to the owmesh file. All parameters correspond
    to test parameters. Returns (-1, error_msg)  on failure and (0, $test_id) on success.
=cut

sub add_test_traceroute {
    #my ( $self, @params, @members ) = @_;
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name          => 0,
            description   => 1,
            test_interval => 1,
            test_schedule => 0,
            packet_size   => 0,
            timeout       => 0,
            waittime      => 0,
            first_ttl     => 0,
            max_ttl       => 0,
            pause         => 0,
            protocol      => 0,
            added_by_mesh => 0,
            local_interface => 0,
            tool            => 0,
            disabled        => 0,
	    members         => 1
        }
    );

    #$self->{LOGGER}->debug( "Add: " . Dumper( $parameters ) );

    my $test_id;
    do {
        $test_id = "test." . genuid();
    } while ( $self->{toolkit_tests}->{$test_id} );

    my %test = ();
    $test{id}          = $test_id;
    $test{name}        = $parameters->{name};
    $test{description} = $parameters->{description};
    $test{disabled}    = $parameters->{disabled} if ( defined $parameters->{disabled} );
    $test{type}        = "trace";
    $test{added_by_mesh} = $parameters->{added_by_mesh};
    my $members        = $parameters->{members};

    my %test_parameters = ();
    $test_parameters{test_interval}             = $parameters->{test_interval}             if ( defined $parameters->{test_interval} );
    $test_parameters{test_schedule}             = $parameters->{test_schedule}             if ( defined $parameters->{test_schedule} );
    $test_parameters{packet_size}               = $parameters->{packet_size}               if ( defined $parameters->{packet_size} );
    $test_parameters{timeout}                   = $parameters->{timeout}                   if ( defined $parameters->{timeout} );
    $test_parameters{waittime}                  = $parameters->{waittime}                  if ( defined $parameters->{waittime} );
    $test_parameters{first_ttl}                 = $parameters->{first_ttl}                 if ( defined $parameters->{first_ttl} );
    $test_parameters{max_ttl}                   = $parameters->{max_ttl}                   if ( defined $parameters->{max_ttl} );
    $test_parameters{pause}                     = $parameters->{pause}                     if ( defined $parameters->{pause} );
    $test_parameters{protocol}                  = $parameters->{protocol}                  if ( defined $parameters->{protocol} );
    $test_parameters{local_interface} = $parameters->{local_interface} if ( defined $parameters->{local_interface} );
    $test_parameters{local_address} = $parameters->{local_interface} if ( defined $parameters->{local_interface} );
    $test_parameters{tool}                      = $parameters->{tool}                      if ( defined $parameters->{tool} );

    $test{parameters} = \%test_parameters;

    #my %tmp = ();
    #$test{members} = \%tmp;
    $test{members} = $members;

    $self->{toolkit_tests}->{$test_id} = \%test;

    return ( 0, $test_id );
}


=head2 add_default_trace_tests ({ test_id => 1, address => 1, port => 0, name => 0, description => 0, sender => 0, receiver => 0 })
    Adds a new address to the test. Address can be any of hostname/ipv4/ipv6.
    Port specifies which port should be connected to, this is ignored in ping
    tests. The sender/receiver fields can be set to 1 or 0 and specify whether that
    test member should do a send or receive test.
    Returns (0, $member_id) on success and (-1, $error_msg) on failure.
=cut

sub add_default_trace_tests {
    my ( $self ) = shift;
   
#    my $parameters = validate(
#        @params,
#        {
#            test_id     => 1,
#            address     => 1,
#            port        => 0,
#            name        => 0,
#            description => 0,
#            sender      => 0,
#            receiver    => 0,
#            test_ipv4   => 0,
#            test_ipv6   => 0,
#            skip_default_rules => 0,
#            id          => 0
#        }
#    );

    #$self->{LOGGER}->debug( "Adding address " . $parameters->{address} . " to test " . $parameters->{test_id} );

    #my $test = $self->{TESTS}->{ $parameters->{test_id} };
    #foreach my $member_address($self->{members_wothout_trace_tests}->keys()) {
    #    my $member = $self->{members_wothout_trace_tests}->{ $member_address };


    my $parameters = {};
    $parameters->{ description } = $self->{ default_trace_test_parameters }->{ description };
    $parameters->{ test_interval } = $self->{ default_trace_test_parameters }->{ test_interval };
    #$parameters->{ members } = $self->{members_without_trace_tests}->values();
    $parameters->{ members } = $self->members_without_trace_tests()->values();
    #$parameters->{ members } = values $self->{members_without_trace_tests};
    my ($status, $res) = $self->add_test_traceroute($parameters);

}

sub configure_default_tests {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { } );

    # jovana: nepotrebno jer su vec svi testovi obrisani
    # Initialize the default traceroute test, and make sure that its test set
    # are only those hosts that are in non-mesh added, non-traceroute tests.
    #foreach my $test ( values %{ $self->{TESTS} } ) {
    #    next unless ($test->{description} eq $defaults{traceroute_test_parameters}->{description});

    #    $self->delete_test({ test_id => $test->{id} });
    #}

    # JOVANA: fale members
    my ($status, $res) = $self->add_test_traceroute($self->default_trace_test_parameters);

    return ($status, $res) unless ($status == 0);

    my $traceroute_test_id = $res;

    my %hosts_to_add = ();
    #foreach my $test ( values %{ $self->{TESTS} } ) {
    foreach my $test ( values %{ $self->{toolkit_tests} } ) {
        next if $test->{added_by_mesh} or $test->{type} eq "trace";

        foreach my $member (values %{ $test->{members} }) {
            unless ($hosts_to_add{$member->{address}}) {
                my %new_member = %$member;

                $hosts_to_add{$member->{address}} = \%new_member;
            }

            $hosts_to_add{$member->{address}}->{test_ipv4} = 1 if $member->{test_ipv4};
            $hosts_to_add{$member->{address}}->{test_ipv6} = 1 if $member->{test_ipv6};
        }
    }

    # Don't do a default traceroute test if we're already doing one as part of
    # another test
    #foreach my $test ( values %{ $self->{TESTS} } ) {
    foreach my $test ( values %{ $self->{toolkit_tests} } ) {
        next unless $test->{type} eq "trace";
        foreach my $member (values %{ $test->{members} }) {
            delete($hosts_to_add{$member->{address}});
        }
    }

    foreach my $member (values %hosts_to_add) {
        my ($status, $res) = $self->add_test_member({
                                 test_id     => $traceroute_test_id,
                                 address     => $member->{address},
                                 name        => $member->{name},
                                 description => $member->{description},
                                 sender      => 1,
                                 receiver    => 1,
                                 test_ipv4   => $member->{test_ipv4},
                                 test_ipv6   => $member->{test_ipv6},
                                 skip_default_rules => 1,
                             });
        if ($status != 0) {
            $self->{LOGGER}->warn("Problem adding ".$member->{address}." to default traceroute test: ".$res);
        }
    }

    return (0, "");
}


__PACKAGE__->meta->make_immutable;

1;

__END__

