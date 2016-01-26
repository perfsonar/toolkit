// make sure jquery and Dispatcher load before this

var TestConfigComponent = {
    testConfigTopic: 'store.change.test_config',
    data: null,
    dataSet: false,
    expandedDataGroups: {},
    tableView: 'byHost',
    interfaces: [],
    interfacesSet: false,
};

TestConfigComponent.initialize = function() {
    //$('#loading-modal').foundation('reveal', 'open');
    Dispatcher.subscribe( TestConfigComponent.testConfigTopic, TestConfigComponent._setTestData );
    Dispatcher.subscribe( HostDetailsStore.detailsTopic, TestConfigComponent._setHostData );


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

    $("div.config__form").on("click", ".cb_test_enabled", function(e, f) {
        //console.log('!!!');
        //e.preventDefault();
        // use $(this).data("test-id");
        TestConfigComponent.toggleTestEnabled( this );
    });
    $("div.config__form").on("click", "a#viewByHost", function(e) {
        e.preventDefault();
        TestConfigComponent._showTable('byHost');
    });
    $("div.config__form").on("click", "a#viewByTest", function(e) {
        e.preventDefault();
        TestConfigComponent._showTable('byTest');
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

TestConfigComponent._showTable = function( tableView ) {
    if ( typeof (tableView) != 'undefined' ) {
        TestConfigComponent.tableView = tableView;
    }
    tableView = TestConfigComponent.tableView;
    if (tableView == 'byHost') {
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
    if ( tableView == undefined ) {
        tableView = 'byHost';
    }

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

    TestConfigComponent._showTable( tableView );
};


TestConfigComponent._loadInterfaceWhenReady = function() {
    if ( TestConfigComponent.dataSet && TestConfigComponent.interfacesSet ) {
        TestConfigComponent._showConfig();
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

    //$(':checkbox').each(function () { this.checked = !this.checked; });
    var self = this;
    $.each( tests,  function( i, j ) {
        //console.log( "i", i, "j", j, "test", test);
        //console.log('self', self);
        //if ( $(j).data("test-id") == test ) {
            //if (i == 0) {
            //    checked = !$(j).prop("checked");
            //}
            //$(j).prop("checked", checked);
            //if ($(self)
            if ( !$( self.clickedTest ).is( $(j) ) ) {
                $(j).prop("checked", checked );
            } else {
                //$(j).prop("checked", !checked );

            }
        //}
    });


};

TestConfigComponent.showTestConfigModal = function( testID ) {
    console.log('test config testID', testID);
    var data = TestConfigStore.data;
    console.log('test config data', data);
    var testConfig = TestConfigStore.getTestConfig( testID );
    testConfig.interfaces = TestConfigComponent.interfaces;
    console.log("test config", testConfig);

    var memberTemplate = Handlebars.compile($("#member-partial").html());
    TestConfigComponent.memberTemplate = memberTemplate;
    //Handlebars.registerPartial("member", $("#member-partial").html());
    Handlebars.registerPartial("member", memberTemplate);

    var config_template = $("#configureTestTemplate").html();
    var template = Handlebars.compile( config_template );
    var config_modal = template( testConfig );
    $("#configureTestContainer").html(config_modal);
    $('#configure-test-modal').foundation('reveal', 'open');
    //$('#myModal').foundation('reveal', 'close');
    $('#testEnabledSwitch').change( function() {
        TestConfigComponent._setSwitch( '#testEnabledSwitch' ); 
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
        console.log('self', self);
        console.log('testID: ' + testID);
        console.log('e', e);
        TestConfigComponent._getUserValues( self.testConfig );
        console.log('testConfig after ok', testConfig);

        console.log('publishing reloadTopic ' + TestConfigStore.reloadTopic);

        e.preventDefault();
        $('#configure-test-modal').foundation('reveal', 'close');
        console.log("data after ok", TestConfigComponent.data);
        console.log("TestConfigStore data after ok", TestConfigStore.data);
        console.log("testconfigadminstore data after ok", TestConfigAdminStore.data);

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

TestConfigComponent._getUserValues = function( testConfig ) {
    var testEnabled = $('#testEnabledSwitch').prop("checked");
    var testID = testConfig.test_id;
    var test = TestConfigStore.getTestByID( testID );
    //testConfig.disabled = !testEnabled;
    //TestConfigStore.setTestEnabled( test, testEnabled);
    console.log('test enabled', testEnabled);
    var testDescription = $("#test-name").val();
    console.log('test description', testDescription);
    //TestConfigStore.setTestDescription( test, testDescription );
    var interface = $("#interfaceSelector").val();
    console.log('interface: ' + interface);
    //TestConfigStore.setInterface( test, interface);
    var settings = {};
    settings.enabled = testEnabled;
    settings.description = testDescription;
    settings.interface = interface;

    switch ( test.type ) {
        case 'bwctl/throughput':
            console.log('setting bwctl settings ...');
            var protocol = $('#protocolSelector').val();
            console.log('protocol: ' + protocol);
            settings.protocol = protocol;

            var autotuning = $('#useAutotuningSwitch').val();
            settings.autotuning = autotuning;
            console.log('autotuning: ' + autotuning);

            var tos_bits = $('#tosBits').val();
            settings.tos_bits = tos_bits;
            console.log('tos_bits: ' + tos_bits);

            var window_size = $('#windowSize').val();
            settings.window_size = window_size;

            console.log('settings', settings);
            break;        
    }


    TestConfigStore.setTestSettings( testID, settings );
    console.log('test config after setTestSettings', test);
};

TestConfigComponent._setSwitch = function( elID ) {
    var checkbox_el = $( elID );
    console.log('elID', elID);
    var checked = checkbox_el.prop('checked');
    var label = SharedUIFunctions.getLabelText(checked);
    $("span[for='" + checkbox_el.attr("id") + "']").text(label);
    //var label_el = checkbox_el.next('.switch_label' )
    //label_el.text(label);
};

TestConfigComponent.removeTestMember = function( memberID ) {
    var row = $('tbody.test-members tr.subrow[member_id=' + memberID + ']');
    row.remove();
    //e.preventDefault();
    //var dataGroup = $(this).attr("data-group");
    //var el = $(".js-subrow[data-group=" + dataGroup + "]");
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
    var id = TestConfigStore.generateMemberID( test );

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

TestConfigComponent.initialize();
