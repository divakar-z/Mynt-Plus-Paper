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
  var symbolDataCache = {}; // Cache symbol info from API
  var subscriptions = {};   // containerId -> { callback, lastBar, resolution, preVolume, exchange }
  var desiredSymbols = {};  // containerId -> symbol name (for gating stale getBars/subscribeBars)
  var changeSymbolTimers = {}; // containerId -> debounce timer

  /**
   * Create a datafeed object for a TradingView widget.
   * Each widget gets its own datafeed with user credentials and containerId in closure.
   */
  function createDatafeed(user, usession, containerId) {
    var lastBarFromHistory = null;
    // Tag lastBarFromHistory with the symbol it belongs to. Without this,
    // a re-subscribe after a setSymbol can seed subscriptions[].lastBar
    // with a bar from the *previous* symbol, producing a phantom candle
    // on the first tick of the new symbol.
    var lastBarSymbol = null;

    return {
      onReady: function (callback) {
        setTimeout(function () {
          callback({
            supported_resolutions: ['1', '3', '5', '15', '30', '45', '60', '120', '180', '240', '1D', '1W', '1M'],
          });
        }, 0);
      },

      searchSymbols: function (userInput, exchange, symbolType, onResultReadyCallback) {
        onResultReadyCallback([]);
      },

      resolveSymbol: function (symbolName, onResolvedCallback, onErrorCallback) {
        var cleanName = symbolName.includes(':') ? symbolName.split(':')[1] : symbolName;

        fetch('https://be.mynt.in/getSymbolinfo?tsym=' + encodeURIComponent(cleanName))
          .then(function (r) { return r.json(); })
          .then(function (symData) {
            symbolDataCache[cleanName] = symData;

            var raw = 'jData={"uid":"' + user + '","exch":"' + symData.exch + '","token":"' + symData.Token + '"}&jKey=' + usession;
            return fetch('https://go.mynt.in/NorenWClientWeb/GetSecurityInfo', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: raw
            }).then(function (r) { return r.json(); });
          })
          .then(function (info) {
            if (info && info.stat === 'Ok') {
              console.log('Symbol resolved:', info.tsym, info.exch + '|' + info.token);
            }

            // Cache under both the raw name and the resolved tsym so getBars
            // can find the data regardless of which key TradingView uses.
            var resolvedName = info.tsym || cleanName;
            if (resolvedName !== cleanName) {
              symbolDataCache[resolvedName] = symbolDataCache[cleanName];
            }

            // Update desiredSymbols to match the resolved name so the
            // getBars/subscribeBars stale-gate checks pass correctly.
            if (desiredSymbols[containerId] === cleanName && resolvedName !== cleanName) {
              desiredSymbols[containerId] = resolvedName;
              console.log('ScalperCharts: desiredSymbol updated', cleanName, '->', resolvedName);
            }

            var symbolInfo = {
              ticker: info.tsym,
              name: info.tsym,
              description: info.tsym,
              symbols_types: [{ name: "All types", value: "" }],
              value: info.exch,
              session: info.exch === "MCX" ? "0900-2355:23456" : info.exch === "CDS" ? "0900-1700:23456" : '0915-1530:23456',
              timezone: 'Asia/Kolkata',
              exchange: info.exch,
              minmov: 1,
              pricescale: 100,
              has_intraday: true,
              has_daily: true,
              has_weekly_and_monthly: false,
              intraday_multipliers: ["1"],
              daily_multipliers: ["1"],
              weekly_multipliers: ["1"],
              monthly_multipliers: ["1"],
              has_no_volume: false,
              supported_resolutions: ['1', '3', '5', '15', '30', '45', '60', '120', '180', '240', '1D', '1W', '1M'],
              volume_precision: 1,
              data_status: 'streaming',
              charts_storage_url: 'https://chartbe.mynt.in',
              charts_storage_api_version: '1.1',
              client_id: user,
              user_id: user,
            };
            onResolvedCallback(symbolInfo);
          })
          .catch(function (e) {
            console.error('resolveSymbol error:', e);
            onErrorCallback('Error resolving symbol: ' + e);
          });
      },

      getBars: function (symbolInfo, resolution, periodParams, onHistoryCallback, onErrorCallback) {
        var symData = symbolDataCache[symbolInfo.name] || {};

        if (resolution === '1D' || resolution === '1W' || resolution === '1M') {
          // Day/weekly/monthly chart
          var index = symData.index || symbolInfo.name;
          var reqBody = JSON.stringify({ sym: index, from: periodParams.from, to: periodParams.to });

          fetch('https://go.mynt.in/chartApi/getdata', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: reqBody
          })
            .then(function (r) { return r.json(); })
            .then(function (data) {
              if (!data || data.length === 0) {
                onHistoryCallback([], { noData: true });
                return;
              }
              var parsed = data.map(JSON.parse);
              var bars = parsed.map(function (d) {
                return {
                  time: parseFloat(d.ssboe) * 1000,
                  open: parseFloat(d.into),
                  high: parseFloat(d.inth),
                  low: parseFloat(d.intl),
                  close: parseFloat(d.intc),
                  volume: parseFloat(d.intv)
                };
              }).sort(function (a, b) { return a.time - b.time; });

              // Cache the last bar for subscribeBars (only if this is still the desired symbol)
              if (periodParams.firstDataRequest && bars.length > 0) {
                var desired = desiredSymbols[containerId];
                if (!desired || symbolInfo.name === desired || symbolInfo.ticker === desired) {
                  lastBarFromHistory = bars[bars.length - 1];
                  lastBarSymbol = symbolInfo.name;
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
          // Intraday chart
          var raw = 'jData={"uid":"' + user + '","exch":"' + (symData.exch || symbolInfo.exchange) + '","token":"' + (symData.Token || '') + '","st":"' + (periodParams.from - 320000) + '","et":"' + periodParams.to + '","intrv":"' + resolution + '"}&jKey=' + usession;

          fetch('https://go.mynt.in/NorenWClientWeb/TPSeries', {
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
              var bars = data.map(function (d) {
                return {
                  time: parseFloat(d.ssboe) * 1000,
                  open: parseFloat(d.into),
                  high: parseFloat(d.inth),
                  low: parseFloat(d.intl),
                  close: parseFloat(d.intc),
                  volume: parseFloat(d.intv)
                };
              }).sort(function (a, b) { return a.time - b.time; });

              // Cache the last bar for subscribeBars (only if this is still the desired symbol)
              if (periodParams.firstDataRequest && bars.length > 0) {
                var desired = desiredSymbols[containerId];
                if (!desired || symbolInfo.name === desired || symbolInfo.ticker === desired) {
                  lastBarFromHistory = bars[bars.length - 1];
                  lastBarSymbol = symbolInfo.name;
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
        // Gate: skip if this is a stale callback from a previous setSymbol call
        var desired = desiredSymbols[containerId];
        if (desired && symbolInfo.name !== desired && symbolInfo.ticker !== desired) {
          console.log('ScalperCharts: Skipping stale subscribeBars for', symbolInfo.name, '- desired:', desired);
          return;
        }

        // Register subscription for this chart container.
        // Dart will push ticks via ScalperCharts.pushTick().
        // Only seed lastBar from history if it belongs to the symbol we're
        // subscribing to — otherwise we'd inherit a stale bar from a prior
        // setSymbol cycle and corrupt the first tick's candle.
        var seedBar = (lastBarSymbol === symbolInfo.name) ? lastBarFromHistory : null;
        subscriptions[containerId] = {
          callback: onRealtimeCallback,
          lastBar: seedBar,
          resolution: resolution,
          subscriberUID: subscriberUID,
          preVolume: 0,
          exchange: symbolInfo.exchange || ''
        };
        console.log('ScalperCharts: subscribeBars -', containerId, 'res:', resolution);
      },

      unsubscribeBars: function (subscriberUID) {
        if (subscriptions[containerId] && subscriptions[containerId].subscriberUID === subscriberUID) {
          delete subscriptions[containerId];
          console.log('ScalperCharts: unsubscribeBars -', containerId);
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
        var datafeed = createDatafeed(options.user, options.usession, containerId);

        try {
          var widget = new TradingView.widget({
            symbol: options.symbol,
            interval: options.resolution || '5',
            container: containerId,
            library_path: options.libraryPath,
            datafeed: datafeed,
            timezone: 'Asia/Kolkata',
            autosize: true,
            fullscreen: false,
            theme: isDark ? 'dark' : 'light',
            custom_font_family: "Geist, monospace",
            disabled_features: ["header_compare", "end_of_period_timescale_marks", "header_symbol_search"],
            enabled_features: ["timeframes_toolbar", "symbol_info", "study_templates", "countdown", "create_volume_indicator_by_default", "control_bar", "show_zoom_and_move_buttons_on_touch", "left_toolbar"],
            study_count_limit: 5,
            charts_storage_url: 'https://chartbe.mynt.in',
            charts_storage_api_version: "1.1",
            client_id: options.user,
            user_id: options.user,
          });

          widget.onChartReady(function () {
            widget.activeChart().applyOverrides({
              "paneProperties.background": isDark ? '#131722' : '#ffffff',
              "paneProperties.backgroundGradientEndColor": isDark ? '#131722' : '#ffffff',
              "paneProperties.backgroundGradientStartColor": isDark ? '#131722' : '#ffffff',
              "paneProperties.horzGridProperties.color": isDark ? 'rgba(240, 243, 250, 0.06)' : 'rgba(42, 46, 57, 0.06)',
              "paneProperties.vertGridProperties.color": isDark ? 'rgba(240, 243, 250, 0.06)' : 'rgba(42, 46, 57, 0.06)',
              "scalesProperties.lineColor": isDark ? 'rgba(240, 243, 250, 0)' : 'rgba(42, 46, 57, 0)',
              "scalesProperties.textColor": isDark ? '#B2B5BE' : '#131722',
              'scalesProperties.showStudyPlotLabels': false,
              'mainSeriesProperties.showCountdown': true,
              'paneProperties.legendProperties.showStudyArguments': false,
              'paneProperties.legendProperties.showSeriesTitle': false,
              'mainSeriesProperties.statusViewStyle.showExchange': false,
              'mainSeriesProperties.statusViewStyle.showInterval': false,
            });
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
     * Change the symbol on an existing chart.
     * TradingView handles the re-resolution and data fetch internally.
     * This also triggers unsubscribeBars -> subscribeBars cycle.
     */
    changeSymbol: function (containerId, symbol) {
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
      var sub = subscriptions[containerId];
      if (!sub || !sub.callback) return;

      var lp = parseFloat(tickData.lp);
      if (isNaN(lp) || lp === 0) return;

      var vol = tickData.v ? parseFloat(tickData.v) : 0;
      var exchange = tickData.e || sub.exchange || '';

      // Parse trade time
      var time = parseLTT(tickData.ltt);

      // Bucket to candle boundary
      time = bucketTime(time, sub.resolution, exchange);

      // If lastBar is severely stale (long tab hide / system sleep), drop it.
      // Without this guard, the first tick after resume creates a phantom
      // candle whose OHLC are all the same single-tick price.
      if (sub.lastBar) {
        var staleGapMs = 60 * 60 * 1000; // 1 hour
        if (time - sub.lastBar.time > staleGapMs) {
          sub.lastBar = null;
          sub.preVolume = 0;
        }
      }

      // Volume delta calculation
      var curVolume = vol;
      if (curVolume < sub.preVolume) curVolume = sub.preVolume;
      var volumeDelta = curVolume - sub.preVolume;

      var lastBar = sub.lastBar;
      var bar;

      if (!lastBar) {
        // No history bar yet — initialize from this tick so real-time updates
        // can start even if getBars failed or returned empty data.
        bar = {
          time: time,
          open: lp,
          high: lp,
          low: lp,
          close: lp,
          volume: 0
        };
        sub.preVolume = curVolume;
      } else if (time > lastBar.time) {
        // New candle - price crossed into next time bucket
        bar = {
          time: time,
          open: lp,
          high: lp,
          low: lp,
          close: lp,
          volume: 0
        };
        sub.preVolume = curVolume;
      } else {
        // Update existing candle
        bar = {
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
    },

    /**
     * Refetch bar data via TradingView's resetData. Does NOT touch
     * subscriptions[containerId] — that record is owned by the
     * subscribeBars / unsubscribeBars cycle, not by us.
     *
     * In this TV version, activeChart().resetData() may not always
     * trigger a fresh subscribeBars cycle, so for a guaranteed full
     * refresh use the Dart-side recreateAllCharts() instead.
     */
    resetData: function (containerId) {
      var widget = charts[containerId];
      if (!widget) return;

      try {
        widget.activeChart().resetData();
        console.log('ScalperCharts: resetData -', containerId);
      } catch (e) {
        console.error('ScalperCharts: resetData error -', containerId, e);
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
      delete desiredSymbols[containerId];
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
