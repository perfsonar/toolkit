var HostServicesComponent = {
    host_info: null,
    host_status: null,
    status_topic: 'store.change.host_status',
    services_topic: 'store.change.host_services',
    info_topic: 'store.change.host_info'
};


HostServicesComponent.initialize = function() {
    Dispatcher.subscribe(HostServicesComponent.services_topic, HostServicesComponent._setServices);
};

HostServicesComponent._setStatus = function( topic ) {
    var data = HostStore.getHostSummary();
    $("#primary_hostname").text(data.external_address.address);

};

HostServicesComponent._setServices = function( topic ) {
    var data = HostStore.getHostServices();
    for(var h=0; h<data.services.length; h++) {
        var ports_formatted = '';
        if (data.services[h].testing_ports !== undefined)  {
            for(var i=0; i<data.services[h].testing_ports.length; i++) {
                var test_port = data.services[h].testing_ports[i];
                ports_formatted += test_port.min_port + '-' + test_port.max_port;
                if (i<data.services[h].testing_ports.length - 1) {
                    ports_formatted += ', ';
                }
            }
        }

        data.services[h].ports_formatted = ports_formatted;
        data.services[h].has_details = (data.services[h].addresses || data.services[h].port_formatted);
    }

    var host_services_template = $("#host-services-template").html();
    var template = Handlebars.compile(host_services_template);
    var services = template(data);
    $("#host_services").html(services);

};

HostServicesComponent.initialize();

