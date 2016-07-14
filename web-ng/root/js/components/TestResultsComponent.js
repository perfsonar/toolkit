/* Requires: TestStore, d3
 * 
*/
var TestResultsComponent = {
    test_list: null,
    test_list_topic: 'store.change.test_list',
    tests_topic: 'store.change.tests',
    tests_error_topic: 'store.change.tests_error',
    test_list_error_topic: 'store.change.test_list_error',
    inactive_threshold: (new Date() / 1000) - 86400 * 7, // now minus 7 days
    ma_url: 'http://localhost/esmond/perfsonar/archive/',
    testListSet: false,
    testListError: false,
    testDataSet: false,
    testsDataError: false,
    data: {},
};

$.urlParam = function(name){
    var results = new RegExp('[\?&]' + name + '=([^&#]*)').exec(window.location.href);
    if (results == null){
       return null;
    }
    else{
       return results[1] || 0;
    }
};

TestResultsComponent.initialize = function() {
    TestResultsComponent.data = {};
    $('#test-loading-modal').show();
    var ma_url = TestStore.getMAURL();
    TestResultsComponent.ma_url = ma_url;
    TestResultsComponent._registerHelpers();
    Dispatcher.subscribe(TestResultsComponent.test_list_topic, TestResultsComponent._setTestList);
    Dispatcher.subscribe(TestResultsComponent.tests_error_topic, TestResultsComponent._setTestDataError);
    Dispatcher.subscribe(TestResultsComponent.tests_topic, TestResultsComponent._handleTestData);
    Dispatcher.subscribe(TestResultsComponent.test_list_error_topic, TestResultsComponent._setTestListError);
};

// When the test list has been obtained by TestStore, put it in the table, then have TestStore get the test results.
TestResultsComponent._setTestList = function( ) {
    //$('#test-loading-modal').foundation('reveal', 'close');
    $('#test-loading-modal').hide();
    if ($('#num_test_results').length == 0 || $('#num_test_results_holder').length == 0 || $("#test_results").length == 0) {
        console.log("didn't find the template or holder");
        return;
    }
    var data = TestResultsComponent.data; // empty right now

    // get test list from TestStore
    data.test_results = TestStore.getTestList();
    TestResultsComponent.testListSet = true;
    for(var i=0; i<data.test_results.length; i++) {
        data.test_results[i].rowID = i;
    }
    data.test_results.sort(SortBySrcDst);

    data.ma_url = encodeURIComponent(TestResultsComponent.ma_url);

    data.num_test_results = data.test_results.length || 'No';
    $('#num_test_results').html(data.num_test_results);
    $('#num_test_results_holder').show();

    var test_results_template = $("#test-results-template").html();
    var template = Handlebars.compile(test_results_template);
    data.summaryDataError = TestResultsComponent.testsDataError;
    var test_results = template(data);
    // put the list of tests on the page
    $("#test_results").html(test_results);

    // select the proper value in the timeperiod dropdown
    $('#summary_timeperiod').val(TestStore.getTimeperiod());  


    // make existing table into a DataTable (gets cell values from DOM)
    // This adds pagination, sorting, and searching.
    var testResultsDataTable = $('#testResultsTable').DataTable( {
        stateSave:  true,
        columnDefs: [
            { "targets": [2,3,4], searchable: false },
            { "targets": [2,3,4], orderable: false }
        ]
    } );

    // ask TestStore to get averages for those tests on the current current pg
    // When it's finished, _handleTestData/_setTestData will be executed.
    TestResultsComponent._askForTestData();

    // add traceroute links (ask for test data first, so ajax can get started)
    for (var i in data.test_results) {
        var row = data.test_results[i];
        var container_id = "trace_" + TestResultsComponent.ipToID(row.source_ip) + "_"
            + TestResultsComponent.ipToID(row.destination_ip);
        TestResultsComponent.setTracerouteLink(row.source_ip, row.destination_ip, container_id);
    }

    // After a change of the table page, sorting, or search, additional test data may need to be obtained
    $('#testResultsTable').on( 'draw.dt', function() {
        TestResultsComponent._askForTestData();
    } );

    // If the timeperiod selection changes, start over
    $('#summary_timeperiod').change( function() {
        // put data cells back to "loading values..."
        var rows_el = $("#testResultsTable tr");
        rows_el.addClass('no_data');
        rows_el.removeClass('data');
        // reload the list of tests (and their averages)
        var timeperiod = $('#summary_timeperiod').val();
        TestStore.reloadTestTable( timeperiod );  
    } );

};

// Ask TestStore to get test results/averages for those tests on the currently showing pg. 
TestResultsComponent._askForTestData = function() {
    var sources = []; 
    var destinations = [];
    // Source IP's are assumed to be in the first table column, in div with class=host_ip, destinations in the 2nd col.
    $('#testResultsTable').find('tr').each( function() {
        var IP = $(this).find("td").eq(0).find("div.host_ip").html();
        if (IP) {
            sources.push(IP);
        }
        IP = $(this).find("td").eq(1).find("div.host_ip").html();
        if (IP) {
            destinations.push(IP);
        }
    } );
    TestStore.retrieveNeededTestAvgs(sources, destinations);
}

// When avg values have been obtained by TestStore, put them in the table.
TestResultsComponent._handleTestData = function( ) {
    var data = TestResultsComponent.data;
    var test_data = TestStore.getTests();
    data.test_data = test_data;
    TestResultsComponent.testDataSet = true;
    TestResultsComponent._setTestData();
};
TestResultsComponent._setTestData = function( ) {
    // We only want to set the test summary data if we already have the listing
    if ( !TestResultsComponent.testListSet || !TestResultsComponent.testDataSet ) {
        return;
    }
    var data = TestResultsComponent.data;
    var test_data = data.test_data;
    var test_list = data.test_results;

    var table_sel = "#testResultsTable";
    var table_el = $( table_sel );
    var rows_el = $("#testResultsTable tr.no_data");
    rows_el.addClass('data');
    rows_el.removeClass('no_data');

    var test_data_template = $("#test-data-value-template").html();
    var template = Handlebars.compile(test_data_template);

    for(var i=0; i<test_list.length; i++) {
        var test = test_list[i];
        var success = TestResultsComponent._setSingleTestData( test, test_data, template );
    }

};

// Helper function that sets the stats data for ONE test
TestResultsComponent._setSingleTestData = function ( test, test_data, template ) {
    var source = test.source;
    var dest = test.destination;
    var result = $.grep(test_data, function(e){ 
        return ( (e.source_ip == source && e.destination_ip == dest) || ( e.source_ip == dest && e.destination_ip == source) );
    });

    if (result.length == 0) {
        // not found
        // there isn't much we can do in this case
    } else if (result.length == 1) {
        // access the first (and only) element 
        result = result[0];
        var types = [ "throughput", "latency", "loss"  ];
        for(var i in types) {
            var type = types[i];
            result.type = type;
            var test_data_template = template(result);
            $("tr#test_row_" + test.rowID + " td.test-values." + type).html(test_data_template);
        }

    } else {
        // multiple items found
        // this shouldn't happen
        //console.log("multiple test data found, this should not happen");
    }

};


function SortBySrcDst(a, b){
    var aHost = a.source_host + '0' + a.destination_host;
    var bHost = b.source_host + '0' + b.destination_host;
    return ((aHost < bHost) ? -1 : ((aHost > bHost) ? 1 : 0));
}

TestResultsComponent._setTestListError = function( topic, errorThrown ) {

    $("span#testDataErrorBox").show();
    var error = "Error loading test listing: ";
    error += errorThrown;
    if ( errorThrown == "timeout" ) {
        error += " (this usually means you have too many results to show the list)";
    }
    $("span#testDataErrorMessage").text(error);
    TestResultsComponent.testListError = true;
    $('#test-loading-modal').hide();

};

TestResultsComponent._setTestDataError = function( topic, errorThrown ) {
    // If the test listing didn't load, we can't load the summary data either
    if ( TestResultsComponent.testListError ) {
        return;
    }

    $("span#testDataErrorBox").show();
    var error = "Error loading detailed test summary data: ";
    error += errorThrown;
    if ( errorThrown == "timeout" ) {
        error += " (this usually means you have too many results to show a detailed summary)";
    }
    $("span#testDataErrorMessage").text(error);
    TestResultsComponent.testsDataError = true;

};


TestResultsComponent._registerHelpers = function() {
    Handlebars.registerHelper ("formatValue", function (value, type) {
        return TestResultUtils.formatValue(value, type);
    });
    Handlebars.registerHelper ("ipToID", function (ip) {
        return TestResultsComponent.ipToID(ip);
    });
    $(document).on('close.fndtn.reveal', '[data-reveal]', function () {
          var modal = $(this);
          var id = modal.attr("ID");
          if ( /^dialogGraph\d+/.test(id)) {
              TestResultsComponent.clearContainer('#' + id);
          }
    });
};

TestResultsComponent.ipToID = function(ip) {
    var ret = ip;
    ret = ret.replace(/\./g, '_');
    ret = ret.replace(/:/g, '_');
    return ret;
};

// onclick="showResultsGraph({{source_host}}, {{destination_host }}, {{../ma_url}})">
    // test-results-graph-iframe
//
TestResultsComponent.showResultsGraph = function(container, src, dst, ma_url, rowID) {
    // first, clear the URL of the existing iframe
//$("#test-results-graph-iframe").attr('src', '');
    TestResultsComponent.clearContainer(container);
    var url = "/perfsonar-graphs/graphWidget.cgi?source=" + src;
    url += "&dest=" + dst + "&url=" + ma_url;

     $('<iframe />', {
        name: 'Graph Frame',
        id:   'test-results-graph-iframe-' + rowID,
        src: url,
        width: '100%',
        height: '692px'
        //height: '80%'
    }).appendTo(container);

     var close_link = '<a class="close-reveal-modal" aria-label="Close" onclick="TestResultsComponent.closeFrame(\'#test-results-graph-iframe-' + rowID + '\')">&#215;</a>';
     $(close_link).appendTo(container);
    
    return false; 
};

TestResultsComponent.closeFrame = function(iframe) {
    TestResultsComponent.clearFrame(iframe);
};

TestResultsComponent.clearContainer = function(container) {
    if ( $(container).length > 0) {
        $(container).empty();
    } 
};

TestResultsComponent.clearFrame = function(iframe) {
    if (iframe === undefined) {
        iframe = '#test-results-graph-iframe-dynamic';
    }
    $(iframe).src = '';
    $(iframe).remove();
};

TestResultsComponent.setTracerouteLink = function(source_ip, dest_ip, container_id) {
    var ma_url = TestResultsComponent.ma_url;
    var container = $('#' + container_id);
    var link = $('#' + container_id + ' a.traceroute_link');
    var tr_url = '/perfsonar-graphs/graphData.cgi?action=has_traceroute_data&url=' + ma_url
            + '&source=' + source_ip + '&dest=' + dest_ip;
    $.ajax({
        url: tr_url,
        type: 'GET',
        contentType: "application/json",
        success: function(trace_data) {
            if (typeof trace_data !== "undefined") {
                if (typeof trace_data.has_traceroute !== "undefined" && trace_data.has_traceroute == 1) {
                    var trace_url = '/perfsonar-traceroute-viewer/index.cgi?';
                    trace_url += '&mahost=' + trace_data.ma_url;
                    trace_url += '&stime=yesterday';
                    trace_url += '&etime=now';
                    //trace_url += '&tzselect='; // Commented out (allow default to be used)
                    trace_url += '&epselect=' + trace_data.traceroute_uri;
                    trace_url += '';

                    link.attr("href", trace_url);
                    container.addClass('has_traceroute');
                } else {
                    container.removeClass('has_traceroute');
                    link.attr("href", "");
                }
            }

        },
        error: function (jqXHR, textStatus, errorThrown) {
            console.log(errorThrown);
        }
    });

};

TestResultsComponent.initialize();

