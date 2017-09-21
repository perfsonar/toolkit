// make sure jquery, Dispatcher, TestStore, TestResultsComponent, 
// HostMetadataStore, HostMetadataComponent load before this.

var AdminInfoPage = {
    adminInfoTopic:     'store.change.host_info',
    formSubmitTopic:    'ui.form.submit',
};

//var GraphUtilities = psShared.GraphUtilities;
var LSCacheStore = psShared.LSCacheStore;

AdminInfoPage.gotCaches = function() {
    LSCacheStore.retrieveCommunities();

};

AdminInfoPage.initialize = function() {
    var callback = this.gotCaches;
    LSCacheStore.subscribeLSCaches( callback );
    $("#adminInfoForm")
        .on('valid.fndtn.abide', function(e) {
            if(e.namespace != 'abide.fndtn') {
                return;
            }
            Dispatcher.publish(AdminInfoPage.formSubmitTopic);
            e.preventDefault();
        })
        .on('invalid.fndtn.abide', function (e) {
            if(e.namespace != 'abide.fndtn') {
                return;
            }
            StickySaveBar.showValidationError();
        });
    $('#loading-modal').foundation('reveal', 'open');
};

AdminInfoPage.initialize();
