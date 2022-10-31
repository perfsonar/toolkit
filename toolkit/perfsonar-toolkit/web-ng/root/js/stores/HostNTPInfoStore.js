// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)

var HostNTPInfoStore = {
    hostNTPInfo: null,
    ntpInfoTopic: 'store.change.host_ntp_info',
};

HostNTPInfoStore.initialize = function() {
    HostNTPInfoStore._retrieveInfo();
    
};

HostNTPInfoStore._retrieveInfo = function() {
    $.ajax({
            url: "services/host.cgi?method=get_ntp_info",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",            
            success: function (data) {
                HostNTPInfoStore.hostNTPInfo = data;
                Dispatcher.publish(HostNTPInfoStore.ntpInfoTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
};

HostNTPInfoStore.getHostNTPInfo = function() {
    return HostNTPInfoStore.hostNTPInfo;
};

HostNTPInfoStore.initialize();
