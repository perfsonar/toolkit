// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)

var HostAdminInfoStore = {
    hostAdminInfo: null,
    adminInfoTopic: 'store.change.host_info',
};

HostAdminInfoStore.initialize = function() {
    HostAdminInfoStore._retrieveInfo();
    
};

HostAdminInfoStore._retrieveInfo = function() {
    $.ajax({
            url: "services/host.cgi?method=get_admin_info",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",            
            success: function (data) {
                HostAdminInfoStore.hostAdminInfo = data;
                Dispatcher.publish(HostAdminInfoStore.adminInfoTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
};

HostAdminInfoStore.getHostAdminInfo = function() {
    return HostAdminInfoStore.hostAdminInfo;
};

HostAdminInfoStore.initialize();
