// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)

var HostGuessLatLonStore = {
    coordinates: null,
    latLonTopic: 'store.change.guess_lat_lon',
};

HostGuessLatLonStore.initialize = function() {
    HostGuessLatLonStore._retrieveLatLon(); 
};

HostGuessLatLonStore._retrieveLatLon = function() {
    $.ajax({
            url: "services/host.cgi?method=get_calculated_lat_lon",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                HostGuessLatLonStore.coordinates = data;
                Dispatcher.publish(HostGuessLatLonStore.latLonTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
};

HostGuessLatLonStore.getLatLon = function() {
    return HostGuessLatLonStore.coordinates;
};

HostGuessLatLonStore.initialize();
