var AutoUpdatesComponent = {
    autoUpdates: null,
    detailsTopic: 'store.change.host_details',
    saveAutoUpdatesTopic: 'store.auto_updates.save',
    saveAutoUpdatesErrorTopic: 'store.auto_updates.save_error',
    formAutoUpdatesChangeTopic: 'ui.form.auto_updates.change',
    formAutoUpdatesSuccessTopic: 'ui.form.auto_updates.success',
    formAutoUpdatesErrorTopic: 'ui.form.auto_updates.error',
    formAutoUpdatesCancelTopic: 'ui.form.auto_updates.cancel',
};


AutoUpdatesComponent.initialize = function() {
    Dispatcher.subscribe(AutoUpdatesComponent.detailsTopic, AutoUpdatesComponent._setAutoUpdates);
    Dispatcher.subscribe(AutoUpdatesComponent.saveAutoUpdatesTopic, AutoUpdatesComponent._saveSuccess);
    Dispatcher.subscribe(AutoUpdatesComponent.saveAutoUpdatesErrorTopic, AutoUpdatesComponent._saveError);
    $('#autoUpdatesSwitch').change( function() {
        AutoUpdatesComponent.autoUpdates = ! AutoUpdatesComponent.autoUpdates;
        AutoUpdatesComponent._setSwitch();
    });
};

AutoUpdatesComponent._setAutoUpdates = function() {
    var autoUpdates = HostDetailsStore.getAutoUpdates();
    AutoUpdatesComponent.autoUpdates = autoUpdates;
    AutoUpdatesComponent._setSwitch();

};

AutoUpdatesComponent._setSwitch = function(e) {
    var autoUpdates = AutoUpdatesComponent.autoUpdates
    var checkbox_el = $('#autoUpdatesSwitch');
    checkbox_el.prop('checked', autoUpdates);
    var label = AutoUpdatesComponent._getLabelText(autoUpdates);
    var label_el = $('#autoUpdatesLabel');
    label_el.text(label);
    //e.preventDefault();

};

// Returns text based on the state of the boolean
// Returns "Enabled" if true or "Disabled" if false
AutoUpdatesComponent._getLabelText = function ( state ) {
    return state ? 'Enabled' : 'Disabled';
};

AutoUpdatesComponent.save = function() {
    var data = {};
    data.enabled = AutoUpdatesComponent.autoUpdates ? 1 : 0;

    HostAdminStore.saveAutoUpdates(data);

};
AutoUpdatesComponent._saveSuccess = function( topic, message ) {
    Dispatcher.publish(AutoUpdatesComponent.formAutoUpdatesSuccessTopic, message);
};

AutoUpdatesComponent._saveError = function( topic, message ) {
    Dispatcher.publish(AutoUpdatesComponent.formAutoUpdatesErrorTopic, message);
};

AutoUpdatesComponent._cancel = function() {
    Dispatcher.publish(AutoUpdatesComponent.formAutoUpdatesCancelTopic);
    Dispatcher.publish(AutoUpdatesComponent.info_topic);

};

AutoUpdatesComponent._showSaveBar = function() {
    Dispatcher.publish(AutoUpdatesComponent.formAutoUpdatesChangeTopic);
};

AutoUpdatesComponent.initialize();

