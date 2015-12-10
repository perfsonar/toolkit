// make sure jquery and Dispatcher load before this

var TestConfigComponent = {
    testConfigTopic: 'store.change.test_config',
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

    $(".js-row").click(function(){
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

TestConfigComponent._showTable = function( data, tableView ) {
    if ( tableView == undefined ) {
        tableView = 'byHost';
    }
    console.log('tableView', tableView);

    var test_template = $("#testConfigByHostTableTemplate").html();
    var template = Handlebars.compile(test_template);
    var test_table = template(data);
    $("#testConfigContainer").html(test_table);

};

TestConfigComponent._showConfig = function() {
    console.log('Test Config Topic received, showing config ...');
    console.log('testconfigcomponent TestConfigStore.getStatus()', TestConfigStore.getStatus() );
    console.log('testconfigcomponent TestConfigStore.getTestConfiguration()', TestConfigStore.getTestConfiguration() );
    //console.log('testconfigcomponent TestConfigStore.getData()', TestConfigStore.getData() );
    //console.log('testconfigcomponent TestConfigStore.getAllTestMembers()', TestConfigStore.getAllTestMembers() );

    var data = {};
    data.testsByHost = TestConfigStore.getTestsByHost();
    console.log('testconfigcomponent TestConfigStore.getTestsByHost()', data );

    // ** Test config tables **
    TestConfigComponent._showTable( data );

};

TestConfigComponent.initialize();
