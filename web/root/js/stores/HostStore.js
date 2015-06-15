// Make sure jquery loads first
// assues Dispatcher has already been declared (so load that first as well)

var HostStore = {
    hostHealth: null,
    hostInfo: null,
    hostStatus: null,
    hostServices: null,
    hostCommunities: null,
    hostSummary: {}
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
    HostStore.hostSummary.statusSet = false;
    HostStore.hostSummary.summarySet = false;
    HostStore.hostSummary.servicesSet = false;
};

HostStore._retrieveInfo = function() {
        $.ajax({
            url: "/toolkit-ng/services/host.cgi?method=get_info",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                HostStore.hostInfo = data;
                Dispatcher.publish('store.change.host_info');
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
};

HostStore._retrieveStatus = function() {
    $.ajax({
            url: "/toolkit-ng/services/host.cgi?method=get_status",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                HostStore.hostStatus = data;
                Dispatcher.publish('store.change.host_status');
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
    Dispatcher.subscribe('store.change.host_status', HostStore._setSummaryData);
    Dispatcher.subscribe('store.change.host_info', HostStore._setSummaryData);
    Dispatcher.subscribe('store.change.host_services', HostStore._setSummaryData);
    Dispatcher.subscribe('store.change.health_status', HostStore._setSummaryData);
};

HostStore._setSummaryData = function (topic, data) {
    if (topic == 'store.change.host_status') {
        var data = HostStore.getHostStatus();
        //console.log('host_status', data);
        jQuery.extend(HostStore.hostSummary.data, data);
        HostStore.hostSummary.statusSet = true;
    } else if (topic == 'store.change.host_info') {
        var data = HostStore.getHostInfo();
        jQuery.extend(HostStore.hostSummary.data, data);
        HostStore.hostSummary.infoSet = true;
    } else if (topic == 'store.change.host_services') {
        var data = HostStore.getHostServices();
        jQuery.extend(HostStore.hostSummary.data, data);
        HostStore.hostSummary.servicesSet = true;
    } else if (topic == 'store.change.health_status') {
        var data = HostStore.getHealthStatus();
        jQuery.extend(HostStore.hostSummary.data, data);
        HostStore.hostSummary.healthSet = true;
    }
    if (HostStore.hostSummary.infoSet 
            && HostStore.hostSummary.statusSet 
            && HostStore.hostSummary.servicesSet 
            && HostStore.hostSummary.healthSet) {
        HostStore.hostSummary.summarySet = true;
        Dispatcher.publish('store.change.host_summary');
        // TODO: see if this summary needs to be disconnected due to the health updates
        //console.log('summary data');
        //console.log(data);
    }    
};

HostStore.getHostInfo = function() {
    return HostStore.hostInfo;
};
HostStore.getHostStatus = function() {
    return HostStore.hostStatus;
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
