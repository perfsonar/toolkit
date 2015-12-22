// make sure jquery, Dispatcher
// all load before this.

var TestConfigPage = { 
};

TestConfigPage.initialize = function() {
    //$('#loading-modal').foundation('reveal', 'open');
    //Dispatcher.subscribe(TestConfigPage.detailsTopic, TestConfigPage._setDetails);
    $('#admin_info_save_button').click(TestConfigComponent.save);
};

TestConfigPage._setDetails = function(topic) {
    //$('#loading-modal').foundation('reveal', 'close');
    var details = HostDetailsStore.getHostDetails();

};

TestConfigPage.initialize();
