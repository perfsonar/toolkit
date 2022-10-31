var PageHeader = {
    details_topic: 'store.change.host_details',
};


PageHeader.initialize = function() {
    Dispatcher.subscribe(PageHeader.details_topic, PageHeader._setDetails);
};

PageHeader._setDetails = function( topic ) {    
    var data = HostDetailsStore.getHostDetails();
    var hostNameOrIP = data.external_address.dns_name || data.external_address.ipv4_address || data.external_address.ipv6_address || data.toolkit_name;
    var primaryHostName="";
    if(data.external_address.dns_name){
        primaryHostName += data.external_address.dns_name + '<span class="ip_address"> at ';
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

    if(!primaryHostName){
        primaryHostName = data.toolkit_name;
    }

    $("#primary_hostname").html(primaryHostName);
    $("#header_hostname").text(" on " + hostNameOrIP);
    $(document).prop('title', 'perfSONAR Toolkit | ' + hostNameOrIP);

};

PageHeader.initialize();

