var CommunityUpdateComponent = {
    communities: {},
    communitiesToAdd: [],
    communitiesToRemove: [],
    allTopic: 'store.change.communities_all',
    hostTopic: 'store.change.communities_host',
    allSet: false,
    hostSet: false,
    placeholder: 'Select communities',
    closeEventSet: false,
    select2Set: false,
};

CommunityUpdateComponent.initialize = function() {
    Dispatcher.subscribe(CommunityUpdateComponent.hostTopic, CommunityUpdateComponent._setHostCommunities);
    Dispatcher.subscribe(CommunityUpdateComponent.allTopic, CommunityUpdateComponent._setAllCommunities);
    var addButton = $('#community_add_button');
    var addName = $('#community_add_name');
    var sel = $('#update_communities');
    addButton.click(function (e) {
        var newCommunity = addName.val(); 
        console.log("New community ", newCommunity);
        e.preventDefault();
        var host = CommunityUpdateComponent.communities.host;
        console.log('host', host);
        host[newCommunity] = 1;
        CommunityUpdateComponent._selectCommunities();
        addName.val("");
        /*
        sel.append( $("<option></option>")
                        .attr("value", newCommunity)
                        .prop("selected", true)
                        .text(newCommunity) );
        */
        //sel.select2();
    });

};

CommunityUpdateComponent._setHostCommunities = function( topic ) {
    /* Sets the host communities in the format {name: selected} */
    CommunityUpdateComponent.communities.host = {};
    var data = CommunityHostStore.getHostCommunities();

    var commObj = {};
    var h = 0;
    for(var i in data.communities) {
        var row = {};
        row.id = h;
        row.text = data.communities[i];
        commObj[data.communities[i]] = 1;
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
    //CommunityUpdateComponent.communities.all = communities;
    CommunityUpdateComponent.communities.all = commObj;

    CommunityUpdateComponent.allSet = true;

    if (CommunityUpdateComponent.allSet && CommunityUpdateComponent.hostSet) {
        CommunityUpdateComponent._selectCommunities();
    }

};

CommunityUpdateComponent._selectCommunities = function() {
    var sel = $('#update_communities');
    var host = CommunityUpdateComponent.communities.host;
   
    sel.empty();
    if (CommunityUpdateComponent.select2Set) {
        sel.select2("data", null); 
        sel.select2("destroy");        
    }
    //sel.first().select2('data', null)
    //sel.select2("destroy");

    CommunityUpdateComponent._combineCommunities();

    var combined = CommunityUpdateComponent.communities.combined;
    $.each(combined, function(i, val) {
        sel.append( $("<option></option>")
                        .attr("value", val.text)
                        .prop("selected", val.selected)
                        .text(val.text) );
        
    });

    console.log('#update_communities before creating select2', $('#update_communities'));

    sel.select2( { 
        placeholder: CommunityUpdateComponent.placeholder,
        //data: CommunityUpdateComponent.communities.all,            
    });
    console.log('#update_communities after creating select2', $('#update_communities'));
    CommunityUpdateComponent.select2Set = true;
    /*
    sel.on("change", function (e) { 
            //console.log('sel2 changed, e=', e);
            var selections = sel.val();
            console.log("select2 value = ", selections);
            
    });
      */  

    if (! CommunityUpdateComponent.closeEventSet ) {
        sel.on('select2:unselect', function(e) {
                console.log('close clicked', e);
                console.log('host', host);
                var unselectedName = e.params.data.text;
                console.log(unselectedName + ' closed');
                //sel.val(null).trigger("change");
                //host[unselectedName] = 0;
                delete host[unselectedName];
                console.log('hosts after deletion', host);
                //CommunityUpdateComponent._selectCommunities();
                console.log('#update_communities', $('#update_communities'));
        });
        CommunityUpdateComponent.closeEventSet = true;
    }
    
};

CommunityUpdateComponent.save = function() {
    var sel = $('#update_communities');
    var communities_arr = sel.val();
    console.log('community values', communities_arr);

    //var communities = { communities_arr.join(',');

    HostAdminStore.saveCommunities( communities_arr );
    
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

    console.log('combined communities', sorted);

};

CommunityUpdateComponent.initialize();
