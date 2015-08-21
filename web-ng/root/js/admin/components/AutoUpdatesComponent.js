var AutoUpdatesComponent = {
    auto_updates: null,
    details_topic: 'store.change.host_details',
    saveAutoUpdatesTopic: 'store.auto_updates.save',
    saveAutoUpdatesErrorTopic: 'store.auto_updates.save_error',
    formChangeTopic: 'ui.form.change',
    formSuccessTopic: 'ui.form.success',
    formErrorTopic: 'ui.form.error',
    formCancelTopic: 'ui.form.cancel',
};


AutoUpdatesComponent.initialize = function() {    
    //AutoUpdatesComponent._getAutoUpdates();
    Dispatcher.subscribe(AutoUpdatesComponent.details_topic, AutoUpdatesComponent._setAutoUpdates);
    /*
    $('form#adminInfoForm input').change(AutoUpdatesComponent._showSaveBar);
    $('form#adminInfoForm select').change(AutoUpdatesComponent._showSaveBar);
    $('#admin_info_cancel_button').click( AutoUpdatesComponent._cancel);
    Dispatcher.subscribe(AutoUpdatesComponent.saveAutoUpdatesTopic, AutoUpdatesComponent._saveSuccess);
    Dispatcher.subscribe(AutoUpdatesComponent.saveAutoUpdatesErrorTopic, AutoUpdatesComponent._saveError);
    $('#loading-modal').foundation('reveal', 'open');
    */
    $('#autoUpdatesSwitch').change( function() {
        AutoUpdatesComponent.auto_updates = ! AutoUpdatesComponent.auto_updates;
        AutoUpdatesComponent._setSwitch();            
    });
};

AutoUpdatesComponent._setAutoUpdates = function() {
    var auto_updates = HostDetailsStore.getAutoUpdates();
    AutoUpdatesComponent.auto_updates = auto_updates;
    AutoUpdatesComponent._setSwitch();

};

AutoUpdatesComponent._setSwitch = function() {
    var auto_updates = AutoUpdatesComponent.auto_updates
    console.log('auto updates', auto_updates);
    var checkbox_el = $('#autoUpdatesSwitch');
    checkbox_el.prop('checked', auto_updates);
    var label = AutoUpdatesComponent._getLabelText(auto_updates);
    var label_el = $('#autoUpdatesLabel');
    label_el.text(label);

};

// Returns text based on the state of the boolean
// Returns "Enabled" if true or "Disabled" if false
AutoUpdatesComponent._getLabelText = function ( state ) {
    return state ? 'Enabled' : 'Disabled';
};

AutoUpdatesComponent.save = function() {
    var data = {};
    data.enabled = AutoUpdatesComponent.auto_updates ? 1 : 0;

    HostAdminStore.saveAutoUpdates(data);

};
AutoUpdatesComponent._saveSuccess = function( topic, message ) {
    Dispatcher.publish(AutoUpdatesComponent.formSuccessTopic, message);
};

AutoUpdatesComponent._saveError = function( topic, message ) {
    Dispatcher.publish(AutoUpdatesComponent.formErrorTopic, message);
};

AutoUpdatesComponent._cancel = function() {
    Dispatcher.publish(AutoUpdatesComponent.formCancelTopic);
    Dispatcher.publish(AutoUpdatesComponent.info_topic);

};

AutoUpdatesComponent._showSaveBar = function() {
    Dispatcher.publish(AutoUpdatesComponent.formChangeTopic);
};

AutoUpdatesComponent.initialize();

