// make sure jquery, Dispatcher, TestStore, TestResultsComponent, 
// HostMetadataStore, HostMetadataComponent load before this.

var AdminInfoPage = { 
    adminInfoTopic:     'store.change.host_info',
    formSubmitTopic:    'ui.form.submit',
};

AdminInfoPage.initialize = function() {
    $("#adminInfoForm").on('valid.fndtn.abide', function(e) {
        Dispatcher.publish(AdminInfoPage.formSubmitTopic);
        e.preventDefault();
    });
    $('#loading-modal').foundation('reveal', 'open');
};

AdminInfoPage.initialize();
