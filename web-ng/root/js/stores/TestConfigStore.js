// assumes stores/DataStore has already been loaded

//var TestConfigStore = new DataStore();
var TestConfigStore = new DataStore("store.change.test_config", "services/regular_testing.cgi?method=get_test_configuration");
//var TestConfigStore = new DataStore;
//TestConfigStore.initialize("store.change.test_config", "services/regular_testing.cgi");

console.log('TestConfigStore', TestConfigStore);

Dispatcher.subscribe('store.change.test_config', function() {
    console.log('data from dispatcher/testconfigstore', TestConfigStore.getData()); 
});

TestConfigStore.getTestConfiguration = function() {
    return this.data.test_configuration;
};

TestConfigStore.getStatus = function() {
    console.log('getting status');
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
    for(var i in this.data.test_configuration) {
        var test = this.data.test_configuration[i];
        for(var j in test.members) {
            var member = test.members[j];
            var address = member.address;
            tests = TestConfigStore.addHostToTest(tests, test, member); 
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

TestConfigStore.addHostToTest = function (tests, test, member) {
    var address = member.address;
    var type = test.type;
    var type_count_name = type + "_count";
    type_count_name = type_count_name.replace('/', '_');
    if ( !(address in tests) ) {
        tests[address] = {};
        tests[address].tests = [];
    }

    tests[address].tests.push(test);
    tests[address].address = address;
    if ( test[type_count_name] ) {
        tests[address][type_count_name]++;
    } else {
        tests[address][type_count_name] = 1;
    }
    return tests;

};

