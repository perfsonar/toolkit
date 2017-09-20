require('es6-promise').polyfill()

var HtmlWebpackPlugin = require('html-webpack-plugin');

var PRODUCTION = false; // TODO: fix

module.exports = {
  entry: './psshared.js',
  output: {
    path: __dirname + '/dist',
    filename: 'index_bundle.js',
    libraryTarget: 'var',
    library: 'psShared'
  },
  plugins: [new HtmlWebpackPlugin()],
   module: {
        loaders: [
            { test: /\.(js|jsx)$/,
                //loader: 'babel-loader',
                loader: ( PRODUCTION ? 'babel-loader!webpack-strip?strip[]=console.log' : 'babel-loader' ),
                exclude: [/node_modules/],
                //include: includePaths
                //query: {
                    //presets: ["es2015", "react", "stage-0"]
                //}
              //loader: "babel?stage=0"
            },
            //{ test: /\.(js|jsx)$/,
            //  loader: "babel-loader", query: { presets: ['es2015', 'react']  } },
            //{ test: /\.(js|jsx)$/, loader: 'babel?optional=es7.objectRestSpread' },
            { test: /\.css$/, loader: "style-loader!css-loader" },
            { test: /\.(png|jpg|gif)$/, loader: "url-loader?limit=8192"},
            { test: /\.json$/, loader: "json-loader" },
            { test: /\.(ttf|eot|svg)(\?v=[0-9]\.[0-9]\.[0-9])?$/,
              loader: "file-loader?name=[name].[ext]" }
        ]
            /*
            ,
        postLoaders: [
            { test: /\.js$/, loader: "webpack-strip?strip[]=console.log" }
        ]
        */
    },
};

