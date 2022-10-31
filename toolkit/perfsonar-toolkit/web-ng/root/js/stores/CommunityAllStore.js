// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)

var CommunityAllStore = {
    communityDetails: null,
    communityAllTopic: 'store.change.communities_all',
    communityAllErrorTopic: 'store.change.communities_all_error',
};

CommunityAllStore.initialize = function() {
    CommunityAllStore._retrieveCommunities();

};

CommunityAllStore._retrieveCommunities = function() {
    $.ajax({
            url: "services/communities.cgi?method=get_all_communities",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                CommunityAllStore.communityDetails = data;
                Dispatcher.publish(CommunityAllStore.communityAllTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
                Dispatcher.publish(CommunityAllStore.communityAllErrorTopic);
            }
        });
};

CommunityAllStore.getAllCommunities = function() {
    return CommunityAllStore.communityDetails;
};

CommunityAllStore.initialize();
