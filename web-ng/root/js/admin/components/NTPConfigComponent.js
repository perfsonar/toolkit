var NTPConfigComponent = {
    config: {},
    modalData: {},
    configTopic: 'store.change.ntp_config',
    placeholder: 'Select NTP servers',
    closeEventSet: false,
    listHeight: null,
    //select2Set: false,
};

NTPConfigComponent.initialize = function() {
    NTPConfigComponent.modalData.servers = [];
    NTPConfigComponent.modalData.newServers = [];
    Dispatcher.subscribe(NTPConfigComponent.configTopic, NTPConfigComponent._setServers);
    
    NTPConfigComponent._setEventHandlers();

    /*
    var addButton = $('#community_add_button');
    var addName = $('#community_add_name');
    var sel = $('#update_communities');
    addButton.click(function (e) {
        var newCommunity = addName.val(); 
        e.preventDefault();
        var host = NTPConfigComponent.communities.host;
        host[newCommunity] = 1;
        addName.val("");
        
        sel.append( $("<option></option>")
                        .attr("value", newCommunity)
                        .prop("selected", true)
                        .text(newCommunity) );
        
        sel.select2( { placeholder: NTPConfigComponent.placeholder });
    });
    */

};



NTPConfigComponent._setServers = function( topic ) {
    /* Sets the list of servers servers in the format  
     * { id: "hostname", text: "Description", selected: true or false}
     * */
    NTPConfigComponent.config = {};
    var data = NTPConfigStore.getNTPKnownServers();
    console.log("known servers", data);


    var commObj = [];

    commObj = NTPConfigComponent._formatServers(data);

    NTPConfigComponent.config = commObj;
    NTPConfigComponent.modalData.servers = commObj;
    
    console.log('servers (modified)', commObj);

    NTPConfigComponent._selectServers();
};

NTPConfigComponent._selectServers = function() {
    var sel = $('#select_ntp_servers');
    var config = NTPConfigComponent.config;
   
    sel.empty();

    $.each(config, function(i, val) {
        sel.append( $("<option></option>")
                        .attr("value", val.text)
                        .prop("selected", val.selected)
                        .text(val.text) );
    });

    sel.select2( { 
        placeholder: NTPConfigComponent.placeholder,
    });
    //NTPConfigComponent.select2Set = true;

    if (! NTPConfigComponent.closeEventSet ) {
        sel.on('select2:unselect', function(e) {
                var unselectedName = e.params.data.text;
        });
        NTPConfigComponent.closeEventSet = true;
    }
    
};

NTPConfigComponent.save = function() {
    var sel = $('#update_communities');
    var communities_arr = sel.val();
    console.log('community values', communities_arr);

    HostAdminStore.saveCommunities( communities_arr );
    
};

NTPConfigComponent._formatServers = function( data ) {
    /* 
     * Formats the list of servers for use in select2
     * sorts, and then puts in the expected format, an array of objects where each row looks like
     * { id: 0, text: "Community name", selected: true or false}
    */

    var formatted = [];
    var keys = Object.keys(data).sort();
    for(var i in keys) {
        var row = {};
        var hostname = keys[i];
        var selected = data[ keys[i] ].selected || 0;
        var description = data[ keys[i] ].description;        
        row.id = hostname;
        row.text = NTPConfigComponent._formatServer(hostname, description);
        row.selected = selected;
        if (typeof description != "undefined") {
            row.description = description;
        }
        formatted.push( row );
    }

    return formatted;

};

NTPConfigComponent._formatServer = function ( hostname, description ) {
    /* 
     * Utility function to format the NTP server name either as
     * Hostname (Description)
     * or
     * Description - Hostname
     * TODO: Update hostname format with design choice
    */
    var server = '';
    /*
    // Description - hostname
    if ( typeof description != 'undefined' && description != "") {
        server = description + ' - ';
    }
    server += hostname;
    */
    
    // Hostname (Description)
    server = hostname;
    if ( typeof description != 'undefined' && description != "") {
        server += ' (' + description + ')';
    }
    
    return server;
};

NTPConfigComponent._getContainerHeight = function() {
            var modal_height = $('div.reveal-modal-bg').height();
            var min_height = 120;
            var listHeight = ( modal_height / 2.5 > min_height ? modal_height / 2.5 : min_height) + 'px';
            console.log("modal height", modal_height, "list height", listHeight);
            NTPConfigComponent.listHeight = listHeight;
};

NTPConfigComponent._setListHeight = function() {
            $('#ntp_list').height(NTPConfigComponent.listHeight);

};

NTPConfigComponent._setEventHandlers = function() {
    var manage_link = $("#manage-available-servers-link");

    if (("#ntp-modal-server-list-template").length == 0 || $("#ntp-modal-server-list").length == 0 ) {
        return;
    }

    manage_link.click( function(e) {
            NTPConfigComponent._getContainerHeight();
            NTPConfigComponent._displayModalServerList();
    });

    var add_button_el = $('#ntp_server_add_button');
    add_button_el.click(function(e) {
        var add_hostname_el = $('#ntp_server_add_hostname');
        var add_description_el = $('#ntp_server_add_description');
        var add_hostname = add_hostname_el.val();
        var add_description = add_description_el.val();
        add_hostname_el.val('');
        add_description_el.val('');
        NTPConfigComponent._addServerModal(add_hostname, add_description);
    });

};

NTPConfigComponent._displayModalServerList = function() {
    var data = {};
    data.servers = NTPConfigComponent.modalData.servers;
    var list_container = $('#ntp-modal-server-list');
    var server_template = $('#ntp-modal-server-list-template').html();
    var template = Handlebars.compile(server_template);
    var servers = template(data);
    list_container.html(servers);
    NTPConfigComponent._setListHeight();

};

NTPConfigComponent._addServerModal = function( hostname, description ) {
    var data = NTPConfigComponent.modalData.servers;
    var row = {};
    row.id = hostname;
    if (typeof description != "undefined" && description != "") {
        row.description = description; // NTPConfigComponent._formatServer(hostname, description);
    }
    row.selected = true;
    data.unshift(row);
    NTPConfigComponent.modalData.newServers.push(row);
    console.log('new servers', NTPConfigComponent.modalData.newServers);
    NTPConfigComponent._displayModalServerList();
};

NTPConfigComponent.initialize();
