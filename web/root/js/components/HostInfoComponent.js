$(document).ready( function() {
var HostInfoComponent = {
    host_info: null,
    host_status: null,
    status_topic: 'store.change.host_status',
    info_topic: 'store.change.host_info'

};


HostInfoComponent.initialize = function() {
    //Dispatcher.subscribe('store.change.host_status', HostInfoComponent._setStatus);
    Dispatcher.subscribe('store.change.host_summary', HostInfoComponent._setStatus);
};

HostInfoComponent._setStatus = function( topic ) {
    console.log("setstatus topic: " + topic);
    var data = HostStore.getHostSummary();
    console.log(data);
    $("#primary_hostname").text(data.external_address.address);

};

        var info_topic = 'store.change.host_info';
        //$.pubsub( 'subscribe', topic, subscriber );
        //$.pubsub( 'publish', topic, data );

        var info_subscriber = function ( topic ) {
                console.log( 'info_subscriber' );
                console.log( topic );
                var data = HostStore.getHostInfo();
                //console.log(data);

                var host_overview_template = $("#host-overview-template").html();
                var template = Handlebars.compile(host_overview_template);
                var address_formatted = data.location.city + ", " + data.location.state + " " + data.location.zipcode + " " + data.location.country;
                data.address_formatted = address_formatted;
                var latlon = data.location.latitude + "," + data.location.longitude;
                var map_url = 'http://www.google.com/maps/place/' + latlon + '/@' + latlon + ',12z';
                data.map_url = map_url;
                var admin = template(data);
                $("#host_overview").html(admin);
                    // this link will show the location, with no map pin
                    //$("#map_link").html('<a href="http://www.google.com/maps/place/@' + latlon + ',12z" target="_blank">map</a>');
                    // the link below will have a pin
        };
        Dispatcher.subscribe(HostInfoComponent.info_topic, info_subscriber);

       var host_info_subscriber = function ( topic, data ) { 
            $.ajax({
                url: "/toolkit-ng/services/host.cgi?method=get_info",
                type: 'GET',
                contentType: "application/json",
                dataType: "json",
                success: function (data) {
                    console.log('Success!');
                    //$('#host_org').text(data
                    $("#primary_hostname").text(data.external_address.address);
                    if (data.external_address.ipv4_address != data.external_address.address) {
                        $("#primary_ipv4_address").text(data.external_address.ipv4_address);
                        $("#display_primary_ipv4_address").show();
                    }
                    //$("#host_country").text(data.location.country);
                    //$("#host_postal_code").text(data.location.zipcode);
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    alert(errorThrown);
                }
            });
    };
/*
$.ajax({
    url: "/toolkit-ng/services/host.cgi?method=get_status",
    type: 'GET',
    contentType: "application/json",
    dataType: "json",
    success: function (data) {
        console.log('Success!');
        //$('#host_org').text(data
        $("#primary_hostname").text(data.external_address.address);
        if (data.external_address.ipv4_address != data.external_address.address) {
            $("#primary_ipv4_address").text(data.external_address.ipv4_address);
            $("#display_primary_ipv4_address").show();
        }
        //$("#host_country").text(data.location.country);
        //$("#host_postal_code").text(data.location.zipcode);
    },
    error: function (jqXHR, textStatus, errorThrown) {
        alert(errorThrown);
    }
});
*/
HostInfoComponent.initialize();
});

