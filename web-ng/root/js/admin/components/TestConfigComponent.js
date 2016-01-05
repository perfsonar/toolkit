// make sure jquery and Dispatcher load before this

var TestConfigComponent = {
    testConfigTopic: 'store.change.test_config',
    data: null,
    expandedDataGroups: {},
    tableView: 'byHost',
};

TestConfigComponent.initialize = function() {
    //$('#loading-modal').foundation('reveal', 'open');
    Dispatcher.subscribe( TestConfigComponent.testConfigTopic, TestConfigComponent._showConfig );

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

        console.log('dataGroup ' + dataGroup);
        console.log('expandedDataGroups', TestConfigComponent.expandedDataGroups );
        //TestConfigComponent._showConfig();
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

TestConfigComponent._showConfig = function( topic ) {
    console.log('Test Config Topic received, showing config ...');

    TestConfigComponent._destroyTable();

    SharedUIFunctions._showSaveBar();    

    var data = {};
    data.testsByHost = TestConfigStore.getTestsByHost();
    data.testsByTest = TestConfigStore.getTestConfiguration();
    TestConfigComponent.data = data;
    //console.log('all test data', data );

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
        TestConfigStore.setTestEnabled( testID, true );
    } else {
        TestConfigStore.setTestEnabled( testID, false );
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
    console.log("test config", testConfig);
    var config_template = $("#configureTestTemplate").html();
    var template = Handlebars.compile( config_template );
    var config_modal = template( testConfig );
    $("#configureTestContainer").html(config_modal);
    $('#configure-test-modal').foundation('reveal', 'open');
    //$('#myModal').foundation('reveal', 'close');

};

TestConfigComponent.initialize();
