// make sure jquery and Dispatcher load before this

var TestConfigComponent = {
    testConfigTopic: 'store.change.test_config',
    testConfigReloadTopic: 'store.change.test_config_reload',
    saveTestConfigTopic: 'store.change.test_config.save',
    saveTestConfigErrorTopic: 'store.change.test_config.save_error',
    formSubmitTopic:    'ui.form.submit',
    data: null,
    dataSet: false,
    expandedDataGroups: {},
    tableView: 'test',
    interfaces: [],
    interfacesSet: false,
    testConfig: null,
    placeholder: 'Please select a community',
};

TestConfigComponent.initialize = function() {
    $('#loading-modal').foundation('reveal', 'open');
    Dispatcher.subscribe(TestConfigComponent.saveTestConfigTopic, SharedUIFunctions._saveSuccess);
    Dispatcher.subscribe(TestConfigComponent.saveTestConfigErrorTopic, SharedUIFunctions._saveError);

    Dispatcher.subscribe( TestConfigComponent.testConfigTopic, TestConfigComponent._setTestData );
    Dispatcher.subscribe( HostDetailsStore.detailsTopic, TestConfigComponent._setHostData );

    Dispatcher.subscribe( CommunityHostsStore.topic, TestConfigComponent._setHostsFromCommunity );

    // cancel button clicked 
    $('#admin_info_cancel_button').click( TestConfigComponent._cancel );

    // Get the view setting
    var view = SharedUIFunctions.getUrlParameter( 'view' );
    if ( typeof view != 'undefined' && view == 'test' ) {
        TestConfigComponent.tableView = 'test';
    }

    Handlebars.registerHelper('formatHostCount', function(count) {
        var ret;
        if ( count == undefined ) {
            ret = '';
        } else {
            ret = count + ' host';
            ret += ( count != 1 ? 's' : '' );
        }
        return ret;
    });

    Handlebars.registerHelper('formatTestCount', function(count) {
        var ret;
        if ( count == undefined ) {
            ret = '';
        } else {
            ret = count + ' test';
            ret += ( count != 1 ? 's' : '' );
        }
        return ret;
    });

    // Hide subrows on load
    $(".js-subrow").hide();

    $('#testAddHostButton').click( function(e) {
        e.preventDefault();
        TestConfigComponent.showTestAddHostModal();
    });


    $("div.config__form").on("click", ".cb_test_enabled", function(e, f) {
        TestConfigComponent.toggleTestEnabled( this );
    });
    var default_view = 'test';
    $("div.config__form").on("click", "a#viewByHost", function(e) {
        e.preventDefault();
        TestConfigComponent.tableView = 'host';
        SharedUIFunctions.addQueryStringParameter( 'view', TestConfigComponent.tableView, true, default_view );
        TestConfigComponent._showTable( );
    });
    $("div.config__form").on("click", "a#viewByTest", function(e) {
        e.preventDefault();
        TestConfigComponent.tableView = 'test';
        SharedUIFunctions.addQueryStringParameter( 'view', TestConfigComponent.tableView, true, default_view );
        TestConfigComponent._showTable( );
    });
    // Click to collapse/expand rows
    $("div#testConfigContainer").on("click", ".js-row", function(e) {
        e.preventDefault();
        var dataGroup = $(this).attr("data-group");
        var el = $(".js-subrow[data-group=" + dataGroup + "]");
        el.toggle();
        var display = el.css('display');
        if ( display == "none" ) {
            delete TestConfigComponent.expandedDataGroups[ dataGroup ];
        } else {
            TestConfigComponent.expandedDataGroups[ dataGroup ] = 1;
        }
    });

    // Add new host to test members
    $(".js-add-new-host").click(function(e) {
        e.preventDefault();
        $("tbody.test-members").append('<tr class="subrow subrow--content"><td><input type="text"></td><td><input type="text"></td><td><label class="inline-label">IPv4</label> <input type="checkbox"></td><td><label class="inline-label">IPv6</label> <input type="checkbox"></td><td><a href="#"><i class="fa fa-trash"></i></a></td>');
        $(".js-add-new-wrapper").hide();
        $(".new-host-save").show();
    });

};

TestConfigComponent.save = function(e) {
    Dispatcher.publish(TestConfigComponent.formSubmitTopic);
    TestConfigAdminStore.save(TestConfigStore.data);
};

TestConfigComponent.showRows = function(e) {
    //e.preventDefault();
    $(".js-subrow").show();
    return false;
};

TestConfigComponent.hideRows = function(e) {
    //e.preventDefault();
    $(".js-subrow").hide();
    return false;
};

TestConfigComponent._showTable = function( ) {
    tableView = TestConfigComponent.tableView;
    if (tableView == 'host') {
        $("#testConfigContainer .config-table-by-test").hide();
        $("#testConfigContainer .config-table-by-host").show();
        $("a#viewByHost").addClass('color-disabled');
        $("a#viewByTest").removeClass('color-disabled');

    } else {
        $("#testConfigContainer .config-table-by-test").show();
        $("#testConfigContainer .config-table-by-host").hide();
        $("a#viewByHost").removeClass('color-disabled');
        $("a#viewByTest").addClass('color-disabled');
    }
};

TestConfigComponent._buildTable = function() {
    var tableView = TestConfigComponent.tableView;
    var data = TestConfigComponent.data;
    if (data === null) {
        return;
    }
    /* We *shouldn't* need this anymore since it happens in the constructor
    if ( tableView == undefined ) {
        tableView = 'host';
    }
    */

    for (var i in Object.keys(data.testsByHost) ) {
        var host = data.testsByHost[i];
        host.expanded = TestConfigComponent.expandedDataGroups[ host.host_id ] == 1;
    }
    data.interfaces = TestConfigComponent.interfaces;

    var host_template = $("#testConfigByHostTableTemplate").html();
    var template = Handlebars.compile(host_template);
    var host_table = template(data);
    $("#testConfigContainer").html(host_table);

    var test_template = $("#testConfigByTestTableTemplate").html();
    template = Handlebars.compile(test_template);
    var test_table = template(data);
    $("#testConfigContainer").append(test_table);

    TestConfigComponent._showTable( );
};


TestConfigComponent._loadInterfaceWhenReady = function() {
    if ( TestConfigComponent.dataSet && TestConfigComponent.interfacesSet ) {
        TestConfigComponent._showConfig();
        $('#loading-modal').foundation('reveal', 'close');
    }
};

TestConfigComponent._setTestData = function() {
    var data = {};
    data.testsByHost = TestConfigStore.getTestsByHost();
    data.testsByTest = TestConfigStore.getTestConfigurationFormatted();
    TestConfigComponent.data = data;
    TestConfigComponent.dataSet = true;
    TestConfigComponent._showStatusMessages();
    TestConfigComponent._loadInterfaceWhenReady();
};

TestConfigComponent._showStatusMessages = function() {
    var status = TestConfigStore.data.status;
    var network_percent_used = status.network_percent_used;
    if ( !isNaN( parseInt( network_percent_used ) ) ) {
        $('#network_percent_used').text( network_percent_used );
        $('#throughput_percent_message').show();
    }
    var throughput_tests = status.throughput_tests;
    var owamp_tests = status.owamp_tests;
    if ( throughput_tests > 0 && owamp_tests > 0 ) {
        $('#throughput_latency_message').show();
    }


};

TestConfigComponent._setHostData = function() {
    TestConfigComponent.interfaces = HostDetailsStore.getHostInterfaces();
    TestConfigComponent.interfacesSet = true;
    TestConfigComponent._loadInterfaceWhenReady();
};

TestConfigComponent._showConfig = function( topic ) {
    TestConfigComponent._destroyTable();

    // ** Test config tables **
    TestConfigComponent._buildTable( );

};

TestConfigComponent._destroyTable = function() {
    $("#testConfigContainer").empty();
};

TestConfigComponent.toggleTestEnabled = function( clickedThis ) {
    var testID = $(clickedThis).data("test-id");
    var test = $('#' + testID);
    var tests = $(".cb_test_enabled[data-test-id='" + testID + "']");
    this.clickedTest = clickedThis;
    var checked = $( this.clickedTest ).prop("checked");
    if ( checked ) {
        TestConfigStore.setTestEnabled( testID, 1 );
    } else {
        TestConfigStore.setTestEnabled( testID, 0 );
    }

    var self = this;
    $.each( tests,  function( i, j ) {
        if ( !$( self.clickedTest ).is( $(j) ) ) {
            $(j).prop("checked", checked );
        } else {
        }
    });


};

TestConfigComponent.showTestAddHostModal = function( ) {
    var data = TestConfigComponent.data;
    var config_template = $("#testAddHostTemplate").html();
    var template = Handlebars.compile( config_template );
    var config_modal = template( data );
    $("#testAddHostContainer").html(config_modal);
    $('#test-add-host-modal').foundation('reveal', 'open');


    var test_template = $("#testConfigByTestTableTemplate").html();
    template = Handlebars.compile(test_template);
    var testsByTest = [];
    for(var i in data.testsByTest) {
        var row = data.testsByTest[i];
        if ( !row.editable ) {
            continue;
        }
        testsByTest.push(row);

    }
    var editableData = {};
    editableData.testsByTest = testsByTest;
    var test_table = template(editableData);
    $("#testAddHostTableContainer").html(test_table);

    $("#testAddHostTableContainer .test_actions").hide();
    $("#testAddHostTableContainer .test_add").show();

    $('#testAddHostOKButton').click( function( e ) {
        e.preventDefault();
        var host = TestConfigComponent._getUserHostToAddInfo();
        var modified = TestConfigComponent._getUserTestsToAddHostInfo( host );
        $('#test-add-host-modal').foundation('reveal', 'close');

        if ( modified ) {
            SharedUIFunctions._showSaveBar();
        }

        // Fire the testConfigStore topic, signalling the data has changed
        Dispatcher.publish( TestConfigStore.topic );
    });

    $('#testAddHostCancelButton').click( function( e ) {
        e.preventDefault();
        $('#test-add-host-modal').foundation('reveal', 'close');
    });

};

TestConfigComponent.showTestConfigModal = function( testID ) {
    var data = TestConfigStore.data;
    var newTest = ( typeof testID  == 'undefined' );
    var testConfig;
    if ( newTest ) {
        data = {};
        testConfig = {};
        testConfig.editable = true;
        testConfig.added_by_mesh = false;
    } else {
        testConfig = TestConfigStore.getTestConfig( testID );

    }
    testConfig.newTest = newTest;

    // if they are adding a test, testID will be undefined
    testConfig.interfaces = TestConfigComponent.interfaces;

    var config_modal_template = $("#configureTestModalContainerTemplate").html();
    var template = Handlebars.compile( config_modal_template );
    $("#configureTestContainer").html( template() );

    TestConfigComponent.testConfig = testConfig;

    TestConfigComponent._drawConfigForm( );

    TestConfigComponent._showAddHostByCommunity( 'testConfigAddHostByCommunityContainer' );


     $('#configure-test-modal').foundation('reveal', 'open', {
        //root_element: 'form',
    });

     setTimeout(function(){
           //$('#someid').addClass("done");
           TestConfigComponent._setValidationEvents();
     }, 200);


    //$(document).foundation('abide', 'reflow');
    $(document).foundation('abide', 'events');
    $('#browseCommunitiesLink').click( function(e) {
        e.preventDefault();
        $('#testAddHostByCommunityDiv').show();
        $('#addHostManually').hide();
    });

    return false;
};

TestConfigComponent._showAddHostByCommunity = function( containerID ) {
    var container = $('#' + containerID );
    var data = {};


    var host_comm_template = $('#testAddHostByCommunityTemplate').html();
    var template = Handlebars.compile( host_comm_template );
    container.html( template(data) );
    TestConfigComponent._setAllCommunities();

    $('#addHostManuallyLink').click( function(e) {
        e.preventDefault();
        $('#testAddHostByCommunityDiv').hide();
        $('#addHostManually').show();
    });

};

TestConfigComponent._setAllCommunities = function( ) {
    /* Sets the global communities in the format {name: selected} */
    //TestConfigComponent.communities.all = {};
    var communities = CommunityAllStore.getAllCommunities().keywords;

    var sorted = [];
    var keys = Object.keys(communities).sort();
    for(var i in keys) {
        var row = {};
        row.id = i;
        row.text = keys[i];
        //row.selected = combined[ keys[i] ];
        sorted.push( row );
    }

    TestConfigComponent._selectCommunities( sorted );

};

TestConfigComponent._selectCommunities = function( communities ) {
    var sel = $('#testAddHostByCommunitySel');

    sel.empty(); // remove old options, if any

    sel.append( $("<option></option>") );
    $.each(communities, function(i, val) {
        sel.append( $("<option></option>")
                        .attr("value", val.text)
                        .prop("selected", false)
                        .text(val.text) );
    });

    sel.select2( {
        placeholder: "Select a community",
        allowClear: true,
        multiple: false,
    });
    /*
    TestConfigComponent.select2Set = true;

    if (! TestConfigComponent.closeEventSet ) {
        sel.on('select2:unselect', function(e) {
                var unselectedName = e.params.data.text;
        });
        TestConfigComponent.closeEventSet = true;
    }
    */

    sel.change( function(e) {
        var selectedCommunity = sel.val();
        if ( selectedCommunity != '' ) {
            $('#hosts-in-community-loading-modal').show();
            $('#community-hosts').hide();
            CommunityHostsStore.getHostByCommunity ( selectedCommunity, TestConfigComponent.testConfig.type );
        } else {
            TestConfigComponent._clearCommunityHosts();

        }
    });

};

TestConfigComponent._clearCommunityHosts = function() {
    var container_el = $('#hostsInCommunityTableContainer table tbody.test-members');
    container_el.empty();
    $('#community-hosts').hide();
};

TestConfigComponent._setHostsFromCommunity = function() {
    var data = CommunityHostsStore.getData();

    $('#hosts-in-community-loading-modal').hide();
    var hosts = TestConfigComponent._processHostData( data );

    var hosts_data = {};
    hosts_data.hosts = hosts;
    hosts_data.hostAction = "add";
    var container_el = $('#hostsInCommunityTableContainer');
    var template_el = $('#hostsInCommunityTableTemplate');
    var raw_template = template_el.html();
    var template = Handlebars.compile( raw_template );
    container_el.html( template( { hosts: hosts_data } ) );
    $('#hostsInCommunityTableContainer  a.member-add-button').click( TestConfigComponent.addTestMemberFromCommunity );

};

TestConfigComponent._processHostData = function ( data ) {
    var hosts = [];

    $.each(data.hosts, function(i, host) {
        var host_row = {};
        var address_formatted = '';
        var description = host.description || '';
        var name = host.name || '';
        var address = host.address;
        var ip = host.ip;
        var dns_name = host.dns_name;
        var test_ipv4 = host.ipv4;
        var test_ipv6 = host.ipv6;
        var port = host.port;
        if ( dns_name ) {
            address_formatted = dns_name;
            if ( ip ) {
                address_formatted += ' (' + ip + ')';
            }
        } else {
            address_formatted = ip;
        }
        host_row.test_ipv4 = ( test_ipv4 == 1 );
        host_row.test_ipv6 = ( test_ipv6 == 1 );
        host_row.name = name;
        host_row.description = description;
        host_row.address = address;
        host_row.dns_name = dns_name;
        host_row.ip = ip;
        host_row.address_formatted = address_formatted;
        host_row.port = port;
        hosts.push( host_row );

    });
    hosts.sort(function(a,b){
        if(a.address > b.address){ return  1 }
        if(a.address < b.address){ return -1 }
        return 0;
    });
    return hosts;
};

TestConfigComponent.deleteTestMember = function( testID, memberID ) {
    var testConfig = TestConfigStore.getTestConfig( testID );
    var choice = window.confirm('Do you really want to delete this host from the test "' + testConfig.description + '"? Your changes will not take effect until you click the Save button.');
    if ( choice ) {
        var success = TestConfigStore.deleteMemberFromTest( testID, memberID );
        if ( success ) {
            Dispatcher.publish( TestConfigStore.topic );
            SharedUIFunctions._showSaveBar();
        }
    }
    return false;
};

TestConfigComponent.deleteTest = function( testID ) {
    //var data = TestConfigStore.data;
    var testConfig = TestConfigStore.getTestConfig( testID );
    var description = testConfig.description;
    var choice = window.confirm('Do you really want to delete the test "' + testConfig.description + '"? Your changes will not take effect until you click the Save button.');
    if ( choice ) {
        var success = TestConfigStore.deleteTest( testID );
        if ( success ) {
            Dispatcher.publish( TestConfigStore.topic );
            SharedUIFunctions._showSaveBar();
        }
    }
    return false;
};

TestConfigComponent._drawConfigForm = function( ) {
    var testConfig = TestConfigComponent.testConfig;

    if ( testConfig.type ) {
        testConfig.defaults = $.extend( true, {}, TestConfigStore.data.defaults.type[ testConfig.type ] );
/*
        if ( ( typeof testConfig.parameters == "undefined" 
                || $.isEmptyObject(testConfig.parameters) )
                && newTest ) {
*/
        if ( testConfig.newTest ) {
            testConfig.parameters = $.extend( true, {}, testConfig.defaults );
        } else {
            testConfig.parameters = $.extend( true, {}, testConfig.defaults, testConfig.parameters );

        }
        TestConfigStore.setTypesToDisplay( testConfig );
    }
    testConfig.hostAction = 'update';
    var newTest = testConfig.newTest;
    var memberTemplate = Handlebars.compile($("#member-partial").html());
    TestConfigComponent.memberTemplate = memberTemplate;
    Handlebars.registerPartial("member", memberTemplate);


    var config_template = $("#configureTestTemplate").html();
    var template = Handlebars.compile( config_template );
    var config_modal = template( testConfig );
    $("#configure-test-modal").html(config_modal);



    $('#newTestTypeSel').change( function() {
        var type = $('#newTestTypeSel').val();
        testConfig.type = type;
        //TestConfigStore.setTypesToDisplay( testConfig );
        TestConfigComponent._drawConfigForm( );
        $(document).foundation('abide', 'events');
        TestConfigComponent._setValidationEvents();
        if ( type != '' ) {
            $('#configureTestForm .existing_test_type_only').show();
        } else {
            $('#configureTestForm .existing_test_type_only').hide();

        }

    });
    $('#testEnabledSwitch').change( function() {
        TestConfigComponent._setSwitch( '#testEnabledSwitch' );
    });
    if ( newTest ) {
        $('#configureTestForm .new_test_only').show();
        $('#configureTestForm .existing_test_type_only').hide();
        $('#addTestMemberPanel').show();
    } else {
        $('#configureTestForm .new_test_only').hide();
        $('#configureTestForm .existing_test_type_only').show();
    }
    $('#protocolSelector').change( function() {
        var protocol = $('#protocolSelector').val();
        if ( protocol == 'udp' ) {
            $('#udpBandwidthContainer').show();
        } else {
            $('#udpBandwidthContainer').hide();
        }
    });
    $('#useAutotuningSwitch').change( function() {
        TestConfigComponent._setSwitch( '#useAutotuningSwitch' );
        if ( $('#useAutotuningSwitch').prop('checked') ) {
            $('#windowSize').hide();
            $('#windowSize').removeAttr('required');
            $('#windowSize').removeAttr('pattern');
        } else {
            $('#windowSize').show();
            $('#windowSize').removeAttr('required');
            $('#windowSize').attr('pattern', 'positive_integer');
        }
    });

    TestConfigComponent._showAddHostByCommunity( 'testConfigAddHostByCommunityContainer' );

    $('#browseCommunitiesLink').click( function(e) {
        e.preventDefault();
        $('#testAddHostByCommunityDiv').show();
        $('#addHostManually').hide();
    });

    $('#advanced_traceroute_button').click( function( e ) {
        TestConfigComponent.toggle_advTraceroute(e);
    });

    $('#advanced_throughput_button').click( function( e ) {
        TestConfigComponent.toggle_advThroughput(e);
    });

    $('#advanced_ping_button').click( function( e ) {
        TestConfigComponent.toggle_advPing(e);
    });

    $('#advanced_owamp_button').click( function( e ) {
        TestConfigComponent.toggle_advOwamp(e);
    });

    $('#member_add_button').click( function( e ) {
        TestConfigComponent.addTestMember(e);
    });

    this.testConfig = testConfig;
    var self = this;
    $('#configureTestForm button.testConfigOKButton').click( function( e, testID ) {
        e.preventDefault();

        if ( $('#addTestMemberPanel').is(":visible") && $('#new-host-name').val() != '' ) {
            $('#member_add_button').click();
        }
        $('form#configureTestForm').submit();
    });

    $('#configureTestForm a.testConfigCancelButton').click( function( e ) {
        e.preventDefault();
        $('#configure-test-modal').foundation('reveal', 'close');
    });

    $('form#configureTestForm input').change(SharedUIFunctions._showSaveBar);

    $('form#configureTestForm select').change(SharedUIFunctions._showSaveBar);


    $('form#configureTestForm').submit(function( e ) {
        e.preventDefault();
    });

};

TestConfigComponent._setValidationEvents = function() {

    $('form#configureTestForm')
      .on('valid.fndtn.abide', function(e) {
            if(e.namespace != 'abide.fndtn') {
                return;
            }
            var testConfig = TestConfigComponent.testConfig;
            TestConfigComponent.submitTestConfigForm( );
            e.preventDefault();
            $('#configure-test-modal').foundation('reveal', 'close');
        })
        .on('invalid.fndtn.abide', function (e) {
            if(e.namespace != 'abide.fndtn') {
                return;
            }
	    // if there are errors in any advanced params, be sure the div is visible 
            TestConfigComponent._invalid_in_advanced();
        });

};

TestConfigComponent.submitTestConfigForm = function( ) {
    var testConfig = TestConfigComponent.testConfig;
    TestConfigComponent._getUserValues( testConfig );
    TestConfigComponent._getNewMemberConfig ( testConfig );

    $('#configure-test-modal').foundation('reveal', 'close');

    // Fire the testConfigStore topic, signalling the data has changed
    Dispatcher.publish( TestConfigStore.topic );

};

TestConfigComponent._getUserHostToAddInfo = function() {
    var host = {};
    var address = $('#test-add-host-address').val();
    host.address = address;
    var description = $('#test-add-host-description').val();
    host.description = description;
    return host;
};

TestConfigComponent._updateExistingMemberByAddress = function( settings ) {
    var address = settings.address;
    var testTable = $('table#test-members');
    var test = TestConfigComponent.testConfig;
    var exists = false;

    $('table#test-members > tbody > tr.member').each( function () {
        var row = $(this);
        var memberID = row.attr("member_id");
        var testID = test.test_id;
        var table_address = row.find('td.address').text();
        if ( table_address == address ) {
            var description = row.find('description');
            if ( typeof settings.description != 'undefined' && settings.description != '') {
                description.text( settings.descripton );
            }
            var test_ipv4 = row.find('input.test_ipv4');
            var test_ipv6 = row.find('input.test_ipv6');
            test_ipv4.prop('checked', settings.test_ipv4);
            test_ipv6.prop('checked', settings.test_ipv6);
            //exists = true;
            return true;
        }
    });
    return exists;
};

TestConfigComponent._getUserTestsToAddHostInfo = function( host ) {
    var tests = [];
    this.host = host;
    var self = this;
    var modified = false;
    var rows = $('#testAddHostTableContainer tbody tr').each( function(i) {
        var testID = $(this).attr("data-group");
        var address = self.host.address;
        var description = self.host.description;

        var ipv4 = $(this).find('input[type=checkbox].ipv4').first().prop("checked");
        var ipv6 = $(this).find('input[type=checkbox].ipv6').first().prop("checked");

        var member = {};
        member.member_id = TestConfigStore.generateMemberID( testID );
        member.address = address;
        member.description = description;
        member.test_ipv4 = ipv4;
        member.test_ipv6 = ipv6;

        if ( ipv4 || ipv6 ) { 
            TestConfigStore.addOrUpdateTestMember( testID, member );
            modified = true;
        }


    }); 
    return modified;

};

TestConfigComponent._getNewMemberConfig = function( test ) {
    var testTable = $('table#test-members');

    // Create a hash containing the member ids
    // we'll delete them from the hash as we update the values from the form
    // if we have any left over at the end, these have been deleted from the
    // form and need to be deleted from the backend
    this.existingMemberIDs = {};
    var existingMemberIDs = this.existingMemberIDs;
    for( var i in test.members ) {
        existingMemberIDs[ test.members[i].member_id ] = 1;
    }

    this.existingMemberIDs = existingMemberIDs;
    this.test = test;
    var self = this;
    var tableRows = $('table#test-members > tbody > tr.member').each( function () {
        var memberID = $(this).attr("member_id");
        var testID = self.test.test_id;
        var member = {};
        member.member_id = memberID;
        var row = $(this);
        var address = row.find('td.address').text();
        var description = row.find('input.description').val();

        var test_ipv4 = row.find('input.test_ipv4').prop('checked');
        var test_ipv6 = row.find('input.test_ipv6').prop('checked');

        member.address = address;
        member.description = description;
        member.test_ipv4 = test_ipv4;
        member.test_ipv6 = test_ipv6;

        TestConfigStore.addOrUpdateTestMember( testID, member );
        delete self.existingMemberIDs[ memberID ];
    });

    // If there are any existingMemberIDs left, these are nodes that were
    // in the config but NOT in the user input form (they need to
    // be deleted).
    $.each(existingMemberIDs, function( memberID, value ) {
        var success = TestConfigStore.deleteMemberFromTest( test.test_id, memberID );
    });

    TestConfigStore.setTestMembers( test.test_id, test );

};


TestConfigComponent._getUserValues = function( testConfig ) {
    var testConfig = TestConfigComponent.testConfig;
    var testEnabled = $('#testEnabledSwitch').prop("checked");
    var newTest = testConfig.newTest;
    var testID;
    var test;
    if ( newTest ) {
        //testID = TestConfigStore.generateTestID();
        test = TestConfigStore.addTest( testConfig );
        testID = test.test_id;

    } else {
        testID = testConfig.test_id;
        test = TestConfigStore.getTestByID( testID );

    }
    var testDescription = $("#test-name").val();
    var interface = $("#interfaceSelector").val();
    var settings = {};
    settings.enabled = testEnabled;
    settings.description = testDescription;
    settings.interface = interface;

    switch ( test.type ) {
        case 'bwctl/throughput':
            var protocol = $('#protocolSelector').val();
            settings.protocol = protocol;

            var autotuning = $('#useAutotuningSwitch').prop('checked');
            settings.autotuning = autotuning;

            var tos_bits = $('#tosBits').val();
            settings.tos_bits = tos_bits;

            var window_size = $('#windowSize').val();
            settings.window_size = window_size;

            var protocol = $('#protocolSelector').val();
            settings.protocol = protocol;

            if ( protocol == 'udp' ) {
                var udp_bandwidth = $('#udpBandwidth').val();
                settings.udp_bandwidth = udp_bandwidth;
            }

            var test_interval = TestConfigComponent._getDateValue( 'time-between-tests' );
            settings.test_interval = test_interval;

            var duration = TestConfigComponent._getDateValue( 'test-duration' );
            settings.duration = duration;

            break;
        case 'owamp':
            var packet_rate = $('#packetRateSel').val();
            settings.packet_rate = packet_rate;

            var packet_size = $('#packetSize').val();
            settings.packet_size = packet_size;

            break;
        case 'pinger':
            var test_interval = TestConfigComponent._getDateValue( 'time-between-tests' );
            settings.test_interval = test_interval;

            var packet_count = $('#packetsPerTest').val();
            settings.packet_count = packet_count;

            var packet_interval = $('#timeBetweenPackets').val();
            settings.packet_interval = packet_interval;

            var packet_size = $('#sizeOfTestPackets').val();
            settings.packet_size = packet_size;

            break;
        case 'traceroute':
            var test_interval = TestConfigComponent._getDateValue( 'time-between-tests' );
            settings.test_interval = test_interval;

            var tool = $('#toolSel').val();
            settings.tool = tool;

            var packet_size = $('#sizeOfTestPackets').val();
            settings.packet_size = packet_size;

            var first_ttl = $('#firstTTL').val();
            settings.first_ttl = first_ttl;

            var max_ttl = $('#maxTTL').val();
            settings.max_ttl = max_ttl;

            break;
    }


    TestConfigStore.setTestSettings( testID, settings );
};

// gets date value from an input and associated selector, which is assumed to have
// an id of inputID + '_units'
TestConfigComponent._getDateValue = function( inputID ) {
    inputID = '#' + inputID;
    var selectorID = inputID + '_units';
    var num = $( inputID ).val();
    var unit = $( selectorID ).val();

    var seconds = SharedUIFunctions.getSecondsFromTimeUnits( num, unit );
    return seconds;

};

TestConfigComponent._setSwitch = function( elID ) {
    var checkbox_el = $( elID );
    var checked = checkbox_el.prop('checked');
    var label = SharedUIFunctions.getLabelText(checked);
    $("span[for='" + checkbox_el.attr("id") + "']").text(label);
};

TestConfigComponent.removeTestMember = function( memberID ) {
    var row = $('tbody.test-members tr.subrow[member_id=' + memberID + ']');
    row.remove();
    SharedUIFunctions._showSaveBar();

    return false;
};


TestConfigComponent.addTestMemberFromCommunity = function( e ) {
    e.preventDefault();
    var button = $(this);
    var row = button.parent().parent();

    var settings = {};
    var hostname = row.find('td.address').text();
    var description = row.find('input.description').val();
    var new_host_ipv4 = row.find('input.test_ipv4').prop('checked');
    var new_host_ipv6 = row.find('input.test_ipv6').prop('checked');
    button.addClass('disabled');
    var settings = {};
    settings.address = hostname;
    settings.description = description;
    settings.test_ipv4 = new_host_ipv4;
    settings.test_ipv6 = new_host_ipv6;

    TestConfigComponent._addMemberWithSettings( settings );

};

TestConfigComponent._addMemberWithSettings = function(settings) {
    var test = TestConfigComponent.testConfig;
    var members = test.members;
    var memberTemplate = TestConfigComponent.memberTemplate;

    var updated = TestConfigComponent._updateExistingMemberByAddress( settings );

    if ( !updated ) {
        var id = TestConfigStore.generateMemberID( test.test_id );

        var newHost = {};
        newHost.address = settings.address;
        newHost.description = settings.description;
        newHost.test_ipv4 = settings.test_ipv4;
        newHost.test_ipv6 = settings.test_ipv6;
        newHost.member_id = id;

        var memberMarkup = memberTemplate( newHost );


        var table = $('table#test-members > tbody:last-child');

        table.append( memberMarkup );

        SharedUIFunctions._showSaveBar();
    }

};

TestConfigComponent.addTestMember = function(e) {
    e.preventDefault();

    var hostname = $('#new-host-name').val();
    if ( typeof hostname == 'undefined' || hostname == '' ) {
        return false;
    }
    var description = $('#new-host-description').val();
    var new_host_ipv4 = $('#new-ipv4').prop("checked");
    var new_host_ipv6 = $('#new-ipv6').prop("checked");
    var settings = {};
    settings.address = hostname;
    settings.description = description;
    settings.test_ipv4 = new_host_ipv4;
    settings.test_ipv6 = new_host_ipv6;

    TestConfigComponent._addMemberWithSettings( settings );


    $('#new-host-name').val('');
    $('#new-host-description').val('');

    return false;
};

TestConfigComponent._invalid_in_advanced = function(e) {
    // See if there are any errors in Advanced Parameter values.
    // If there are, be sure the Advanced Parameters div is visible.
    var invalid_fields = $('#configureTestForm').find('[data-invalid]');
    var invalid_in_advanced = 0;
    for (var i = 0; i < invalid_fields.length; i++) {
        var adv_div = $("#"+invalid_fields[i].id).parents('div.advanced_params');
        var adv_id = adv_div.attr('id');
        if (adv_id !== undefined) {
            adv_div.show();
            return true;
        }
    }
    return false;
};

// If there are errors, _invalid_in_advanced() will open the Advanced Params div.
// Allow it to be toggled (closed) only if there are no invalid entries.
TestConfigComponent.toggle_advTraceroute = function(e) {
    e.preventDefault(); 
    if (!TestConfigComponent._invalid_in_advanced()) {
        $('#advTracerouteDiv').toggle();
    }
};
TestConfigComponent.toggle_advThroughput = function(e) {
    e.preventDefault(); 
    if (!TestConfigComponent._invalid_in_advanced()) {
        $('#advThroughputDiv').toggle();
    }
};
TestConfigComponent.toggle_advPing = function(e) {
    e.preventDefault(); 
    if (!TestConfigComponent._invalid_in_advanced()) {
        $('#advPingDiv').toggle();
    }
};
TestConfigComponent.toggle_advOwamp = function(e) {
    e.preventDefault(); 
    if (!TestConfigComponent._invalid_in_advanced()) {
        $('#advOwampDiv').toggle();
    }
};

TestConfigComponent._cancel = function() {
    StickySaveBar._formCancel();
    TestConfigStore.revertTestSettings();
};

TestConfigComponent.initialize();
