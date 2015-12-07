// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)
// load first:
// HostMetadataStore.js, HostDetailsStore.js, HostHealthStore.js, HostServicesStore.js 
// HostStore.js

var HostAdminStore = {
    adminInfoTopic: 'store.change.host_info',
    detailsTopic: 'store.change.host_details',
    servicesTopic: 'store.change.host_services',
    summaryTopic: 'store.change.host_summary',
    saveAdminInfoTopic: 'store.host_admin_info.save',
    saveAdminInfoErrorTopic: 'store.host_admin_info.save_error',
    saveMetadataTopic: 'store.host_metadata.save',
    saveMetadataErrorTopic: 'store.host_metadata.save_error',
    saveServicesTopic: 'store.host_services.save',
    saveServicesErrorTopic: 'store.host_services.save_error',
    saveCommunitiesTopic: 'store.communities_host.save',
    saveCommunitiesErrorTopic: 'store.communities_host.save_error',
    ntpInfoTopic: 'store.change.ntp_config',
    saveNTPConfigTopic: 'store.ntp_config.save',
    saveNTPConfigErrorTopic: 'store.ntp_config.save_error',
    saveAutoUpdatesTopic: 'store.auto_updates.save',
    saveAutoUpdatesErrorTopic: 'store.auto_updates.save_error',
};

HostAdminStore.saveAdminInfo = function(info) {
    var topic = HostAdminStore.saveAdminInfoTopic;
    var error_topic = HostAdminStore.saveAdminInfoErrorTopic;
    $.ajax({
        url: 'services/host.cgi?method=update_info',
        type: 'POST',
        data: info,
        dataType: 'json',
        contentType: 'application/x-www-form-urlencoded',
        success: function(result) {
            HostMetadataStore._retrieveInfo();
            Dispatcher.publish(topic, result.message);
        },
        error: function(jqXHR, textStatus, errorThrown) {
            Dispatcher.publish(error_topic, errorThrown);
        }
    });


};

HostAdminStore.saveMetadata = function( data ) {
    var topic = HostAdminStore.saveMetadataTopic;
    var error_topic = HostAdminStore.saveMetadataErrorTopic;
    $.ajax({
        url: 'services/host.cgi?method=update_metadata',
        type: 'POST',
        data: data,
        dataType: 'json',
        contentType: 'application/x-www-form-urlencoded',
        success: function(result) {
            HostMetadataStore._retrieveMetadata();
            Dispatcher.publish(topic, result.message);

        },
        traditional: true, // so we pass role array as two role args, not role[]
        error: function(jqXHR, textStatus, errorThrown) {
            Dispatcher.publish(error_topic, errorThrown);
        }
    });
};

HostAdminStore.saveServices = function(services) {
    var topic = HostAdminStore.saveServicesTopic;
    var error_topic = HostAdminStore.saveServicesErrorTopic;
    $.ajax({
        url: 'services/host.cgi?method=update_enabled_services',
        type: 'POST',
        data: services,
        dataType: 'json',
        contentType: 'application/x-www-form-urlencoded',
        success: function(result) {
            HostServicesStore._retrieveServices();
            Dispatcher.publish(topic, result.message);

        },
        error: function(jqXHR, textStatus, errorThrown) {
            Dispatcher.publish(error_topic, errorThrown);
        }
    });
};

HostAdminStore.saveAutoUpdates = function( data ) {
    var topic = HostAdminStore.saveAutoUpdatesTopic;
    var error_topic = HostAdminStore.saveAutoUpdatesErrorTopic;
    $.ajax({
        url: 'services/host.cgi?method=update_auto_updates',
        type: 'POST',
        data: data,
        dataType: 'json',
        contentType: 'application/x-www-form-urlencoded',
        success: function(result) {
            HostDetailsStore._retrieveDetails();
            Dispatcher.publish(topic, result.message);

        },
        error: function(jqXHR, textStatus, errorThrown) {
            Dispatcher.publish(error_topic, errorThrown);
        }
    });


};

HostAdminStore.saveCommunities = function( communities_arr ) {
    var topic = HostAdminStore.saveCommunitiesTopic;
    var error_topic = HostAdminStore.saveCommunitiesErrorTopic;
    //var communities_str = communities_arr.join(',');
    var communities = { communities: communities_arr };
    communities = JSON.stringify(communities);
    $.ajax({
        url: 'services/communities.cgi?method=update_host_communities',
        type: 'POST',
        data: communities,
        dataType: 'json',
        contentType: "application/json",
        //contentType: 'application/x-www-form-urlencoded',
        success: function(result) {
            HostMetadataStore._retrieveMetadata();
            CommunityAllStore._retrieveCommunities();
            Dispatcher.publish(topic, result.message);

        },
        error: function(jqXHR, textStatus, errorThrown) {
            Dispatcher.publish(error_topic, errorThrown);
        }
    });


};

HostAdminStore.saveNTP = function( ntp_conf ) {
    ntp_conf = JSON.stringify(ntp_conf);
    var topic = HostAdminStore.saveNTPConfigTopic;
    var error_topic = HostAdminStore.saveNTPConfigErrorTopic;
    $.ajax({
        url: 'services/ntp.cgi?method=update_ntp_configuration',
        type: 'POST',
        data: ntp_conf,
        dataType: 'json',
        //contentType: 'application/x-www-form-urlencoded',
        contentType: "application/json",
        success: function(result) {
            NTPConfigStore._retrieveNTPConfig();
            Dispatcher.publish(topic, result.message);

        },
        error: function(jqXHR, textStatus, errorThrown) {
            Dispatcher.publish(error_topic, errorThrown);
        }
    });


};

