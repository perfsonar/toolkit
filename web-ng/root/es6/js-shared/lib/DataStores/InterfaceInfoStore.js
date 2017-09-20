import LSCacheStore from "./LSCacheStore.js";
import HostInfoStore from "./HostInfoStore";
import GraphUtilities from "../Utils/GraphUtilities";

let EventEmitter = require('events').EventEmitter;
let emitter = new EventEmitter();

module.exports = {

    /* Expects an object of hosts like this (keys must be src, dst (can be multiple -- number of sources and dests must match) ): 
     * {
     *   src: "1.2.3.4,"
     *   dst: "2.3.4.5",
     * }
     * Createes a cache keyed on ip addressas
     * { 
     *   {"ip"}: { addresses, mtu, capacity}
     *   ...
     *  }
     */
    interfaceInfo: [],
    interfaceObj: {},
    lsInterfaceResults: [],
    sources: [],
    dests: [],
    lsRequestCount: 0,

    _init: function() {
        //LSCacheStore.subscribe( LSCacheStore.LSCachesRetrievedTag, this.handleLSCachesRetrieved );

    },

    handleLSCachesRetrieved: function() {


    },

    handleInterfaceInfoError: function( data ) {

    },

    // This function actually queries the LS cache (using LSCacheStore)
    retrieveInterfaceInfo: function( sources, dests ) {

        if ( typeof sources == "undefined" || typeof dests == "undefined" ) {
            console.log("sources and/or dests undefined; aborting");
                    return;

        }
        if ( !Array.isArray( sources ) ) {
            sources = [ sources ];
        }
        if ( !Array.isArray( dests ) ) {
            dests = [ dests ];
        }
        this.sources = sources;
        this.dests = dests;

        console.log("retrieveInterfaceInfo sources", sources);
        console.log("dests", dests);

        let hosts = sources.concat( dests );
        hosts = GraphUtilities.unique( hosts );

        let query = {
              "query": {
                      "bool": {
                        "must": [
                              {"match": { "type": "interface" } },
                              {"terms": { "interface-addresses": hosts } }

                        ]
                    }
              }
              ,
              "sort": [
                  { "expires": { "order": "desc" } }

              ]

        };
        let tag = "interfaceInfo";
        LSCacheStore.queryLSCache( query, tag );
        LSCacheStore.subscribeTag( this.handleInterfaceInfoResponse.bind(this), tag );

    },

    getInterfaceInfo: function( ) {
        return this.interfaceObj;
    },

    handleInterfaceInfoResponse: function( ) {
        let data = LSCacheStore.getResponseData();
        console.log("data", data);
        data = this._parseInterfaceResults( data );
        console.log("processed data", data);

        let interfaceObj =  this.interfaceObj
        console.log("combined data", interfaceObj);

        this.interfaceInfo = interfaceObj;

        emitter.emit("get");
    },

    _parseInterfaceResults: function( data ) {
        let out = [];
        let obj = {};
        for(let i in data.hits.hits ) {
            let row = data.hits.hits[i]._source;
            let addresses = row["interface-addresses"];
            let uuid = row["client-uuid"];
            for(let j in addresses) {
                let address = addresses[j];
                if ( !( address in obj ) ) {
                    out.push( row );
                    this.lsInterfaceResults.push( row );
                    obj[ address ] = row;
                    continue;
                }

            }

        }
        this.interfaceObj = obj;
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
        console.log("getInterfaceDetails details", details);
        if ( host in details ) {
            console.log("found details for ", host, details[host]);
            return details[host];
        } else {
            console.log("host details not found; searching");
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
