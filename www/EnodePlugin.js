var exec = require('cordova/exec');

var PLUGIN_NAME = 'EnodePlugin';

var EnodePlugin = {
    /**
     * Opens the Enode Link UI flow using a linkToken obtained by the O11 backend
     * (via POST /users/{userId}/link).
     *
     * @param {string} linkToken Enode link session token.
     * @param {string} themeMode "light" | "dark" | "system". Defaults to "system".
     * @param {function(Object):void} successCallback Called with
     *        { status: "success" } or { status: "cancelled" }.
     * @param {function(Object):void} errorCallback Called with { status: "error", message }.
     */
    openLinkUI: function (linkToken, themeMode, successCallback, errorCallback) {
        exec(
            successCallback,
            errorCallback,
            PLUGIN_NAME,
            'openLinkUI',
            [linkToken, themeMode || 'system']
        );
    }
};

module.exports = EnodePlugin;
