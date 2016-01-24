var CommunityUpdateComponent = {
    communities: {},
    communitiesToAdd: [],
    communitiesToRemove: [],
    allTopic: 'store.change.communities_all',
    hostTopic: 'store.change.communities_host',
    metadataTopic: 'store.change.host_metadata', 
    allSet: false,
    hostSet: false,
    placeholder: 'Select communities',
    closeEventSet: false,
    select2Set: false,
};

CommunityUpdateComponent.initialize = function() {
    Dispatcher.subscribe(CommunityUpdateComponent.metadataTopic, CommunityUpdateComponent._setHostCommunities);
    Dispatcher.subscribe(CommunityUpdateComponent.allTopic, CommunityUpdateComponent._setAllCommunities);
    var addButton = $('#community_add_button');
    var addName = $('#community_add_name');
    var sel = $('#update_communities');
    addButton.click(function (e) {
        var newCommunity = addName.val(); 
        e.preventDefault();
        var host = CommunityUpdateComponent.communities.host;
        host[newCommunity] = 1;
        addName.val("");
        
        sel.append( $("<option></option>")
                        .attr("value", newCommunity)
                        .prop("selected", true)
                        .text(newCommunity) );
        
        sel.select2( { placeholder: CommunityUpdateComponent.placeholder });
    });

};

CommunityUpdateComponent._setHostCommunities = function( topic ) {
    /* Sets the host communities in the format {name: selected} */
    CommunityUpdateComponent.communities.host = {};
    var data = HostMetadataStore.getHostCommunities();

    var commObj = {};
    var h = 0;
    for(var i in data) {
        var row = {};
        row.id = h;
        row.text = data[i];
        commObj[data[i]] = 1;
        h++;
    }
    CommunityUpdateComponent.communities.host = commObj;

    CommunityUpdateComponent.hostSet = true;

    if (CommunityUpdateComponent.allSet && CommunityUpdateComponent.hostSet) {
        CommunityUpdateComponent._selectCommunities();
    }
};

CommunityUpdateComponent._setAllCommunities = function( topic ) {
    /* Sets the global communities in the format {name: selected} */
    CommunityUpdateComponent.communities.all = {};
    var data = CommunityAllStore.getAllCommunities();
    data = Object.keys(data.keywords);
    var commObj = {};
    var h = 0;
    for(var i in data) {
        var row = {};
        row.id = h;
        row.text = data[i];
        commObj[ data[i] ] = 0;
        h++;
    }
    CommunityUpdateComponent.communities.all = commObj;

    CommunityUpdateComponent.allSet = true;

    if (CommunityUpdateComponent.allSet && CommunityUpdateComponent.hostSet) {
        CommunityUpdateComponent._selectCommunities();
    }

};

CommunityUpdateComponent._selectCommunities = function() {
    var sel = $('#update_communities');
    var host = CommunityUpdateComponent.communities.host;
   
    sel.empty(); // remove old options, if any

    CommunityUpdateComponent._combineCommunities();

    var combined = CommunityUpdateComponent.communities.combined;
    $.each(combined, function(i, val) {
        sel.append( $("<option></option>")
                        .attr("value", val.text)
                        .prop("selected", val.selected)
                        .text(val.text) );
    });

    sel.select2( { 
        placeholder: CommunityUpdateComponent.placeholder,
    });
    CommunityUpdateComponent.select2Set = true;

    if (! CommunityUpdateComponent.closeEventSet ) {
        sel.on('select2:unselect', function(e) {
                var unselectedName = e.params.data.text;
        });
        CommunityUpdateComponent.closeEventSet = true;
    }
    
};

CommunityUpdateComponent.save = function() {
    var sel = $('#update_communities');
    var communities_arr = sel.val() || [];

    HostAdminStore.saveCommunities( communities_arr );
    
};

CommunityUpdateComponent.getSelectedCommunities = function() {
    var sel = $('#update_communities');
    var communities_arr = sel.val() || [];
    return communities_arr;
};

CommunityUpdateComponent._combineCommunities = function() {
    /* Combines the list of all global communities (CommunityUpdateComponent.communities.all)
     * with the communities defined for the host   (CommunityUpdateComponent.communities.host)
     * sorts, and then puts in the expected format, an array ob objects where each row looks like
     * { id: 0, text: "Community name", selected: true or false}
     * */
    CommunityUpdateComponent.communities.combined = {};
    var all = CommunityUpdateComponent.communities.all;
    var host = CommunityUpdateComponent.communities.host;
    var combined = $.extend({}, all, host);
    var sorted = [];
    var keys = Object.keys(combined).sort();
    for(var i in keys) {
        var row = {};
        row.id = i;
        row.text = keys[i];
        row.selected = combined[ keys[i] ];
        sorted.push( row );
    }

    CommunityUpdateComponent.communities.combined = sorted;

};

CommunityUpdateComponent.initialize();
