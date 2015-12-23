// assumes stores/DataStore has already been loaded

var TestConfigAdminStore = new DataStore(TestConfigStore.topic, "services/regular_testing.cgi?method=update_test_configuration", "POST");

TestConfigAdminStore.save = function( tests ) {
    tests.data = $.extend( true, [], tests.test_configuration_raw );
    TestConfigAdminStore._sanitizeTestConfig( tests );

    var topic = TestConfigStore.saveTopic;
    var error_topic = TestConfigStore.saveErrorTopic; 
   
    var testsJSON = JSON.stringify(tests);
    console.log('tests', tests);

    $.ajax({
        url: TestConfigAdminStore.url,
        type: 'POST',
        data: testsJSON,
        dataType: 'json',
        contentType: 'application/json',
        success: function(result) {
            TestConfigStore._retrieveData();
            Dispatcher.publish(topic, result.message);
        },
        error: function(jqXHR, textStatus, errorThrown) {
            Dispatcher.publish(error_topic, errorThrown);
        }
    });

};

TestConfigAdminStore._sanitizeTestConfig = function( tests ) {
    for(var i in tests.data) {
        var test = tests.data[i];
        for(var j in test.members) {
            var member = test.members[j];
            delete member.member_id;

        }
    } 
};

Dispatcher.subscribe('store.change.test_config', function() {
   // TestConfigAdminStore._setAdditionalVariables();
    console.log('data from dispatcher/testconfigstore', TestConfigAdminStore.getData());    
});


TestConfigAdminStore.getTestConfiguration = function() {
    TestConfigAdminStore.data = TestConfigStore.data;
    return TestConfigAdminStore.data.test_configuration;
};

