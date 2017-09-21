// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)
// psShared also needs to be loaded first

var LSCacheStore = psShared.LSCacheStore;

var CommunityAllStore = {
    communityDetails: null,
    communityAllTopic: 'store.change.communities_all',
};

CommunityAllStore.getValues = function() {
    var communities = LSCacheStore.getCommunities();
    
    // format like "key": 0
    // as this is the format other places expect

    var out = {};
    for(var i in communities) {
        var comm = communities[i];
        out[comm] = 0;
    }

    var structured = {
        "keywords": out
    };
    console.log("out", structured);
    CommunityAllStore.communityDetails = structured;
    Dispatcher.publish(CommunityAllStore.communityAllTopic);

};

CommunityAllStore.retrieveCommunities = function() {
    var message = "communities";
    var callback = CommunityAllStore.getValues;
    LSCacheStore.subscribeTag( callback, message );
    LSCacheStore.retrieveCommunities();

};

CommunityAllStore.initialize = function() {
    var callback = CommunityAllStore.retrieveCommunities;
    LSCacheStore.subscribeLSCaches( callback );

};

CommunityAllStore.getAllCommunities = function() {
    return CommunityAllStore.communityDetails;
};

CommunityAllStore.initialize();
