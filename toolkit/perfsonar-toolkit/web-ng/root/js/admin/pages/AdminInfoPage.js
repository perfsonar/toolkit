// make sure jquery, Dispatcher, TestStore, TestResultsComponent, 
// HostMetadataStore, HostMetadataComponent load before this.

var AdminInfoPage = {
    adminInfoTopic:     'store.change.host_info',
    formSubmitTopic:    'ui.form.submit',
};

AdminInfoPage.initialize = function() {
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
            var checkbox = $("#privacyPolicySwitch");
            if ( checkbox.prop("checked") ) {
                StickySaveBar.showValidationError();
            } else {
                var message = "You must accept our privacy policy to save this information.";
                StickySaveBar.showCustomValidationError( message );

            }
        });
    $('#loading-modal').foundation('reveal', 'open');
};

AdminInfoPage.initialize();
