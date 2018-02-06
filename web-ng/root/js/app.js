$(document).ready(function() {
    $(".nav-dropdown-toggle").on("click", function(e) {
        e.preventDefault();
        $(".nav-dropdown-menu").toggle(); 
    });

    //Hide the dropdown when anything outside is clicked
    $(document).on("click", function() {
        $(".nav-dropdown-menu").hide();
    });

    // Don't hide the dropdown if items inside are clicked
    // and exclude nav-dropdown-toggle from the click outside thing above.
    $(".nav-dropdown-toggle, .nav-dropdown-menu").on("click", function(e){
        e.stopPropagation();
    });

    // Show/hide the services. use the on() event to allow DOM elements 
    // created later to still trigger the event
    $("div#host_services").on("click", ".services--title-link", function(e) {
        e.preventDefault();
        $(this).next(".services--list").toggleClass("visible-inline");

    });
    $(".alert--dismiss").on("click", function(e) {
        e.preventDefault();
        $(this).parent().fadeOut();
    });

    $(".communities__add, .servers__add").on("click", function(e) {
        e.preventDefault();
        $(".communities__popular, .servers__popular").toggle(); 
    });

    $("body").on("click", ".add_panel_heading", function(e) {
        e.preventDefault();
        $(".add_panel_heading").next(".add_panel").toggle(); 
    });

    /*
    $(".config__input").change(function(e) {
        $(".js-unsaved-message").fadeIn("fast");
    });
    */

    /*
    $(".js-save-button").on("click", function(e) {
        e.preventDefault();
        $(".js-unsaved-message").fadeOut("fast");
        $(".sticky-bar--saved").fadeIn("fast").delay(1500).fadeOut("slow");
    });
    */
    /*
    $(".js-cancel-button").on("click", function(e) {
        e.preventDefault();
        $(".sticky-bar--failure").fadeIn("fast");
    });

    $(".js-sticky-dismiss").on("click", function(e) {
        e.preventDefault();
        $(".js-unsaved-message").hide();
        $(".sticky-bar--failure").fadeOut("fast");
    });
    */

    // Sidebar popover menu used to exand on larger sets of sidebar info
    // For example, "Interfaces"
    //$(document).on('click', '.btn_test', function() { alert('test'); });
    $(document).on("click", ".js-sidebar-popover-toggle", function(e) {
        e.preventDefault();
        $(this).next(".sidebar-popover").fadeToggle("fast");
    });

    $(document).on("click", ".js-sidebar-popover-close", function(e) {
        e.preventDefault();
        $(this).parent(".sidebar-popover").fadeOut("fast");
    });

    // Hide the popover when the user clicks outside of it
    $(document).on("click", function(e) {
        $(".sidebar-popover").not(".graph-values-popover").fadeOut("fast");
    });

    // Stop clicking inside the popover from hiding it
    $(document).on("click", ".js-sidebar-popover-toggle, .sidebar-popover", function(e) {
        e.stopPropagation();
    });

    $(document).on('open.fndtn.reveal', '[data-reveal]', function () {
            $('body').addClass('modal-open');
    });
    $(document).on('close.fndtn.reveal', '[data-reveal]', function () {
            $('body').removeClass('modal-open');
    });

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
