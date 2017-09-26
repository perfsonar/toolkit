// assumes stores/DataStore has already been loaded

var CommunityHostsStore = new DataStore("store.change.test_by_community", "services/communities.cgi?method=get_hosts_in_community", false);

CommunityHostsStore.baseurl = CommunityHostsStore.url;

CommunityHostsStore.getHostByCommunity = function ( community, testType, cacheURL ) {
    var url = CommunityHostsStore.baseurl;
    url += '&community=' + encodeURIComponent(community);
    if (testType ) {
       url += '&test_type=' + encodeURIComponent(testType);
    }
    if ( cacheURL ) {
        url += '&cache=' + cacheURL;

    }
    CommunityHostsStore.url = url;
    CommunityHostsStore._retrieveData();

};

