// assumes stores/DataStore has already been loaded

//var TestConfigStore = new DataStore();
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

Dispatcher.subscribe('store.change.test_config', function() {
    TestConfigStore._setAdditionalVariables();
    console.log('data from dispatcher/testconfigstore', TestConfigStore.getData());    
});


TestConfigStore.getTestConfiguration = function() {
    return this.data.test_configuration;
};

TestConfigStore.getStatus = function() {
    return this.data.status;
};


TestConfigStore.getAllTestMembers = function() {
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


TestConfigStore.getTestsByHost = function() {
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
    var tests = this.data.test_configuration;

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

        // Set test_interval_formatted
        var interval = test.parameters.test_interval;
        if ( interval != undefined ) {
            test.parameters.test_interval_formatted = SharedUIFunctions.getTime( interval );
        }

    }


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
