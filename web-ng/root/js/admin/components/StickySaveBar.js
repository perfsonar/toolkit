var StickySaveBar = {
    formChangeTopic:    'ui.form.change',
    formSubmitTopic:    'ui.form.submit',
    formSuccessTopic:   'ui.form.success',
    formErrorTopic:     'ui.form.error',
    formCancelTopic:    'ui.form.cancel',
    unsavedText: "You've made changes that haven't been saved.",
};


StickySaveBar.initialize = function() {
    Dispatcher.subscribe(StickySaveBar.formChangeTopic,  StickySaveBar._formChange  );
    Dispatcher.subscribe(StickySaveBar.formSubmitTopic,  StickySaveBar._formSubmit  );
    Dispatcher.subscribe(StickySaveBar.formSuccessTopic, StickySaveBar._formSuccess );
    Dispatcher.subscribe(StickySaveBar.formErrorTopic,   StickySaveBar._formError   );
    Dispatcher.subscribe(StickySaveBar.formCancelTopic,  StickySaveBar._formCancel  );
    $(".js-sticky-dismiss").click(function(e) {
        e.preventDefault();
        $(".sticky-bar--failure").fadeOut("fast");
    });
    $(document).foundation({
        abide: {
            focus_on_invalid: false
        }
    });

};

StickySaveBar._formChange = function( topic ) {
    $("#sticky-unsaved-message").fadeIn("fast");
    $("#sticky-unsaved-message").text(StickySaveBar.unsavedText);
    //$("#sticky-bar").css('background-color', '').css('background-color', 'black');
    //$("#unnsave").css('background-color', '').css('background-color', 'black');
    StickySaveBar._enableButtons();
    StickySaveBar._enableUnsavedWarning();
};

StickySaveBar._enableButtons = function() {
    $("#sticky-bar input.admin-action-button").prop("disabled", false);
    $("#unnsave").css('background-color', '').css('background-color', 'black');
};

StickySaveBar._disableButtons = function() {
    $("#sticky-bar input.admin-action-button").prop("disabled", true);
    $("#unnsave").css('background-color', '').css('background-color', 'gray');
};

StickySaveBar._enableUnsavedWarning = function() {
    $("#sticky-unsaved-message").text(StickySaveBar.unsavedText);
    window.onbeforeunload = function() {
        // TODO: create enhanced captive dialog box with unsaved changes
        return "You have unsaved changes.";
    };

};

StickySaveBar._disableUnsavedWarning = function() {
    $("#sticky-unsaved-message").text(StickySaveBar.unsavedText);
    window.onbeforeunload = null;
    /* 
     //if the above doesn't work, try this
    function() {
        return null;
    };
    */

};

StickySaveBar._formSubmit = function( topic, message ) {
    $("#sticky-unsaved-message").fadeOut("fast");
    $("#admin_info_save_button").prop("value", "Saving ...");
    $("#saved").css('background-color', '').css('background-color', 'gray');
    StickySaveBar._disableButtons();    
    $("#sticky-unsaved-message").text(StickySaveBar.unsavedText);
};

StickySaveBar._formSuccess = function( topic, message ) {
    $("#sticky-unsaved-message").fadeOut("fast");
    $(".sticky-bar--saved").fadeIn("fast").delay(1500).fadeOut("slow");
    $("#admin_info_save_button").prop("value", "Save");
    if (typeof message != "undefined") {
        $("#sticky-saved-message").text(message);
    } else {
        $("#sticky-saved-message").text("Your changes have been saved.");
    }
    StickySaveBar._disableUnsavedWarning();
};

StickySaveBar._formError = function( topic, message ) {
    StickySaveBar._enableButtons();
    $(".sticky-bar--failure").fadeIn("fast");
    $("#admin_info_save_button").prop("value", "Save");
    if (typeof message != "undefined" && message != "") {
        $("#sticky-failure-message").text(message);
    } else {
        $("#sticky-failure-message").text( StickySaveBar.unsavedText );
    }
};

StickySaveBar.showValidationError = function( ) {
    var message = "Please correct the invalid form data before continuing.";
    StickySaveBar.showError( message );
};

StickySaveBar.showCustomValidationError = function( message ) {
    StickySaveBar.showError( message );
};

StickySaveBar.showError = function( message ) {
    StickySaveBar._enableButtons();
    $("#admin_info_save_button").prop("value", "Save");
    if (typeof message != "undefined" && message != "") {
        $("#sticky-unsaved-message").text(message);
    } else {
       // $("#sticky-failure-message").text("An error occured saving your changes.");
    }
};

StickySaveBar._formCancel = function( topic ) {
    StickySaveBar._init();
    $("#unnsave").css('background-color', '').css('background-color', 'gray');
};

StickySaveBar._init = function() {
    $("#sticky-bar input.admin-action-button").prop("disabled", true);
    $(".sticky-bar--saved").fadeOut("fast");
    $(".sticky-bar--failure").fadeOut("fast");
    $("#sticky-unsaved-message").fadeOut("fast");
    StickySaveBar._disableUnsavedWarning();
};

StickySaveBar.initialize();
