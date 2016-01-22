// assumes stores/DataStore has already been loaded

var TestConfigStore = new DataStore("store.change.test_config", "services/regular_testing.cgi?method=get_test_configuration");


//var TestConfigStore = new DataStore;
//TestConfigStore.initialize("store.change.test_config", "services/regular_testing.cgi");

// Raw/formatted test type names
// Could probably have used a hash with raw values as keys, but they may
// contain invalid keyname characters
TestConfigStore.testTypes = [
    { 
        raw: "pinger",
        formatted: "Ping (RTT)",
    },
    {
        raw: "bwctl/throughput",
        formatted: "Throughput",
    },
    {
        raw: "owamp",
        formatted: "One-way latency",
    },
    {
        raw: "traceroute",
        formatted: "Traceroute",
    },
];

Dispatcher.subscribe(TestConfigStore.topic, function() {
    console.log('received test data changed event');
    TestConfigStore.data = TestConfigStore.getData();
    TestConfigStore._setAdditionalVariables();
    //console.log('data from dispatcher/testconfigstore', TestConfigStore.getData());    
});

TestConfigStore.getTestConfiguration = function() {
    return TestConfigStore.data.test_configuration;
};

TestConfigStore.getStatus = function() {
    return TestConfigStore.data.status;
};


TestConfigStore.getAllTestMembers = function() {
    var member_array = [];
    for(var i in TestConfigStore.data.test_configuration) {
        var test = TestConfigStore.data.test_configuration[i];
        for(var j in test.members) {
            var member = test.members[j];
            member_array.push(member.address);
        }
    }
    return member_array;
};


TestConfigStore.getTestsByHost = function() {
    var tests = {};
    var member_array = [];
    var host_id = 0;
    for(var i in TestConfigStore.data.test_configuration) {
        var test = TestConfigStore.data.test_configuration[i];
        for(var j in test.members) {
            var member = test.members[j];
            member.host_id = host_id;
            
            // This portion will need to happen in the get configuration section
            // or at least some of it
            tests = TestConfigStore.addHostToTest(tests, test, member);
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
TestConfigStore._setAdditionalVariables = function ( ) {
    console.log('setting additional variables');
    TestConfigStore.data.test_configuration_raw = $.extend( true, [], TestConfigStore.data.test_configuration );
    var tests = TestConfigStore.data.test_configuration;

    for(var i in tests) {
        var test = tests[i];
        var type = test.type;
        var protocol = test.parameters.protocol;

        // set test.type_formatted
        var formattedType = TestConfigStore._formatTestType( type );
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
        if ( type == 'pinger' ) {
            test.showPingParameters = true;
        }
        if ( type == 'bwctl/throughput' ) {
            test.showThroughputParameters = true;
            if ( test.parameters.window_size > 0 ) {
                test.showWindowSize = true;
            } else {
                test.showWindowSize = false;
            }
        }
        if ( type == 'owamp') {
            test.showOWAMPParameters = true;
            test.parameters.packet_size = test.parameters.packet_padding + 20;
            test.parameters.packet_rate = 1/test.parameters.packet_interval;
        }
        if ( type == 'traceroute') {
            test.showTracerouteParameters = true;

        }

        // Set test_interval_formatted
        var interval = test.parameters.test_interval;
        if ( interval != undefined ) {
            test.parameters.test_interval_formatted = SharedUIFunctions.getTime( interval );
        }
    }
    console.log('data after adding additional info', TestConfigStore.data);


};

// Sets whether the test is enabled
// Note that in the backend config, this is counter-intuitively
// stored as "disabled" that's true if the test is disabled.
TestConfigStore.setTestEnabled = function ( testID, testStatus ) {
    var data = TestConfigStore.data.test_configuration_raw;
    for(var i in data) {
        var test = data[i];
        if ( testID == test.test_id ) {
            var disabledStatus = !testStatus;
            if ( disabledStatus ) {
                disabledStatus = 1;
            } else {
                disabledStatus = 0;
            }
            test.disabled = disabledStatus;
            break; // there should only be one
        }
    }
    //TestConfigStore._setAdditionalVariables();
    console.log('data after setTestEnabled', TestConfigStore.data);
};

TestConfigStore.setTestDescription = function ( testID, testDescription ) {
    var data = TestConfigStore.data.test_configuration_raw;
    for(var i in data) {
        var test = data[i];
        if ( testID == test.test_id ) {
            test.description = testDescription;
            break; // there should only be one
        }
    }
    //TestConfigStore._setAdditionalVariables();
    console.log('data after setTestEnabled', TestConfigStore.data);
};
// TestConfigStore.addHostToTest
// Adds a host to a test in the Host-centric view
TestConfigStore.addHostToTest = function (tests, test, member) {
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

// Gets the configuration for the one test that matches
// the provided testID
TestConfigStore.getTestConfig = function ( testID ) {
    var ret;
    var data = TestConfigStore.data.test_configuration;
    for(var i in data) {
        var test = data[i];
        if ( test.test_id == testID ) {
            return test;
        }
    }
    return;
};

// Given the raw test type name as returned by esmond, return a formatted version
TestConfigStore._formatTestType = function ( rawName ) {
    var types = TestConfigStore.testTypes;
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
