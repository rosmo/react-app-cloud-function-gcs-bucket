const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');

module.exports = {
    entry: path.join(__dirname, "src", "index.js"),
    output: {
        path: path.resolve(__dirname, "dist"),
    },
    plugins: [
        new HtmlWebpackPlugin({
            template: path.join(__dirname, "public", "index.html"),
            hash: true,
        }),
        new CopyWebpackPlugin({
            patterns: [
                { from: 'public/404.html', to: "." },
                { from: 'public/*.png', to: path.resolve(__dirname, 'dist', '[name][ext]'), },
                { from: 'public/*.json', to: path.resolve(__dirname, 'dist', '[name][ext]'), },
                { from: 'public/*.txt', to: path.resolve(__dirname, 'dist', '[name][ext]'), },
                { from: 'public/*.ico', to: path.resolve(__dirname, 'dist', '[name][ext]'), },
                { from: 'public/static/main.css', to: "static/main.css" },
            ]
        }),
    ],
    module: {
        rules: [
            {
                test: /\.?js$/,
                exclude: /node_modules/,
                use: {
                    loader: "babel-loader",
                    options: {
                        presets: ['@babel/preset-env', '@babel/preset-react']
                    }
                }
            },
            {
                test: /\.css$/,
                use: ['style-loader', 'css-loader'],
            },
            {
                test: /\.svg$/,
                use: [
                    {
                        loader: "babel-loader"
                    },
                    {
                        loader: "react-svg-loader",
                        options: {
                            // jsx: true // true outputs JSX tags
                        }
                    }
                ]
            },
        ]
    },
    devServer: {
        port: 3000,
    },
};