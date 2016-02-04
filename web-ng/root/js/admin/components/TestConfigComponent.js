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
    tableView: 'host',
    interfaces: [],
    interfacesSet: false,
};

TestConfigComponent.initialize = function() {
    $('#loading-modal').foundation('reveal', 'open');
    Dispatcher.subscribe(TestConfigComponent.saveTestConfigTopic, SharedUIFunctions._saveSuccess);
    Dispatcher.subscribe(TestConfigComponent.saveTestConfigErrorTopic, SharedUIFunctions._saveError);

    Dispatcher.subscribe( TestConfigComponent.testConfigTopic, TestConfigComponent._setTestData );
    Dispatcher.subscribe( HostDetailsStore.detailsTopic, TestConfigComponent._setHostData );

    // cancel button clicked 
    $('#admin_info_cancel_button').click( TestConfigComponent._cancel );

    // Get the view setting
    var view = SharedUIFunctions.getUrlParameter( 'view' );
    console.log('view', view);
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
    $("div.config__form").on("click", "a#viewByHost", function(e) {
        e.preventDefault();
        TestConfigComponent.tableView = 'host';
        SharedUIFunctions.addQueryStringParameter( 'view', TestConfigComponent.tableView, true, 'host' );
        TestConfigComponent._showTable( );
    });
    $("div.config__form").on("click", "a#viewByTest", function(e) {
        e.preventDefault();
        TestConfigComponent.tableView = 'test';
        SharedUIFunctions.addQueryStringParameter( 'view', TestConfigComponent.tableView, true, 'host' );
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
    //SharedUIFunctions._showSaveBar();
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
        console.log('no data!');
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
    console.log('buildTable data', data);

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
    TestConfigComponent._loadInterfaceWhenReady();
};

TestConfigComponent._setHostData = function() {
    TestConfigComponent.interfaces = HostDetailsStore.getHostInterfaces();
    TestConfigComponent.interfacesSet = true;
    TestConfigComponent._loadInterfaceWhenReady();
};

TestConfigComponent._showConfig = function( topic ) {
    TestConfigComponent._destroyTable();

    //SharedUIFunctions._showSaveBar();

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
    console.log('add host data', data);
    var config_template = $("#testAddHostTemplate").html();
    var template = Handlebars.compile( config_template );
    var config_modal = template( data );
    $("#testAddHostContainer").html(config_modal);
    $('#test-add-host-modal').foundation('reveal', 'open');


    var test_template = $("#testConfigByTestTableTemplate").html();
    template = Handlebars.compile(test_template);
    var test_table = template(data);
    $("#testAddHostTableContainer").html(test_table);

    $("#testAddHostTableContainer .test_actions").hide();
    $("#testAddHostTableContainer .test_add").show();

    $('#testAddHostOKButton').click( function( e ) {
        console.log('cancel clicked');
        e.preventDefault();
        var host = TestConfigComponent._getUserHostToAddInfo();
        var modified = TestConfigComponent._getUserTestsToAddHostInfo( host );
        $('#test-add-host-modal').foundation('reveal', 'close');
        console.log("TestConfigStore data after ok", TestConfigStore.data);

        if ( modified ) {
            SharedUIFunctions._showSaveBar();
        }

        // Fire the testConfigStore topic, signalling the data has changed
        Dispatcher.publish( TestConfigStore.topic );
    });

    $('#testAddHostCancelButton').click( function( e ) {
        console.log('cancel clicked');
        e.preventDefault();
        $('#test-add-host-modal').foundation('reveal', 'close');
    });

};

TestConfigComponent.showTestConfigModal = function( testID ) {
    var data = TestConfigStore.data;
    console.log('test config data', data);
    var testConfig = TestConfigStore.getTestConfig( testID );
    testConfig.interfaces = TestConfigComponent.interfaces;
    console.log("test config", testConfig);

    var memberTemplate = Handlebars.compile($("#member-partial").html());
    TestConfigComponent.memberTemplate = memberTemplate;
    Handlebars.registerPartial("member", memberTemplate);

    var config_template = $("#configureTestTemplate").html();
    var template = Handlebars.compile( config_template );
    var config_modal = template( testConfig );
    $("#configureTestContainer").html(config_modal);
    $('#configure-test-modal').foundation('reveal', 'open');
    $('#testEnabledSwitch').change( function() {
        TestConfigComponent._setSwitch( '#testEnabledSwitch' ); 
    });
    $('#protocolSelector').change( function() {
        console.log('protocol changed');
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
            $('.window_size').hide();
        } else {
            $('.window_size').show();
        }
    });

    $('#member_add_button').click( function( e ) {
        TestConfigComponent.addTestMember(e);
    });


    this.testConfig = testConfig;
    var self = this;
    $('#testConfigOKButton').click( function( e, testID ) {
        console.log('ok clicked');
        TestConfigComponent._getUserValues( self.testConfig );
        TestConfigComponent._getNewMemberConfig ( self.testConfig );
        console.log('testConfig after ok', testConfig);

        e.preventDefault();
        $('#configure-test-modal').foundation('reveal', 'close');
        console.log("TestConfigStore data after ok", TestConfigStore.data);

        // Fire the testConfigStore topic, signalling the data has changed
        Dispatcher.publish( TestConfigStore.topic );
    });
    $('#testConfigCancelButton').click( function( e ) {
        console.log('cancel clicked');
        e.preventDefault();
        $('#configure-test-modal').foundation('reveal', 'close');
    });
    $('form#configureTestForm input').change(SharedUIFunctions._showSaveBar);
    $('form#configureTestForm select').change(SharedUIFunctions._showSaveBar);
    return false;
};

TestConfigComponent._getUserHostToAddInfo = function() {
    var host = {};
    var address = $('#test-add-host-address').val();
    host.address = address;
    var description = $('#test-add-host-description').val();
    host.description = description;
    console.log('host', host);
    return host;
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

        console.log('member', member);
       
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
        console.log('memberID', memberID);
        console.log('value', value);
        var success = TestConfigStore.deleteMemberFromTest( test.test_id, memberID );
        console.log('attempted to delete memberID: ' + memberID + ' success: ' + success);
    });

    console.log('test config before setTestMembers', test);
    TestConfigStore.setTestMembers( test.test_id, test );
    console.log('test config after setTestMembers', test);

};


TestConfigComponent._getUserValues = function( testConfig ) {
    var testEnabled = $('#testEnabledSwitch').prop("checked");
    var testID = testConfig.test_id;
    var test = TestConfigStore.getTestByID( testID );
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

    console.log('settings', settings);

    TestConfigStore.setTestSettings( testID, settings );
    console.log('test config after setTestSettings', test);
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
    console.log('elID', elID);
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

TestConfigComponent.addTestMember = function(e) {
    e.preventDefault();
    var test = this.testConfig;
    var memberTemplate = TestConfigComponent.memberTemplate;
    var hostname = $('#new-host-name').val();
    var description = $('#new-host-description').val();
    var new_host_ipv4 = $('#new-ipv4').prop("checked");
    var new_host_ipv6 = $('#new-ipv6').prop("checked");
    var id = TestConfigStore.generateMemberID( test.test_id );

    var newHost = {};
    newHost.address = hostname;
    newHost.description = description;
    newHost.test_ipv4 = new_host_ipv4;
    newHost.test_ipv6 = new_host_ipv6;
    newHost.member_id = id;

    var memberMarkup = memberTemplate( newHost );


    var table = $('table#test-members > tbody:last-child');

    table.append( memberMarkup );

    $('#new-host-name').val('');
    $('#new-host-description').val('');

    return false;
};

TestConfigComponent._cancel = function() {
    StickySaveBar._formCancel();
    TestConfigStore.revertTestSettings();
};

TestConfigComponent.initialize();
