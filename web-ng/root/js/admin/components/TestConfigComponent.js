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

    /*
    $('#testAddTestButton').click( function(e) {
        e.preventDefault();
        TestConfigComponent.showTestAddTestModal();
    });
    */

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

TestConfigComponent.showTestAddTestModal = function( ) {
    var data = TestConfigComponent.data;
    var config_template = $("#testAddTestTemplate").html();
    var template = Handlebars.compile( config_template );
    var config_modal = template( data );
    $("#testAddTestContainer").html(config_modal);
    $('#test-add-test-modal').foundation('reveal', 'open');


    $('#testAddTestOKButton').click( function( e ) {
        e.preventDefault();

        // take some action to save the user input here
        //var host = TestConfigComponent._getUserHostToAddInfo();
        //var modified = TestConfigComponent._getUserTestsToAddHostInfo( host );

        // close the modal window
        $('#test-add-test-modal').foundation('reveal', 'close');

        /*
        if ( modified ) {
            SharedUIFunctions._showSaveBar();
        }
        */

        // Fire the testConfigStore topic, signalling the data has changed
        //Dispatcher.publish( TestConfigStore.topic );
    });


    $('#testAddTestCancelButton').click( function( e ) {
        e.preventDefault();
        $('#test-add-test-modal').foundation('reveal', 'close');
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
    var test_table = template(data);
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


     $('#configure-test-modal').foundation('reveal', 'open', {
        //root_element: 'form',
    });

     setTimeout(function(){
           //$('#someid').addClass("done");
           TestConfigComponent._setValidationEvents();
     }, 200);


    //$(document).foundation('abide', 'reflow');
    $(document).foundation('abide', 'events');

    return false;
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
        //TestConfigComponent.submitTestConfigForm( self.testConfig );

    });


    //$(document).foundation('abide', 'events');
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
            //StickySaveBar.showValidationError();
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
            exists = true;
            return false;
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


TestConfigComponent.addTestMember = function(e) {
    e.preventDefault();
    var test = TestConfigComponent.testConfig;
    var members = test.members;
    var memberTemplate = TestConfigComponent.memberTemplate;

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
    var updated = TestConfigComponent._updateExistingMemberByAddress( settings );

    if ( !updated ) {
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
    }

    $('#new-host-name').val('');
    $('#new-host-description').val('');

    return false;
};

TestConfigComponent._cancel = function() {
    StickySaveBar._formCancel();
    TestConfigStore.revertTestSettings();
};

TestConfigComponent.initialize();
