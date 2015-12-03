var HostMetadataComponent = {
    metadata_topic: 'store.change.host_metadata',
    formSubmitTopic:    'ui.form.submit',
    saveMetadataTopic: 'store.host_metadata.save',
    saveMetadataErrorTopic: 'store.host_metadata.save_error',
    rolePlaceholder: 'Select a node role',
    policyPlaceholder: 'Select an access policy',
    allRoles: [ 
        {id: 'nren', text: 'NREN'}, 
        {id: 'regional', text: 'Regional'},
        {id: 'site-border', text: 'Site Border'},
        {id: 'site-internal', text: 'Site Internal'},
        {id: 'science-dmz', text: 'Science DMZ'},
        {id: 'exchange-point', text: 'Exchange Point'},
        {id: 'test-host', text: 'Test Host'},
        {id: 'default-path', text: 'Default Path'},
        {id: 'backup-path', text: 'Backup Path'},
    ],
    allAccessPolicies: [
        {id: 'public', text: 'Public'},
        {id: 'research-education', text: 'R&E Only'},
        {id: 'private', text: 'Private'},
        {id: 'limited', text: 'Limited'},
    ],
};


HostMetadataComponent.initialize = function() {
    Dispatcher.subscribe(HostMetadataComponent.metadata_topic, HostMetadataComponent._setMetadata);
    Dispatcher.subscribe(HostMetadataComponent.formSubmitTopic, HostMetadataComponent.save);
    Dispatcher.subscribe(HostMetadataComponent.saveMetadataTopic, SharedUIFunctions._saveSuccess);
    Dispatcher.subscribe(HostMetadataComponent.saveMetadataErrorTopic, SharedUIFunctions._saveError);
    Dispatcher.subscribe(HostMetadataComponent.saveAdminInfoTopic, SharedUIFunctions._saveSuccess);
    Dispatcher.subscribe(HostMetadataComponent.saveAdminInfoErrorTopic, SharedUIFunctions._saveError);
};

HostMetadataComponent._setMetadata = function( topic ) {
    var data = HostMetadataStore.getHostMetadata();
    var allRoles = HostMetadataComponent.allRoles;
    var selectedRoles = data.config.role;   
    var roleValues = SharedUIFunctions.getSelectedValues( allRoles, selectedRoles );  
    
    var roleSel = $('#node_role_select');
    roleSel.select2( { 
        placeholder: HostMetadataComponent.rolePlaceholder,
        data: roleValues,
    });

    var allAccessPolicies = HostMetadataComponent.allAccessPolicies;
    var selectedAccessPolicies = data.config.access_policy;
    var accessPolicyValues = SharedUIFunctions.getSelectedValues( allAccessPolicies, selectedAccessPolicies );

    var accessPolicySel = $('#access_policy');
    accessPolicySel.select2( { 
        placeholder: HostMetadataComponent.policyPlaceholder,
        data: accessPolicyValues,
        allowClear: true, // allow an empty selection
        minimumResultsForSearch: Infinity, // disable search box
    });

    var policyNotesText = $('#node_access_policy_notes');
    var policyNotes = data.config.access_policy_notes;
    policyNotesText.val(policyNotes);

};

HostMetadataComponent.save = function() {
    var roleSel = $('#node_role_select');
    var accessPolicySel = $('#access_policy');
    var policyNotesText = $('#node_access_policy_notes');

    var data = {};
    data.access_policy = accessPolicySel.val();
    data.access_policy_notes = policyNotesText.val();
    data.role = roleSel.val();
    data.communities = CommunityUpdateComponent.getSelectedCommunities();

    var adminInfoData = HostMetadataComponent.getAdminInfoData();
    $.extend(data, adminInfoData);

    HostAdminStore.saveMetadata( data );

};

HostMetadataComponent.getAdminInfoData = function() {
    var data= {};
    data.organization_name = $("#admin_organization_name").val();
    data.admin_name = $("#admin_name").val();
    data.admin_email = $("#admin_email").val();
    data.city = $("#admin_city").val();
    data.country = $("#admin_country").val();
    if ( $("#admin_states").is(":visible") ) {
        data.state = $("#admin_states").val();
    } else {
        data.state = $("#admin_state").val();
    }
    data.postal_code = $("#admin_postal_code").val();
    data.latitude = $("#admin_latitude").val();
    data.longitude = $("#admin_longitude").val();

    return data;
};

HostMetadataComponent.initialize();

