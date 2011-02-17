// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

if (typeof (TENGEN) === "undefined" || !TENGEN) {
  var TENGEN = {};
}

TENGEN.util = {};

TENGEN.util.Doc = {
  reloadPage: function(abortIfFormElemHasFocus) {
    var reload = true;
    var activeElement = document.activeElement.tagName.toUpperCase();

    if ((activeElement == 'SELECT') || activeElement == 'INPUT' || activeElement == 'TEXTAREA') {
      if (abortIfFormElemHasFocus) {
        reload = false;
      }
    }

    if (reload) {
      location.reload();
    }
  }
};
