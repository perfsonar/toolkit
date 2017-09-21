import GraphUtilities from "../Utils/GraphUtilities";

let EventEmitter = require("events").EventEmitter;
let emitter = new EventEmitter();
let querystring = require('querystring');

let axios = require("../axios-instance-config.js");

const lsCacheHostsURL = "/perfsonar-graphs/cgi-bin/graphData.cgi?action=ls_cache_hosts";
const lsQueryURL = "/perfsonar-graphs/cgi-bin/graphData.cgi?action=interfaces";
const proxyURL = "/perfsonar-graphs/cgi-bin/graphData.cgi?action=ls_cache_data&url=";

/*
 * DESCRIPTION OF CLASS HERE
*/

module.exports = {
    LSCachesRetrievedTag: "lsCaches",
    useProxy: false,
    lsCacheURL: null,
    data: null,

    retrieveCommunities: function( callback ) {
        console.log("retrieving communities ...");
        let query = {
            "size": 0,
            "aggs": {
                "distinct_communities": {
                    "terms": {
                        "field": "group-communities.keyword",
                        "size": 1000

                    }

                }

            }

        };
        let message = "communities_request";
        LSCacheStore.subscribeTag( this.handleLSCommunityResponse.bind(this) , message );
        LSCacheStore.queryLSCache( query, message );

    },

    handleLSCommunityResponse: function() {
        let data = LSCacheStore.getResponseData();
        console.log("data!", data);
        if ( typeof ( data ) != "undefined"
                && "aggregations" in data
                && "distinct_communities" in data.aggregations
                && "buckets" in data.aggregations.distinct_communities
                && data.aggregations.distinct_communities.buckets.length > 0
           ) {
               data = data.aggregations.distinct_communities.buckets;
               let communities = [];
               for( let i in data ) {
                   let row = data[i];
                   if ( row.key == "" || typeof row.key == "undefined" ) {
                       continue;
                   }
                   communities.push( row.key );
               }

               //communities.sort();

               communities.sort(function(a,b) {
                   a = a.toLowerCase();
                   b = b.toLowerCase();
                   if( a == b) return 0;
                   if( a > b) return 1;
                   return -1;
               });
               console.log("communities", communities);

            let message = "communities";
            emitter.emit("communities");

        } else {
            console.log("no data!!!");

        }

    },

    retrieveLSList: function() {
        axios.get( lsCacheHostsURL )
             .then(function(response){
                let data = response.data;
                console.log("lscachehosts", data);
                this.handleLSListResponse( data );
        }.bind(this));
    },

    handleLSListResponse: function( data ) {
        this.lsURLs = data;
        console.log("lsURLs", data);
        if ( typeof data == "undefined" || ! Array.isArray( data ) ) {
            console.log("LS cache host data is invalid/missingZ");
        } else if ( data.length > 0  ) {
            console.log("array of LS cache host data");
            this.lsCacheURL = data[0].url;
            if ( this.lsCacheURL === null ) {
                console.log("no url found!");

            }
            console.log("selecting cache url: ", this.lsCacheURL);
            emitter.emit( this.LSCachesRetrievedTag );
        } else {
            console.log("no LS cache host data available");
        } 
        //LSCacheStore.subscribe( 
        //this.retrieveLSHosts();

    },

    subscribeLSCaches: function( callback ) {
        emitter.on( this.LSCachesRetrievedTag, callback );

    },

    unsubscribeLSCaches: function( callback ) {
        emitter.removeListener( this.LSCachesRetrievedTag, callback );

    },

    subscribeTag: function( callback, tag ) {
        emitter.on( tag, callback );

    },

    unsubscribeTag: function( callback, tag ) {
        emitter.off( tag, callback );

    },

    // TODO: convert this function to a generic one that can take a query as a parameter
    // and a callback
    queryLSCache: function( query, message ) {
        let lsCacheURL = this.lsCacheURL + "_search";

        //this.retrieveHostLSData( hosts, lsCacheURL );

        console.log("query", query);

        let preparedQuery = JSON.stringify( query );

        console.log("stringified query", preparedQuery);

        console.log("lsCacheURL", lsCacheURL);
        console.log("message", message);

        this.message = message;

        let self = this;
        let successCallback = function( data ) {
            self.handleLSCacheDataResponse( data, message );

        };

        axios({
            "url": lsCacheURL,
            "data": preparedQuery,
            "dataType": 'json',
            "method": "POST"
        })
        .then(function( response ) {
            let data = response.data;
            console.log("data from posted request FIRST DONE SECTION", data);
            //this.handleInterfaceInfoResponse( data );
            //this.handleLSCacheDataResponse( data, message );
            successCallback( data );

        }.bind(this))
        .catch(function(error) {
            console.log("error", error);

            if (error.response) {
                // The request was made and the server responded with a status code
                // that falls out of the range of 2xx
                console.log("response error", error.response.data);
                console.log(error.response.status);
                console.log(error.response.headers);
            } else if (error.request) {
                // The request was made but no response was received
                // `error.request` is an instance of XMLHttpRequest in the browser and an instance of
                // http.ClientRequest in node.js
                console.log("request error", error.request);
                    // if we get an error, try the cgi instead
                    // and set a new flag, useProxy  and make
                    // all requests through the proxy CGI
                    let request = error.request;
                    if ( request.status == 0 ) {
                        console.log("got here!");
                        this.useProxy = true;
                        let url = this.getProxyURL( lsCacheURL );
                        console.log("proxy URL", url);

                        preparedQuery = JSON.stringify( query );

                        let postData = {
                            "query": preparedQuery,
                            "action": "ls_cache_data",
                            "dataType": 'json',
                            "url": lsCacheURL

                        };

                        let preparedData = JSON.stringify( postData );

                        axios({
                            url: url,
                            data: querystring.stringify(postData),
//dataType: 'json',
                            method: "POST"
                        })
                        .then(function(response) {
                                let data = response.data;
                                console.log("query data! SECOND DONE SECTIONz", data);
                                //this.handleInterfaceInfoResponse(data);
                                //this.handleLSCacheDataResponse( data, message );
                                successCallback( data );
                            }.bind(this))
                            .catch (function( data ) {
                                  //this.handleInterfaceInfoError(data);
                            }.bind(this));
            } else {
                // Something happened in setting up the request that triggered an Error
                console.log('Error', error.message);
            }
            console.log(error.config);



                        } else {
                            console.log('fail jqXHR, textStatus, errorThrown', jqXHR, textStatus, errorThrown);
                            this.handleInterfaceInfoError( data );

                        }

        }.bind(this));



    },
    handleLSCacheDataResponse: function( data, message ) {
        console.log("handling LS cache data response (data, message)", data, message);
        this.data = data;
        emitter.emit( this.message );
    },

    getResponseData: function() {
        console.log("getting response data ...");
        return this.data;
    },

    getProxyURL( url ) {

        let proxy = this.parseUrl( proxyURL );

        if ( this.useProxy ) {
            url = encodeURIComponent( url );
            url = proxyURL + url;
        }
        let urlObj = this.parseUrl( url );
        url = urlObj.origin + urlObj.pathname + urlObj.search;
        return url;

    },

    parseUrl: (function () {
        return function (url) {
            var a = document.createElement('a');
            a.href = url;

            // Work around a couple issues:
            // - don't show the port if it's 80 or 443 (Chrome didn''t do this, but IE did)
            // - don't append a port if the port is an empty string ""
            let port = "";
            if ( typeof a.port != "undefined" ) {
                if ( a.port != "80" && a.port != "443" && a.port != "" ) {
                    port = ":" + a.port;
                }
            }

            let host = a.host;
            let ret = {
                host: a.host,
                hostname: a.hostname,
                pathname: a.pathname,
                port: a.port,
                protocol: a.protocol,
                search: a.search,
                hash: a.hash,
                origin: a.protocol + "//" + a.hostname + port
            };
            return ret;
        }
    })(),

    retrieveInterfaceInfo: function( source_input, dest_input ) {


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
        this.sources = sources;
        this.dests = dests;

        //this.retrieveLSList();

    },
    getInterfaceInfo: function( ) {
        return this.interfaceObj;
    },
    handleInterfaceInfoResponse: function( data ) {
        console.log("data", data);
        data = this._parseInterfaceResults( data );
        console.log("processed data", data);
        //this.addData( data );
        this.interfaceInfo = data;
    },

    _parseInterfaceResults: function( data ) {
        let out = {};
        for(let i in data.hits.hits ) {
            let row = data.hits.hits[i]._source;
            let addresses = row["interface-addresses"];
            for(let j in addresses) {
                let address = addresses[j];
                if ( !( address in out ) ) {
                    out[ address ] = row;
                    console.log("client uuid: ", row["client-uuid"] );

                }

            }



        }
        console.log("keyed on address", out);
        return out;
    },

    subscribe: function( callback ) {
        emitter.on("get", callback);
    },
    unsubscribe: function( callback ) {
        emitter.off("get", callback);
    },

    array2param: function( name, array ) {
        var joiner = "&" + name + "=";
        return joiner + array.join(joiner);
    },

    // Retrieves interface details for a specific ip and returns them
    // Currently keys on ip; could extend to search all addresses later if needed
    getInterfaceDetails: function( host ) {
        let details = this.interfaceObj || {};
        if ( host in details ) {
            return details[host];
        } else {
            for(let i in details ) {
                let row = details[i];

                for( let j in row.addresses ) {
                    let address = row.addresses[j];
                    if ( address == host ) {
                        return details[i];
                    } else {
                        let addrs = host.split(",");
                        if ( addrs.length > 1 ) {
                            // handle case where addresses have comma(s)
                            for(var k in addrs) {
                                if ( addrs[k] == address ) {
                                    return details[i];
                                }
                            }


                        }
                    }

                }


            }

        }
        // host not found in the cache, return empty object
        return {};
    }
};

module.exports.retrieveLSList();
