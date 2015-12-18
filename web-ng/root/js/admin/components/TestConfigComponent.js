// make sure jquery and Dispatcher load before this

var TestConfigComponent = {
    testConfigTopic: 'store.change.test_config',
    data: null,
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
        $(".js-subrow[data-group="+$(this).attr("data-group")+"]").toggle();
    });

    // Add new host to test members
    $(".js-add-new-host").click(function(e) {
        e.preventDefault();
        $("tbody.test-members").append('<tr class="subrow subrow--content"><td><input type="text"></td><td><input type="text"></td><td><label class="inline-label">IPv4</label> <input type="checkbox"></td><td><label class="inline-label">IPv6</label> <input type="checkbox"></td><td><a href="#"><i class="fa fa-trash"></i></a></td>');
        $(".js-add-new-wrapper").hide();
        $(".new-host-save").show();
    });

   
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
    
TestConfigComponent._buildTable = function( tableView ) {
    var data = TestConfigComponent.data;
    if (data === null) {
        console.log('no data!');
        return;
    }
    if ( tableView == undefined ) {
        tableView = 'byHost';
    }
    console.log('tableView', tableView);

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

TestConfigComponent._showConfig = function( topic, b ) {
    console.log('Test Config Topic received, showing config ...');
    console.log('topic,', topic, 'b', b);
    console.log('testconfigcomponent TestConfigStore.getStatus()', TestConfigStore.getStatus() );
    console.log('testconfigcomponent TestConfigStore.getTestConfiguration()', TestConfigStore.getTestConfiguration() );
    //console.log('testconfigcomponent TestConfigStore.getData()', TestConfigStore.getData() );
    //console.log('testconfigcomponent TestConfigStore.getAllTestMembers()', TestConfigStore.getAllTestMembers() );

    var data = {};
    data.testsByHost = TestConfigStore.getTestsByHost();
    data.testsByTest = TestConfigStore.getTestConfiguration();
    TestConfigComponent.data = data;
    console.log('all test data', data );

    // ** Test config tables **
    TestConfigComponent._buildTable( );

};

TestConfigComponent.initialize();
