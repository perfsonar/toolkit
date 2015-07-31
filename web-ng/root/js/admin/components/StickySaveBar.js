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
    $(".js-sticky-dismiss").click(function(e) {
        e.preventDefault();
        $(".sticky-bar--failure").fadeOut("fast");
    });
};

StickySaveBar._formChange = function( topic ) {
    $("#sticky-unsaved-message").fadeIn("fast");
    StickySaveBar._enableButtons();
};

StickySaveBar._enableButtons = function() {
    $("#sticky-bar input.admin-action-button").prop("disabled", false);
};

StickySaveBar._disableButtons = function() {
    $("#sticky-bar input.admin-action-button").prop("disabled", true);
};

StickySaveBar._formSuccess = function( topic, message ) {
    $("#sticky-unsaved-message").fadeOut("fast");
    $(".sticky-bar--saved").fadeIn("fast").delay(1500).fadeOut("slow");
    StickySaveBar._disableButtons();    
    if (typeof message != "undefined") {
        $("#sticky-saved-message").text(message);
    } else {
        $("#sticky-saved-message").text("Your changes have been saved.");
    }
};

StickySaveBar._formError = function( topic, message ) {
    StickySaveBar._enableButtons();    
    $(".sticky-bar--failure").fadeIn("fast");
    if (typeof message != "undefined" && message != "") {
        $("#sticky-failure-message").text(message);
    } else {
        $("#sticky-failure-message").text("An error occured saving your changes.");
    }
};

StickySaveBar._formCancel = function( topic ) {
    StickySaveBar._init();
};

StickySaveBar._init = function() {
    $("#sticky-bar input.admin-action-button").prop("disabled", true);
    $(".sticky-bar--saved").fadeOut("fast");
    $(".sticky-bar--failure").fadeOut("fast");
    $("#sticky-unsaved-message").fadeOut("fast");
};

StickySaveBar.initialize();
