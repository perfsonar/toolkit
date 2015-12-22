// Make sure jquery loads first
// assumes Dispatcher has already been declared (so load that first as well)

/*
var DataStore = function() {
    DataStore.topic = null;
    DataStore.url = null;
    DataStore.data = null;
    //DataStore.initialize = function() {};
};
*/


/*
var DataStore = {
    topic: null,
    url: null,
    data:null,
};
*/


function DataStore(topic, url, type) {
    this.topic = topic;
    this.saveTopic = topic + ".save";
    this.saveErrorTopic = topic + ".save_error";
    this.url = url;
    this.type = type || 'GET';
    this.data = null;

    this._retrieveData = function() {
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
        self._retrieveData();
    }(this); 

    this.getData = function() {
        return this.data;
    };


};
