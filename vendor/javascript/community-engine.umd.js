// community-engine.umd.js — stub placeholder
// Replace with the built artifact from @better-together/community-engine-js dist/.
// Build: cd community-engine-js && npm run build
// Copy: cp dist/community-engine.umd.js ../community-engine-rails/vendor/javascript/

(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports) :
  typeof define === 'function' && define.amd ? define(['exports'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global.CommunityEngine = {}));
})(this, (function (exports) {
  'use strict';

  // ── Stub implementations ────────────────────────────────────────────────────
  // These stubs ensure the importmap resolves without errors before the real
  // built artifact is deployed. All crypto functions return a rejected promise
  // so failures are surfaced clearly in the browser console.

  function notBuilt(name) {
    return function() {
      return Promise.reject(new Error(
        `community-engine-js: "${name}" called but the package has not been built yet. ` +
        'Run: cd community-engine-js && npm run build && cp dist/community-engine.umd.js ' +
        '../community-engine-rails/vendor/javascript/'
      ))
    }
  }

  exports.generateIdentity               = notBuilt('generateIdentity')
  exports.hasSession                     = notBuilt('hasSession')
  exports.initOutboundSession            = notBuilt('initOutboundSession')
  exports.encryptMessage                 = notBuilt('encryptMessage')
  exports.decryptMessage                 = notBuilt('decryptMessage')
  exports.createSenderKeyDistribution    = notBuilt('createSenderKeyDistribution')
  exports.encryptGroupMessage            = notBuilt('encryptGroupMessage')
  exports.processSenderKeyDistribution   = notBuilt('processSenderKeyDistribution')
  exports.decryptGroupMessage            = notBuilt('decryptGroupMessage')
  exports.getLocalIdentity               = notBuilt('getLocalIdentity')
  exports.hasLocalIdentity               = notBuilt('hasLocalIdentity')
  exports.clearKeystore                  = notBuilt('clearKeystore')
  exports.fetchPrekeyBundle              = notBuilt('fetchPrekeyBundle')
  exports.registerPrekeys                = notBuilt('registerPrekeys')
  exports.fetchParticipantBundles        = notBuilt('fetchParticipantBundles')
  exports.formatPersonName               = function(person) { return person.name || '' }
  exports.truncate                       = function(text, max) { return max && text && text.length > max ? text.slice(0, max - 1) + '…' : text }
}));
