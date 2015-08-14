// Make sure jquery loads first
// assues Dispatcher has already been declared (so load that first as well)

var HostStore = {
    hostHealth: null,
    hostInfo: null,
    hostDetails: null,
    hostServices: null,
    hostCommunities: null,
    hostSummary: {},
    adminInfoTopic: 'store.change.host_info',
    detailsTopic: 'store.change.host_details',
    servicesTopic: 'store.change.host_services',
    healthTopic: 'store.change.health_status',
    summaryTopic: 'store.change.host_summary',
    saveAdminInfoTopic: 'store.host_admin_info.save',
    saveAdminInfoErrorTopic: 'store.host_admin_info.save_error',
    saveServicesTopic: 'store.host_services.save',
    saveServicesErrorTopic: 'store.host_services.save_error',
};

HostStore.initialize = function() {
    HostStore._retrieveInfo();
    HostStore._retrieveStatus();
    HostStore._retrieveServices();
    HostStore._retrieveHealth();
    HostStore._createSummaryTopic();
    
    HostStore.hostSummary.data = {};
    HostStore.hostSummary.healthSet = false;
    HostStore.hostSummary.infoSet = false;
    HostStore.hostSummary.detailsSet = false;
    HostStore.hostSummary.summarySet = false;
    HostStore.hostSummary.servicesSet = false;
};

HostStore._retrieveInfo = function() {
        $.ajax({
            url: "/toolkit-ng/services/host.cgi?method=get_admin_info",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                HostStore.hostInfo = data;
                Dispatcher.publish(HostStore.adminInfoTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
};

HostStore._retrieveStatus = function() {
    $.ajax({
            url: "/toolkit-ng/services/host.cgi?method=get_details",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                HostStore.hostDetails = data;
                Dispatcher.publish(HostStore.detailsTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
};

HostStore._retrieveServices = function() {
    $.ajax({
            url: "/toolkit-ng/services/host.cgi?method=get_services",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                HostStore.hostServices = data;
                Dispatcher.publish('store.change.host_services');
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log("retrieveServices error");
                console.log(errorThrown);
            }
        });
};

HostStore._retrieveHealth = function() {
        $.ajax({
            url: "/toolkit-ng/services/host.cgi?method=get_health",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                HostStore.hostHealth = data;
                Dispatcher.publish('store.change.health_status');
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log("retrieveHealth error");
                console.log(errorThrown);
            }
        });
};

HostStore._createSummaryTopic = function() {
    Dispatcher.subscribe(HostStore.detailsTopic, HostStore._setSummaryData);
    Dispatcher.subscribe(HostStore.adminInfoTopic, HostStore._setSummaryData);
    Dispatcher.subscribe(HostStore.servicesTopic, HostStore._setSummaryData);
    Dispatcher.subscribe(HostStore.healthTopic, HostStore._setSummaryData);
};

HostStore._setSummaryData = function (topic, data) {
    if (topic == HostStore.detailsTopic) {
        var data = HostStore.getHostDetails();
        jQuery.extend(HostStore.hostSummary.data, data);
        HostStore.hostSummary.detailsSet = true;
    } else if (topic == HostStore.adminInfoTopic) {
        var data = HostStore.getHostInfo();
        jQuery.extend(HostStore.hostSummary.data, data);
        HostStore.hostSummary.infoSet = true;
    } else if (topic == HostStore.servicesTopic) {
        var data = HostStore.getHostServices();
        jQuery.extend(HostStore.hostSummary.data, data);
        HostStore.hostSummary.servicesSet = true;
    } else if (topic == HostStore.healthTopic) {
        var data = HostStore.getHealthStatus();
        jQuery.extend(HostStore.hostSummary.data, data);
        HostStore.hostSummary.healthSet = true;
    }
    if (HostStore.hostSummary.infoSet 
            && HostStore.hostSummary.detailsSet 
            && HostStore.hostSummary.servicesSet 
            && HostStore.hostSummary.healthSet) {
        HostStore.hostSummary.summarySet = true;
        Dispatcher.publish(HostStore.summaryTopic);
        // TODO: see if this summary needs to be disconnected due to the health updates
    }    
};

HostStore.saveAdminInfo = function(info) {
    var topic = HostStore.saveAdminInfoTopic;
    var error_topic = HostStore.saveAdminInfoErrorTopic;
    $.ajax({
        url: '/toolkit-ng/admin/services/host.cgi?method=update_info',
        type: 'POST',
        data: info,
        dataType: 'json',
        contentType: 'application/x-www-form-urlencoded',
        success: function(result) {
            HostStore._retrieveInfo();
            Dispatcher.publish(topic, result.message);
        },
        error: function(jqXHR, textStatus, errorThrown) {
            Dispatcher.publish(error_topic, errorThrown);
        }
    });


};

HostStore.saveServices = function(services) {
    var topic = HostStore.saveServicesTopic;
    var error_topic = HostStore.saveServicesErrorTopic;
    $.ajax({
        url: '/toolkit-ng/admin/services/host.cgi?method=update_enabled_services',
        type: 'POST',
        data: services,
        dataType: 'json',
        contentType: 'application/x-www-form-urlencoded',
        success: function(result) {
            HostStore._retrieveServices();
            Dispatcher.publish(topic, result.message);

        },
        error: function(jqXHR, textStatus, errorThrown) {
            Dispatcher.publish(error_topic, errorThrown);
        }
    });


};

HostStore.getHostInfo = function() {
    return HostStore.hostInfo;
};
HostStore.getHostDetails = function() {
    return HostStore.hostDetails;
};
HostStore.getHealthStatus = function() {
    return HostStore.hostHealth;
};
HostStore.getHostServices = function() {
    return HostStore.hostServices;
};
HostStore.getHostSummary = function() {
    return HostStore.hostSummary.data;
};

HostStore.initialize();
