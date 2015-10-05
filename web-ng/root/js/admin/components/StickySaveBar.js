var StickySaveBar = {
    formChangeTopic:    'ui.form.change',
    formSubmitTopic:    'ui.form.submit',
    formSuccessTopic:   'ui.form.success',
    formErrorTopic:     'ui.form.error',
    formCancelTopic:    'ui.form.cancel',
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
};

StickySaveBar._formChange = function( topic ) {
    $("#sticky-unsaved-message").fadeIn("fast");
    StickySaveBar._enableButtons();
    StickySaveBar._enableUnsavedWarning();
    console.log('StickySaveBar received topic: ' + topic);
};

StickySaveBar._enableButtons = function() {
    $("#sticky-bar input.admin-action-button").prop("disabled", false);
};

StickySaveBar._disableButtons = function() {
    $("#sticky-bar input.admin-action-button").prop("disabled", true);
};

StickySaveBar._enableUnsavedWarning = function() {
    window.onbeforeunload = function() {
        // TODO: create enhanced captive dialog box with unsaved changes
        return "You have unsaved changes.";
    };

};

StickySaveBar._disableUnsavedWarning = function() {
    window.onbeforeunload = null;
    /* 
     //if the above doesn't work, try this
    function() {
        return null;
    };
    */

};

StickySaveBar._formSubmit = function( topic, message ) {
    console.log('StickySaveBar received topic: ' + topic);
    $("#sticky-unsaved-message").fadeOut("fast");
    $("#admin_info_save_button").prop("value", "Saving ...");
    StickySaveBar._disableButtons();    
};

StickySaveBar._formSuccess = function( topic, message ) {
    console.log('StickySaveBar received topic: ' + topic);
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
    console.log('StickySaveBar received topic: ' + topic);
    StickySaveBar._enableButtons();    
    $(".sticky-bar--failure").fadeIn("fast");
    $("#admin_info_save_button").prop("value", "Save");
    if (typeof message != "undefined" && message != "") {
        $("#sticky-failure-message").text(message);
    } else {
        $("#sticky-failure-message").text("An error occured saving your changes.");
    }
};

StickySaveBar._formCancel = function( topic ) {
    console.log('StickySaveBar received topic: ' + topic);
    StickySaveBar._init();
};

StickySaveBar._init = function() {
    $("#sticky-bar input.admin-action-button").prop("disabled", true);
    $(".sticky-bar--saved").fadeOut("fast");
    $(".sticky-bar--failure").fadeOut("fast");
    $("#sticky-unsaved-message").fadeOut("fast");
    StickySaveBar._disableUnsavedWarning();
};

StickySaveBar.initialize();
