var HostStatusSidebarComponent = {
    host_info: null,
    host_status: null,
    status_topic: 'store.change.host_status'
};


HostStatusSidebarComponent.initialize = function() {
    Dispatcher.subscribe(HostStatusSidebarComponent.status_topic, HostStatusSidebarComponent._setStatus);
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

HostStatusSidebarComponent.initialize();
