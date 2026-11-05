// Paper trading browser guard. Loaded before the app and every other script.
//
// PaperNetworkGuard only sees requests made through ApiCore's client. This
// covers everything else in the page: raw http calls, chart scripts, and links
// that would hand the session to a real Zebu site. Keep the order patterns in
// step with lib/api/paper/paper_network_guard.dart.
(function (root) {
  'use strict';

  var BLOCKED_REQUEST_HOSTS = ['fundapi.mynt.in'];
  var BLOCKED_REQUEST =
    /\/((place|modify|cancel|exit)[a-z]*order|productconversion|fundtransfer|add(ipo|ncb|sgb)toportfolio|addcorporateaction|lumsum_[a-z_]+|xsip_(purchase|cancel|pause)|mandate_creation|all_payment|placeredeemorder)\/?$/i;

  // Keep in step with _blockedAccountPaths in paper_network_guard.dart.
  var BLOCKED_ACCOUNT_PATHS = [
    '/mail_otpsend', '/mail_otpverify', '/file_write_email', '/mob_otp_req',
    '/mob_otp_ver', '/file_write_mob', '/adr_chn', '/bank', '/ddpi', '/mtf',
    '/income_otp_req', '/income_otp_ver', '/income', '/pdf_lock', '/nominee',
    '/add_segment', '/manual_cancel_request', '/img_upload',
    '/cdsl/signature_upload', '/send_link_request', '/closure',
  ];
  var BLOCKED_ACCOUNT_ANY_HOST =
    /\/(userapikeyrenreq|getuserapikey|appkeystore|gensecretkey|oauth-apps\/(create|update|delete))$/i;

  // Real sites where the signed-in user could move money or trade.
  var BLOCKED_SITES = [
    'fund.zebuetrade.com',
    'algo.zebuetrade.com',
    'profile.zebuetrade.com',
    'fundapi.mynt.in',
  ];
  var SESSION_IN_URL = /[?&#](token|hstk|stoken|susertoken|jkey|slogin[a-z]*)=/i;
  var ZEBU_HOST = /(^|\.)(mynt\.in|zebuetrade\.com)$/i;

  function parse(url) {
    try {
      return new URL(String(url), root.location ? root.location.href : undefined);
    } catch (_) {
      return null;
    }
  }

  function isBlockedRequest(url) {
    var u = parse(url);
    if (!u) return false;
    var host = u.hostname.toLowerCase();
    if (BLOCKED_REQUEST_HOSTS.indexOf(host) !== -1) return true;
    if (host === 'rekycbe.mynt.in' && /^\/pledge(\/|$)/i.test(u.pathname)) return true;
    var path = u.pathname.replace(/\/+/g, '/').replace(/\/$/, '');
    if (host === 'rekycbe.mynt.in' && BLOCKED_ACCOUNT_PATHS.indexOf(path.toLowerCase()) !== -1) return true;
    return BLOCKED_ACCOUNT_ANY_HOST.test(path) || BLOCKED_REQUEST.test(u.pathname);
  }

  function isBlockedSite(url) {
    var u = parse(url);
    if (!u) return false;
    var host = u.hostname.toLowerCase();
    if (BLOCKED_SITES.indexOf(host) !== -1) return true;
    if (/(^|\.)atomtech\.in$/.test(host)) return true;
    return ZEBU_HOST.test(host) && SESSION_IN_URL.test(u.search + u.hash);
  }

  root.__paperGuard = { isBlockedRequest: isBlockedRequest, isBlockedSite: isBlockedSite };

  if (typeof root.document === 'undefined') return;

  function notify(url) {
    if (root.console) root.console.warn('[PaperGuard] blocked', String(url).split('?')[0]);
    var body = root.document.body;
    if (!body) return;
    var box = root.document.createElement('div');
    box.textContent = 'Not available in paper trading mode.';
    box.style.cssText =
      'position:fixed;left:50%;bottom:24px;transform:translateX(-50%);z-index:2147483647;' +
      'padding:10px 16px;border-radius:6px;background:#222;color:#fff;font:14px sans-serif';
    body.appendChild(box);
    root.setTimeout(function () { box.remove(); }, 3000);
  }

  var nativeFetch = root.fetch;
  if (nativeFetch) {
    root.fetch = function (input, init) {
      var url = input && input.url ? input.url : input;
      if (isBlockedRequest(url)) {
        notify(url);
        return Promise.reject(new TypeError('Blocked in paper trading mode'));
      }
      return nativeFetch.call(root, input, init);
    };
  }

  var xhrOpen = XMLHttpRequest.prototype.open;
  var xhrSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (method, url) {
    this.__paperBlocked = isBlockedRequest(url);
    this.__paperUrl = url;
    return xhrOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function () {
    if (!this.__paperBlocked) return xhrSend.apply(this, arguments);
    notify(this.__paperUrl);
    var xhr = this;
    root.setTimeout(function () { xhr.dispatchEvent(new Event('error')); }, 0);
  };

  if (root.navigator && root.navigator.sendBeacon) {
    var beacon = root.navigator.sendBeacon.bind(root.navigator);
    root.navigator.sendBeacon = function (url, data) {
      return isBlockedRequest(url) ? false : beacon(url, data);
    };
  }

  var nativeOpen = root.open;
  root.open = function (url) {
    if (url && isBlockedSite(url)) {
      notify(url);
      return null;
    }
    return nativeOpen.apply(root, arguments);
  };

  // Plain <a> links and form posts never go through window.open.
  root.document.addEventListener('click', function (e) {
    var link = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (link && isBlockedSite(link.href)) {
      e.preventDefault();
      e.stopPropagation();
      notify(link.href);
    }
  }, true);
  root.document.addEventListener('submit', function (e) {
    var action = e.target && e.target.action;
    if (action && (isBlockedSite(action) || isBlockedRequest(action))) {
      e.preventDefault();
      e.stopPropagation();
      notify(action);
    }
  }, true);
  var formSubmit = HTMLFormElement.prototype.submit;
  HTMLFormElement.prototype.submit = function () {
    if (isBlockedSite(this.action) || isBlockedRequest(this.action)) {
      notify(this.action);
      return;
    }
    return formSubmit.call(this);
  };
})(typeof window !== 'undefined' ? window : globalThis);
