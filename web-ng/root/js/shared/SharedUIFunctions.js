/* This library contains shared functions to be used in the GUI
 *
 * */
var SharedUIFunctions = {
    formChangeTopic: 'ui.form.change',
    formSuccessTopic: 'ui.form.success',
    formErrorTopic: 'ui.form.error',
    formCancelTopic: 'ui.form.cancel',
};

/*
 * SharedUIFunctions.setSelect2Values( allValues, selectedValues )
 * Description: Creates the datastructure to pass to a select2 box in the format
 * {id: 'idNameorNumber', text: 'text', selected: bool}
 * The 'selected' portion is optional'
 * Arguments:
 *      * allValues - an array of hashes containing all available values for the select2 box. 
 *          In the same format as the return but without the 'selected' field
 *      * selectedValues - an optional string containing one value to select, or an array containing
 *          all values to be selected.
 * Return value:
 *      * Returns an array of hashes in the format [ {id: 'idNameorNumber', text: 'text', selected: bool} ]
 *      * If no values, return an empty array
 */

SharedUIFunctions.getSelectedValues = function( allValues, selectedValues ) { 
    for(var i in allValues) {
        var currentName = allValues[i].id;
    
        if ( typeof selectedValues != 'undefined' ) {
            if ( typeof selectedValues == 'string' ) {
                selectedValues = [ selectedValues ];
            } 
            for (var j in selectedValues) {
                var selectedName = selectedValues[j];
                if ( selectedName == currentName ) {
                    allValues[i].selected = true;
                    continue;
                }
            }        
        }
    } 
    return allValues;
}; 


SharedUIFunctions._saveSuccess = function( topic, message ) {
    Dispatcher.publish(SharedUIFunctions.formSuccessTopic, message);
};

SharedUIFunctions._saveError = function( topic, message ) {
    Dispatcher.publish(SharedUIFunctions.formErrorTopic, message);
};

SharedUIFunctions._cancel = function() {
    Dispatcher.publish(SharedUIFunctions.formCancelTopic);
    Dispatcher.publish(SharedUIFunctions.info_topic);

};

SharedUIFunctions._showSaveBar = function() {
    Dispatcher.publish(SharedUIFunctions.formChangeTopic);
};

// takes a variable as its argument, and returns it as an array
// typically this is useful if you don't know whether a value will be a string 
// or an array of strings, for example.
// returns null if undefined
SharedUIFunctions._getAsArray = function( value ) {
    if (typeof value == 'string' || typeof value == 'number') {
        return [ value ];
    } else {
        return value;
    }

};

// Returns text based on the state of the boolean
// Returns "Enabled" if true or "Disabled" if false
SharedUIFunctions.getLabelText = function ( state ) {
    return state ? 'Enabled' : 'Disabled';
};


Handlebars.registerHelper("everyOther", function (index, amount, scope) {
    if ( ++index % amount ) 
        return scope.inverse(this);
    else 
        return scope.fn(this);
});

SharedUIFunctions.getSecondsFromFields = function( valueID, unitID ) {

};

SharedUIFunctions.getUrlParameter = function ( paramName ) {
    var pageURL = decodeURIComponent(window.location.search.substring(1));
    var URLVariables = pageURL.split('&');

    var parameterName;
    for (var i = 0; i < URLVariables.length; i++) {
        parameterName = URLVariables[i].split('=');

        if (parameterName[0] === paramName) {
            return parameterName[1] === undefined ? true : parameterName[1];
        }
    }
};


SharedUIFunctions.setUrlParameter = function ( paramName, value ) {
    var pageURL = decodeURIComponent(window.location.search.substring(1));
    var URLVariables = pageURL.split('&');

    var parameterName;
    for (var i = 0; i < URLVariables.length; i++) {
        parameterName = URLVariables[i].split('=');
        console.log('parameterName', parameterName, 'value', value);

        if (parameterName[0] === paramName) {
            parameterName[0] = value;
            console.log('parameterName after setting', parameterName, 'value', value);

            var param = {};
            param.view = value;
            console.log('param', param);



            return true;
            //return parameterName[1] === undefined ? true : parameterName[1];
        }
    }
};

SharedUIFunctions.addQueryStringParameter = function(name, value) {
    var url = window.location.href;
    console.log('url', url);
    var re = new RegExp("([?&]" + name + "=)[^&]+", "");

    function add(sep) {
        url += sep + name + "=" + encodeURIComponent(value);
    }

    function change() {
        url = url.replace(re, "$1" + encodeURIComponent(value));
    }
    if (url.indexOf("?") === -1) {
        add("?");
    } else {
        if (re.test(url)) {
            change();
        } else {
            add("&");
        }
    }
    //window.history.pushState("object or string", "View by " + value, url);
    window.history.replaceState("object or string", "View by " + value, url);
};


// Given a time in seconds, reduce to its lowest granularity and return
// formatted value, raw values, and unit text
SharedUIFunctions.getTimeWithUnits = function( seconds ) {
    var granularity;
    var unit;

    if (seconds % 86400 == 0) {
        granularity = 86400;
        unit = 'day';
    } else if (seconds % 3600 == 0) {
        granularity = 3600;
        unit = 'hour';
    } else if (seconds % 60 == 0) {
        granularity = 60;
        unit = 'minute'
    } else {
        granularity = 1;
        unit = 'second';
    }

    var value = seconds / granularity;
    var valueFormatted = value + ' ' + unit;
    if ( value != 1 ) {
        valueFormatted += 's';
    }
    var output = {};
    output.seconds = seconds;
    output.value = value;
    output.valueFormatted = valueFormatted;
    output.unit = unit;

    console.log('timeWithUnits output', output);

    return output;
};
 
   
SharedUIFunctions.generateRandomIntInRange = function( min, max ) {
    var rand = Math.floor(Math.random() * (max - min) + min);
    return rand;
};

// Register a 'compare' helper function for handling conditional 
// comparison of values
// see https://gist.github.com/pheuter/3515945#gistcomment-1378171

Handlebars.registerHelper('compare', function (lvalue, operator, rvalue, options) {

    var operators, result;

    if (arguments.length < 3) {
        throw new Error("Handlerbars Helper 'compare' needs 2 parameters");
    }

    if (options === undefined) {
        options = rvalue;
        rvalue = operator;
        operator = "===";
    }

    operators = {
        '==': function (l, r) { return l == r; },
        '===': function (l, r) { return l === r; },
        '!=': function (l, r) { return l != r; },
        '!==': function (l, r) { return l !== r; },
        '<': function (l, r) { return l < r; },
        '>': function (l, r) { return l > r; },
        '<=': function (l, r) { return l <= r; },
        '>=': function (l, r) { return l >= r; },
        'typeof': function (l, r) { return typeof l == r; }
    };

    if (!operators[operator]) {
        throw new Error("Handlerbars Helper 'compare' doesn't know the operator " + operator);
    }

    result = operators[operator](lvalue, rvalue);

    if (result) {
        return options.fn(this);
    } else {
        return options.inverse(this);
    }

});
