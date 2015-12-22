// assumes stores/DataStore has already been loaded

var TestConfigAdminStore = new DataStore(TestConfigStore.topic, "services/regular_testing.cgi?method=update_test_configuration", "POST");

TestConfigAdminStore.save = function( tests ) {
    tests.data = tests.test_configuration_raw;
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
    TestConfigAdminStore._setAdditionalVariables();
    console.log('data from dispatcher/testconfigstore', TestConfigAdminStore.getData());    
});


TestConfigAdminStore.getTestConfiguration = function() {
    TestConfigAdminStore.data = TestConfigStore.data;
    return TestConfigAdminStore.data.test_configuration;
};

TestConfigAdminStore.getStatus = function() {
    return TestConfigAdminStore.data.status;
};


TestConfigAdminStore.getAllTestMembers = function() {
    var member_array = [];
    for(var i in this.data.test_configuration) {
        var test = this.data.test_configuration[i];
        for(var j in test.members) {
            var member = test.members[j];
            member_array.push(member.address);
        }
    }
    return member_array;
};


TestConfigAdminStore.getTestsByHost = function() {
    var tests = {};
    var member_array = [];
    var host_id = 0;
    for(var i in this.data.test_configuration) {
        var test = this.data.test_configuration[i];
        for(var j in test.members) {
            var member = test.members[j];
            member.host_id = host_id;
            
            // This portion will need to happen in the get configuration section
            // or at least some of it
            tests = TestConfigAdminStore.addHostToTest(tests, test, member);
            host_id++;
        }
    }
    var tests_sorted = [];
    var keys = Object.keys(tests);
    keys.sort();
    for(var i in keys) {
        tests_sorted.push(tests[ keys[i] ]);
    }
    return tests_sorted;
};

// Set additional variables for each test/member
TestConfigAdminStore._setAdditionalVariables = function ( ) {
    console.log('setting additional variables');
    var tests = TestConfigStore.data.test_configuration;

    for(var i in tests) {
        var test = tests[i];
        var type = test.type;
        var protocol = test.parameters.protocol;

        // set test.type_formatted
        var formattedType = TestConfigAdminStore._formatTestType( type );
        if ( protocol != undefined ) {
            formattedType += " - " + protocol.toUpperCase(); 
        }
        test.type_formatted = formattedType;
        var udp_bandwidth = parseInt( test.parameters.udp_bandwidth );
        if ( test.parameters.protocol == "udp" && !isNaN(udp_bandwidth) ) {
            var formatted = udp_bandwidth / 1000000;
            formatted += "M";
            test.parameters.udp_bandwidth_formatted = formatted;
            test.type_formatted += ' (' + formatted + ')';
        }

        // Set test_interval_formatted
        var interval = test.parameters.test_interval;
        if ( interval != undefined ) {
            test.parameters.test_interval_formatted = SharedUIFunctions.getTime( interval );
        }

    }


};

// TestConfigAdminStore.addHostToTest
// Adds a host to a test in the Host-centric view
TestConfigAdminStore.addHostToTest = function (tests, test, member) {
    var address = member.address;
    var type = test.type;   
    var host_id = member.host_id;
    var protocol = test.parameters.protocol;
    var type_count_name = type + "_count";

    type_count_name = type_count_name.replace('/', '_');
    if ( !(address in tests) ) {
        tests[address] = {};
        tests[address].tests = [];
    }

    tests[address].tests.push(test);
    tests[address].address = address;
    tests[address].host_id = host_id;

    if ( test[type_count_name] ) {
        tests[address][type_count_name]++;
    } else {
        tests[address][type_count_name] = 1;
    }
    return tests;

};

// Given the raw test type name as returned by esmond, return a formatted version
TestConfigAdminStore._formatTestType = function ( rawName ) {
    var types = TestConfigAdminStore.testTypes;
    if ( rawName == undefined ) {
        return;
    }
    for(var i in types) {
        var type = types[i];
        var raw = type.raw;
        var formatted = type.formatted;
        if ( raw == rawName) {
            return formatted;
        }
    }
};
