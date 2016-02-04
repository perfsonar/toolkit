// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)

function DataStore(topic, url, autoload, type) {
    this.topic = topic;
    this.reloadTopic = topic + "_reload";
    this.saveTopic = topic + ".save";
    this.saveErrorTopic = topic + ".save_error";
    this.url = url;
    this.autoload = true;
    if ( autoload !== undefined ) {
        this.autoload = autoload;
    }
    this.type = type || 'GET';
    this.data = null;

    Dispatcher.subscribe( this.reloadTopic, this._retrieveData );

    this._retrieveData = function() {
        console.log('retrieving data ...');
        var self = this;
        $.ajax({
            url: this.url,
            type: 'GET',
            contentType: "application/json",
            dataType: "json",
            success: function (data) {
                self.data = data;
                console.log('publishing self.topic: ', self.topic);
                Dispatcher.publish(self.topic);
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.log(errorThrown);
            }
        });
    }

    var __construct = function(self) {
        if ( self.autoload ) {
            self._retrieveData();
        }
    }(this); 

    this.getData = function() {
        return this.data;
    };


};
