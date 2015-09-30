// assumes stores/DataStore has already been loaded

//var TestConfigStore = new DataStore();
var TestConfigStore = new DataStore("store.change.test_config", "services/regular_testing.cgi?method=get_test_configuration");
//var TestConfigStore = new DataStore;
//TestConfigStore.initialize("store.change.test_config", "services/regular_testing.cgi");

console.log(TestConfigStore);

Dispatcher.subscribe('store.change.test_config', function() {
    console.log('data from dispatcher/testconfigstore', TestConfigStore.getData()); 
});

TestConfigStore.getTestConfiguration = function() {
    return this.data.test_configuration;
};

TestConfigStore.getStatus = function() {
    return this.data.status;
};
