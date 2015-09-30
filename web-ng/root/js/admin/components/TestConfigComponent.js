// make sure jquery and Dispatcher load before this

var TestConfigComponent = {
    testConfigTopic: 'store.change.test_config',
};

TestConfigComponent.initialize = function() {
    //$('#loading-modal').foundation('reveal', 'open');
    Dispatcher.subscribe( TestConfigComponent.testConfigTopic, TestConfigComponent._showConfig );
};

TestConfigComponent._showConfig = function() {
    console.log('testconfigcomponent TestConfigStore.getStatus()', TestConfigStore.getStatus() );
    console.log('testconfigcomponent TestConfigStore.getTestConfiguration()', TestConfigStore.getTestConfiguration() );
    console.log('testconfigcomponent TestConfigStore.getData()', TestConfigStore.getData() );
    console.log('testconfigcomponent TestConfigStore', TestConfigStore );
};

TestConfigComponent.initialize();
