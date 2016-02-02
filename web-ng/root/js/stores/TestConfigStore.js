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
    console.log('data from dispatcher/testconfigstore', TestConfigStore.getData()); 
    TestConfigStore._setAdditionalVariables();
});

TestConfigStore._processData = function() {
};  

TestConfigStore.getTestConfigurationFormatted = function() {
    return TestConfigStore.data.test_configuration_formatted;
};

TestConfigStore.getTestConfiguration = function() {
    return TestConfigStore.data.test_configuration;
};

TestConfigStore.getStatus = function() {
    return TestConfigStore.data.status;
};


TestConfigStore.getAllTestMembers = function() {
    var member_array = [];
    for(var i in TestConfigStore.data.test_configuration_formatted) {
        var test = TestConfigStore.data.test_configuration_formatted[i];
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
    for(var i in TestConfigStore.data.test_configuration_formatted) {
        var test = TestConfigStore.data.test_configuration_formatted[i];
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
    TestConfigStore.data.test_configuration_formatted = [];
    TestConfigStore.data.test_configuration_formatted = $.extend( true, [], TestConfigStore.data.test_configuration );
    var tests = TestConfigStore.data.test_configuration_formatted;

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
            test.parameters.duration_formatted = SharedUIFunctions.getTimeWithUnits( test.parameters.duration );
        }
        if ( type == 'owamp') {
            test.showOWAMPParameters = true;
            test.parameters.packet_size = parseInt( test.parameters.packet_padding ) + 20;
            test.parameters.packet_rate = 1/test.parameters.packet_interval;
        }
        if ( type == 'traceroute') {
            test.showTracerouteParameters = true;

        }

        // Set test_interval_formatted
        var interval = test.parameters.test_interval;
        if ( interval != undefined ) {
            var time = SharedUIFunctions.getTimeWithUnits( interval ); 
            test.parameters.test_interval_formatted = time;
        }
    }

};

TestConfigStore.setTestSettings = function ( testID, settings ) {
    var test = TestConfigStore.getTestByID( testID );
    if ( settings.enabled ) {
        test.disabled = 0;
    } else {
        test.disabled = 1;
    }
    if ( settings.description ) {
        test.description = settings.description;
    }
    if ( settings.interface ) {
        test.parameters.local_interface = settings.interface;
    } else {
        delete test.parameters.local_interface;
    }
    switch ( test.type ) {
        case 'bwctl/throughput':
            if ( settings.protocol ) {
                test.parameters.protocol = settings.protocol;
            } else {
                delete test.parameters.protocol;
            }
            if ( settings.tos_bits ) {
                test.parameters.tos_bits = settings.tos_bits;
            } else {
                test.parameters.tos_bits = 0;
            }

            if ( settings.window_size && !settings.autotuning ) {
                test.parameters.window_size = settings.window_size;
            } else {
                test.parameters.window_size = 0;
            }
            if ( !isNaN( parseInt(settings.test_interval ) ) ) {
                test.parameters.test_interval = settings.test_interval;
            } else {
                test.parameters.test_interval = 21600; // 6hrs TODO: change to use configured default
            }
            if ( !isNaN( parseInt(settings.duration ) ) ) {
                test.parameters.duration = settings.duration;
            } else {
                test.parameters.duration = 20; // TODO: change to use configured default
            }
            break;
        case 'owamp':
            if ( typeof settings.packet_rate != 'undefined' && settings.packet_rate > 0 ) {
                test.parameters.packet_interval = 1 / parseInt( settings.packet_rate );
            } else {
                test.parameters.packet_interval = 0.1;
            }
            if ( typeof settings.packet_size != 'undefined' && settings.packet_size >= 20 ) {
                test.parameters.packet_padding = parseInt( settings.packet_size ) - 20;
            } else {
                test.parameters.packet_padding = 0;
            }
            break;
        case 'traceroute':
            if (typeof settings.tool != 'undefined' && settings.tool != '') {
                test.parameters.tool = settings.tool;
            }
            if ( typeof settings.packet_size != 'undefined' && settings.packet_size > 0 ) {
                test.parameters.packet_size = settings.packet_size;
            } else {
                test.parameters.packet_size = 40; // TODO: change to use configured default
            }
            if ( !isNaN( parseInt( settings.first_ttl ) ) ) {
                test.parameters.first_ttl = settings.first_ttl;
            } else {
                delete test.parameters.first_ttl;
            }
            if ( !isNaN( parseInt( settings.max_ttl ) ) ) {
                test.parameters.max_ttl = settings.max_ttl;
            } else {
                delete test.parameters.max_ttl;
            }
            if ( !isNaN( parseInt(settings.test_interval ) ) ) {
                test.parameters.test_interval = settings.test_interval;
            } else {
                test.parameters.test_interval = 600; // TODO: change to use configured default
            }
            break;
        case 'pinger':
            if ( !isNaN( parseInt(settings.test_interval ) ) ) {
                test.parameters.test_interval = settings.test_interval;
            } else {
                test.parameters.test_interval = 300; // TODO: change to use configured default
            }
            if ( typeof settings.packet_size != 'undefined' && settings.packet_size > 0 ) {
                test.parameters.packet_size = settings.packet_size;
            } else {
                test.parameters.packet_size = 1000; // TODO: change to use configured default
            }
            if ( typeof settings.packet_interval != 'undefined' && settings.packet_size > 0 ) {
                test.parameters.packet_interval = settings.packet_interval;
            } else {
                test.parameters.packet_interval = 1; // TODO: change to use configured default
            }
            if ( typeof settings.packet_count != 'undefined' && settings.packet_size > 0 ) {
                test.parameters.packet_count = settings.packet_count;
            } else {
                test.parameters.packet_count = 10; // TODO: change to use configured default
            }

            break;
    }

};

TestConfigStore.setTestMembers = function ( testID, settings ) {
    console.log('setting test members');
    var test = TestConfigStore.getTestByID( testID );
    //test.members = []; 
    //test.members = settings.members;
    //TODO: investigate, is this necessary? doesn't seem to be


};

// Given a test config, this function generates and returns 
// a new, integer unique id that doesn't conflict with any of 
// the existing member ids
TestConfigStore.generateMemberID = function( test ) {
    var min = 2000000;
    var max = 3000000;
    var ids = {};
    for(var i in test.members) {
        var member_id = test.members[i].member_id;
        ids[ test.members[i].member_id ] = 1;

    }    
    var rand = SharedUIFunctions.generateRandomIntInRange( min, max );
    var i = 0;
    while ( rand in ids ) {
        rand = SharedUIFunctions.generateRandomIntInRange( min, max );
        i++;

        // If we've tried 100 times and haven't found any 
        // usable ids, give up. This shouldn't happen
        if ( i > 100 ) {
            return false;
        }
    }
    return rand;

};


// Sets whether the test is enabled
// Note that in the backend config, this is counter-intuitively
// stored as "disabled" that's true if the test is disabled.
TestConfigStore.setTestEnabled = function ( test, testStatus ) {
    var disabledStatus = !testStatus;
    if ( disabledStatus ) {
        disabledStatus = 1;
    } else {
        disabledStatus = 0;
    }
    test.disabled = disabledStatus;
    console.log('test after setTestEnabled', test);
};

TestConfigStore.setTestDescription = function ( test, testDescription ) {
    test.description = testDescription;
    console.log('test after setTestDescription', test);
};

TestConfigStore.setInterface = function ( test, interface ) {
    test.parameters.local_interface = interface;
    console.log('test after setInterface', test);
};

TestConfigStore.getTestByID = function ( testID ) {
    var data = TestConfigStore.data.test_configuration;
    for(var i in data) {
        var test = data[i];
        if ( testID == test.test_id ) {
            return TestConfigStore.data.test_configuration[i];
        }
    }
    return {};
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

TestConfigStore.deleteMemberFromTest = function ( testID, memberID ) {
    var test = TestConfigStore.getTestByID( testID );
    var members = test.members;
    this.test = test;

    for (var i = members.length - 1; i >= 0; i--) {
        var member = members[i];
        if ( member.member_id == memberID ) {
            members.splice( i, 1 );
            return true;
        }
    }

    return false;

};

TestConfigStore.getTestMemberIndex = function( memberID, testID ) {
    var test = TestConfigStore.getTestByID( testID );
    for ( var i in test.members ) {
        if ( test.members[i].member_id == memberID ) {
            return i;
        }
    }
    return -1;
};

TestConfigStore.addOrUpdateTestMember = function ( testID, member ) {
    var test = TestConfigStore.getTestByID( testID );
    var memberIndex = TestConfigStore.getTestMemberIndex( member.member_id, testID );


    /*
    var result = $.grep( test.members, function( val, index ) {
        return ( val.member_id == member.member_id  );
    });
    console.log('addOrUpdate grep result', result);
    */
    var config = {};
    /*
    config.address = member.address;
    config.description = member.description;
    config.test_ipv4 = member.test_ipv4;
    config.test_ipv6 = member.test_ipv6;
    */

    if ( memberIndex >= 0 ) {
        // The member was found in the config. Update it with the new values.
        // We do this by taking the config as stored as 'defaults' and override
        // anything that was specified in the GUI. This way we should be able to 
        // retain any settings that were stored in the config that the GUI does not
        // support
        var result = test.members[ memberIndex ];

        //var config = $.extend( {}, result, member );
        var config = member;
        test.members[memberIndex] = $.extend({}, result, member);
        //test.members[memberIndex] = config;
        return true;
    } else {
        // this member not found
        // add it as a new member, in this case
        test.members.push( member );
        return true;
    }

};

// Gets the configuration for the one test that matches
// the provided testID
TestConfigStore.getTestConfig = function ( testID ) {
    var ret;
    var data = TestConfigStore.data.test_configuration_formatted;
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
