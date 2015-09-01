// make sure jquery and Dispatcher load before this

var OldTestConfigComponent = {

};

OldTestConfigComponent.initialize = function() {
    $('#loading-modal').foundation('reveal', 'open');
    $('#oldTestFrame').load(function() {
        $('#loading-modal').foundation('reveal', 'close');
    });
};

OldTestConfigComponent.initialize();
