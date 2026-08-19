import Foundation

/// JavaScript injected into every page. Kept ES5-style on purpose and every
/// block is wrapped in try/catch so one failing hook can never kill the rest
/// (the old script died at `Object.defineProperty(window.location, ...)`,
/// which left everything after it dead).
enum JSScripts {

    // MARK: Ad blocker (runs at document start)

    static let adBlocker = """
(function() {
    'use strict';

    var blockedDomains = [
        'googlesyndication.com', 'googleadservices.com', 'doubleclick.net',
        'google-analytics.com', 'googletagmanager.com', 'ads.google.com',
        'adservice.google.com', 'connect.facebook.net', 'adnxs.com',
        'advertising.com', 'amazon-adsystem.com', 'criteo.com',
        'outbrain.com', 'taboola.com', 'popads.net', 'propellerads.com',
        'imasdk.googleapis.com'
    ];

    function isBlocked(url) {
        if (!url) { return false; }
        url = String(url);
        for (var i = 0; i < blockedDomains.length; i++) {
            if (url.indexOf(blockedDomains[i]) !== -1) { return true; }
        }
        return false;
    }

    // Block fetch()
    try {
        if (window.fetch) {
            var originalFetch = window.fetch;
            window.fetch = function() {
                try {
                    var url = typeof arguments[0] === 'string' ? arguments[0] : (arguments[0] ? arguments[0].url : '');
                    if (isBlocked(url)) { return Promise.reject(new Error('Blocked by ad blocker')); }
                } catch (e) {}
                return originalFetch.apply(this, arguments);
            };
        }
    } catch (e) {}

    // Block XHR (both open and send so nothing throws inside page code)
    try {
        var originalOpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) {
            try { if (isBlocked(url)) { this.__adBlocked = true; } } catch (e) {}
            if (this.__adBlocked) { return; }
            return originalOpen.apply(this, arguments);
        };
        var originalSend = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.send = function() {
            if (this.__adBlocked) { return; }
            return originalSend.apply(this, arguments);
        };
    } catch (e) {}

    // Block WebSocket ads
    try {
        var OriginalWebSocket = window.WebSocket;
        var WrappedWebSocket = function(url, protocols) {
            if (isBlocked(url)) { throw new Error('Blocked by ad blocker'); }
            return protocols ? new OriginalWebSocket(url, protocols) : new OriginalWebSocket(url);
        };
        WrappedWebSocket.prototype = OriginalWebSocket.prototype;
        window.WebSocket = WrappedWebSocket;
    } catch (e) {}

    // Block popups
    try { window.open = function() { return null; }; } catch (e) {}

    // Remove ad elements from the DOM (safe to run repeatedly)
    var adSelectors = [
        '[id*="google_ads"]', '[class*="adsbygoogle"]',
        '[id*="ad-container"]', '[class*="ad-container"]',
        'iframe[src*="doubleclick"]', 'iframe[src*="googlesyndication"]',
        '[data-ad]', 'ins.adsbygoogle'
    ];

    function removeAds() {
        for (var i = 0; i < adSelectors.length; i++) {
            try {
                var els = document.querySelectorAll(adSelectors[i]);
                for (var j = 0; j < els.length; j++) {
                    if (els[j].offsetHeight < 300) { els[j].remove(); }
                }
            } catch (e) {}
        }
    }

    function startDomCleanup() {
        try { removeAds(); } catch (e) {}
        try {
            if (document.body) {
                var observer = new MutationObserver(function() { removeAds(); });
                observer.observe(document.body, { childList: true, subtree: true });
            }
        } catch (e) {}
        try { setInterval(removeAds, 2500); } catch (e) {}
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', startDomCleanup);
    } else {
        startDomCleanup();
    }

    // Click YouTube's own "Skip Ad" button and close ad overlays
    try {
        if (location.hostname.indexOf('youtube.com') !== -1) {
            setInterval(function() {
                try {
                    var skip = document.querySelector('.ytp-skip-ad-button, .ytp-ad-skip-button');
                    if (skip) { skip.click(); }
                    var overlayClose = document.querySelector('.ytp-ad-overlay-close-button');
                    if (overlayClose) { overlayClose.click(); }
                } catch (e) {}
            }, 800);
        }
    } catch (e) {}
})();
"""

    // MARK: Video detector (runs at document end)

    static let videoDetector = """
(function() {
    'use strict';

    var seen = {};
    var formatsByExtension = {
        '.mp4': 'MP4',
        '.m4v': 'MP4',
        '.mov': 'MP4',
        '.webm': 'WEBM',
        '.m3u8': 'HLS',
        '.mpd': 'DASH'
    };

    function report(url, format) {
        try {
            if (!url || seen[url]) { return; }
            var lower = String(url).toLowerCase();
            if (lower.indexOf('blob:') === 0 || lower.indexOf('data:') === 0) { return; }
            seen[url] = true;
            window.webkit.messageHandlers.videoHandler.postMessage({
                url: String(url),
                title: document.title || '',
                format: format
            });
        } catch (e) {}
    }

    function inspect(url) {
        try {
            if (!url || typeof url !== 'string') { return; }
            var clean = url.split('#')[0].split('?')[0].toLowerCase();
            for (var ext in formatsByExtension) {
                if (clean.slice(-ext.length) === ext) {
                    report(url, formatsByExtension[ext]);
                    return;
                }
            }
        } catch (e) {}
    }

    // Scan <video> and <source> elements
    function scanVideos() {
        try {
            var videos = document.querySelectorAll('video');
            for (var i = 0; i < videos.length; i++) {
                var v = videos[i];
                if (v.src) { inspect(v.src); }
                if (!v.src && v.currentSrc) { inspect(v.currentSrc); }
                var sources = v.querySelectorAll('source');
                for (var j = 0; j < sources.length; j++) { inspect(sources[j].src); }
            }
        } catch (e) {}
    }

    // Watch fetch() for video URLs requested by page scripts
    try {
        if (window.fetch) {
            var originalFetch = window.fetch;
            window.fetch = function() {
                try {
                    var url = typeof arguments[0] === 'string' ? arguments[0] : (arguments[0] ? arguments[0].url : '');
                    inspect(url);
                } catch (e) {}
                return originalFetch.apply(this, arguments);
            };
        }
    } catch (e) {}

    // Watch XHR for video URLs
    try {
        var originalOpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) {
            try { inspect(typeof url === 'string' ? url : (url ? String(url) : '')); } catch (e) {}
            return originalOpen.apply(this, arguments);
        };
    } catch (e) {}

    scanVideos();
    try { setInterval(scanVideos, 3000); } catch (e) {}
})();
"""
}
