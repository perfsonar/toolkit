// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)

var HostMetadataStore = {
    hostMetadata: null,
    metadataTopic: 'store.change.host_metadata',
    allRoles: [ 
        {id: 'nren', text: 'NREN'}, 
        {id: 'regional', text: 'Regional'},
        {id: 'site-border', text: 'Site Border'},
        {id: 'site-internal', text: 'Site Internal'},
        {id: 'science-dmz', text: 'Science DMZ'},
        {id: 'exchange-point', text: 'Exchange Point'},
        {id: 'test-host', text: 'Test Host'},
        {id: 'default-path', text: 'Default Path'},
        {id: 'backup-path', text: 'Backup Path'},
    ],
    allAccessPolicies: [
        {id: 'public', text: 'Public'},
        {id: 'research-education', text: 'R&E Only'},
        {id: 'private', text: 'Private'},
        {id: 'limited', text: 'Limited'},
    ],
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
                data = HostMetadataStore._setRole( data );
                HostMetadataStore.hostMetadata = data;
                Dispatcher.publish(HostMetadataStore.metadataTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
};

HostMetadataStore._setCommunities = function( data  ) {
    var communities = data.communities;
    communities = SharedUIFunctions._getAsArray( communities );
    /*
    if ( typeof communities == 'string' ) {
        communities = [ communities ];
    }
    */
    data.communities = communities;
    return data;
};

HostMetadataStore._setRole = function( data  ) {
    var role = data.config.role;
    role = SharedUIFunctions._getAsArray( role );
    var role_text = HostMetadataStore.getRoleNames( role );
    data.role_text = role_text;
    data.role = role;

    var access_policy = data.config.access_policy;
    access_policy = HostMetadataStore.getAccessPolicyName( access_policy );
    data.access_policy = access_policy;

    var pn_text = data.config.pn_text;
    data.pn_text = pn_text;
    var pn_link = data.config.pn_link;
    data.pn_link = pn_link;   

    var access_policy_notes = data.config.access_policy_notes;
    data.access_policy_notes = access_policy_notes;
    data.show_access_policy = access_policy || access_policy_notes;

    return data;
};

// Get the role names for the specified roles. Takes an array of roles and returns
// an array of objects with the role info

HostMetadataStore.getRoleNames = function( roles ) {
    var role_text;
    var roleInfo = [];
    var allRoles = HostMetadataStore.allRoles; 
    for (var i in roles) {
        var name = roles[i];
        var result = $.grep(allRoles, function(e){ return e.id == name; });
        if (result.length > 0) {
            // found (we should only find one, so no need to loop)
            roleInfo.push( result[0].text );
        }
    }
    
    role_text = roleInfo.join(', ');

    return role_text;
};

// Get the names for the specified access policy. Takes a string of the id and returns
// its name

HostMetadataStore.getAccessPolicyName = function( policy ) {
    var name;
    var allAccessPolicies = HostMetadataStore.allAccessPolicies;
    var result = $.grep(allAccessPolicies, function(e){ return e.id == policy; });
    if (result.length > 0) {
        // found (we should only find one, so no need to loop)
        name = result[0].text
    }
    return name;
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
