var HostInfoComponent = {
    host_info: null,
    host_status: null,
    status_topic: 'store.change.host_status',
    info_topic: 'store.change.host_info'
};


HostInfoComponent.initialize = function() {
    Dispatcher.subscribe(HostInfoComponent.status_topic, HostInfoComponent._setStatus);
    Dispatcher.subscribe(HostInfoComponent.info_topic, HostInfoComponent._setInfo);
};

HostInfoComponent._setStatus = function( topic ) {
    var data = HostStore.getHostSummary();
    $("#primary_hostname").text(data.external_address.address);

};

HostInfoComponent._setInfo = function( topic ) {
    var data = HostStore.getHostInfo();

    var host_overview_template = $("#host-overview-template").html();
    var template = Handlebars.compile(host_overview_template);
    var address_formatted = data.location.city + ", " + data.location.state + " " + data.location.zipcode + " " + data.location.country;
    data.address_formatted = address_formatted;
    // TODO: add host address (numeric) back in
    var latlon = data.location.latitude + "," + data.location.longitude;    
    // the url below will have a map pin
    var map_url = 'http://www.google.com/maps/place/' + latlon + '/@' + latlon + ',12z';
    // this link will show the location, with no map pin
    //var map_url = 'http://www.google.com/maps/place/@' + latlon + ',12z';
    data.map_url = map_url;
    var admin = template(data);
    $("#host_overview").html(admin);

};

HostInfoComponent.initialize();

