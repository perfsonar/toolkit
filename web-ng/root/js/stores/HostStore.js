// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)
// load first:
// HostAdminInfoStore.js, HostDetailsStore.js, HostHealthStore.js, HostServicesStore.js 

var HostStore = {
    hostSummary: {},
    adminInfoTopic: 'store.change.host_info',
    detailsTopic: 'store.change.host_details',
    servicesTopic: 'store.change.host_services',
    healthTopic: 'store.change.health_status',
    summaryTopic: 'store.change.host_summary',
};

HostStore.initialize = function() {
    HostStore._createSummaryTopic();
    
    HostStore.hostSummary.data = {};
    HostStore.hostSummary.healthSet = false;
    HostStore.hostSummary.infoSet = false;
    HostStore.hostSummary.detailsSet = false;
    HostStore.hostSummary.summarySet = false;
    HostStore.hostSummary.servicesSet = false;
};

HostStore._createSummaryTopic = function() {
    Dispatcher.subscribe(HostStore.detailsTopic, HostStore._setSummaryData);
    Dispatcher.subscribe(HostStore.adminInfoTopic, HostStore._setSummaryData);
    Dispatcher.subscribe(HostStore.servicesTopic, HostStore._setSummaryData);
    Dispatcher.subscribe(HostStore.healthTopic, HostStore._setSummaryData);
};

HostStore._setSummaryData = function (topic, data) {
    if (topic == HostStore.detailsTopic) {
        var data = HostDetailsStore.getHostDetails();
        jQuery.extend(HostStore.hostSummary.data, data);
        HostStore.hostSummary.detailsSet = true;
    } else if (topic == HostStore.adminInfoTopic) {
        var data = HostAdminInfoStore.getHostAdminInfo();
        jQuery.extend(HostStore.hostSummary.data, data);
        HostStore.hostSummary.infoSet = true;
    } else if (topic == HostStore.servicesTopic) {
        var data = HostServicesStore.getHostServices();
        jQuery.extend(HostStore.hostSummary.data, data);
        HostStore.hostSummary.servicesSet = true;
    } else if (topic == HostStore.healthTopic) {
        var data = HostHealthStore.getHealthStatus();
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

HostStore.getHostSummary = function() {
    return HostStore.hostSummary.data;
};

HostStore.initialize();
