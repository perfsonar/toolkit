// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)

var NTPClosestStore = {
    ntpClosest: null,
    ntpClosestTopic: 'store.change.ntp_closest',
};

NTPClosestStore.initialize = function() {
//    NTPClosestStore._retrieveNTPClosest();    
};

NTPClosestStore.retrieveNTPClosest = function() {
    $.ajax({
            url: "services/ntp.cgi?method=get_closest_servers",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                NTPClosestStore.ntpClosest = data;
                Dispatcher.publish(NTPClosestStore.ntpClosestTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
};

NTPClosestStore.getNTPClosest = function() {
    return NTPClosestStore.ntpClosest;
};

NTPClosestStore.initialize();
