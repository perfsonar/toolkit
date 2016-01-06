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

Handlebars.registerHelper("everyOther", function (index, amount, scope) {
    if ( ++index % amount ) 
        return scope.inverse(this);
    else 
        return scope.fn(this);
});

SharedUIFunctions.getTime = function(seconds) {

    //a day contains 60 * 60 * 24 = 86400 seconds
    //an hour contains 60 * 60 = 3600 seconds
    //a minute contains 60 seconds
    //the amount of seconds we have left
    var leftover = seconds;

    //how many full days fits in the amount of leftover seconds
    var days = Math.floor(leftover / 86400);

    //how many seconds are left
    leftover = leftover - (days * 86400);

    //how many full hours fits in the amount of leftover seconds
    var hours = Math.floor(leftover / 3600);

    //how many seconds are left
    leftover = leftover - (hours * 3600);

    //how many minutes fits in the amount of leftover seconds
    var minutes = leftover / 60;

    //how many seconds are left
    leftover = leftover - (minutes * 60);

    var output = '';
    output += (days ? days + ' d ' : '');
    output += (hours ? hours + ' hr ' : '');
    output += (minutes ? minutes + ' min ' : '');
    output += (leftover ? leftover + ' s ' : '');
    
    return output;
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
