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

    /*
    $(".config__input").change(function(e) {
        $(".js-unsaved-message").fadeIn("fast");
    });
    */

    /*
    $(".js-save-button").click(function(e) {
        e.preventDefault();
        $(".js-unsaved-message").fadeOut("fast");
        $(".sticky-bar--saved").fadeIn("fast").delay(1500).fadeOut("slow");
    });
    */
    /*
    $(".js-cancel-button").click(function(e) {
        e.preventDefault();
        $(".sticky-bar--failure").fadeIn("fast");
    });

    $(".js-sticky-dismiss").click(function(e) {
        e.preventDefault();
        $(".js-unsaved-message").hide();
        $(".sticky-bar--failure").fadeOut("fast");
    });
    */


    // Select2 plugin - https://select2.github.io/
    /*
    $(".js-select-multiple").select2({
        placeholder: "Add a new server"
    });


    $(".select2-search__field").keypress(function() {
        $(".sticky-bar--unsaved").fadeIn("fast");    
    });
    */

});
