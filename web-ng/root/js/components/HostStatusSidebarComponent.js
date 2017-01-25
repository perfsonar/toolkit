var HostStatusSidebarComponent = {
    details_topic: 'store.change.host_details',
    health_topic: 'store.change.health_status',
    ntp_topic: 'store.change.host_ntp_info',
    metadata_topic: 'store.change.host_metadata',
    ntp_info: null,
    status: null,
    details: null,
    metadata: null,
    details_set: false,
    metadata_set: false,
    health_token: null,        
    health_refresh_interval: 10000, // in milliseconds
    id_prefix: "health-value-",
    recommended_ram: 4, // in gigabytes
    show_ram_in_details: true,
};

HostStatusSidebarComponent.initialize = function() {
    if ($("#sidebar_host_status").length == 0 ) { 
            return;
    }
    HostStatusSidebarComponent._registerHelpers();
    Dispatcher.subscribe(HostStatusSidebarComponent.details_topic, HostStatusSidebarComponent._setDetails);
    Dispatcher.subscribe(HostStatusSidebarComponent.metadata_topic, HostStatusSidebarComponent._setMetadata);
    Dispatcher.subscribe(HostStatusSidebarComponent.ntp_topic, HostStatusSidebarComponent._setNTPInfo);
    HostStatusSidebarComponent.health_token = Dispatcher.subscribe(HostStatusSidebarComponent.health_topic, HostStatusSidebarComponent._setHealthStatus);
};

HostStatusSidebarComponent._setDetails = function( topic ) {
    var data = HostDetailsStore.getHostDetails();
    HostStatusSidebarComponent.status = data;

    // will print out individually
    data.ntp_synced = (data.ntp.synchronized == 1 ? "Yes" : "No");
    if (data.ntp.synchronized == 1 ) {
        data.ntp_classes = 'color-green';
    } else {
        data.ntp_classes = 'color-red';
    }
    
    data.registered = (data.globally_registered == 1 ? "Yes" : "No");
    if (data.globally_registered == 1 ) {
        data.registered_classes = 'color-green';
    } else {
        data.registered_classes = 'color-red';
    }

    var primary_interface = data.external_address.iface;
    if (typeof primary_interface != "undefined") {  
        data.primary_interface = primary_interface;
    }

    // will loop to print out (in order)
    var status_values = [];
   
    var auto_updates = data.auto_updates;
    if (typeof auto_updates != "undefined") {
        var auto_updates_value = (auto_updates == 1 ? "ON" : "OFF");
        var auto_updates_class = (auto_updates == 1 ? "color-green" : "color-red");
        status_values.push({label:"Auto Updates", value: auto_updates_value, classes: auto_updates_class });
    }

    var is_vm = data.is_vm;
    if (is_vm == 1) {
        status_values.push( {label: "Virtual Machine", value: "Yes"} );
    } else {
        status_values.push( {label: "Virtual Machine", value: "No"} ); // actually 0 could mean unknown also
    }

    // (will be hidden in Status section if shown in Health section)
    var host_memory = data.host_memory;
    if (typeof host_memory != "undefined") {   
        var memVal = {};
        if (host_memory < HostStatusSidebarComponent.recommended_ram) {
            memVal.classes = "color-red";
        }
        host_memory += " GB";
        memVal.id    = "ram_details";  
        memVal.label = "RAM";
        memVal.value = host_memory;
        status_values.push( memVal );
    }

    // for More Host Details popup
    var status_more_values = [];

    if (typeof data.sys_vendor != "undefined") {
        status_more_values.push( {label: "Vendor", value: data.sys_vendor} );
    }
    if (typeof data.product_name != "undefined") {
        if (is_vm == 1) {
            status_more_values.push( {label: "VM Host", value: data.product_name} );
        } else {
            status_more_values.push( {label: "Model", value: data.product_name} );
        }
    }
        
    var cpu_val;
    var cpus = data.cpus;
    if (typeof cpus != "undefined") {   
       cpu_val = cpus; 
    } else {
        cpu_val = "?";
    }
    var cpu_cores = data.cpu_cores;
    if (typeof cpu_cores != "undefined") {   
        cpu_val = cpu_val + " / " + cpu_cores;
    } else {
        cpu_val = cpu_val + " / ?";
    }
    status_more_values.push( {label: "CPUs / Cores", value: cpu_val} );


    var cpu_speed = Math.round(data.cpu_speed);
    if (typeof cpu_speed != "undefined") {  
        cpu_speed += " MHz"; 
        status_more_values.push( {label: "CPU Speed", value: cpu_speed} );
    }

    var os_info = data.distribution;
    if (typeof os_info != "undefined") {
        status_more_values.push( {label: "OS", value: os_info} );
    }

    var kernel = data.kernel_version;
    if (typeof kernel != "undefined") {
        status_more_values.push( {label: "Kernel version", value: kernel} );
    }

    var toolkit_version = data.toolkit_version;
    if (toolkit_version !== null) {  
        status_more_values.push( {label: "perfSONAR version", value: toolkit_version} );
    }

    var rpm_version = data.toolkit_rpm_version;
    if (typeof rpm_version != "undefined") {  
        status_more_values.push( {label: "Toolkit package version", value: rpm_version} );
    }

    data.status_values = status_values;
    data.status_more_values = status_more_values;
    
    HostStatusSidebarComponent.details = data;

    HostStatusSidebarComponent.details_set = true;

    HostStatusSidebarComponent._showDetails();

};

HostStatusSidebarComponent._setMetadata = function( topic ) {
    var data = HostMetadataStore.getHostAdminInfo();
    HostStatusSidebarComponent.metadata = data;
    HostStatusSidebarComponent.metadata_set = true;
    HostStatusSidebarComponent._showDetails();

};

HostStatusSidebarComponent._showDetails = function() {
    if (!HostStatusSidebarComponent.details_set || !HostStatusSidebarComponent.metadata_set) {
        return;
    }

    var details = HostStatusSidebarComponent.details;
    var metadata = HostStatusSidebarComponent.metadata;

    var data = {};
    data = $.extend({}, details, metadata);

    var host_status_template = $("#sidebar-status-template").html();
    var template = Handlebars.compile(host_status_template);

    var status_output = template(data);

    $("#sidebar_host_status").html(status_output);

    HostStatusSidebarComponent.details_set = true;
    HostStatusSidebarComponent._hideRAMInDetails();

    HostStatusSidebarComponent._handleNTPInfo();

}

HostStatusSidebarComponent._setNTPInfo = function( topic ) {
    var data = HostNTPInfoStore.getHostNTPInfo();
    HostStatusSidebarComponent.ntp_info = data;

    if ( $("#sidebar_ntp_details_link").length == 0 ) {
        return;
    }


    HostStatusSidebarComponent._handleNTPInfo();

};

HostStatusSidebarComponent._hideRAMInDetails = function() {
    if (HostStatusSidebarComponent.details_set && !HostStatusSidebarComponent.show_ram_in_details) {
        if ($("#ram_details").length > 0) {
            $("#ram_details").hide();
        }
    }
};

HostStatusSidebarComponent._handleNTPInfo = function() {
    if ( HostStatusSidebarComponent.status !== null && HostStatusSidebarComponent.ntp_info !== null) {
        var data = HostStatusSidebarComponent.ntp_info;
        // Check for # of keys > 1 because we expect to have
        // synchronized: 0 even if not synced so more than 1 means we have
        // more info to show
        if (Object.keys(data).length > 1) {
            $('#sidebar_ntp_details_link').show();
            var container = $('#sidebar-ntp-popover-container');
            var ntp_template = $("#sidebar-status-ntp-popover-template").html();
            var template = Handlebars.compile(ntp_template);

            var ntp_output = template(data);

            container.html(ntp_output);
            }            
    } 

};

HostStatusSidebarComponent._registerHelpers = function() {
    Handlebars.registerHelper('formatSpeed', function(speed) {
        var ret = null;
        if ( speed > 0 ) {
            ret = speed /  ( 1000000 ) + 'M';
        }
        return ret;
    });

    Handlebars.registerHelper('is_equal', function(a, b) {
        if ( a == b ) {
            return true;
        } else {
            return false;
        }
    });

    Handlebars.registerHelper('hostnames_of_ip', function(hostnames, ip, options) {
        if (hostnames[ip]) {
            return hostnames[ip];
        } else {
            return [];
        }
    });
};

HostStatusSidebarComponent._getHealthVariables = function(data) {
    var health_values = [];

    // Use an ID prefix to better scope these elements in the DOM
   var id_prefix = HostStatusSidebarComponent.id_prefix;

    var cpu_util = data.cpu_util;
    if (typeof cpu_util != "undefined") {
        cpu_util += "%";
        var id = "cpu_util";
        id = id_prefix + id;
        health_values.push( { label: "CPU Usage", value: cpu_util, id: id } );
    }

    id = "cpu_load";
    id = id_prefix + id;
    var load = HostStatusSidebarComponent._formatLoad(data.load_avg);
    if (typeof load != "undefined") {
        health_values.push( { label: "Load", value: load, id: id } );
    } 

    id = "mem_usage";
    id = id_prefix + id;
    var memory = HostStatusSidebarComponent._formatMemoryUsage(data.mem_used, data.mem_total);
    if (typeof memory != "undefined") {
        var memVal = {};
        if (data.mem_total < HostStatusSidebarComponent.recommended_ram * 1000000000) {
            memVal.classes = "color-red";
        }
        memVal.label = "RAM";
        memVal.value = memory;
        health_values.push( memVal );
    }

    id = "swap_usage";
    id = id_prefix + id;
    var swap = HostStatusSidebarComponent._formatMemoryUsage(data.swap_used, data.swap_total);
    if (typeof swap != "undefined") {
        health_values.push( { label: "Swap usage", value: swap, id: id } );
    }

    id = "root_usage";
    id = id_prefix + id;
    var root = HostStatusSidebarComponent._formatMemoryUsage(data.rootfs.used, data.rootfs.total);
    if (typeof root != "undefined") {
        health_values.push( { label: "Root partition", value: root, id: id } );
    }

    return health_values;
};

HostStatusSidebarComponent._setHealthStatus = function( topic ) {
    var data = HostHealthStore.getHealthStatus();
    var health_values = HostStatusSidebarComponent._getHealthVariables(data);

    HostStatusSidebarComponent.show_ram_in_details = false; 
    HostStatusSidebarComponent._hideRAMInDetails();

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
 
    setTimeout( HostStatusSidebarComponent._getUpdatedHealth, HostStatusSidebarComponent.health_refresh_interval );
};

HostStatusSidebarComponent._formatLoad = function(load_obj) {
    if (typeof load_obj == "undefined") {
        return;
    }
    var load_vals = [ load_obj.avg_1,
                      load_obj.avg_5,
                      load_obj.avg_15 ];

    var load = load_vals.join(', ') || null;
    return load; 
};


HostStatusSidebarComponent._formatMemoryUsage = function(memory1, memory2) {
    if (typeof memory1 == "undefined" || typeof memory2 == "undefined") {
        return;
    }
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
    HostHealthStore._retrieveHealth();
    setTimeout( HostStatusSidebarComponent._getUpdatedHealth, HostStatusSidebarComponent.health_refresh_interval );
};

HostStatusSidebarComponent._updateHealth = function() {
    var data = HostHealthStore.getHealthStatus();
    var health_values = HostStatusSidebarComponent._getHealthVariables(data);
    for(var i=0; i<health_values.length; i++) {
        var val = health_values[i];
        $("#" + val.id).html(val.value);
    }
    health_values = null;
    data = null;
};

HostStatusSidebarComponent.initialize();
