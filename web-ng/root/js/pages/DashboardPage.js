// make sure jquery, Dispatcher, TestStore, TestResultsComponent, 
// HostStore, HostServicesComponent and HostInfoComponent all load before this.

var DashboardPage = { 
    dashboardTopics: [],
    numTopics: 0
};

DashboardPage.initialize = function() {
    //if (!HostStore.hostSummary.summarySet) {
        $('#loading-modal').foundation('reveal', 'open');
    //}
    DashboardPage.dashboardTopics = [
        'store.change.host_details',
        'store.change.host_info',
        'store.change.host_services',
        // for now, let's allow the loader to clear even if the tests
        // have not yet loaded
        //'store.change.tests'
    ];
    DashboardPage._setTopics();
};

DashboardPage._setTopics = function() {
    for (var i=0; i<DashboardPage.dashboardTopics.length; i++) {
        var topic = DashboardPage.dashboardTopics[i];
        Dispatcher.subscribe(topic, DashboardPage._dataStoreReturned);
        DashboardPage.numTopics++;
    }
};

DashboardPage._dataStoreReturned = function(topic, data) {
    DashboardPage.numTopics--;
    if (DashboardPage.numTopics == 0) {
        $('#loading-modal').foundation('reveal', 'close');
    }
};

/*
$( document ).on( "pagechange", function() {
        //$('#loading-modal').foundation('reveal', 'close');
        $('#loading-modal').hide(); 
             });
*/
DashboardPage.initialize();
