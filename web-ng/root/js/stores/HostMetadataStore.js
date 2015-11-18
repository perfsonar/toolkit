// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)

var HostMetadataStore = {
    hostMetadata: null,
    metadataTopic: 'store.change.host_metadata',
};

HostMetadataStore.initialize = function() {
    HostMetadataStore._retrieveInfo();
    
};

HostMetadataStore._retrieveInfo = function() {
    $.ajax({
            url: "services/host.cgi?method=get_metadata",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",            
            success: function (data) {
                HostMetadataStore.hostMetadata = data;
                Dispatcher.publish(HostMetadataStore.metadataTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
};

HostMetadataStore.getHostMetadata = function() {
    return HostMetadataStore.hostMetadata;
};

HostMetadataStore.initialize();
