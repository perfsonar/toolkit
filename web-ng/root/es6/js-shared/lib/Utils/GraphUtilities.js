import moment from "moment-timezone";

import { TimeSeries, TimeRange, Event } from "pondjs";

module.exports = {
    getTimezone: function( date ) {
        let tz;
        let tzRe = /\(([^)]+)\)/;
        let out;
        let offset;

        if ( ( typeof date == "undefined" ) || date == null ) {
            return;
        } else if ( date == "Invalid Date" ) {
            tz = "";
            out = "";
        } else {
            tz = tzRe.exec( date );
            if ( typeof tz == "undefined" || tz === null ) {
                // timezone is unknown
                return "";
            } else {
                tz = tz[1];
                let dateObj = new Date( date );
                let dateMoment = moment( dateObj );
                offset = dateMoment.utcOffset() / 60;
                if ( typeof ( offset ) != "undefined" && offset >= 0 ) {
                    offset = "+" + offset;
                }
            }
        }

        out = " (GMT" + offset + ")";
        return out;

    },

    getTimeVars: function (period) {
        let timeDiff;
        let summaryWindow;
        if (period == '4h') {
            timeDiff = 60*60 * 4;
            summaryWindow = 0;
        } else if (period == '12h') {
            timeDiff = 60*60 * 12;
            summaryWindow = 0;
        } else if (period == '1d') {
            timeDiff = 86400;
            summaryWindow = 300;
        } else if (period == '3d') {
            timeDiff = 86400 * 3;
            summaryWindow = 300;
        } else if (period == '1w') {
            timeDiff = 86400*7;
            summaryWindow = 3600;
        } else if (period == '1m') {
            timeDiff = 86400*31;
            summaryWindow = 3600;
        } else if (period == '1y') {
            timeDiff = 86400*365;
            summaryWindow = 86400;
        }
        let timeRange = {
            timeDiff: timeDiff,
            summaryWindow: summaryWindow,
            timeframe: period
        };
        return timeRange;

    },

    // Returns the UNIQUE values of an array
    unique: function (arr) {
        var i,
            len = arr.length,
            out = [],
            obj = { };

        for (i = 0; i < len; i++) {
            obj[arr[i]] = 0;
        }
        out = Object.keys( obj );
        return out;
    },

    formatBool: function( input, unknownText ) {
        let out;
        if ( input === true || input === 1 || input == "1" ) {
            out = "Yes";
        } else if ( input === false || input === 0 || input == "0" ) {
            out = "No";
        }
        out = this.formatUnknown( out, unknownText );
        return out;

    },

    formatSItoSI: function( value, Y ) {
        console.log("value", value);
        let out = value;
        let re = /^(\d+\.?\d*)\s?([KMGT])(\w*)/;
        let results = value.match( re );
        if ( results !== null ) {
            let values = {};
            values.K = 1024;
            values.M = 1024 * 1024;
            values.G = 1024 * 1024 * 1024;
            console.log("values", values);
            console.log("value, re, results", value, re, results);

            out = results[1];

            if ( results[2].toUpperCase() in values ) {
                let X = results[2]
                out = out * values[ results[2] ];
                // convert to Y
                out = out / values[Y];
                out = Math.round( out * 10) / 10;
                out += " " + Y + results[3];
            };
        }
        console.log("outvalue", out);


        return out;

    },

    formatUnknown: function( str, unknownText ) {
        if ( typeof unknownText == "undefined" || unknownText === null ) {
            unknownText = "unknown";
        }
        if ( typeof str == "undefined" || str === null || str == "" ) {
            return unknownText;
        } else {
            return str;

        }


    }

};

