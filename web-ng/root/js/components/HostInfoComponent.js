var HostInfoComponent = {
    details_topic: 'store.change.host_details',
    info_topic: 'store.change.host_info',
    metadataTopic: 'store.change.host_metadata',
};


HostInfoComponent.initialize = function() {
    Dispatcher.subscribe(HostInfoComponent.details_topic, HostInfoComponent._setDetails);
    Dispatcher.subscribe(HostInfoComponent.metadataTopic, HostInfoComponent._setInfo);
};

HostInfoComponent._setDetails = function( topic ) {
    var data = HostDetailsStore.getHostDetails();
    var hostNameOrIP;
    var primaryHostName="";
    if(data.external_address.dns_name){
        primaryHostName += data.external_address.dns_name + '<span class="ip_address"> at ';
    } else if ( data.all_addrs_private && !data.configuration.allow_internal_addresses) {
        primaryHostName += data.toolkit_name;
        primaryHostName += ' <div class="ip_address">All detected addresses are in private addresses, and private addresses are disabled. To change this, edit /etc/perfsonar/toolkit/web/web_admin.conf</div>';
    }
    if(data.external_address.ipv4_address){
        primaryHostName += data.external_address.ipv4_address;
    }
    if(data.external_address.ipv6_address){
        if(data.external_address.ipv4_address){
            primaryHostName += ", "+data.external_address.ipv6_address + "</span>";
        }else{
            primaryHostName += data.external_address.ipv6_address + "</span>";
        }

    }
    if (data.force_toolkit_name) {
        hostNameOrIP = data.toolkit_name;
    } else {
        hostNameOrIP = data.external_address.dns_name || data.external_address.ipv4_address || data.external_address.ipv6_address || data.toolkit_name;
    }

    if(!primaryHostName){
        primaryHostName = hostNameOrIP;
    }

    var hostname_text = primaryHostName;
    $("#primary_hostname").html(hostname_text);
    $("#header_hostname").text(" on " + hostNameOrIP);
    $(document).prop('title', 'perfSONAR Toolkit | ' + hostNameOrIP);

};

HostInfoComponent._setInfo = function( topic ) {
    //var data = HostMetadataStore.getHostAdminInfo();
    var data = HostMetadataStore.getHostMetadata();

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
    data.org_and_site = (data.config.site_name != null && data.config.organization != null);
    data.org_or_site = (data.config.site_name != null || data.config.organization != null);

    var admin = template(data);
    $("#host_overview").html(admin);

};

HostInfoComponent.initialize();

