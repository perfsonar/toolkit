var HostMetadataComponent = {
    metadata_topic: 'store.change.host_metadata',
    rolePlaceholder: 'Select a node role',
    policyPlaceholder: 'Select an access policy',
    allRoles: [ 
        {id: 'exchange-point', text: 'Exchange Point'}, 
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
};

HostMetadataComponent._setMetadata = function( topic ) {
    var data = HostMetadataStore.getHostMetadata();
    console.log('metadata component data', data);
    var allRoles = HostMetadataComponent.allRoles;
    console.log('allRoles', allRoles);
    console.log('allAccessPolicies', HostMetadataComponent.allAccessPolicies);
    var selectedRoles = data.config.role;   
    var roleValues = SharedUIFunctions.getSelectedValues( allRoles, selectedRoles );  
    console.log('roleValues returned from function', roleValues);
    
    var roleSel = $('#node_role_select');
    roleSel.select2( { 
        placeholder: HostMetadataComponent.rolePlaceholder,
        data: roleValues,
    });

    var allAccessPolicies = HostMetadataComponent.allAccessPolicies;
    var selectedAccessPolicies = data.config.access_policy;
    var accessPolicyValues = SharedUIFunctions.getSelectedValues( allAccessPolicies, selectedAccessPolicies );
    console.log('accessPolicyValues', accessPolicyValues);

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

HostMetadataComponent.initialize();

