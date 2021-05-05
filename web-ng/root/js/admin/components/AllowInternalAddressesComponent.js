var AllowInternalAddressesComponent = {
	allowInternalAddresses: null,
    allowInternalAddressesTopic: 'store.change.host_in_add',
    saveAllowInternalAddressesTopic: 'store.in_add.save',
    saveAllowInternalAddressesErrorTopic: 'store.in_add.save_error',
    formAllowInternalAddressesChangeTopic: 'ui.form.in_add.change',
    formAllowInternalAddressesSuccessTopic: 'ui.form.in_add.success',
    formAllowInternalAddressesErrorTopic: 'ui.form.in_add.error',
    formAllowInternalAddressesCancelTopic: 'ui.form.in_add.cancel',
};


AllowInternalAddressesComponent.initialize = function() {
	Dispatcher.subscribe(AllowInternalAddressesComponent.allowInternalAddressesTopic, AllowInternalAddressesComponent._setAllowInternalAddresses);
    Dispatcher.subscribe(AllowInternalAddressesComponent.saveAllowInternalAddressesTopic, AllowInternalAddressesComponent._saveSuccess);
    Dispatcher.subscribe(AllowInternalAddressesComponent.saveAllowInternalAddressesErrorTopic, AllowInternalAddressesComponent._saveError);
    $('#allowInternalAddressesSwitch').change( function() {
    	AllowInternalAddressesComponent.allowInternalAddresses = ! AllowInternalAddressesComponent.allowInternalAddresses;
    	AllowInternalAddressesComponent._setSwitch();
    });
    
};

AllowInternalAddressesComponent._setAllowInternalAddresses = function() {
    var allowInternalAddresses = HostAllowInternalAddressesStore.getAllowInternalAddresses();
    AllowInternalAddressesComponent.allowInternalAddresses = allowInternalAddresses;
    AllowInternalAddressesComponent._setSwitch();

};

AllowInternalAddressesComponent._setSwitch = function(e) {
    var allowInternalAddresses = AllowInternalAddressesComponent.allowInternalAddresses
    var checkbox_el = $('#allowInternalAddressesSwitch');
    checkbox_el.prop('checked', allowInternalAddresses);
    var label = AllowInternalAddressesComponent._getLabelText(allowInternalAddresses);
    var label_el = $('#allowInternalAddressesLabel');
    label_el.text(label);
    //e.preventDefault();

};

// Returns text based on the state of the boolean
AllowInternalAddressesComponent._getLabelText = function ( state ) {
    return state ? 'Allowed' : 'Not Allowed';
    
};

AllowInternalAddressesComponent.save = function() {
    var data = {};
   data.enabled = AllowInternalAddressesComponent.allowInternalAddresses ? 1 : 0;

    HostAdminStore.saveAllowInternalAddresses(data);
    
    //HostAdminStore.saveAutoUpdates(data);
    
    
    
    
};
AllowInternalAddressesComponent._saveSuccess = function( topic, message ) {
    Dispatcher.publish(AllowInternalAddressesComponent.formAllowInternalAddressesSuccessTopic, message);
};

AllowInternalAddressesComponent._saveError = function( topic, message ) {
    Dispatcher.publish(AllowInternalAddressesComponent.formAllowInternalAddressesErrorTopic, message);
};

AllowInternalAddressesComponent._cancel = function() {
    Dispatcher.publish(AllowInternalAddressesComponent.formAllowInternalAddressesCancelTopic);
    Dispatcher.publish(AllowInternalAddressesComponent.info_topic);

};

AllowInternalAddressesComponent._showSaveBar = function() {
    Dispatcher.publish(AllowInternalAddressesComponent.formAllowInternalAddressesChangeTopic);
};

AllowInternalAddressesComponent.initialize();

