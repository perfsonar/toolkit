var HostMetadataComponent = {
    metadata_topic: 'store.change.host_metadata',
    placeholder: 'Select a node role',
};


HostMetadataComponent.initialize = function() {
    Dispatcher.subscribe(HostMetadataComponent.metadata_topic, HostMetadataComponent._setMetadata);
};

HostMetadataComponent._setMetadata = function( topic ) {
    var data = HostMetadataStore.getHostMetadata();
    var sel = $('#node_role_select');
    sel.select2( { 
        placeholder: HostMetadataComponent.placeholder,
    });

    if (("#host-overview-template").length == 0 || $("#host_overview").length == 0 ) {
        return;
    }
    var host_overview_template = $("#host-overview-template").html();
    var template = Handlebars.compile(host_overview_template);
    var address_formatted = data.location.city + ", " + data.location.state + " " + data.location.zipcode + " " + data.location.country;
    data.address_formatted = address_formatted;
    var map_url = '';
    if (data.location.latitude !== null && data.location.longitude !== null && data.location.latitude != '' && data.location.longitude != '' ) {
        var latlon = data.location.latitude + "," + data.location.longitude;    
        // the url below will have a map pin
        var map_url = 'http://www.google.com/maps/place/' + latlon + '/@' + latlon + ',12z';
        // this link will show the location, with no map pin
        //var map_url = 'http://www.google.com/maps/place/@' + latlon + ',12z';
    }
    data.map_url = map_url;
    var admin = template(data);
    $("#host_overview").html(admin);

};

HostMetadataComponent.initialize();

