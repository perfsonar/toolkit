// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)
// TODO: DELETE THIS ENTIRELY. FUNCTIONALITY HAS MOVED TO HostMetadataStore.

var CommunityHostStore = {
    communityDetails: null,
    communityHostTopic: 'store.change.communities_host',
};

CommunityHostStore.initialize = function() {
    CommunityHostStore._retrieveCommunities();
    
};

CommunityHostStore._retrieveCommunities = function() {
    $.ajax({
            url: "services/communities.cgi?method=get_host_communities",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                CommunityHostStore.communityDetails = data;
                Dispatcher.publish(CommunityHostStore.communityHostTopic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
};

CommunityHostStore.getHostCommunities = function() {
    return CommunityHostStore.communityDetails;
};

CommunityHostStore.initialize();
