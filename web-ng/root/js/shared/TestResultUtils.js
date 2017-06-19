// Utility functions for displaying test results
// TODO: remove d3 requirement

var TestResultUtils = {};

TestResultUtils.formatValue = function(value, prefix) {
    var format_str = '';
    var formatted_value;
    var suffix = '';
    if (value !== null && ! isNaN(value)) {
        if ((/^throughput_/).test(prefix)) {
            format_str = '.3s';
            suffix = 'bps';
        } else if ((/^owdelay_/).test(prefix)) {
            format_str = '.2f';
            var re = /^owdelay(_\w{3})$/;
            var match;
            var results;
            if ( match = re.exec(prefix) ) {
                if ( value === null ) {
                    prefix = 'rtt' + match[1];
                    suffix = '(rtt)';
                }
            }
        } else if ((/^rtt_/).test(prefix)) {
            format_str = '.2f';
            suffix = '(rtt)';
        } else if ((/^loss_/).test(prefix)) {
            // may or may not need this - formatting to float based on precision
            // value = parseFloat( value.toPrecision(6) );
            format_str = '.3%';
        }
        var val_prefix = d3.formatPrefix(value, 3);

        if ( (/^owdelay_/).test(prefix) || (/^rtt_/).test(prefix) ) {
            formatted_value = value.toPrecision(3) + " " + suffix;
        } else if ((/^loss_/).test(prefix)) {
            if (value == 0) {
                formatted_value = 0;
            } else  {
                formatted_value = d3.format(format_str)(value);
            }
        } else {
            formatted_value = val_prefix.scale(value).toPrecision(3) + " " + val_prefix.symbol + suffix;
        }
    } else { 
        formatted_value = "n/a";
    }
    return formatted_value;
}

TestResultUtils.formatStats = function(d, prefix, inactive_threshold) {
    var avg = null;
    var min = null;
    var max = null;

    avg = d[prefix + '_average'];
    min = d[prefix + '_min'];
    max = d[prefix + '_max'];

    // If there is no value for 'avg', AND we're looking at the owdelay type,
    // attempt to grab rtt instead
    var re = /^owdelay(_\w{3})$/;
    var match;
    var results;
    if ( avg === null ) {
        if ( match = re.exec(prefix) ) {
            prefix = 'rtt' + match[1];
            avg = d[prefix + '_average'];
            min = d[prefix + '_min'];
            max = d[prefix + '_max'];
        }
    }

    var data = new Array();
    data[0] = new Object();
    data[0].value = TestResultUtils.formatValue(avg, prefix);

    // Account for the last_update field name not including _src or _dst
    prefix = prefix.replace('_src', '');
    prefix = prefix.replace('_dst', '');
    var inactive;
    var last_update_key = prefix + '_last_update';
    if (d[last_update_key] != null && d[last_update_key] < inactive_threshold) {
        inactive = true;
    } else {
        inactive = false;
    }


    data[0].inactive = inactive;
    var ret = TestResultUtils.formatOutput(data);
    return ret;

}; 

TestResultUtils.formatOutput = function(data) {
    var ret = '';
    var inactive_class = '';
    ret += '<table class="grid-value' + inactive_class  + '">';
    for(var d in data) {
        inactive_class = '';
        if (data[d].inactive) {
            inactive_class = ' inactive';
        }
        ret += '<tr class="' + inactive_class + '">';
        ret += '<td>' + 
            '</td><td><span class="psgraph-val">' + 
            ((data[d].value !== null 
              && typeof data[d].value !== 'undefined') 
             ? data[d].value 
             : 'n/a ') 
            +  '</span></td>';
        ret += '</tr>';
    }
    ret += "</table>";
    return ret;
};

TestResultUtils.formatHost = function(d, type, inactive_threshold) {
    var ret = '';
    if (d[type + '_host']) { 
        ret += d[type + '_host'];
    }
    if (d[type + '_ip'] && d[type + '_ip'] != d[type + '_host']) {
        ret += ' (' + d[type + '_ip'] + ') ';
    } else {
        ret = d[type + '_ip'];
    }
    d[type + '_name'] = ret;
    if (d.last_updated < inactive_threshold) {
        ret = '<span class="inactive">' + ret + '</span>';
    }
    return ret;
};

TestResultUtils.formatBoolean = function(val) {
    var ret = '';
    if (val === 1) {
        ret = 'yes';
    } else {
        ret = 'no';
    }
    return ret;
};

