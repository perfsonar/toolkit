// Make sure jquery loads first
// assues Dispatcher has already been declared (so load that first as well)

var HostStore = {
    hostInfo: null,
    hostStatus: null,
    hostCommunities: null,
    hostSummary: {}
};

HostStore.initialize = function() {
    HostStore._retrieveInfo();
    HostStore._retrieveStatus();
    HostStore._createSummaryTopic();
    HostStore.hostSummary.data = {};
    HostStore.hostSummary.infoSet = false;
    HostStore.hostSummary.statusSet = false;
    HostStore.hostSummary.summarySet = false;
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
                alert(errorThrown);
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
                alert(errorThrown);
            }
        });
};

HostStore._createSummaryTopic = function() {
    Dispatcher.subscribe('store.change.host_status', HostStore._setSummaryData);
    Dispatcher.subscribe('store.change.host_info', HostStore._setSummaryData);
};

HostStore._setSummaryData = function (topic, data) {
    if (topic == 'store.change.host_status') {
        var data = HostStore.getHostStatus();
        jQuery.extend(HostStore.hostSummary.data, data);
        HostStore.hostSummary.statusSet = true;
    } else if (topic == 'store.change.host_info') {
        var data = HostStore.getHostInfo();
        jQuery.extend(HostStore.hostSummary.data, data);
        HostStore.hostSummary.infoSet = true;
    }
    if (HostStore.hostSummary.infoSet && HostStore.hostSummary.statusSet) {
        HostStore.hostSummary.summarySet = true;
        Dispatcher.publish('store.change.host_summary');
    }    
};

HostStore.getHostInfo = function() {
    return HostStore.hostInfo;
};
HostStore.getHostStatus = function() {
    return HostStore.hostStatus;
};
HostStore.getHostSummary = function() {
    return HostStore.hostSummary.data;
};

HostStore.initialize();
