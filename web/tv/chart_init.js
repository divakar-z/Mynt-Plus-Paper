/**
 * ScalperCharts - TradingView Chart Bridge for Flutter Web
 *
 * This file creates and manages TradingView widget instances on div elements.
 * Called from Dart via JS interop. No iframes needed from Flutter side.
 *
 * Real-time data flow:
 *   Dart WebSocket -> scalperChartManager.pushTick() -> JS interop -> pushTick()
 *   -> subscribeBars callback -> TradingView updates candle in real-time
 *
 * The TradingView library (charting_library.js) must be loaded before this file.
 */
(function () {
  'use strict';

  var charts = {};          // TradingView widget instances by containerId
  var symbolDataCache = {}; // Cache raw API symData (getSymbolinfo + GetSecurityInfo bundle) by tsym
  var symbolInfoMap = {};   // Cache fully-resolved TV symbolInfo by full "EXCH:TSYM" — mirrors window._symbolInfoMap in feedFactory.js
  // containerId -> { main: <sub>, studies: { uid: <sub> } }
  // <sub> = { callback, lastBar, resolution, subscriberUID, preVolume, exchange, symbolName }
  // Split so indicator studies on a different resolution (e.g. 52-week H/L
  // needs weekly bars while the main series is 5m) don't overwrite the main
  // series subscription — the previous flat-map layout let TV's study
  // subscribeBars clobber the main slot, after which pushTick bucketed live
  // ticks to the wrong resolution and the chart looked frozen.
  var subscriptions = {};
  var desiredSymbols = {};  // containerId -> symbol name (for gating stale getBars/subscribeBars)
  // symbol ("EXCH:TSYM") -> decorative display name from DerivativeMaster,
  // e.g. "NIFTY 21 JUL 26 23450 PE" instead of "NIFTY21JUL2623450PE". Read by
  // resolveSymbol for `description`, which is what the `symbol_info` header
  // renders as the chart title. Seeded from Dart via createChart's
  // options.dispname and the setDispName bridge call. Replaces the `dispname`
  // URL/postMessage param the old remote-iframe chart used (commit d3b903c9).
  var dispNames = {};
  var changeSymbolTimers = {}; // containerId -> debounce timer
  var lastNotifiedSymbol = {}; // containerId -> last symbol sent to Dart via onChartSymbolChanged (dedup)

  // Noren app path. Match the app that issued the jKey we forward as
  // `usession`:
  //   web    → api_link.dart goMyntURL = go.mynt.in/NorenWClientWeb
  //   mobile → api_link.dart goMyntURL = go.mynt.in/NorenWClient
  // This file is shared with the mobile port, so three calls arrived here
  // still on mobile's "NorenWClient" (SearchScrip, GetSecurityInfo,
  // TPSeries); only EODChartData was corrected, in 3c50ee88. Realigned to
  // the web app path, which is what every other web API call uses and what
  // the pre-migration web datafeed (web/tv/src/datafeed.js) used for both
  // TPSeries and GetSecurityInfo.
  // NOTE: not confirmed that the mixed paths actually failed — both app
  // paths exist and reject an invalid key identically, and mobile calls
  // NorenWClientWeb/EODChartData with a NorenWClient key seemingly fine, so
  // cross-app keys may well be tolerated. This is alignment, not a proven
  // fix. Keep every Noren call on this one constant so a future port is a
  // single-line change instead of four drifting URLs.
  var NOREN_BASE = 'https://go.mynt.in/NorenWClientWeb';

  // OI overlay marker — a symbol resolved with this suffix returns bars
  // whose `close` is the open-interest value, not price. Used by the OI
  // study on the desktop web chart. Mirrors `$OISYMBOL` handling in
  // feedFactory.js (resolveSymbol + getBars).
  var OI_SUFFIX = '$OISYMBOL';

  // Exchange holiday calendar — TradingView uses this to grey out closed
  // days on the time axis. Mirrors feedFactory.js:622-651 exactly. Note:
  // the dates here are 2024 — same as web; refresh annually.
  function getHolidays(exchange) {
    switch (exchange) {
      case 'NSE':
      case 'NFO':
        return '20240122,20240126,20240308,20240325,20240329,20240411,20240417,20240501,20240617,20240717,20240815,20241002,20241115,20241225';
      case 'BSE':
      case 'BFO':
        return '20240126,20240308,20240325,20240329,20240411,20240417,20240501,20240617,20240717,20240815,20241002,20241115,20241225';
      case 'MCX':
        return '20240126,20240329,20240815,20241002,20241225';
      case 'CDS':
        return '20240122,20240126,20240219,20240308,20240325,20240329,20240401,20240409,20240411,20240417,20240501,20240523,20240617,20240717,20240815,20240916,20241002,20241115,20241225';
      case 'NCOM':
        return '20240122,20240126,20240329,20240815,20241002,20241225';
      case 'BCD':
        return '20240126,20240219,20240308,20240325,20240329,20240401,20240409,20240411,20240417,20240501,20240523,20240617,20240717,20240815,20240916,20241002,20241115,20241225';
      default:
        return '';
    }
  }

  // ── Resolution config ──────────────────────────────────────────────────────
  // Mirrors web (feedFactory.js): a broad list passed to SymbolInfo so users
  // can type custom resolutions via `custom_resolutions`, plus a compact list
  // for the on-screen timeframe selector.
  var FULL_RESOLUTIONS = (function () {
    var r = [];
    for (var m = 1; m <= 1200; m++) {
      if (m <= 60 || m % 5 === 0) r.push(String(m));
    }
    ['1D','2D','3D','4D','5D','6D','1W','2W','3W','4W',
     '1M','2M','3M','4M','5M','6M','7M','8M','9M','10M','11M','12M']
      .forEach(function (s) { r.push(s); });
    return r;
  })();
  var DISPLAY_RESOLUTIONS = ['1','3','5','15','30','45','60','75','120','180','240','1D','1W','1M'];

  // ── Default-indicators sync (server-backed, two-way) ──────────────────────
  // Mirrors web (zebu-mobchart.web.app — `setIndicatorsInterval`): on
  // chart-ready, fetch the user's saved default-indicator list and create
  // them; then every 5s diff the active (non-Volume) studies and push the
  // new list to /storeindicators. Two-way sync keeps a user's "always show
  // RSI" preference identical on web and mobile.
  var indicatorSyncTimers = {}; // containerId -> setInterval id

  function fetchJson(url) {
    return fetch(url).then(function (r) { return r.json(); }).catch(function () { return null; });
  }

  // Notify Dart that TradingView's chart symbol changed externally (saved
  // layout load, TV's header search box, etc.). Dart re-points the WS
  // owner at the new token so live ticks follow the displayed symbol —
  // without this the chart shows the new symbol's candles but pushTick
  // still feeds the previous symbol's ltp, or nothing at all.
  // Payload exch/Token come from symbolDataCache, which resolveSymbol
  // populates from /getSymbolinfo and /GetSecurityInfo right before this
  // fires — by the time TV emits onSymbolChanged the cache is hot.
  // Mobile bridges via flutter_inappwebview.callHandler; web (same window,
  // no flutter_inappwebview) calls the Dart-exposed window.onChartSymbolChanged.
  function notifyDartOfSymbolChange(containerId, symbolName) {
    if (!symbolName) return;
    if (lastNotifiedSymbol[containerId] === symbolName) return;
    lastNotifiedSymbol[containerId] = symbolName;
    var seeded = symbolDataCache[symbolName] || {};
    var payload = {
      containerId: containerId,
      symbol: symbolName,
      exch: seeded.exch || '',
      token: seeded.Token || ''
    };
    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        // Mobile: bridge to Dart through the InAppWebView handler.
        window.flutter_inappwebview.callHandler('onChartSymbolChanged', payload);
      } else if (typeof window.onChartSymbolChanged === 'function') {
        // Flutter Web: chart_init.js runs in the SAME window as the Flutter
        // app (no iframe), so call the Dart-exposed global directly.
        // WebChartManager re-points its tick stream at the new scrip's token.
        window.onChartSymbolChanged(JSON.stringify(payload));
      }
    } catch (e) {
      console.error('notifyDartOfSymbolChange error:', e);
    }
  }

  function setupIndicatorsSync(widget, containerId, user) {
    if (!user) return;
    var base = 'https://be.mynt.in';
    var lastSent = null;

    fetchJson(base + '/getindicators?clientCode=' + encodeURIComponent(user))
      .then(function (saved) {
        try {
          var chart = widget.activeChart();
          if (saved && saved.data && saved.data.length) {
            saved.data.forEach(function (name) {
              try { chart.createStudy(name, false, false); } catch (e) { /* unknown study */ }
            });
            lastSent = JSON.stringify(saved.data);
          }
        } catch (e) { /* widget went away */ }
      });

    indicatorSyncTimers[containerId] = setInterval(function () {
      try {
        var studies = widget.activeChart().getAllStudies();
        var names = [];
        for (var i = 0; i < studies.length; i++) {
          if (studies[i].name !== 'Volume') names.push(studies[i].name);
        }
        var serialized = JSON.stringify(names);
        if (serialized !== lastSent) {
          lastSent = serialized;
          fetchJson(base + '/storeindicators?clientCode=' + encodeURIComponent(user) +
                    '&indicators=' + encodeURIComponent(serialized));
        }
      } catch (e) { /* chart not ready */ }
    }, 5000);
  }

  // ── Settings adapter (matches web — single `settings_mob` localStorage key) ─
  // Web stores TradingView settings (candle style, last-used resolution,
  // grid colours, axis tweaks) under `settings_mob` and reads it back on
  // every chart open. Mirroring that here gives a user the same persisted
  // UI prefs on web and mobile. Single key, not per-client — same as web;
  // accept the same trade-off (prefs bleed across users on one device).
  var SETTINGS_KEY = 'settings_mob';

  function loadSettings() {
    try {
      var raw = window.localStorage.getItem(SETTINGS_KEY);
      return raw ? JSON.parse(raw) : {};
    } catch (e) { return {}; }
  }

  function writeSettings(obj) {
    try { window.localStorage.setItem(SETTINGS_KEY, JSON.stringify(obj)); }
    catch (e) { /* quota / private mode — ignore */ }
  }

  var webSettingsAdapter = {
    initialSettings: loadSettings(),
    setValue: function (key, value) {
      var s = loadSettings();
      s[key] = value;
      writeSettings(s);
    },
    removeValue: function (key) {
      var s = loadSettings();
      delete s[key];
      writeSettings(s);
    }
  };

  /**
   * Create a datafeed object for a TradingView widget.
   * Each widget gets its own datafeed with user credentials and containerId in closure.
   */
  // Primary source: Strapi `market-hour` single type, fetched by
  // webview_chart_provider.loadMarketHours() at app launch and cached in
  // Preferences.chartMarketHours. webview_chart.dart / scalp.dart decode
  // it into a `{ exchange: 'HHMM-HHMM[:dayMask]' }` map and pass it as
  // `options.sessions` to createChart. Strapi is the override channel —
  // when the exchange changes its trading window we can update Strapi
  // without shipping a new app build.
  //
  // Fallback: when Strapi is unavailable (fresh install offline, fetch
  // error, or an exchange missing from the response) we use the SAME
  // values the web mobile chart hardcodes in feedFactory.js:224 — no
  // day mask, three buckets. Keeps mobile and web identical when both
  // are running without Strapi. BCD shares the CDS currency window and
  // the equity close is 15:40 — kept in step with web/tv/src/datafeed.js.
  function resolveSession(sessions, exchange) {
    if (sessions && sessions[exchange]) return sessions[exchange];
    if (exchange === 'MCX') return '0900-2330';
    if (exchange === 'CDS' || exchange === 'BCD') return '0900-1700';
    return '0915-1540';
  }

  function createDatafeed(user, usession, containerId, sessions) {
    // Per-resolution cache of the most recent historical bar. A single
    // shared variable broke when TV issued back-to-back getBars for two
    // resolutions (e.g. 1m and 1D on a Daily-view switch): whichever
    // response landed last won, so the daily subscribeBars could end up
    // with a 1-minute lastBar, and pushTick then snapped to that minute's
    // timestamp. Keying by resolution isolates each series.
    var lastBarByResolution = {};

    return {
      onReady: function (callback) {
        // Mirrors feedFactory.js `configurationData` (lines 64-85). The
        // `exchanges` / `symbols_types` arrays drive TradingView's built-in
        // symbol-search dialog dropdowns. `supports_search:true` is needed
        // for `searchSymbols` to be called at all if `header_symbol_search`
        // is ever re-enabled.
        setTimeout(function () {
          callback({
            supported_resolutions: DISPLAY_RESOLUTIONS,
            exchanges: [
              { value: 'ALL', name: 'All exchange' },
              { value: 'NSE', name: 'NSE' },
              { value: 'BSE', name: 'BSE' },
              { value: 'MCX', name: 'MCX' }
            ],
            symbols_types: [
              { name: 'All',       value: '' },
              { name: 'Equity',    value: 'STOCK' },
              { name: 'F&O',       value: 'F&O' },
              { name: 'Currency',  value: 'CURR' },
              { name: 'Commodity', value: 'COMM' },
              { name: 'Indices',   value: 'UNDIND' }
            ],
            supports_search: true,
            supports_group_request: false,
            supports_marks: false,
            supports_timescale_marks: true,
            supports_time: true,
          });
        }, 0);
      },

      searchSymbols: function (userInput, exchange, symbolType, onResultReadyCallback) {
        // Port of feedFactory.js:426-598. Maps TV's (exchange, symbolType)
        // pair to a Mynt `SearchScrip` request and a TV-shaped result list.
        // Indices (UNDIND) bypass the API in web — same here.
        if (symbolType === 'UNDIND') { onResultReadyCallback([]); return; }
        if (userInput.indexOf(':') !== -1) userInput = userInput.split(':')[1];

        var filterMap = {
          NSE: { STOCK: ['NSE'], 'F&O': ['NFO'], CURR: ['CDS'], COMM: ['NCOM'], UNDIND: ['NSE'], '': ['NSE','NFO','CDS','NCOM'] },
          BSE: { STOCK: ['BSE'], 'F&O': ['BFO'], CURR: ['BCD'], COMM: ['BCOM'], UNDIND: ['BSE'], '': ['BSE','BFO','BCD','BCOM'] },
          MCX: { STOCK: [], 'F&O': [], CURR: [], COMM: ['MCX'], UNDIND: ['MCX'], '': ['MCX'] },
          ALL: { STOCK: ['NSE','BSE'], 'F&O': ['NFO','BFO'], CURR: ['CDS','BCD'], COMM: ['NCOM','BCOM','MCX'], UNDIND: [], '': ['NSE','NFO','CDS','NCOM','BSE','BFO','BCD','BCOM','MCX'] }
        };
        var exchMap = {
          NSE: { STOCK: 'NSE', 'F&O': 'NFO', CURR: 'CDS', COMM: 'NCOM', UNDIND: 'UNDIND' },
          BSE: { STOCK: 'BSE', 'F&O': 'BFO', CURR: 'BCD', COMM: 'BCOM', UNDIND: 'UNDIND' },
          MCX: { COMM: 'MCX', UNDIND: 'UNDIND' }
        };

        var typeKey = symbolType || '';
        var filterList = (filterMap[exchange] && filterMap[exchange][typeKey]) || [];
        var exch = (exchMap[exchange] && exchMap[exchange][symbolType]) || (exchange === 'MCX' ? 'MCX' : '');

        var stext = userInput.replace(/&/g, '%26').replace(/ /g, '_');
        var body = 'jData={"uid":"' + user + '","stext":"' + stext + '"' +
                   (exch ? ',"exch":"' + exch + '"' : '') + '}&jKey=' + usession;

        fetch(NOREN_BASE + '/SearchScrip', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: body
        })
          .then(function (r) { return r.json(); })
          .then(function (data) {
            if (!data || data.stat === 'Not_Ok' || !data.values) {
              onResultReadyCallback([]);
              return;
            }
            var typeMap = {
              OPTIDX: 'Option', OPTSTK: 'Option', OPTCUR: 'Option', OPTFUT: 'Option',
              FUTIDX: 'Future', FUTSTK: 'Future', FUTCUR: 'Future', FUTCOM: 'Future',
              COM: 'Commodity', UNDIND: 'Index'
            };
            var results = data.values.map(function (v) {
              var stype = typeMap[v.instname] || 'Stock';
              var desc = v.cname;
              var match = v.tsym.match(/(\d{1,2})[a-zA-Z]{3}(\d{2,4})?/g);
              if (match) {
                var parts = v.tsym.split(match[0]);
                if (v.instname.indexOf('OPT') === 0 && parts.length > 1) {
                  desc = parts[0] + '  ' +
                         match[0].replace(/(..)(...)(..)/, '$1-$2-$3') + '  ' +
                         parts[1].substring(0, 1) + 'E  ' +
                         parts[1].substring(1) +
                         (v.weekly ? '  (week ' + v.weekly.substring(1) + ')' : '');
                } else if (v.instname.indexOf('FUT') === 0 && parts.length > 1) {
                  desc = parts[0] + '  ' +
                         match[0].replace(/(..)(...)(..)/, '$1-$2-$3') + '  FUT  ' +
                         parts[1].substring(1);
                }
              }
              return {
                exchanges: v.exch,
                symbols_types: stype,
                symbol: v.exch + ':' + v.tsym.toUpperCase(),
                full_name: v.cname,
                description: desc,
                exchange: v.exch,
                ticker: v.exch + ':' + v.tsym.toUpperCase(),
                type: stype
              };
            }).filter(function (r) {
              if (filterList.length === 0) return true;
              return filterList.indexOf(r.exchanges) !== -1 && r.symbols_types !== 'Commodity';
            });
            onResultReadyCallback(results);
          })
          .catch(function () { onResultReadyCallback([]); });
      },

      resolveSymbol: function (symbolName, onResolvedCallback, onErrorCallback) {
        // Mirrors feedFactory.js — keep symbolName intact (e.g. "NSE:NIFTY 50")
        // and derive everything from it. The legend's symbol text comes from
        // `name`/`description`, and TradingView shows them verbatim, so name
        // must be the full "EXCH:TSYM" string just like web.

        // OI-overlay marker — strip for the API lookup, restore for the
        // resulting symbolInfo so getBars can detect it and emit OI as
        // `close` (mirrors feedFactory.js:191-203).
        var isOiSymbol = symbolName.indexOf(OI_SUFFIX) !== -1;
        var lookupSymbol = isOiSymbol ? symbolName.replace(OI_SUFFIX, '') : symbolName;

        // Cache hit — Vue's window._symbolInfoMap mirrored here. Re-creates
        // (theme toggle, screen reopen) become instant.
        if (symbolInfoMap[symbolName]) {
          setTimeout(function () { onResolvedCallback(symbolInfoMap[symbolName]); }, 0);
          return;
        }

        var hasColon = lookupSymbol.includes(':');
        var inputExchange = hasColon ? lookupSymbol.split(':')[0] : '';
        var cleanName = hasColon ? lookupSymbol.split(':')[1] : lookupSymbol;

        // Skip getSymbolinfo when we already have an authoritative exch + Token
        // from Dart (seeded via createChart's options.initialToken/initialExch or
        // ScalperCharts.seedSymbolData). The be.mynt.in/getSymbolinfo endpoint
        // does NOT return MCX scrips reliably — without the seed the MCX chart
        // ends up with empty symData.exch / symData.Token, GetSecurityInfo
        // fails, and resolveSymbol's catch fires with "Error resolving symbol".
        // The web fallback works because its URL embeds &exch=...&token=... so
        // it never hits getSymbolinfo for the initial scrip. Seeding from Dart
        // gives the local chart the same head start.
        var seeded = symbolDataCache[symbolName] || symbolDataCache[lookupSymbol];
        var symDataPromise;
        if (seeded && seeded.Token) {
          symDataPromise = Promise.resolve(seeded);
        } else {
          symDataPromise = fetch('https://be.mynt.in/getSymbolinfo?tsym=' + encodeURIComponent(cleanName))
            .then(function (r) { return r.json(); });
        }

        symDataPromise
          .then(function (symData) {
            symbolDataCache[symbolName] = symData;
            symbolDataCache[lookupSymbol] = symData;
            symbolDataCache[cleanName] = symData;

            // Prefer the seeded exch/Token (authoritative) over symData when
            // getSymbolinfo returned partial data for a different exchange.
            var exchForApi = symData.exch || inputExchange;
            var tokenForApi = symData.Token || '';

            var raw = 'jData={"uid":"' + user + '","exch":"' + exchForApi + '","token":"' + tokenForApi + '"}&jKey=' + usession;
            return fetch(NOREN_BASE + '/GetSecurityInfo', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: raw
            }).then(function (r) { return r.json(); }).then(function (info) {
              return { info: info, symData: symData };
            });
          })
          .then(function (bundle) {
            var info = bundle.info;
            var symData = bundle.symData;

            if (info && info.stat === 'Ok') {
              console.log('Symbol resolved:', symbolName, '->', info.exch + '|' + info.token);
            }

            // Field mapping (mirrors web feedFactory.js exactly):
            //   info.instname / symData.instname → "IDX" means index
            //   info.ti  → tick_size (price increment)
            //   info.ls  → lot_size
            var isIndex = (info.instname || symData.instname) === 'IDX';
            var exchange = inputExchange || info.exch;     // prefer input — web does
            var isCDS = exchange === 'CDS';
            var isMCX = exchange === 'MCX';
            var tickSize = parseFloat(info.ti || symData.ti || 0.01) || 0.01;
            var pricescale = isCDS ? 10000 : 100;
            var minmov = isCDS ? Math.round(tickSize * 10000) : Math.round(tickSize * 100);
            if (!minmov || minmov < 1) minmov = 1;

            var isFut = lookupSymbol.toUpperCase().indexOf('FUT') !== -1;
            var sType = isFut ? 'futures' : (isIndex ? 'index' : 'stock');
            var lotSize = String(info.ls || symData.ls || 1);

            // CRITICAL — these fields drive the chart legend. Web uses the
            // raw input (e.g. "NSE:NIFTY 50") for ALL of name/ticker/
            // description/full_name/pro_name; base_name is just the part
            // after the colon. Diverging from this produces a "NSE:Nifty 50
            // · 5 · NSE" rendering on mobile.
            var symbolInfo = {
              ticker: symbolName,
              name: symbolName,
              full_name: symbolName,
              pro_name: symbolName,
              // ONLY field allowed to diverge from the raw input: the
              // `symbol_info` header renders it as the human-readable chart
              // title. Falls back to symbolName when Dart sent no decorative
              // name, which keeps the legend byte-identical to before.
              description: dispNames[symbolName] || symbolName,
              base_name: cleanName,
              symbols_types: [{ name: "All types", value: "" }],
              session: resolveSession(sessions, exchange),
              session_holidays: getHolidays(exchange),
              timezone: 'Asia/Kolkata',
              exchange: exchange,
              listed_exchange: exchange,
              type: sType,
              minmov: minmov,
              pricescale: pricescale,
              tick_size: String(tickSize),
              has_intraday: true,
              has_daily: true,
              has_weekly_and_monthly: false,
              intraday_multipliers: ["1"],
              daily_multipliers: ["1"],
              weekly_multipliers: ["1"],
              monthly_multipliers: ["1"],
              has_no_volume: isIndex,
              visible_plots_set: isIndex ? 'ohlc' : 'ohlcv',
              supported_resolutions: FULL_RESOLUTIONS,
              volume_precision: 1,
              data_status: 'streaming',
              supports_timescale_marks: true,
              lot_size: lotSize,
              isTradable: !isIndex,
              // TV order-ticket integration reads `qty.step` / `qty.default`.
              // MCX trades in single lots — others use the instrument lot.
              qty: {
                step:    String(isMCX ? 1 : lotSize),
                default: String(isMCX ? 1 : lotSize),
              },
            };
            symbolInfoMap[symbolName] = symbolInfo;
            onResolvedCallback(symbolInfo);
          })
          .catch(function (e) {
            console.error('resolveSymbol error:', e);
            onErrorCallback('Error resolving symbol: ' + e);
          });
      },

      getBars: function (symbolInfo, resolution, periodParams, onHistoryCallback, onErrorCallback) {
        // symbolInfo.name is now "EXCH:TSYM" form to match web. Strip the
        // OI suffix for the cache lookup and remember the flag — bars must
        // be rewritten so `close` = `oi` when the OI overlay is active
        // (mirrors feedFactory.js:270-273, 328-339).
        var isOiSymbol = symbolInfo.name.indexOf(OI_SUFFIX) !== -1;
        var lookupKey = isOiSymbol ? symbolInfo.name.replace(OI_SUFFIX, '') : symbolInfo.name;
        var lookupName = lookupKey.includes(':')
          ? lookupKey.split(':')[1]
          : lookupKey;
        var symData = symbolDataCache[symbolInfo.name] || symbolDataCache[lookupKey] || symbolDataCache[lookupName] || {};

        // Maps the raw API row to a TV bar. The `into=="0.00"` fallback to
        // `intc` matches feedFactory.js:292-298 — without it, days where
        // the open feed returned "0.00" render as flat candles pinned to
        // the bottom of the chart. Also emits `oi` for indicators and, if
        // this is the $OISYMBOL view, swaps `close` ← `oi`.
        function toBar(d) {
          var into = (d.into === '0.00') ? d.intc : d.into;
          var inth = (d.inth === '0.00') ? d.intc : d.inth;
          var intl = (d.intl === '0.00') ? d.intc : d.intl;
          var oi = parseFloat(d.oi);
          return {
            time:   parseFloat(d.ssboe) * 1000,
            open:   parseFloat(into),
            high:   parseFloat(inth),
            low:    parseFloat(intl),
            close:  isOiSymbol ? oi : parseFloat(d.intc),
            volume: parseFloat(d.intv),
            oi:     oi
          };
        }

        if (resolution === '1D' || resolution === '1W' || resolution === '1M') {
          // Day/weekly/monthly chart
          var index = symData.index || lookupKey;
          var reqBody = 'jData=' + JSON.stringify({ sym: index, from: periodParams.from, to: periodParams.to }) + '&jKey=' + usession;

          fetch(NOREN_BASE + '/EODChartData', {
            method: 'POST',
            headers: { 'Content-Type': 'text/plain' },
            body: reqBody
          })
            .then(function (r) { return r.json(); })
            .then(function (data) {
              if (!data || data.stat === 'Not_Ok' || data.length === 0) {
                onHistoryCallback([], { noData: true });
                return;
              }
              var bars = data.map(JSON.parse).map(toBar)
                .sort(function (a, b) { return a.time - b.time; });

              // Cache the last bar for subscribeBars (only if this is still the desired symbol)
              if (periodParams.firstDataRequest && bars.length > 0) {
                var desired = desiredSymbols[containerId];
                if (!desired || symbolInfo.name === desired || symbolInfo.ticker === desired) {
                  lastBarByResolution[resolution] = bars[bars.length - 1];
                } else {
                  console.log('ScalperCharts: Stale getBars (day) for', symbolInfo.name, '- desired:', desired);
                }
              }

              onHistoryCallback(bars, { noData: false });
            })
            .catch(function (e) {
              console.error('getBars day error:', e);
              onErrorCallback(e);
            });
        } else {
          // Intraday chart — exchange from symbolInfo.exchange (set by
          // resolveSymbol to the input EXCH prefix), token from cached
          // symData. Don't fall back to symbolInfo.name here because that
          // would include the colon.
          var raw = 'jData={"uid":"' + user + '","exch":"' + (symData.exch || symbolInfo.exchange) + '","token":"' + (symData.Token || '') + '","st":"' + (periodParams.from - 320000) + '","et":"' + periodParams.to + '","intrv":"' + resolution + '"}&jKey=' + usession;

          fetch(NOREN_BASE + '/TPSeries', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: raw
          })
            .then(function (r) { return r.json(); })
            .then(function (data) {
              if (!data || data.stat === 'Not_Ok' || data.length === 0) {
                onHistoryCallback([], { noData: true });
                return;
              }
              var bars = data.map(toBar)
                .sort(function (a, b) { return a.time - b.time; });

              // Cache the last bar for subscribeBars (only if this is still the desired symbol)
              if (periodParams.firstDataRequest && bars.length > 0) {
                var desired = desiredSymbols[containerId];
                if (!desired || symbolInfo.name === desired || symbolInfo.ticker === desired) {
                  lastBarByResolution[resolution] = bars[bars.length - 1];
                } else {
                  console.log('ScalperCharts: Stale getBars (intraday) for', symbolInfo.name, '- desired:', desired);
                }
              }

              onHistoryCallback(bars, { noData: false });
            })
            .catch(function (e) {
              console.error('getBars intraday error:', e);
              onErrorCallback(e);
            });
        }
      },

      subscribeBars: function (symbolInfo, resolution, onRealtimeCallback, subscriberUID, onResetCacheNeededCallback) {
        // The gate's original job was to filter stale callbacks from a
        // previous setSymbol call that landed after a second setSymbol
        // had started. That race is now mostly closed by changeSymbol's
        // 150ms debounce + delete subscriptions, so the gate's reject
        // path needs to be conservative: only reject when there's already
        // a main subscription on a *different* symbol AND TradingView's
        // active chart doesn't agree the symbol has changed. Otherwise
        // accept — covers saved-layout load and TV's header search box,
        // both of which fire subscribeBars for a new symbol BEFORE the
        // onSymbolChanged event reaches our handler.
        var desired = desiredSymbols[containerId];
        var entry = subscriptions[containerId];
        var matchesDesired = !desired ||
            symbolInfo.name === desired || symbolInfo.ticker === desired;
        if (!matchesDesired) {
          var currentSym = null;
          try {
            var w = charts[containerId];
            if (w && w.activeChart) currentSym = w.activeChart().symbol();
          } catch (e) { /* widget mid-init */ }
          var chartAgrees = currentSym &&
              (currentSym === symbolInfo.name || currentSym === symbolInfo.ticker);
          var noMain = !entry || !entry.main;
          if (noMain || chartAgrees) {
            console.log('ScalperCharts: Accepting symbol change to', symbolInfo.name,
                noMain ? '(no main bound)' : '(chart agrees)');
            desiredSymbols[containerId] = symbolInfo.name;
            notifyDartOfSymbolChange(containerId, symbolInfo.name);
          } else {
            console.log('ScalperCharts: Skipping stale subscribeBars for', symbolInfo.name, '- desired:', desired);
            return;
          }
        }

        var sub = {
          callback: onRealtimeCallback,
          lastBar: lastBarByResolution[resolution] || null,
          resolution: resolution,
          subscriberUID: subscriberUID,
          preVolume: 0,
          exchange: symbolInfo.exchange || '',
          symbolName: symbolInfo.name
        };

        // Slotting is bookkeeping for unsubscribeBars (find sub by UID) and a
        // fallback hint for pushTick — it is NOT the live-tick routing
        // decision. Do not reintroduce a `resolution === activeChart()
        // .resolution()` test here: those two values are different things.
        // resolveSymbol declares intraday_multipliers:["1"], so TradingView
        // asks this datafeed for the BASE resolution it builds the view from
        // ("1" for every intraday interval — Interval.letter() is "" for
        // minutes), while activeChart().resolution() returns the DISPLAYED
        // interval ("5"). On any intraday chart they never match, the main
        // series was filed as a study, entry.main stayed null and pushTick
        // dropped every tick — socket data flowing, chart frozen.
        //
        // The first sub bound on an empty entry is the visible series
        // (subscribeBars' natural call order, and createChart / changeSymbol
        // both clear `subscriptions` first). Later subs are indicator studies
        // on other resolutions. pushTick resolves the real target by matching
        // sub.resolution to the chart's DATAFEED resolution — see there.
        if (!entry) {
          subscriptions[containerId] = { main: sub, studies: {} };
        } else if (!entry.main) {
          entry.main = sub;
        } else {
          entry.studies = entry.studies || {};
          entry.studies[subscriberUID] = sub;
        }
        console.log('ScalperCharts: subscribeBars -', containerId, 'res:', resolution, 'uid:', subscriberUID);
      },

      unsubscribeBars: function (subscriberUID) {
        var entry = subscriptions[containerId];
        if (!entry) return;
        if (entry.main && entry.main.subscriberUID === subscriberUID) {
          entry.main = null;
          console.log('ScalperCharts: unsubscribeBars (main) -', containerId, subscriberUID);
        } else if (entry.studies && entry.studies[subscriberUID]) {
          delete entry.studies[subscriberUID];
          console.log('ScalperCharts: unsubscribeBars (study) -', containerId, subscriberUID);
        }
        if (!entry.main && (!entry.studies || Object.keys(entry.studies).length === 0)) {
          delete subscriptions[containerId];
        }
      }
    };
  }

  /**
   * Bucket a timestamp to the correct candle boundary based on resolution.
   * Matches the logic from the existing streaming.js (market-session aligned).
   */
  function bucketTime(timeMs, resolution, exchange) {
    if (resolution === 'D' || resolution === '1D') {
      // Daily: IST-offset time
      return new Date().getTime() + 330 * 60 * 1000;
    }

    var tempRes;
    if (resolution === '1') tempRes = 1;
    else if (resolution === '3') tempRes = 3;
    else if (resolution === '5') tempRes = 5;
    else if (resolution === '15') tempRes = 15;
    else if (resolution === '30') tempRes = 30;
    else if (resolution === '45') tempRes = 45;
    else if (resolution === '60') tempRes = 60;
    else if (resolution === '120') tempRes = 120;
    else if (resolution === '180') tempRes = 180;
    else if (resolution === '240') tempRes = 240;
    else tempRes = parseInt(resolution) || 1;

    var coeff = 1000 * 60 * tempRes;

    if ((resolution === '30' || resolution === '60') && exchange !== 'MCX') {
      // Market-session aligned bucketing for 30/60 min (non-MCX)
      timeMs = Math.floor(timeMs / coeff) * coeff;

      if (resolution === '30') {
        var d30 = new Date(timeMs);
        var mins30 = d30.getMinutes();
        if (mins30 === 0) timeMs += 900000;       // +15 min offset
        else if (mins30 === 30) timeMs -= 900000;  // -15 min offset
      } else if (resolution === '60') {
        var now60 = new Date();
        var mins60 = now60.getMinutes();
        if (mins60 >= 0 && mins60 <= 14) timeMs -= 900000;
        else if (mins60 >= 15 && mins60 <= 59) timeMs += 900000;
      }
    } else {
      timeMs = Math.floor(timeMs / coeff) * coeff;
    }

    return timeMs;
  }

  /**
   * Parse LTT (Last Trade Time) string to milliseconds timestamp.
   * Format: "DD/MM/YYYY HH:MM:SS"
   */
  function parseLTT(ltt) {
    if (!ltt) return Date.now();
    var changedDate = ltt.replace(
      /(..)\/(..)\/(....) (..):(..):(..)/,
      "$3-$2-$1 $4:$5:$6"
    );
    var date = new Date(changedDate);
    return (!isNaN(date.getTime())) ? date.getTime() : Date.now();
  }


  // Expose global API for Dart JS interop
  window.ScalperCharts = {
    /**
     * Create a TradingView chart widget on a container div.
     * Polls for the container to appear in DOM before creating.
     */
    createChart: function (containerId, options) {
      desiredSymbols[containerId] = options.symbol;

      // Decorative chart title for the initial symbol (see dispNames).
      if (options.dispname) dispNames[options.symbol] = options.dispname;

      // Seed the symbol cache with authoritative exch + Token from Dart so
      // resolveSymbol can skip the be.mynt.in/getSymbolinfo lookup (which
      // does not return MCX entries reliably — without this seed the MCX
      // chart never loads).
      if (options.initialToken && options.initialExch) {
        symbolDataCache[options.symbol] = {
          exch: options.initialExch,
          Token: options.initialToken
        };
      }

      var attempts = 0;
      var maxAttempts = 50; // 5 seconds max

      function tryCreate() {
        var container = document.getElementById(containerId);
        if (!container) {
          attempts++;
          if (attempts < maxAttempts) {
            setTimeout(tryCreate, 100);
          } else {
            console.error('ScalperCharts: Container not found after timeout:', containerId);
          }
          return;
        }

        // Don't recreate if already exists
        if (charts[containerId]) {
          console.log('ScalperCharts: Chart already exists for', containerId);
          return;
        }

        var isDark = options.dark === true || options.dark === 'true';
        var isMinimal = options.minimal === true || options.minimal === 'true';
        var datafeed = createDatafeed(options.user, options.usession, containerId, options.sessions);

        // Last-used time-based resolution comes from the same settings key
        // that the web chart writes to (`settings_mob`). When the user
        // changes interval, TradingView calls our settings_adapter.setValue
        // and the choice survives the next chart open. Falls back to the
        // requested resolution and then '5'.
        var savedInterval = webSettingsAdapter.initialSettings['chart.lastUsedTimeBasedResolution'];

        // Feature flags.
        //   Minimal (scalper inline)   — compact look, no left toolbar.
        //   Non-minimal (desktop web)  — mirror the original web/tv/src/main.js
        //                                config (full top/left/bottom toolbars).
        var disabledFeatures = [
          "header_compare",
          "end_of_period_timescale_marks",
          "header_symbol_search"
        ];
        var enabledFeatures = [
          "study_templates",
          "use_localstorage_for_settings"
        ];

        if (isMinimal) {
          // Scalper-only — kept compact for the bottom-sheet view.
          disabledFeatures.push(
            "timeframes_toolbar",
            "symbol_info",
            "left_toolbar",
            "header_saveload",
            "uppercase_instrument_names"
          );
          enabledFeatures.push(
            "countdown",
            "create_volume_indicator_by_default",
            "show_zoom_and_move_buttons_on_touch"
          );
        } else {
          // Desktop web chart — restore the full toolbar set from the
          // pre-port main.js (drawing toolbar on the left, timeframes
          // strip at the bottom, full header).
          enabledFeatures.push(
            "timeframes_toolbar",
            "symbol_info",
            "left_toolbar",
            "countdown",
            "control_bar",
            "create_volume_indicator_by_default",
            "show_zoom_and_move_buttons_on_touch",
            "iframe_loading_compatibility_mode",
            "custom_resolutions",
            "header_saveload"
          );
        }

        try {
          var widgetOptions = {
            symbol: options.symbol,
            interval: savedInterval || options.resolution || '5',
            container: containerId,
            library_path: options.libraryPath,
            datafeed: datafeed,
            timezone: 'Asia/Kolkata',
            locale: 'en',
            autosize: true,
            fullscreen: false,
            theme: isDark ? 'dark' : 'light',
            // custom_font_family intentionally omitted — matches the live web
            // chart (zebu-mobchart.web.app), which lets TradingView use its
            // own Trebuchet MS / sans-serif stack. Forcing Inter here made the
            // legend and axis text noticeably heavier than the web version.

            // Auto-persist chart layout edits to chartbe.mynt.in within 1s
            // of the change. Matches live web (zebu-mobchart
            // `auto_save_delay:1`) so a layout edited on either platform
            // shows up on the other without the user clicking Save.
            auto_save_delay: 1,
            disabled_features: disabledFeatures,
            enabled_features: enabledFeatures,
            studies_overrides: {},
            charts_storage_url: 'https://chartbe.mynt.in',
            charts_storage_api_version: "1.1",
            // load_last_chart intentionally NOT set — mirrors web
            // (mynt.zebuetrade.com/tv/src/main.js where the option is
            // commented out). Each chart open starts fresh; the user
            // restores a saved layout manually via the header save/load
            // menu. This keeps the open path predictable (no surprise
            // overrides from a layout saved on another device).
            // Mirror the live web chart at zebu-mobchart.web.app/tv (the
            // iframe fallback in webview_chart.dart). It hardcodes:
            //     client_id: "Mynt_web",
            //     user_id:    <clientCode>,
            // so chartbe.mynt.in namespaces every saved layout / study
            // template by (Mynt_web, clientCode). Using "Mynt_web" here —
            // not "Mynt_mob" — is deliberate: it gives users one shared
            // namespace across phones and the web, so a layout saved on
            // either side shows up on the other. Switching to "Mynt_mob"
            // would split the namespaces and break web↔mobile sync.
            client_id: 'Mynt_web',
            user_id: options.user,
            // Persist TV-driven settings (candle style, last resolution,
            // grid colours, axis tweaks) to the same `settings_mob`
            // localStorage key the web chart uses, so prefs follow the
            // user across platforms on the same device.
            settings_adapter: webSettingsAdapter,
          };

          // widgetbar config matches the web (right sidebar — none of these on by default)
          if (!isMinimal) {
            widgetOptions.widgetbar = {
              details: false,
              news: false,
              watchlist: false,
              datawindow: false,
              watchlist_settings: { default_symbols: [], readonly: false }
            };
          }

          if (isMinimal) {
            // Scalper-only — covers the widget area until onChartReady fires,
            // hiding the brief "NSE:Nifty 50 · 5 · NSE" legend flash that
            // shows before resolveSymbol settles. The mobile web chart
            // doesn't need this because Vuetify's v-overlay covers it; in
            // the scalper bottom-sheet there is no overlay.
            widgetOptions.loading_screen = {
              backgroundColor: isDark ? '#121212' : '#ffffff',
              foregroundColor: isDark ? '#2E65F6' : '#0037B7'
            };
            // Scalper-only — the mobile web chart has no cap.
            widgetOptions.study_count_limit = 5;
          }
          // Non-minimal (mobile chart): NO `overrides` / no `applyOverrides`
          // anywhere. Mirrors TVChartContainerMOB.vue exactly. Any historical
          // `false` values from the prior code are wiped at module load by
          // `cleanupLegacyTvOverrides()` below.

          var widget = new TradingView.widget(widgetOptions);

          // Scalper-only override block — keeps the scalper inline chart's
          // background solid and re-applies legend tweaks after theme/layout
          // changes. The mobile web chart sets NONE of these (its legend
          // reads "NSE:NIFTY 50 · 5 · NSE  O… H… L… C…  +27.05 (+0.12%)"
          // straight from TradingView defaults), so the non-minimal path
          // skips this entirely.
          function applyScalperOverrides() {
            try {
              widget.activeChart().applyOverrides({
                'paneProperties.background': isDark ? '#121212' : '#ffffff',
                'paneProperties.backgroundType': 'solid',
                'paneProperties.backgroundGradientEndColor': isDark ? '#121212' : '#ffffff',
                'paneProperties.backgroundGradientStartColor': isDark ? '#121212' : '#ffffff',
                // statusViewStyle.showExchange/showInterval and
                // legendProperties.showSeriesOHLC intentionally NOT set —
                // they leaked into the mobile chart's shared localStorage
                // (use_localstorage_for_settings on, per-app origin) and
                // collapsed the mobile chart legend on interval changes.
                // Scalper now uses TV defaults for those properties.
                'mainSeriesProperties.highLowAvgPrice.highLowPriceLinesVisible': true,
                'mainSeriesProperties.highLowAvgPrice.highLowPriceLabelsVisible': true,
                'mainSeriesProperties.showCountdown': true,
                'paneProperties.legendProperties.showStudyArguments': false,
                'scalesProperties.showStudyPlotLabels': false,
              });
            } catch (e) { /* chart not ready */ }
          }

          widget.onChartReady(function () {
            // Hook TV's symbol-change event so that a saved layout load (or
            // TV's header search box) updates desiredSymbols and tells Dart
            // which scrip to subscribe via WS. Fires AFTER setSymbol →
            // resolveSymbol → getBars → subscribeBars completes, so the
            // symbolDataCache entry for the new symbol is ready.
            try {
              var ch = widget.activeChart();
              if (ch && ch.onSymbolChanged) {
                ch.onSymbolChanged().subscribe(null, function () {
                  try {
                    var newSym = ch.symbol();
                    if (!newSym) return;
                    desiredSymbols[containerId] = newSym;
                    notifyDartOfSymbolChange(containerId, newSym);
                  } catch (e) { /* widget mid-tear-down */ }
                });
              }
            } catch (e) { /* onSymbolChanged unavailable in some builds */ }

            // Mirrors TVChartContainerMOB.vue:205-211 — changeTheme, then
            // dataReady → chartReset to auto-fit the visible range.
            try { widget.changeTheme(isDark ? 'dark' : 'light'); } catch (e) { }

            if (isMinimal) {
              // Scalper bottom-sheet has no Vuetify overlay to mask the
              // theme flash, so we paint the body and re-apply overrides
              // after changeTheme (which resets all overrides to TV's
              // theme defaults).
              document.body.style.backgroundColor = isDark ? '#121212' : '#ffffff';
              setTimeout(applyScalperOverrides, 0);
              try {
                widget.subscribe('chart_loaded', function () {
                  try { widget.changeTheme(isDark ? 'dark' : 'light'); } catch (e) { }
                  setTimeout(applyScalperOverrides, 0);
                });
              } catch (e) { /* subscribe unavailable in some builds */ }
            }

            try {
              widget.activeChart().dataReady(function () {
                try { widget.activeChart().executeActionById('chartReset'); } catch (e) { }
              });
            } catch (e) { /* dataReady() unavailable in some builds */ }

            // Two-way default-indicator sync with be.mynt.in. Matches web
            // (TVChartContainerMOB.vue:212 → setIndicatorsInterval). Full
            // chart only — scalper inline view starts clean.
            if (!isMinimal) {
              setupIndicatorsSync(widget, containerId, options.user);
            }
          });

          charts[containerId] = widget;
          console.log('ScalperCharts: Chart created -', containerId, options.symbol);
        } catch (e) {
          console.error('ScalperCharts: Failed to create chart -', containerId, e);
        }
      }

      tryCreate();
    },

    /**
     * Pre-seed the symbol cache with the authoritative exch + Token for a
     * given symbol. Call this BEFORE changeSymbol when switching to a scrip
     * whose tsym isn't reliably resolvable via be.mynt.in/getSymbolinfo
     * (notably MCX). Without this, resolveSymbol fails and the chart stays
     * blank after the switch.
     */
    /**
     * Set the decorative display name used as the chart title for a symbol.
     * Call BEFORE changeSymbol so resolveSymbol picks it up on the way in.
     * Passing an empty name clears it (title falls back to the raw symbol).
     */
    setDispName: function (symbol, dispName) {
      if (!symbol) return;
      if (dispName) dispNames[symbol] = dispName;
      else delete dispNames[symbol];
    },

    seedSymbolData: function (symbol, exch, token) {
      if (!symbol || !token) return;
      symbolDataCache[symbol] = {
        exch: exch || '',
        Token: token
      };
    },

    /**
     * Change the symbol on an existing chart.
     * TradingView handles the re-resolution and data fetch internally.
     * This also triggers unsubscribeBars -> subscribeBars cycle.
     */
    changeSymbol: function (containerId, symbol) {
      // No-op when called with the symbol the chart is already on. Without
      // this, market_watch_provider.setChartScript can race with the initial
      // createChart on first open and wipe `subscriptions[containerId]` for
      // a symbol that TV's `setSymbol` then treats as a no-op — leaving the
      // chart with no live-tick callback bound (bug #19, surfacing again as
      // SENSEX freezing on close/reopen).
      if (desiredSymbols[containerId] === symbol) {
        console.log('ScalperCharts: changeSymbol skip (same symbol) -', containerId, symbol);
        return;
      }

      // Track desired symbol — stale getBars/subscribeBars from a previous
      // setSymbol call will check this and skip if it doesn't match.
      desiredSymbols[containerId] = symbol;

      // Stop tick delivery immediately
      delete subscriptions[containerId];

      // Cancel any pending debounced symbol change
      if (changeSymbolTimers[containerId]) {
        clearTimeout(changeSymbolTimers[containerId]);
      }

      // Debounce the actual setSymbol call (150ms) so rapid switches
      // only fire ONE setSymbol to TradingView, preventing concurrent
      // resolveSymbol/getBars/subscribeBars cycles that corrupt state.
      changeSymbolTimers[containerId] = setTimeout(function () {
        delete changeSymbolTimers[containerId];
        var widget = charts[containerId];
        if (widget) {
          try {
            // Read resolution safely — activeChart() can throw if the widget
            // is still resolving from a previous setSymbol call.
            var res = '5';
            try { res = widget.activeChart().resolution(); } catch (_) { }
            widget.setSymbol(symbol, res, function () { });
            console.log('ScalperCharts: Symbol changed -', containerId, symbol);
          } catch (e) {
            console.error('ScalperCharts: changeSymbol error -', containerId, e);
          }
        }
      }, 150);
    },

    /**
     * Push a real-time tick to update the chart's current candle.
     *
     * Called from Dart via JS interop when WebSocket data arrives.
     * This is the core real-time update mechanism - no polling needed.
     *
     * @param {string} containerId - The chart container div ID
     * @param {object} tickData - WebSocket data: { lp, v, ltt, e, ... }
     */
    pushTick: function (containerId, tickData) {
      var entry = subscriptions[containerId];
      if (!entry) return;

      // Pick the sub that matches the chart's underlying DATAFEED resolution.
      // Pushing to every sub is not an option: feeding 1-minute-bucketed ticks
      // into a study subscribed on another resolution (e.g. 52-week H/L on
      // weekly while main is daily) corrupts TV's internal study state and the
      // next render throws "Cannot read properties of null (reading '1')",
      // after which the chart is stuck and the socket looks disconnected even
      // though Dart is still pushing ticks.
      //
      // Datafeed resolution is DERIVED from the displayed one, because
      // resolveSymbol declares intraday_multipliers:["1"] / daily_multipliers:
      // ["1"]:
      //   - any intraday view (1, 3, 5, 15, …) → datafeed res is always "1";
      //     TV aggregates the view from 1-minute bars.
      //   - 1D / 1W / 1M → TV passes the daily res through to subscribeBars.
      var displayedRes = null;
      try {
        var w = charts[containerId];
        if (w && w.activeChart) displayedRes = w.activeChart().resolution();
      } catch (e) { /* widget mid-init */ }

      var targetRes;
      if (!displayedRes) {
        targetRes = null; // unknown → fall back to entry.main below
      } else if (displayedRes === '1D' || displayedRes === 'D'
              || displayedRes === '1W' || displayedRes === 'W'
              || displayedRes === '1M' || displayedRes === 'M') {
        targetRes = (displayedRes.length === 1) ? '1' + displayedRes : displayedRes;
      } else {
        targetRes = '1';
      }

      var sub = null;
      if (targetRes) {
        if (entry.main && entry.main.resolution === targetRes && entry.main.callback) {
          sub = entry.main;
        } else if (entry.studies) {
          for (var uid in entry.studies) {
            var s = entry.studies[uid];
            if (s && s.resolution === targetRes && s.callback) {
              sub = s;
              break;
            }
          }
        }
      }
      // Fallback: no resolution-matched sub (custom_resolutions input, or
      // displayedRes unreadable mid-init) — push to main so the chart still
      // gets ticks under unusual conditions rather than freezing.
      if (!sub && entry.main && entry.main.callback) sub = entry.main;
      if (!sub) return;

      // Studies subscribed on a DAILY series need the tick too, even while the
      // displayed resolution is intraday. Pivot Points Standard is the case
      // that matters: it opens a secondary 1D series (pivTimeFrame "Auto" maps
      // 1-15m -> "1D") and only emits a pivot set when a NEW bar appears on
      // that series, computed from the PREVIOUS daily bar's H/L/C. EODChartData
      // has no row for the current session, so without a synthesised bar for
      // today the study never sees today's period and draws no lines for it —
      // every earlier day renders fine, which is exactly how the bug presents.
      //
      // Each target is bucketed with its OWN resolution below. That is what
      // makes this safe: the crash this function's targeting was written to
      // avoid ("Cannot read properties of null (reading '1')") came from
      // feeding a bar bucketed for resolution A into a sub on resolution B,
      // not from serving more than one sub.
      //
      // '1D'/'D' is the complete set — a 1W/1M/12M study needs no separate
      // case. resolveSymbol declares has_weekly_and_monthly:false with
      // daily_multipliers:["1"], so the library's
      // findSuitableResolutionToBuildFrom() resolves every W/M series to
      // "1D" and aggregates it itself; the datafeed is never asked for
      // '1W'/'1M'. Verified against this exact symbolInfo: on a 30m chart
      // (Auto pivots -> 1W) the library issues `GETBARS res=1D` and reuses
      // the existing 1D subscription — no 1W subscribe is ever made.
      // So pivots on intervals above 15m ride the same 1D sub as below.
      var targets = [sub];
      if (entry.studies) {
        for (var suid in entry.studies) {
          var st = entry.studies[suid];
          if (!st || !st.callback || st === sub) continue;
          if (st.resolution === '1D' || st.resolution === 'D') targets.push(st);
        }
      }

      var lp = parseFloat(tickData.lp);
      if (isNaN(lp) || lp === 0) return;

      var vol = tickData.v ? parseFloat(tickData.v) : 0;
      var exchange = tickData.e || sub.exchange || '';

      // Today's running OHLC from the broker touchline feed. EODChartData
      // does NOT return today's bar (confirmed: the most recent EOD row
      // on web is the previous trading day). For daily mode we synthesise
      // today's candle from these fields — without them the bar would
      // collapse to a flat single-tick line at LP and be invisible.
      var dayOpen = parseFloat(tickData.o);
      var dayHigh = parseFloat(tickData.h);
      var dayLow  = parseFloat(tickData.l);
      var hasDayOhlc = !isNaN(dayOpen) && dayOpen > 0
                    && !isNaN(dayHigh) && dayHigh > 0
                    && !isNaN(dayLow)  && dayLow  > 0;

      // Parse trade time once; each target buckets it with its own resolution.
      var rawTime = parseLTT(tickData.ltt);

      function emitTo(sub) {
        // Bucket to candle boundary. Daily must land on the EOD grid: bars from
        // EODChartData are stamped at the session time-of-day (09:15 IST /
        // 03:45Z), NOT midnight, and TV spaces daily bars ~24h apart. An
        // IST-midnight anchor is only ~14h45m after the last EOD bar (< 24h),
        // so TV merged today's tick into YESTERDAY's candle. Keep the last
        // bar's time-of-day and move it onto today's UTC date so it forms a
        // proper next-day bucket.
        var isDaily = (sub.resolution === '1D' || sub.resolution === 'D');
        var time;
        if (isDaily) {
          var lastT = sub.lastBar ? sub.lastBar.time : null;
          var eodOffset = (lastT != null)
            ? (((lastT % 86400000) + 86400000) % 86400000)
            : 13500000; // 09:15 IST (03:45Z) fallback
          time = Math.floor(Date.now() / 86400000) * 86400000 + eodOffset;
        } else {
          time = bucketTime(rawTime, sub.resolution, exchange);
        }

        // Volume delta calculation
        var curVolume = vol;
        if (curVolume < sub.preVolume) curVolume = sub.preVolume;
        var volumeDelta = curVolume - sub.preVolume;

        var lastBar = sub.lastBar;
        var bar;

        if (!lastBar) {
          // No history bar yet — initialize from this tick so real-time updates
          // can start even if getBars failed or returned empty data. For daily,
          // seed full OHLC from the broker's day stats instead of a flat tick.
          bar = isDaily && hasDayOhlc ? {
            time: time, open: dayOpen, high: dayHigh, low: dayLow, close: lp, volume: vol
          } : {
            time: time, open: lp, high: lp, low: lp, close: lp, volume: 0
          };
          sub.preVolume = curVolume;
        } else if (time > lastBar.time) {
          // New candle - price crossed into next time bucket. For daily this
          // is the roll into "today" from yesterday's EOD bar — seed full
          // OHLC from the broker's day stats instead of a flat single-tick.
          bar = isDaily && hasDayOhlc ? {
            time: time, open: dayOpen, high: dayHigh, low: dayLow, close: lp, volume: vol
          } : {
            time: time, open: lp, high: lp, low: lp, close: lp, volume: 0
          };
          sub.preVolume = curVolume;
        } else {
          // Update existing candle. For daily, prefer the broker's running
          // day O/H/L since they're authoritative (TV's local high/low can
          // miss spikes that occurred before the chart connected).
          bar = isDaily && hasDayOhlc ? {
            time: lastBar.time,
            open:   dayOpen,
            high:   Math.max(dayHigh, lp),
            low:    Math.min(dayLow,  lp),
            close:  lp,
            volume: vol
          } : {
            time: lastBar.time,
            open: lastBar.open,
            high: Math.max(lastBar.high, lp),
            low: Math.min(lastBar.low, lp),
            close: lp,
            volume: volumeDelta
          };
        }

        sub.lastBar = bar;
        sub.callback(bar);
      }

      for (var ti = 0; ti < targets.length; ti++) emitTo(targets[ti]);
    },

    /**
     * Reset chart data — forces TradingView to re-fetch bars from the datafeed.
     * Use this when returning from a tab switch or system sleep to fill gaps.
     */
    resetData: function (containerId) {
      var widget = charts[containerId];
      if (widget) {
        try {
          // resetData() alone re-requests bars but does NOT invalidate the
          // datafeed's bar cache, so TV repaints from its stale cache and the
          // candles that formed while the tab was backgrounded never load
          // (getBars is never re-hit with to=now). resetCache() must precede
          // it — it discards cached bars, forcing resetData() to issue a fresh
          // firstDataRequest getBars that re-pulls TPSeries for the full
          // session and fills the gap. This is the documented contract:
          // "Before calling [resetData] the resetCache method should be
          // called." (IChartWidgetApi.resetData).
          widget.resetCache();
          widget.activeChart().resetData();
          console.log('ScalperCharts: resetData (cache+data) -', containerId);
        } catch (e) {
          console.error('ScalperCharts: resetData error -', containerId, e);
        }
      }
    },

    /**
     * Remove a chart widget and clean up subscription.
     */
    removeChart: function (containerId) {
      if (changeSymbolTimers[containerId]) {
        clearTimeout(changeSymbolTimers[containerId]);
        delete changeSymbolTimers[containerId];
      }
      if (indicatorSyncTimers[containerId]) {
        clearInterval(indicatorSyncTimers[containerId]);
        delete indicatorSyncTimers[containerId];
      }
      delete desiredSymbols[containerId];
      delete lastNotifiedSymbol[containerId];
      var widget = charts[containerId];
      if (widget) {
        try { widget.remove(); } catch (e) { }
        delete charts[containerId];
      }
      delete subscriptions[containerId];
    },

    /**
     * Check if a chart exists for the given container.
     */
    hasChart: function (containerId) {
      return !!charts[containerId];
    }
  };

  console.log('ScalperCharts bridge loaded');
})();
