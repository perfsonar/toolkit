// make sure jquery, Dispatcher, 
// HostDetailStore all load before this.

var HostConfigPage = { 
    detailsTopic: 'store.change.host_details',
    adminServicesTopic: 'store.change.host_services',
    ntpConfigTopic: 'store.change.ntp_config',
    formChangeTopic: 'ui.form.change',
    formSubmitTopic:    'ui.form.submit',
    formSuccessTopic: 'ui.form.success',
    formErrorTopic: 'ui.form.error',
    formCancelTopic: 'ui.form.cancel',
    formAutoUpdatesChangeTopic: 'ui.form.auto_updates.change',
    formAutoUpdatesSuccessTopic: 'ui.form.auto_updates.success',
    formAutoUpdatesErrorTopic: 'ui.form.auto_updates.error',
    formAutoUpdatesCancelTopic: 'ui.form.auto_updates.cancel',
    formNTPChangeTopic: 'ui.form.ntp.change',
    formNTPSuccessTopic: 'ui.form.ntp.success',
    formNTPErrorTopic: 'ui.form.ntp.error',
    formNTPCancelTopic: 'ui.form.ntp.cancel',
    formAllowInternalAddressesChangeTopic: 'ui.form.in_add.change',
    formAllowInternalAddressesSuccessTopic: 'ui.form.in_add.success',
    formAllowInternalAddressesErrorTopic: 'ui.form.in_add.error',
    formAllowInternalAddressesCancelTopic: 'ui.form.in_add.cancel',
    ntpSaveCompleted: null,
    autoUpdatesSaveCompleted: null,
    allowInternalAddressesSaveCompleted: null,
    ntpSaveMessage: '',
    autoUpdatesSaveMessage: '',
    allowInternalAddressesSaveMessage: '',
};

HostConfigPage.initialize = function() {
    $('#loading-modal').foundation('reveal', 'open');
    Dispatcher.subscribe(HostConfigPage.detailsTopic, HostConfigPage._setDetails);
    Dispatcher.subscribe(HostConfigPage.formAutoUpdatesSuccessTopic, HostConfigPage._handleSubForm);
    Dispatcher.subscribe(HostConfigPage.formAllowInternalAddressesSuccessTopic, HostConfigPage._handleSubForm);
    Dispatcher.subscribe(HostConfigPage.formNTPSuccessTopic, HostConfigPage._handleSubForm);

    $('form#hostConfigForm input').change(HostConfigPage._showSaveBar);
    $('form#hostConfigForm select').change(HostConfigPage._showSaveBar);

    $('#admin_info_save_button').click(HostConfigPage._save);
    $('#admin_info_cancel_button').click( HostConfigPage._cancel);

};

HostConfigPage._setDetails = function(topic) {
    $('#loading-modal').foundation('reveal', 'close');
    var details = HostDetailsStore.getHostDetails();
};

HostConfigPage._handleSubForm = function(topic, result) {
    switch (topic) {
        case HostConfigPage.formAutoUpdatesSuccessTopic:
            HostConfigPage.autoUpdatesSaveCompleted = true;
            HostConfigPage.autoUpdatesSaveMessage = result;
            break;
        case HostConfigPage.formAutoUpdatesErrorTopic:
            HostConfigPage.autoUpdatesSaveCompleted = false;
            HostConfigPage.autoUpdatesSaveMessage = result;
            break;
        case HostConfigPage.formNTPSuccessTopic:
            HostConfigPage.ntpSaveCompleted = true;
            HostConfigPage.ntpSaveMessage = result;
            break;
        case HostConfigPage.formNTPErrorTopic:
            HostConfigPage.ntpSaveCompleted = false;
            HostConfigPage.ntpSaveMessage = result;
            break;
        case HostConfigPage.formAllowInternalAddressesSuccessTopic:
            HostConfigPage.allowInternalAddressesSaveCompleted = true;
            HostConfigPage.allowInternalAddressesSaveMessage = result;
            break;    
        case HostConfigPage.formAllowInternalAddressesErrorTopic:
            HostConfigPage.allowInternalAddressesSaveCompleted = false;
            HostConfigPage.allowInternalAddressesSaveMessage = result;
            break;      
    }

    if (HostConfigPage.ntpSaveCompleted !== null && HostConfigPage.autoUpdatesSaveCompleted !== null) {
        // Both sections save completed.
        var message = '';
        if (HostConfigPage.ntpSaveCompleted && HostConfigPage.autoUpdatesSaveCompleted) {
            message += 'Auto updates and NTP saved successfully';

        } else {
            if (HostConfigPage.autoUpdatesSaveCompleted) {
                message += 'Auto Updates saved successfully. ';
            } else {
                message += 'Error saving Auto Updates: ';
                message += HostConfigPage.autoUpdatesSaveMessage;
            }
            if (HostConfigPage.ntpSaveCompleted) {
                message += 'NTP saved successfully. ';
            } else {
                message += 'Error saving NTP: ';
                message += HostConfigPage.NTPSaveMessage;
            }
        }
        HostConfigPage.ntpSaveCompleted = null;
        HostConfigPage.autoUpdatesSaveCompleted = null;
        HostConfigPage.ntpSaveMessage = '';
        HostConfigPage.autoUpdatesSaveMessage = '';
        HostConfigPage._saveSuccess( topic, message);
    }
};

HostConfigPage._handleSubFormsaved = function(topic, result) {
    switch (topic) {
        case HostConfigPage.formAutoUpdatesSuccessTopic:
            HostConfigPage.autoUpdatesSaveCompleted = true;
            HostConfigPage.autoUpdatesSaveMessage = result;
            break;
        case HostConfigPage.formAutoUpdatesErrorTopic:
            HostConfigPage.autoUpdatesSaveCompleted = false;
            HostConfigPage.autoUpdatesSaveMessage = result;
            break;
        case HostConfigPage.formAllowInternalAddressesSuccessTopic:
            HostConfigPage.allowInternalAddressesSaveCompleted = true;
            HostConfigPage.allowInternalAddressesSaveMessage = result;
            break;    
        case HostConfigPage.formAllowInternalAddressesErrorTopic:
            HostConfigPage.allowInternalAddressesSaveCompleted = false;
            HostConfigPage.allowInternalAddressesSaveMessage = result;
            break;    
        case HostConfigPage.formNTPSuccessTopic:
            HostConfigPage.ntpSaveCompleted = true;
            HostConfigPage.ntpSaveMessage = result;
            break;
        case HostConfigPage.formNTPErrorTopic:
            HostConfigPage.ntpSaveCompleted = false;
            HostConfigPage.ntpSaveMessage = result;
            break;
    }

    if (HostConfigPage.ntpSaveCompleted !== null || HostConfigPage.autoUpdatesSaveCompleted !== null || HostConfigPage.allowInternalAddressesSaveCompleted !== null) {
        // At least one section save completed.
        var message = '';
        if (HostConfigPage.ntpSaveCompleted && HostConfigPage.autoUpdatesSaveCompleted  && HostConfigPage.allowInternalAddressesSaveCompleted) {
            message += 'Allow Internal Addresses, Auto updates and NTP saved successfully';
            
        } else if (HostConfigPage.autoUpdatesSaveCompleted  && HostConfigPage.allowInternalAddressesSaveCompleted) {
            message += 'Allow Internal Addresses and Auto updates saved successfully';
        	
        }else if (HostConfigPage.ntpSaveCompleted && HostConfigPage.allowInternalAddressesSaveCompleted) {
            message += 'Allow Internal Addresses and NTP saved successfully';
            
        }else if (HostConfigPage.ntpSaveCompleted && HostConfigPage.autoUpdatesSaveCompleted) {
            message += 'Auto updates and NTP saved successfully';
    
        } else {
        	if (HostConfigPage.autoUpdatesSaveCompleted) {
                message += 'Auto Updates saved successfully. ';
            } else {
                message += 'Error saving Auto Updates: ';
                message += HostConfigPage.autoUpdatesSaveMessage;
            }
            if (HostConfigPage.allowInternalAddressesSaveCompleted) {
                message += 'Allow Internal Addresses saved successfully. ';
            } else {
                message += 'Error saving Internal Addresses: ';
                message += HostConfigPage.allowInternalAddressesSaveMessage;
            }
            if (HostConfigPage.ntpSaveCompleted) {
                message += 'NTP saved successfully. ';
            } else {
                message += 'Error saving NTP: ';
                message += HostConfigPage.NTPSaveMessage;
            }
        }
        HostConfigPage.ntpSaveCompleted = null;
        HostConfigPage.autoUpdatesSaveCompleted = null;
        HostConfigPage.allowInternalAddressesSaveCompleted = null;
        HostConfigPage.allowInternalAddressesSaveMessage = '';
        HostConfigPage.ntpSaveMessage = '';
        HostConfigPage.autoUpdatesSaveMessage = '';
        HostConfigPage._saveSuccess( topic, message);
    }
};


HostConfigPage._save = function() {
    Dispatcher.publish(HostConfigPage.formSubmitTopic);
    NTPConfigComponent.save();
    AutoUpdatesComponent.save();
    AllowInternalAddressesComponent.save();
};

HostConfigPage._saveSuccess = function( topic, message ) {
    Dispatcher.publish(HostConfigPage.formSuccessTopic, message);
};

HostConfigPage._saveError = function( topic, message ) {
    Dispatcher.publish(HostConfigPage.formErrorTopic, message);
};

HostConfigPage._cancel = function() {
    Dispatcher.publish(HostConfigPage.formCancelTopic);
    Dispatcher.publish(HostConfigPage.ntpConfigTopic);
    Dispatcher.publish(HostConfigPage.detailsTopic);
};

HostConfigPage._showSaveBar = function() {
    Dispatcher.publish(HostConfigPage.formChangeTopic);
};

HostConfigPage.initialize();