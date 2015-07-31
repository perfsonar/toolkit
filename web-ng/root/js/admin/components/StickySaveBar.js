var StickySaveBar = {
    formChangeTopic:    'ui.form.change',
    formSuccessTopic:   'ui.form.success',
    formErrorTopic:     'ui.form.error',
    formCancelTopic:    'ui.form.cancel',
};


StickySaveBar.initialize = function() {
    Dispatcher.subscribe(StickySaveBar.formChangeTopic,  StickySaveBar._formChange  );
    Dispatcher.subscribe(StickySaveBar.formSuccessTopic, StickySaveBar._formSuccess );
    Dispatcher.subscribe(StickySaveBar.formErrorTopic,   StickySaveBar._formError   );
    Dispatcher.subscribe(StickySaveBar.formCancelTopic,  StickySaveBar._formCancel  );
};

StickySaveBar._formChange = function( topic ) {
    console.log("change form topic " , topic);
    console.log("show save message and enable buttons");
    console.log("NOTE: add hiding of error/save divs");
    $("#sticky-unsaved-message").fadeIn("fast");
    //$(".sticky-bar--unsaved").fadeIn("fast");    
    StickySaveBar._enableButtons();
};

StickySaveBar._enableButtons = function() {
    $("#sticky-bar input.admin-action-button").prop("disabled", false);
};

StickySaveBar._disableButtons = function() {
    $("#sticky-bar input.admin-action-button").prop("disabled", true);
};

StickySaveBar._formSuccess = function( topic, data ) {
    console.log("success form topic " , topic);
    console.log("hide save message, disable buttons, and show success message");
    $("#sticky-unsaved-message").fadeOut("fast");
    $(".sticky-bar--saved").fadeIn("fast").delay(1500).fadeOut("slow");
    StickySaveBar._disableButtons();    
    if (typeof data.message != "undefined") {
        $("#sticky-saved-message").text(data.message);
    } else {
        $("#sticky-saved-message").text("Your changes have been saved.");
    }
};

StickySaveBar._formError = function( topic, message ) {
    console.log("error form topic " , topic);
    console.log("hide save message, enable buttons, and shows error message");
    $("#sticky-unsaved-message").fadeOut("fast");
    $(".sticky-bar--failure").fadeIn("fast");
    StickySaveBar._enableButtons();    
    if (typeof message != "undefined" && message != "") {
        $("#sticky-failure-message").text(message);
    } else {
        $("#sticky-failure-message").text("An error occured saving your changes.");
    }
};

StickySaveBar._formCancel = function( topic ) {
    console.log("cancel form topic ", topic);
    StickySaveBar._init();
};

StickySaveBar._init = function() {
    $("#sticky-bar input.admin-action-button").prop("disabled", true);
    $(".sticky-bar--saved").fadeOut("fast");
    $(".sticky-bar--failure").fadeOut("fast");
    $("#sticky-unsaved-message").fadeOut("fast");
};

StickySaveBar.initialize();
