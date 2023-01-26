// assumes stores/DataStore has already been loaded

var TestConfigAdminStore = new DataStore(TestConfigStore.topic, "services/regular_testing.cgi?method=update_test_configuration", false, "POST");

TestConfigAdminStore.save = function( tests ) {
    tests.data = $.extend( true, [], tests.test_configuration );
    var data = tests.data;
//alert('JOVANA: ');
    for(var i in tests.data) {
        var test = tests.data[i];
        for(var j in test.members) {
            var member = test.members[j];
            delete member.id;
            delete member.host_id;
            delete member.member_id;
        }

    }
    TestConfigAdminStore._sanitizeTestConfig( tests );

    var topic = TestConfigStore.saveTopic;
    var error_topic = TestConfigStore.saveErrorTopic;

//    var testsJSON = JSON.stringify(tests);
//alert(testsJSON);
    $.ajax({
        url: TestConfigAdminStore.url,
        type: 'POST',
        data: testsJSON,
        dataType: 'json',
        contentType: 'application/json',
        success: function(result) {
            var error_code = result["Return code"];
            var error_message = result["Error message"];
            if ( error_code == -1 ) {
                SharedUIFunctions._saveError(TestConfigStore.saveErrorTopic, error_message);
            } else {
                TestConfigStore._retrieveData();
                Dispatcher.publish(topic, result.message);
            }

        },
        error: function(jqXHR, textStatus, errorThrown) {
            Dispatcher.publish(error_topic, errorThrown);
        }
    });

};

TestConfigAdminStore._sanitizeTestConfig = function( tests ) {
    for(var i in tests.data) {
        var test = tests.data[i];
        if ( test.parameters.protocol == 'tcp' ) {
            delete test.parameters.udp_bandwidth;
        }
        for(var j in test.members) {
            var member = test.members[j];
            delete member.member_id;

        }
    }
};

TestConfigAdminStore.getTestConfiguration = function() {
    TestConfigAdminStore.data = TestConfigStore.data;
    return TestConfigAdminStore.data.test_configuration;
};

