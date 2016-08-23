// The preprocessor to extract page URL
var GetURL = function() {};

GetURL.prototype = {
    run: function(arguments) {
        arguments.completionFunction({ "currentUrl" : document.URL });
    }
};

var ExtensionPreprocessingJS = new GetURL;