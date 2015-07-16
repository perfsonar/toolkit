<script>
$(document).ready( function() {
var HostInfoComponent = {
    host_info: null,
    host_status: null

};

HostInfoComponent.initialize = function() {

};
        var info_topic = 'store.change.host_info';
        //$.pubsub( 'subscribe', topic, subscriber );
        //$.pubsub( 'publish', topic, data );

        var info_subscriber = function ( topic ) {
                console.log( 'info_subscriber' );
                console.log( topic );
                var data = HostStore.getHostInfo();
                console.log(data);

                var admin_template = '{{administrator.name}} <a href="mailto:{{administrator.email}}">&lt;{{administrator.email}}&gt;</a>';
                //var admin = data.administrator.name + " " + '<a href="mailto:' + data.administrator.email + '">' + data.administrator.email + "</a>";
                var template = Handlebars.compile(admin_template);
                var admin = template(data);
                $("#host_administrator").html(admin);
                $("#host_organization").html(data.administrator.organization);
                //$("#host_administrator").text(data.administrator.name);
                //$("#host_admin_email").text(data.administrator.email);
                /*
                $("#primary_hostname").text(data.external_address.address);
                if (data.external_address.ipv4_address != data.external_address.address) {
                    $("#primary_ipv4_address").text(data.external_address.ipv4_address);
                    $("#display_primary_ipv4_address").show();
                }
                */
                var address = data.location.city + ", " + data.location.state + " " + data.location.zipcode + " " + data.location.country;
                $("#host_street_address").text(address);
                if (data.location.latitude !== null && data.location.longitude !== null) {
                    var latlon = data.location.latitude + "," + data.location.longitude;
                    // this link will show the location, with no map pin
                    $("#map_link").html('<a href="http://www.google.com/maps/place/@' + latlon + ',12z" target="_blank">map</a>');
                    // the link below will have a pin
                    //$("#map_link").html('<a href="http://www.google.com/maps/place/' + latlon + '/@' + latlon + ',12z" target="_blank">map</a>');
                }
        };
        Dispatcher.subscribe('store.change.host_info', info_subscriber);

       var host_info_subscriber = function ( topic, data ) { 
            $.ajax({
                url: "/toolkit-ng/services/host.cgi?method=get_admin_info",
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
    url: "/toolkit-ng/services/host.cgi?method=get_details",
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
});
</script>

