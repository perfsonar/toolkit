var HostServicesComponent = {
    services_topic: 'store.change.host_services',
};


HostServicesComponent.initialize = function() {
    Dispatcher.subscribe(HostServicesComponent.services_topic, HostServicesComponent._setServices);
};

HostServicesComponent._setStatus = function( topic ) {
    var data = HostStore.getHostSummary();
    $("#primary_hostname").text(data.external_address.address);

};

HostServicesComponent._setServices = function( topic ) {
    if ($("#host-services-template").length == 0 || $("#host_services").length == 0) {
        return;
    }
    var data = HostStore.getHostServices();
    for(var h=0; h<data.services.length; h++) {
        var ports_formatted = '';        
        if (data.services[h].is_installed === 0) {
            data.services[h].show_service = false;
        } else {
            data.services[h].show_service = true;
        }
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
        data.services[h].has_details = (data.services[h].addresses.length > 0 || data.services[h].ports_formatted != '');
        var status = '';
        var status_class = '';
        if (data.services[h].is_running == 'yes') {
            status = 'Running';
            status_class = 'running';
        } else if (data.services[h].is_running == 'no') {
            status = 'Not Running';
            status_class = 'off';
        } else {
            status = 'Disabled';
            status_class = 'disabled';
        }
        data.services[h].status = status;
        data.services[h].status_class = status_class;
    }
    var host_services_template = $("#host-services-template").html();
    var template = Handlebars.compile(host_services_template);
    var services = template(data);
    $("#host_services").html(services);

};

HostServicesComponent.initialize();

