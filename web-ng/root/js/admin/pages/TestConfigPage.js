// make sure jquery, Dispatcher
// all load before this.

var TestConfigPage = { 
};

TestConfigPage.initialize = function() {
    //$('#loading-modal').foundation('reveal', 'open');
    //Dispatcher.subscribe(TestConfigPage.detailsTopic, TestConfigPage._setDetails);
    $('#sticky-bar').hide();
};

TestConfigPage._setDetails = function(topic) {
    //$('#loading-modal').foundation('reveal', 'close');
    var details = HostDetailsStore.getHostDetails();

};

TestConfigPage.initialize();
