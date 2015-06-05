// Make sure jquery loads first
// assues Dispatcher has already been declared (so load that first as well)

var TestStore = {
    testList: null,
    tests: null,
    ma_url: 'http://localhost/esmond/perfsonar/archive/',
    ma_url_enc: null,
    testSummary: {}
};

// TODO: move $.urlParam to a common utility library
$.urlParam = function(name){
    var results = new RegExp('[\?&]' + name + '=([^&#]*)').exec(window.location.href);
    if (results==null){
       return null;
    }
    else{
       return results[1] || 0;
    }
};

TestStore.initialize = function() {
    var ma_url = $.urlParam('url') || TestStore.ma_url;
    TestStore.ma_url = ma_url;
    TestStore.ma_url_enc = encodeURIComponent(ma_url);
    TestStore._retrieveList();
    TestStore._retrieveTests();
    TestStore._createSummaryTopic();
    TestStore.testSummary.data = {};
    TestStore.testSummary.listSet = false;
    TestStore.testSummary.testsSet = false;
    TestStore.testSummary.summarySet = false;
};

TestStore._retrieveList = function() {
        $.ajax({
            url: "/serviceTest/graphData.cgi?action=test_list&url=" + TestStore.ma_url_enc,
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                TestStore.testList = data;
                Dispatcher.publish('store.change.test_list');
            },
            error: function (jqXHR, textStatus, errorThrown) {
                alert(errorThrown);
            }
        });
};

TestStore._retrieveTests = function() {
    $.ajax({
            url: "/serviceTest/graphData.cgi?action=tests&url=" + TestStore.ma_url_enc,
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                TestStore.tests = data;
                Dispatcher.publish('store.change.tests');
            },
            error: function (jqXHR, textStatus, errorThrown) {
                alert(errorThrown);
            }
        });
};

TestStore._retrieveServices = function() {
    $.ajax({
            url: "/toolkit-ng/services/host.cgi?method=get_services",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                TestStore.hostServices = data;
                Dispatcher.publish('store.change.host_services');
            },
            error: function (jqXHR, textStatus, errorThrown) {
                alert(errorThrown);
            }
        });
};

TestStore._createSummaryTopic = function() {
    Dispatcher.subscribe('store.change.test_list', TestStore._setSummaryData);
};

TestStore._setSummaryData = function (topic, data) {
    if (topic == 'store.change.test_list') {
        var data = TestStore.getTestList();
        jQuery.extend(TestStore.testSummary.data, data);
        TestStore.testSummary.listSet = true;
    } 
    if (TestStore.testSummary.listSet) {
        TestStore.testSummary.summarySet = true;
        Dispatcher.publish('store.change.test_summary');
    }    
};

TestStore.getTests = function() {
    return TestStore.tests;
};
TestStore.getTestList = function() {
    return TestStore.testList;
};
TestStore.getHostSummary = function() {
    return TestStore.testSummary.data;
};
TestStore.getMAURL = function() {
    return TestStore.ma_url;
};

TestStore.initialize();
