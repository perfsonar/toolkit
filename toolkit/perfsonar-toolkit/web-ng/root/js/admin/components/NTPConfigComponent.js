var NTPConfigComponent = {
    data: {},
    modalData: {},
    configTopic: 'store.change.ntp_config',
    ntpClosestTopic: 'store.change.ntp_closest',
    formChangeTopic: 'ui.form.change',
    formSuccessTopic: 'ui.form.success',
    formErrorTopic: 'ui.form.error',
    formCancelTopic: 'ui.form.cancel',
    formNTPChangeTopic: 'ui.form.ntp.change',
    formNTPSuccessTopic: 'ui.form.ntp.success',
    formNTPErrorTopic: 'ui.form.ntp.error',
    formNTPCancelTopic: 'ui.form.ntp.cancel',
    saveNTPConfigTopic: 'store.ntp_config.save',
    saveNTPConfigErrorTopic: 'store.ntp_config.save_error',
    placeholder: 'Select NTP servers',
    closeEventSet: false,
    listHeight: null,
    //select2Set: false,
};

NTPConfigComponent.initialize = function() {
    NTPConfigComponent._initGlobalData();
    NTPConfigComponent._initModalData();
    Dispatcher.subscribe(NTPConfigComponent.configTopic, NTPConfigComponent._retrieveServers);
    Dispatcher.subscribe(NTPConfigComponent.ntpClosestTopic, NTPConfigComponent._getClosest);
    Dispatcher.subscribe(NTPConfigComponent.saveNTPConfigTopic, NTPConfigComponent._saveSuccess);
    Dispatcher.subscribe(NTPConfigComponent.saveNTPConfigErrorTopic, SharedUIFunctions._saveError );
    NTPConfigComponent._setEventHandlers();
};

NTPConfigComponent._initGlobalData = function () {
    NTPConfigComponent.data.servers = {};
    NTPConfigComponent.data.serversToAdd = [];
    NTPConfigComponent.data.serversToRemove = [];

};

NTPConfigComponent._initModalData = function () {
    NTPConfigComponent.modalData.serversToAdd = [];
    NTPConfigComponent.modalData.serversToRemove = [];
};

NTPConfigComponent._retrieveServers = function( topic ) {
    NTPConfigComponent.data.servers = {};
    var data = NTPConfigStore.getNTPKnownServers();
    var servers = NTPConfigComponent._formatServers(data);
    NTPConfigComponent.data.servers = servers;
    NTPConfigComponent._setServers();
};

NTPConfigComponent._setServers = function() {
    /* Sets the list of servers servers in the format  
     * { id: "hostname", text: "Description", selected: true or false}
     * */
    var servers = NTPConfigComponent.data.servers;
    // Make a COPY of the data to use in the modal window
    NTPConfigComponent.modalData.servers = $.extend([], servers);

    NTPConfigComponent._drawServerSelector();
};

NTPConfigComponent._drawServerSelector = function() {
    var sel = $('#select_ntp_servers');
    var config = NTPConfigComponent.data.servers;

    sel.empty();

    $.each(config, function(i, val) {
        sel.append( $("<option></option>")
                        .attr("value", val.id)
                        .prop("selected", val.selected)
                        .text(val.text) );
    });

    sel.select2( { 
        placeholder: NTPConfigComponent.placeholder,
    });
    //NTPConfigComponent.select2Set = true;
    //NTPConfigComponent.closeEventSet = true;
    if (! NTPConfigComponent.closeEventSet ) {
        sel.on('select2:unselect', function(e) {
                var unselectedName = e.params.data.text;
        });
        NTPConfigComponent.closeEventSet = true;
    }
    
};

NTPConfigComponent.save = function() {
    var sel = $('#select_ntp_servers');
    var options = $('#select_ntp_servers option');
    var selected = sel.val(); 
    var data = {};
    data.enabled_servers = {};
    data.disabled_servers = {};
    data.deleted_servers = NTPConfigComponent.data.serversToRemove;
    var servers = NTPConfigComponent.data.servers;

    var enabled = {};
    var disabled = {};

    for( var i in options ) {
        if ( isNaN( i ) ) {
            continue;
        }
        var option = options[i];
        if ( typeof $(option) == "undefined" ) {
            break;
        }
        var hostname = $(option).val();
        var selected = $(option).prop("selected");
        var row = {};
        var index = NTPConfigComponent.objectFindByKey(servers, 'id', hostname);
        if (index !== null) {
            var description = servers[i].description;
        }
        row[hostname] = description;
        if (selected) {
            enabled[hostname] = description;
            //enabled.push(hostname);
        } else {
            //disabled.push(hostname);
            disabled[hostname] = description;
        }
    };

    data.enabled_servers = enabled;
    data.disabled_servers = disabled;

    HostAdminStore.saveNTP( {data: data} );
    NTPConfigComponent._initGlobalData();

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
     * Utility function to format the NTP server name as
     * Hostname (Description)
    */
    var server = '';
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
            NTPConfigComponent.listHeight = listHeight;
};

NTPConfigComponent._setListHeight = function() {
            $('#ntp_list').height(NTPConfigComponent.listHeight);

};

NTPConfigComponent._setEventHandlers = function() {
    var manage_link = $("#manage-available-servers-link");

    // If we can't find the template or the container, we can't display anything
    if (("#ntp-modal-server-list-template").length == 0 || $("#ntp-modal-server-list").length == 0 ) {
        return;
    }

    // Manage Available Servers Link
    manage_link.click( function(e) {
        NTPConfigComponent._getContainerHeight();
        NTPConfigComponent._displayModalServerList();
    });

    var closest_link = $('#get-closest-servers-link');
    closest_link.click( function(e) {
        NTPClosestStore.retrieveNTPClosest();
        $('#loading-modal').addClass('ntpclosest');
        $('#loading-modal h3 span.loading_text').text(' Selecting Closest Servers -- this may take up to 1 minute ...');
        $('#loading-modal').foundation('reveal', 'open');
        e.preventDefault();

    });

    /*
     * MODAL WINDOW EVENTS
    */

    // Add Server Button
    // Applies the changes to the main server list
    var add_button_el = $('#ntp_server_add_button');
    add_button_el.click(function(e) {
        //var data = {};
        //data.servers = NTPConfigComponent.modalData.servers;
        var add_hostname_el = $('#ntp_server_add_hostname');
        var add_description_el = $('#ntp_server_add_description');
        var add_hostname = add_hostname_el.val();
        var add_description = add_description_el.val() || '';

        if ( NTPConfigComponent._isDuplicate( add_hostname ) ) {
            $('#ntp_server_duplicate').show();
            return;

        } else {
            $('#ntp_server_duplicate').hide();

        }

        
        if (typeof add_hostname != undefined && add_hostname != '') {
            add_hostname_el.val('');
            add_description_el.val('');

            NTPConfigComponent._addServerModal(add_hostname, add_description);
            NTPConfigComponent._showSaveBar();
        }
    });

    // Cancel Modal Window button
    // Reverts the changes and does not affect the main server list
    var cancel_button_el = $('#ntp_modal_cancel_button');
    cancel_button_el.click(function(e) {
        var add_hostname_el = $('#ntp_server_add_hostname');
        var add_description_el = $('#ntp_server_add_description');
        add_hostname_el.val('');
        add_description_el.val('');
        NTPConfigComponent._initModalData();
        NTPConfigComponent.modalData.servers = $.extend([], NTPConfigComponent.data.servers);
        NTPConfigComponent._displayModalServerList();
        $('#ntpModal').foundation('reveal', 'close');
        e.preventDefault();
    });

    /*
     * MAIN UI EVENTS
    */

    var ok_button_el = $('#ntp_modal_ok_button');
    ok_button_el.click(function(e) {
        // If the OK button is pushed, and they have entered a server in the Add box,
        // we add it to the list, as they probably meant to click Add first.
        $('#ntp_server_add_button').click();

        // Now, add/remove servers from the user's changes in the modal 
        // to the list, and select the new ones in the Select2 box
        $.each(NTPConfigComponent.modalData.serversToAdd, function(i, val) {
            NTPConfigComponent._addServer(val.id, val.description);

        });

        // Remove the removed servers
        $.each(NTPConfigComponent.modalData.serversToRemove, function(i, val) {
            NTPConfigComponent._removeServer(val);
        });




        NTPConfigComponent._initModalData();
        NTPConfigComponent._setServers();
        $('#ntpModal').foundation('reveal', 'close');

    });

};

NTPConfigComponent._isDuplicate = function (hostname) {
    var valid = false;
    if ( hostname == "" || (typeof hostname == "undefined") ) {
        return valid;
    }
    var data = NTPConfigComponent.modalData.servers;
    var servers = {};
    for(var i in NTPConfigComponent.modalData.servers ) {
        var server = NTPConfigComponent.modalData.servers[i].id;
        servers[ server ] = 1; 
    }
    if ( hostname in servers ) {
        // This server is already in the list
        valid = true;

    }


    return valid;

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
    // Handle delete button click within modal window
    // Adds the server to delete to a list for later processing and
    // removes the server from the display
    var delete_buttons_el = $('#ntp_list a.ntp-list__delete');
    delete_buttons_el.click( function (e) {
        var hostname = e.target.getAttribute("server");
        NTPConfigComponent._removeServerModal(hostname);
        NTPConfigComponent._showSaveBar();
        e.preventDefault();
    });
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
    NTPConfigComponent.modalData.serversToAdd.push(row);
    NTPConfigComponent._displayModalServerList();
};

NTPConfigComponent._removeServerModal = function( hostname ) {
    var servers = NTPConfigComponent.modalData.servers;

    // Find hostname in 'servers' object (find a row where id: == hostname)
    var index = NTPConfigComponent.objectFindByKey(servers, 'id', hostname);

    // Delete the item from the array
    servers.splice(index, 1);

    // Only do this if the hostname was found in the list
    if ( index !== null ) {
        NTPConfigComponent.modalData.serversToRemove.push( hostname );
    }
    NTPConfigComponent._showSaveBar();
    NTPConfigComponent._displayModalServerList();
};

NTPConfigComponent.objectFindByKey = function(arr, key, value) {
    for (var i = 0; i < arr.length; i++) {
        if (arr[i][key] === value) {
            return i;
        }
    }
    return null;
}

NTPConfigComponent._addServer = function ( hostname, description) {
    var data = NTPConfigComponent.data.servers;
    var row = {};
    row.id = hostname;
    row.description = description || "";
    row.text = NTPConfigComponent._formatServer(hostname, description);
    row.selected = true;
    data.unshift(row);
    NTPConfigComponent.data.serversToAdd.push(row);

};

NTPConfigComponent._removeServer = function ( hostname ) {
    var data = NTPConfigComponent.data.servers;
    var index = NTPConfigComponent.objectFindByKey(data, 'id', hostname);
    if (index !== null) {
        data.splice(index, 1);
        NTPConfigComponent.data.serversToRemove.push(hostname);
    }
    var data = NTPConfigComponent.data.serversToAdd;
    var index = NTPConfigComponent.objectFindByKey(data, 'id', hostname);
    data.splice(index, 1);
};

NTPConfigComponent._getClosest = function( topic ) {
    $('#loading-modal').foundation('reveal', 'close');
    $('#loading-modal').removeClass('ntpclosest');
    var data = NTPClosestStore.getNTPClosest();
    var selected = [];
    $.each(data.selected, function(i, val) {
        selected.push(val.address);
    });
    var sel = $('#select_ntp_servers');
    NTPConfigComponent._selectServers(selected);

};

/* 
 * Takes an array of hostnames; changes the selected servers to match only those hosts
*/

NTPConfigComponent._selectServers = function ( selection ) {
    var data = NTPConfigComponent.data.servers;
    var sel = $('#select_ntp_servers');

    $.each(data, function(i, val) {
        //var result = $.grep( servers, function(e) {
        //var index = NTPConfigComponent.objectFindByKey(selection, 'id', hostname);
        var index = selection.indexOf(val.id);
        if (index > -1) {
            val.selected = true;
        } else {
            val.selected = false;
        }
    });
    NTPConfigComponent._setServers();
    NTPConfigComponent._showSaveBar();
};

NTPConfigComponent._saveSuccess = function( topic, message ) {
    Dispatcher.publish(NTPConfigComponent.formNTPSuccessTopic, message);
};

NTPConfigComponent._cancel = function() {
    Dispatcher.publish(NTPConfigComponent.formNTPCancelTopic);
    Dispatcher.publish(NTPConfigComponent.info_topic);

};

NTPConfigComponent._showSaveBar = function() {
    Dispatcher.publish(NTPConfigComponent.formChangeTopic);
};



NTPConfigComponent.initialize();
