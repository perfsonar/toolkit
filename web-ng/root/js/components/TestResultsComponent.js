/* Requires: TestStore, d3
 * 
*/
var TestResultsComponent = {
    test_list: null,
    test_list_topic: 'store.change.test_list',
    tests_topic: 'store.change.tests',
    inactive_threshold: (new Date() / 1000) - 86400 * 7, // now minus 7 days
    ma_url: 'http://localhost/esmond/perfsonar/archive/'
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
    var ma_url = TestStore.getMAURL();
    TestResultsComponent.ma_url = ma_url;
    TestResultsComponent._registerHelpers();
    Dispatcher.subscribe(TestResultsComponent.tests_topic, TestResultsComponent._setTestResults);
};

TestResultsComponent._setTestResults = function( topic ) {
    if ($('#num_test_results').length == 0 || $('#num_test_results_holder').length == 0 || $("#test_results").length == 0) {
        return;
    }
    var data = {};
    data.test_results = TestStore.getTests();
    for(var i=0; i<data.test_results; i++) {
        data.test_results[i].rowID = i;
    }
    data.ma_url = encodeURIComponent(TestResultsComponent.ma_url);
    data.num_test_results = data.test_results.length || 'None';
    $('#num_test_results').html(data.num_test_results);
    $('#num_test_results_holder').show();
    var test_results_template = $("#test-results-template").html();
    var template = Handlebars.compile(test_results_template);
    var test_results = template(data);
    $("#test_results").html(test_results);
    for (var i in data.test_results) {
        var row = data.test_results[i];
        var container_id = "trace_" + TestResultsComponent.ipToID(row.source_ip) + "_"
            + TestResultsComponent.ipToID(row.destination_ip);
        TestResultsComponent.setTracerouteLink(row.source_ip, row.destination_ip, container_id);
    }
};

TestResultsComponent._registerHelpers = function() {
    Handlebars.registerHelper ("formatValue", function (value, type) {
        return TestResultUtils.formatValue(value, type);
    });
    Handlebars.registerHelper ("ipToID", function (ip) {
        return TestResultsComponent.ipToID(ip);
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
    var url = "/serviceTest/graphWidget.cgi?source=" + src;
    url += "&dest=" + dst + "&url=" + ma_url;
    
     $('<iframe />', {
        name: 'Graph Frame',
        id:   'test-results-graph-iframe-' + rowID,
        src: url,
        width: '100%',
        height: '692px'
        //height: '80%'
    }).appendTo(container);
    
    return false; };

TestResultsComponent.closeFrame = function(iframe) {
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
    var tr_url = '/serviceTest/graphData.cgi?action=has_traceroute_data&url=' + ma_url
            + '&source=' + source_ip + '&dest=' + dest_ip;
    $.ajax({
        url: tr_url,
        type: 'GET',
        contentType: "application/json",
        success: function(trace_data) {
            if (typeof trace_data !== "undefined") {
                if (typeof trace_data.has_traceroute !== "undefined" && trace_data.has_traceroute == 1) {
                    var trace_url = '/toolkit/gui/psTracerouteViewer/index.cgi?';
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

