// Make sure jquery loads first
// assues Dispatcher has already been declared (so load that first as well)

// the default timeperiod (actually "timeperiod,summary_window") is 1-week,1day.
var TestStore = {
    testList: null,
    tests: null,
    ma_url: 'http://localhost/esmond/perfsonar/archive/',
    ma_url_enc: null,
    timeperiod: "604800,86400",
    testSummary: {},
    existingTestResults: null
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
    // just get the list of tests. Rest will follow automatically.
    var ma_url = $.urlParam('url') || TestStore.ma_url;
    TestStore.ma_url = ma_url;
    TestStore.ma_url_enc = encodeURIComponent(ma_url);
    TestStore._retrieveList();

    //this seems to have been redundant?? : TestStore._createSummaryTopic();
    TestStore.testSummary.data = {};
    TestStore.testSummary.listSet = false;
    TestStore.testSummary.testsSet = false;
    TestStore.testSummary.summarySet = false;
};


TestStore.reloadTestTable = function( timeperiod ) {
    // Reload list of tests if a different timeperiod is chosen.
    // New results will follow automatically.
    TestStore.testList = null;
    TestStore.tests = null;
    if (timeperiod) {
        TestStore.timeperiod = timeperiod;
    }
    TestStore._retrieveList(); 
};

TestStore.retrieveNeededTestAvgs = function(sources, destinations) {
    // Get test results for given sources and destinations, but only those we need to. 
    // See if we have results for some tests already in TestStore.tests.
    var sourcesToDo = [];
    var destsToDo = [];
    if (TestStore.tests) {
        TestStore.existingTestResults = TestStore.tests;
        for (var i=0; i<sources.length; i++) {
            var alreadyDone = 0;
            for (var e=0; e<TestStore.existingTestResults.length; e++) {
                var existingSource = TestStore.existingTestResults[e].source_ip;
                var existingDest = TestStore.existingTestResults[e].destination_ip;
                if ( sources[i] == existingSource && destinations[i] == existingDest ) { 
                    alreadyDone = 1;
                    break;
                }
            }
            if (! alreadyDone) {
                sourcesToDo.push(sources[i]);
                destsToDo.push(destinations[i]);
            }
        }
    } else {
        // there are no existing test results
        sourcesToDo = sources;
        destsToDo = destinations;
    }

    if (sourcesToDo.length > 0) {
        // don't retrieveTests if there are no sources and destinations or it'll get ALL test results.
        TestStore._retrieveTests(sourcesToDo, destsToDo);
        // now TestStore.tests contains the latest test results merged with the previous results.
    }
};

TestStore._retrieveList = function() {
        var the_url = "/perfsonar-graphs/graphData.cgi?action=test_list&timeperiod=" + TestStore.timeperiod 
                + "&url=" + TestStore.ma_url_enc;
        $.ajax({
            url: the_url,
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                TestStore.testList = data;
                Dispatcher.publish('store.change.test_list');
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log("Error retrieving test list: " + errorThrown);
                Dispatcher.publish('store.change.test_list_error', errorThrown);
            },
            //timeout: 3000, // sets timeout to 3 seconds
        });
};

TestStore._retrieveTests = function(sources, destinations) {
    var the_url = "/perfsonar-graphs/graphData.cgi?action=tests&timeperiod=" + TestStore.timeperiod
                + "&url=" + TestStore.ma_url_enc;
    for (var i=0; i<sources.length; i++) {
        the_url += '&src='+sources[i]+';dest='+destinations[i];
    }
console.log("GETTING RESULTS FOR "+the_url);
    $.ajax({
            url: the_url,
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                TestStore.tests = data;
                // if we're getting additional test data, add the old results back in.
                if (TestStore.existingTestResults) {
                    TestStore.tests = TestStore.existingTestResults.concat(TestStore.tests);
                    TestStore.existingTestResults = null;
                }
                Dispatcher.publish('store.change.tests');
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log( " Error retrieving test data: " + errorThrown);
                Dispatcher.publish('store.change.tests_error', errorThrown);
            },
            //timeout: 3000, // sets timeout to 3 seconds
        });
};

TestStore._retrieveServices = function() {
    $.ajax({
            url: "services/host.cgi?method=get_services",
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                TestStore.hostServices = data;
                Dispatcher.publish('store.change.host_services');
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
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
TestStore.getTimeperiod = function() {
    return TestStore.timeperiod;
};

TestStore.initialize();
