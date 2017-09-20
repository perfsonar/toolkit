var webpack = require('webpack');
require('es6-promise').polyfill()
var SplitByPathPlugin = require('webpack-split-by-path');
var path = require("path");


var plugins = [
  new webpack.DefinePlugin({
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV)
  }),
  new SplitByPathPlugin([
      {
        name: 'ps-shared',
        path: __dirname + '/js-shared'
      },
      {
        name: 'vendor',
        path: __dirname + '/node_modules'
      },
      {
      manifest: 'app-entry'
      }
    ])
];

if (process.env.COMPRESS) {
  plugins.push(
    new webpack.optimize.UglifyJsPlugin({
      compressor: {
        warnings: false
      }
    })
  );
}

var PRODUCTION = true;
if ( process.env.dev > 0 || process.env.dev == "true" ) {
    PRODUCTION = false;
    console.log( "Initializing DEV build ..." );
} else {
    console.log( "Initializing PRODUCTION build ..." );
}

module.exports = {
    devServer: {
        hot: true,
        host: 'perfsonar-dev.grnoc.iu.edu',
        port: 8080,
        open: 'src/main.jsx'
    },

    //entry: "./src/main.jsx",

    entry: {
            bundle: './src/main.jsx',
            //'shared': './src/shared.js',
            },

    node: {
        fs: "empty"
    },
    output: {
        //filename: './public/bundle.js'
        path: __dirname + '/public',
        filename: "[name].js",
        chunkFilename: "[name].js"
    },

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

    externals: [
        {
            window: "window",
            xmlhttprequest: '{XMLHttpRequest:XMLHttpRequest}'
        }
    ],

    resolve: {
        extensions: ["", ".js", ".jsx", ".json"]
        ,
        symlinks: false,
        resolveLoader: {
              root: path.join(__dirname, 'node_modules')
        }

        , modules: [    path.resolve(__dirname) + "/node_modules",
                        path.resolve(__dirname) + '/js-shared' 
                    ]

    },

    plugins: plugins
};
