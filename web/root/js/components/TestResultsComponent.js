var TestResultsComponent = {
    test_list: null,
    test_list_topic: 'store.change.test_list',
    tests_topic: 'store.change.tests',
    inactive_threshold: (new Date() / 1000) - 86400 * 7 // now minus 7 days
};


TestResultsComponent.initialize = function() {
    TestResultsComponent._registerHelpers();
    Dispatcher.subscribe(TestResultsComponent.tests_topic, TestResultsComponent._setTestResults);
};


TestResultsComponent._setTestResults = function( topic ) {
    var data = {};
    data.test_results = TestStore.getTests();
    data.ma_url = ''; // TODO: complete ma_url

    var test_results_template = $("#test-results-template").html();
    var template = Handlebars.compile(test_results_template);
    var test_results = template(data);
    $("#test_results").html(test_results);

};

TestResultsComponent._registerHelpers = function() {
    Handlebars.registerHelper ("formatValue", function (value, type) {
       return TestResultUtils.formatValue(value, type);
    });
};

TestResultsComponent.initialize();

