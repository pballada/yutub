(function() {
    var oldLog = console.log;
    var oldError = console.error;
    console.log = function() {
        window.webkit.messageHandlers.jsConsole.postMessage({type: 'log', message: Array.from(arguments).join(' ')});
        oldLog.apply(console, arguments);
    };
    console.error = function() {
        window.webkit.messageHandlers.jsConsole.postMessage({type: 'error', message: Array.from(arguments).join(' ')});
        oldError.apply(console, arguments);
    };
})();
