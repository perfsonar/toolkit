$(document).ready(function() {
    $(".nav-dropdown-toggle").click(function(e) {
        e.preventDefault();
        $(".nav-dropdown-menu").toggle(); 
    });

    //Hide the dropdown when anything outside is clicked
    $(document).click(function() {
        $(".nav-dropdown-menu").hide();
    });

    // Don't hide the dropdown if items inside are clicked
    // and exclude nav-dropdown-toggle from the click outside thing above.
    $(".nav-dropdown-toggle, .nav-dropdown-menu").click(function(e){
        e.stopPropagation();
    });

    // Show/hide the services. use the on() event to allow DOM elements 
    // created later to still trigger the event
    $("div#host_services").on("click", ".services--title-link", function(e) {
        e.preventDefault();
        $(this).next(".services--list").toggleClass("visible-inline");

    });
    $(".alert--dismiss").click(function(e) {
        e.preventDefault();
        $(this).parent().fadeOut();
    });

    $(".communities__add, .servers__add").click(function(e) {
        e.preventDefault();
        $(".communities__popular, .servers__popular").toggle(); 
    });

    $(".config__input").keypress(function(e) {
        $(".sticky-bar--unsaved").fadeIn("fast");
    });

    $(".js-save-button").click(function(e) {
        e.preventDefault();
        $(".sticky-bar--unsaved").fadeOut("fast");
        $(".sticky-bar--saved").fadeIn("fast").delay(1500).fadeOut("slow");
    });
});
