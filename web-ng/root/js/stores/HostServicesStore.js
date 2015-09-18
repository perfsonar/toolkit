// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)

var HostServicesStore = {
    hostServices: null,
    servicesTopic: 'store.change.host_services',
};

HostServicesStore.initialize = function() {
    HostServicesStore._retrieveServices();
    
};

HostServicesStore._retrieveServices = function() {
    $.ajax({
            url: "services/host.cgi?method=get_services",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                HostServicesStore.hostServices = data;
                Dispatcher.publish(HostServicesStore.servicesTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
};

HostServicesStore.getHostServices = function() {
    return HostServicesStore.hostServices;
};

HostServicesStore.initialize();
