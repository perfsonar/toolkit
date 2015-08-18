// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)
// load first:
// HostAdminInfoStore.js, HostDetailsStore.js, HostHealthStore.js, HostServicesStore.js 
// HostStore.js

var HostAdminStore = {
    adminInfoTopic: 'store.change.host_info',
    detailsTopic: 'store.change.host_details',
    servicesTopic: 'store.change.host_services',
    summaryTopic: 'store.change.host_summary',
    saveAdminInfoTopic: 'store.host_admin_info.save',
    saveAdminInfoErrorTopic: 'store.host_admin_info.save_error',
    saveServicesTopic: 'store.host_services.save',
    saveServicesErrorTopic: 'store.host_services.save_error',
    saveCommunitiesTopic: 'store.communities_host.save',
    saveCommunitiesErrorTopic: 'store.communities_host.save_error',
};

HostAdminStore.saveAdminInfo = function(info) {
    var topic = HostAdminStore.saveAdminInfoTopic;
    var error_topic = HostAdminStore.saveAdminInfoErrorTopic;
    $.ajax({
        url: '/toolkit-ng/admin/services/host.cgi?method=update_info',
        type: 'POST',
        data: info,
        dataType: 'json',
        contentType: 'application/x-www-form-urlencoded',
        success: function(result) {
            HostAdminInfoStore._retrieveInfo();
            Dispatcher.publish(topic, result.message);
        },
        error: function(jqXHR, textStatus, errorThrown) {
            Dispatcher.publish(error_topic, errorThrown);
        }
    });


};

HostAdminStore.saveServices = function(services) {
    var topic = HostAdminStore.saveServicesTopic;
    var error_topic = HostAdminStore.saveServicesErrorTopic;
    $.ajax({
        url: '/toolkit-ng/admin/services/host.cgi?method=update_enabled_services',
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

HostAdminStore.saveCommunities = function( communities_arr ) {
    var topic = HostAdminStore.saveCommunitiesTopic;
    var error_topic = HostAdminStore.saveCommunitiesErrorTopic;
    var communities_str = communities_arr.join(',');
    var communities = { community: communities_str };
    $.ajax({
        url: '/toolkit-ng/services/communities.cgi?method=add_host_communities',
        type: 'POST',
        data: communities,
        dataType: 'json',
        contentType: 'application/x-www-form-urlencoded',
        success: function(result) {
            CommunityHostStore._retrieveCommunities();
            CommunityAllStore._retrieveCommunities();
            Dispatcher.publish(topic, result.message);

        },
        error: function(jqXHR, textStatus, errorThrown) {
            Dispatcher.publish(error_topic, errorThrown);
        }
    });


};

