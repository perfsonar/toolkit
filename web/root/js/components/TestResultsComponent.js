var TestResultsComponent = {
    test_list: null,
    test_list_topic: 'store.change.test_list',
};


TestResultsComponent.initialize = function() {
    Dispatcher.subscribe(TestResultsComponent.test_list_topic, TestResultsComponent._setTestResults);
};


TestResultsComponent._setTestResults = function( topic ) {
    var data = {};
    data.test_results = TestStore.getTestList();

    console.log("setting test results; data: ");
    console.log(data);

    var test_results_template = $("#test-results-template").html();
    //console.log("test results template " + test_results_template);
    var template = Handlebars.compile(test_results_template);
    var test_results = template(data);
    $("#test_results").html(test_results);

};

TestResultsComponent.initialize();

