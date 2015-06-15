var HostStatusSidebarComponent = {
    host_info: null,
    host_status: null,
    health_status: null,
    status_topic: 'store.change.host_status',
    health_topic: 'store.change.health_status',
    health_token: null,
    health_refresh_interval: 10000, // in milliseconds
    id_prefix: "health-value-"
};

HostStatusSidebarComponent.initialize = function() {
    Dispatcher.subscribe(HostStatusSidebarComponent.status_topic, HostStatusSidebarComponent._setStatus);
    HostStatusSidebarComponent.health_token = Dispatcher.subscribe(HostStatusSidebarComponent.health_topic, HostStatusSidebarComponent._setHealthStatus);
};

HostStatusSidebarComponent._setStatus = function( topic ) {
    var data = HostStore.getHostSummary();
    var status_values = [];
    
    var host_memory = data.host_memory + " GB";
    status_values.push( {label: "RAM", value: host_memory} );

    var cpu_cores = data.cpu_cores;
    status_values.push( {label: "CPU Cores", value: cpu_cores} );

    var cpus = data.cpus;
    status_values.push( {label: "CPUs", value: cpus} );

    var cpu_speed = Math.round(data.cpu_speed) + " MHz";
    status_values.push( {label: "CPU Speed", value: cpu_speed} );

    var primary_interface = data.external_address.iface;
    status_values.push( {label: "Primary Interface", value: primary_interface} );

    var primary_mtu = data.external_address.mtu;
    status_values.push( {label: "MTU", value: primary_mtu} );

    var ntp_synchronized = (data.ntp.synchronized == 1 ? "Yes" : "No");
    status_values.push( {label: "NTP Synced", value: ntp_synchronized} );

    var toolkit_version = data.toolkit_version;
    status_values.push( {label: "Toolkit version", value: toolkit_version} );

    var rpm_version = data.toolkit_rpm_version;
    status_values.push( {label: "Toolkit RPM version", value: rpm_version} );

    var kernel = data.kernel_version;
    status_values.push( {label: "Kernel version", value: kernel} );

    var host_status_template = $("#sidebar-status-template").html();
    var template = Handlebars.compile(host_status_template);

    data.status_values = status_values;

    var status_output = template(data);

    $("#sidebar_host_status").html(status_output);

};

HostStatusSidebarComponent._getHealthVariables = function(data) {
    var health_values = [];

    // Use an ID prefix to better scope these elements in the DOM
    var id_prefix = HostStatusSidebarComponent.id_prefix;

    var cpu_util = data.cpu_util + "%";
    var id = "cpu_util";
    id = id_prefix + id;
    health_values.push( { label: "CPU Usage", value: cpu_util, id: id } );

    id = "cpu_load";
    id = id_prefix + id;
    var load = HostStatusSidebarComponent._formatLoad(data.load_avg);
    health_values.push( { label: "Load", value: load, id: id } );

    id = "mem_usage";
    id = id_prefix + id;
    var memory = HostStatusSidebarComponent._formatMemoryUsage(data.mem_used, data.mem_total);
    health_values.push( { label: "Memory usage", value: memory, id: id } );

    id = "swap_usage";
    id = id_prefix + id;
    var swap = HostStatusSidebarComponent._formatMemoryUsage(data.swap_used, data.swap_total);
    health_values.push( { label: "Swap usage", value: swap, id: id } );

    id = "root_usage";
    id = id_prefix + id;
    var root = HostStatusSidebarComponent._formatMemoryUsage(data.rootfs.used, data.rootfs.total);
    health_values.push( { label: "Root partition", value: root, id: id } );

    return health_values;
};

HostStatusSidebarComponent._setHealthStatus = function( topic ) {
    var data = HostStore.getHealthStatus();
    var health_values = HostStatusSidebarComponent._getHealthVariables(data);

    if ( $("#sidebar-health-template").length == 0 ) {
        return;
    }
    
    var health_template = $("#sidebar-health-template").html();
    var template = Handlebars.compile(health_template);

    data.health_values = health_values;

    var health_output = template(data);

    $("#sidebar_health_status").html(health_output);

    Dispatcher.unsubscribe( HostStatusSidebarComponent.health_token );
    Dispatcher.subscribe(HostStatusSidebarComponent.health_topic, HostStatusSidebarComponent._updateHealth);
    
    //setTimeout( HostStore._retrieveHealth, HostStatusSidebarComponent.health_refresh_interval );
    setTimeout( HostStatusSidebarComponent._getUpdatedHealth, HostStatusSidebarComponent.health_refresh_interval );
};

HostStatusSidebarComponent._formatLoad = function(load_obj) {
    var load_vals = [ load_obj.avg_1,
                      load_obj.avg_5,
                      load_obj.avg_15 ];

    var load = load_vals.join(', ');
    return load; 
};


HostStatusSidebarComponent._formatMemoryUsage = function(memory1, memory2) {
    var prefix;
    if (memory2 > memory1) {
        prefix = d3.formatPrefix(memory2);
    } else {
        prefix = d3.formatPrefix(memory1);
    }
    var memory_out = d3.round(prefix.scale(memory1), 1);
    memory_out += " / "
    memory_out += d3.round(prefix.scale(memory2), 1) + " " + prefix.symbol + "B";
    return memory_out;
};

HostStatusSidebarComponent._formatMemory = function(memory) {
    var prefix = d3.formatPrefix(memory);
    return d3.round(prefix.scale(memory), 1) + " " +  prefix.symbol + "B";

};

HostStatusSidebarComponent._getUpdatedHealth = function() {
    HostStore._retrieveHealth();
    setTimeout( HostStatusSidebarComponent._getUpdatedHealth, HostStatusSidebarComponent.health_refresh_interval );
};

HostStatusSidebarComponent._updateHealth = function() {
    //Dispatcher.subscribe(HostStatusSidebarComponent.health_topic, HostStatusSidebarComponent._updateHealth);
    //HostStore._retrieveHealth();
    var data = HostStore.getHealthStatus();
    var health_values = HostStatusSidebarComponent._getHealthVariables(data);
    for(var i=0; i<health_values.length; i++) {
        var val = health_values[i];
        $("#" + val.id).html(val.value);
    }

    //$('#health-value-cpu_util').html(data.cpu_util);
    //var load = HostStatusSidebarComponent._formatLoad(data.load_avg);
    //$('#health-value-cpu_load').html(load);
    //setTimeout( HostStatusSidebarComponent._updateHealth, HostStatusSidebarComponent.health_refresh_interval );
};

HostStatusSidebarComponent.initialize();
