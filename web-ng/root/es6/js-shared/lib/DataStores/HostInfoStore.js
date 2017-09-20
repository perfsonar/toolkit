var EventEmitter = require('events').EventEmitter;

var emitter = new EventEmitter();

import _ from "underscore";

import LSCacheStore from "./LSCacheStore.js";

module.exports = {

    /* Expects an object of hosts like this (keys must be src, dst (can be multiple -- number of sources and dests must match) ): 
     * {
     *   src: "1.2.3.4,"
     *   dst: "2.3.4.5",
     * }
     * returns host info as
     * { 
     *   src_ip: "1.2.3.4", 
     *   src_host: "hostname.domain"
     *   ...
     *  }
     */
    hostInfo: [],
    hostLSInfo: [],
    tracerouteReqs: 0,
    tracerouteReqsCompleted: 0,
    tracerouteInfo: [],
    serverURLBase: "",

    retrieveTracerouteData: function ( sources, dests, ma_url ) {
        let baseUrl = "cgi-bin/graphData.cgi?action=has_traceroute_data";
        baseUrl += "&url=" + ma_url;
        if ( !_.isArray( sources ) ) {
            sources = [ sources ];
        }
        if ( !_.isArray( dests ) ) {
            dests = [ dests ];
        }
        for( let i in sources ) {
            let src = sources[i];
            let dst = dests[i];

            let url = baseUrl + "&source=" + src;
            url += "&dest=" + dst

            this.tracerouteReqs = sources.length;

            this.serverRequest = $.get( url, function(data) {
                    this.handleTracerouteResponse( data, i );
                }.bind(this));

        }



    },
    _getURL( relative_url ) {
        return this.serverURLBase + relative_url;
    },
    retrieveHostLSInfo: function( hostUUIDs ) {
        if ( !Array.isArray( hostUUIDs ) ) {
            hostUUIDs = [ hostUUIDs ];
        }


        let query = {
              "query": {
                  "constant_score": {
                        "filter": {
                          "bool": {
                            "must": [
                                  {"match": { "type": "host" } },
                                  {"terms": { "client-uuid": hostUUIDs } }

                            ]
                        }
                        }
                  }
              }
              ,
              "sort": [
                  { "expires": { "order": "desc" } }

              ]

        };
        console.log("hostinfo query", query);

        let message = "hostInfoLS";
        LSCacheStore.subscribeTag( this.handleHostLSInfoResponse.bind(this) , message );
        LSCacheStore.queryLSCache( query, message );



    },
    retrieveHostInfo: function( source_input, dest_input, callback ) {
        let url = this._getURL("cgi-bin/graphData.cgi?action=hosts");

        let sources;
        let dests;
        if ( Array.isArray( source_input ) ) {
            sources = source_input;
        } else {
            sources = [ source_input ];
        }
        if ( Array.isArray( dest_input ) ) {
            dests = dest_input
        } else {
            dests = [ dest_input ];
        }
        for (let i=0; i<sources.length; i++ ) {
            url += "&src=" + sources[i];
            url += "&dest=" + dests[i];

        }
        this.serverRequest = $.get( 
                url,
                function(data) {
                    console.log("hostInfo data", data);
                    this.handleHostInfoResponse( data );
                }.bind(this));

        if ( typeof this.serverRequest != "undefined "  ) {

                this.serverRequest.fail(function( jqXHR ) {
                    var responseText = jqXHR.responseText;
                    var statusText = jqXHR.statusText;
                    var errorThrown = jqXHR.status;

                    var errorObj = {
                        errorStatus: "error",
                        responseText: responseText,
                        statusText: statusText,
                        errorThrown: errorThrown
                    };

                    if ( _.isFunction( callback ) ) {
                        callback( errorObj );
                    }

                    emitter.emit("error");

                }.bind(this) );
        }
            //console.log( this.serverRequest.error() );

    },
    getHostInfoData: function( ) {
        return this.hostInfo;
    },
    getHostLSInfo: function( ) {
        return this.hostLSInfo;
    },
    handleHostInfoResponse: function( data ) {
        this.hostInfo = data;
        emitter.emit("get");
    },
    handleHostLSInfoResponse: function( ) {
        let data = LSCacheStore.getResponseData();
        let message = "hostInfoLS";
        console.log("message, host ls info response", message, data);
        this.hostLSInfo = data;
        emitter.emit( message );
    },
    handleTracerouteResponse: function( data, i ) {
        this.tracerouteReqsCompleted++;
        this.tracerouteInfo.push( data );
        if ( this.tracerouteReqsCompleted == this.tracerouteReqs ) {
            this.mergeTracerouteData();

        }
    },
    mergeTracerouteData: function() {
        emitter.emit("getTrace");
    },
    getTraceInfo: function() {
        return this.tracerouteInfo;
    },
    subscribeTrace: function( callback ) {
        emitter.on("getTrace", callback);
    },
    unsubscribeTrace: function( callback ) {
        emitter.off("getTrace", callback);
    },
    subscribe: function( callback ) {
        emitter.on("get", callback);
    },
    subscribeLSInfo: function( callback ) {
        emitter.on("hostInfoLS", callback);
    },
    unsubscribeLSInfo: function( callback ) {
        emitter.off("hostInfoLS", callback);
    },
    unsubscribe: function( callback ) {
        emitter.removeListener("get", callback);
    },
    subscribeError: function( callback ) {
        emitter.on("error", callback);
    },
    unsubscribeError: function( callback ) {
        emitter.removeListener("error", callback);
    },

};


