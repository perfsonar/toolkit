// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)

var HostHealthStore = {
    hostHealth: null,
    healthTopic: 'store.change.health_status',
};

HostHealthStore.initialize = function() {
    HostHealthStore._retrieveHealth();
    
};

HostHealthStore._retrieveHealth = function() {
    $.ajax({
            url: "/toolkit/services/host.cgi?method=get_health",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                HostHealthStore.hostHealth = data;
                Dispatcher.publish(HostHealthStore.healthTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
};

HostHealthStore.getHealthStatus = function() {
    return HostHealthStore.hostHealth;
};

HostHealthStore.initialize();
