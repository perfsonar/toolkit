// make sure jquery, Dispatcher, TestStore, TestResultsComponent, 
// HostStore, HostServicesComponent and HostInfoComponent all load before this.

var AdminInfoPage = { 
    adminInfoTopic:     'store.change.host_info',
    formSubmitTopic:    'ui.form.submit',
};

AdminInfoPage.initialize = function() {
    $('#loading-modal').foundation('reveal', 'open');
    $("#adminInfoForm").submit(function(e) {
        Dispatcher.publish(AdminInfoPage.formSubmitTopic);
        AdminInfoUpdateComponent.save();
        CommunityUpdateComponent.save();
        e.preventDefault();
    });
};

AdminInfoPage.initialize();
