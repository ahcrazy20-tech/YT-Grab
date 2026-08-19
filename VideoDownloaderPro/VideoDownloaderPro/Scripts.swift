import Foundation

/// JavaScript injected into every page. Hooks deliberately stay conservative:
/// they discover media that the page itself requests, but never attempt to
/// decrypt DRM, defeat a paywall, or manufacture a protected stream URL.
enum JSScripts {

    static let adBlocker = """
(function() {
    'use strict';
    var blockedDomains = ['googlesyndication.com','googleadservices.com','doubleclick.net','google-analytics.com','googletagmanager.com','adnxs.com','advertising.com','amazon-adsystem.com','criteo.com','outbrain.com','taboola.com','popads.net','propellerads.com','imasdk.googleapis.com'];
    function isBlocked(url) { url = String(url || ''); for (var i=0;i<blockedDomains.length;i++) { if (url.indexOf(blockedDomains[i]) !== -1) return true; } return false; }
    try { var open = XMLHttpRequest.prototype.open; XMLHttpRequest.prototype.open = function(method,url) { if (isBlocked(url)) { this.__adBlocked = true; return; } return open.apply(this, arguments); }; var send = XMLHttpRequest.prototype.send; XMLHttpRequest.prototype.send = function() { if (this.__adBlocked) return; return send.apply(this, arguments); }; } catch(e) {}
    try { var fetch = window.fetch; window.fetch = function() { var url = typeof arguments[0] === 'string' ? arguments[0] : (arguments[0] && arguments[0].url); if (isBlocked(url)) return Promise.reject(new Error('Blocked')); return fetch.apply(this, arguments); }; } catch(e) {}
    try { window.open = function() { return null; }; } catch(e) {}
})();
"""

    // Detects direct media, HLS manifests, and media URLs without an extension.
    // It observes page activity only; blob/data and DRM playback are excluded.
    static let videoDetector = """
(function() {
    'use strict';
    var seen = {};
    var mediaExtensions = {'.mp4':'MP4','.m4v':'MP4','.mov':'MP4','.webm':'WEBM','.avi':'AVI','.mkv':'MKV','.3gp':'3GP','.m3u8':'HLS','.mpd':'DASH'};
    function absolute(url) { try { return new URL(url, document.baseURI).href; } catch(e) { return String(url || ''); } }
    function formatFor(url, hint) {
        var clean = String(url).split('#')[0].split('?')[0].toLowerCase();
        for (var ext in mediaExtensions) if (clean.slice(-ext.length) === ext) return mediaExtensions[ext];
        hint = String(hint || '').toLowerCase();
        if (hint.indexOf('application/vnd.apple.mpegurl') >= 0 || hint.indexOf('application/x-mpegurl') >= 0) return 'HLS';
        if (hint.indexOf('application/dash+xml') >= 0) return 'DASH';
        if (hint.indexOf('video/') >= 0 || hint.indexOf('audio/') >= 0) return 'FILE';
        return '';
    }
    function report(url, hint, force) {
        try {
            url = absolute(url);
            if (!url || seen[url] || /^blob:|^data:|^mediasource:/i.test(url)) return;
            var format = formatFor(url, hint);
            if (!format && !force) return;
            seen[url] = true;
            window.webkit.messageHandlers.videoHandler.postMessage({url:url, title:document.title || 'فيديو', format:format || 'FILE'});
        } catch(e) {}
    }
    function inspect(url, hint) { report(url, hint, false); }
    function scan(root) {
        try {
            var nodes = (root || document).querySelectorAll('video,audio,source,track');
            for (var i=0;i<nodes.length;i++) {
                var n = nodes[i], src = n.currentSrc || n.src || n.getAttribute('src');
                if (src) report(src, n.type || '', n.tagName === 'VIDEO' || n.tagName === 'AUDIO');
            }
            var metas = document.querySelectorAll('meta[property="og:video"],meta[property="og:video:url"],meta[name="twitter:player:stream"]');
            for (var j=0;j<metas.length;j++) report(metas[j].content, metas[j].getAttribute('type') || '', true);
        } catch(e) {}
    }
    try { var oldFetch = window.fetch; window.fetch = function() { try { var r=arguments[0], u=typeof r==='string'?r:(r&&r.url), h=(arguments[1]&&arguments[1].headers&&arguments[1].headers.Accept)||''; inspect(u,h); } catch(e) {} return oldFetch.apply(this,arguments); }; } catch(e) {}
    try { var oldOpen = XMLHttpRequest.prototype.open; XMLHttpRequest.prototype.open = function(method,url) { try { inspect(url,''); } catch(e) {} return oldOpen.apply(this,arguments); }; } catch(e) {}
    try { var observer = new MutationObserver(function(records) { for(var i=0;i<records.length;i++) for(var j=0;j<records[i].addedNodes.length;j++) { var n=records[i].addedNodes[j]; if(n.nodeType===1) { scan(n); if(n.matches && n.matches('video,audio,source')) report(n.currentSrc || n.src || n.getAttribute('src'), n.type || '', true); } } }); observer.observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['src']}); } catch(e) {}
    scan(document);
    try { setInterval(function() { scan(document); var entries = performance.getEntriesByType('resource'); for(var i=Math.max(0,entries.length-120);i<entries.length;i++) inspect(entries[i].name,''); }, 2500); } catch(e) {}
})();
"""
}
