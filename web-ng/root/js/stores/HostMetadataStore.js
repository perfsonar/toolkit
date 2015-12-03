// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)

var HostMetadataStore = {
    hostMetadata: null,
    metadataTopic: 'store.change.host_metadata',
};

HostMetadataStore.initialize = function() {
    HostMetadataStore._retrieveMetadata();
    
};

HostMetadataStore._retrieveMetadata = function() {
    $.ajax({
            url: "services/host.cgi?method=get_metadata",
            type: 'GET',
            contentType: "application/json",
            dataType: "json", 
            success: function (data) {
                data = HostMetadataStore._setCommunities( data );
                HostMetadataStore.hostMetadata = data;                
                Dispatcher.publish(HostMetadataStore.metadataTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
};

HostMetadataStore._setCommunities = function( data  ) {
    var communities = data.config.site_project;
    if ( typeof communities == 'string' ) {
        communities = [ communities ];
    }
    data.communities = communities;
    console.log('typeof site_project', typeof communities, 'typeof asdf', typeof 'asdf', 'typeof []', typeof []);
    console.log('set communities; data: ', data);
    return data;
};

HostMetadataStore.getHostMetadata = function() {
    return HostMetadataStore.hostMetadata;
};

HostMetadataStore.getHostAdminInfo = function() {
    return HostMetadataStore.hostMetadata;
};

HostMetadataStore.getHostCommunities = function() {
    return HostMetadataStore.hostMetadata.communities;
};

HostMetadataStore.initialize();
