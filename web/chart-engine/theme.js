'use strict';

// Mirror of lib/res/mynt_web_color_styles.dart MyntColors — keep these
// values in sync with the Dart source of truth. Buy/sell button colors
// are sourced from there so the chart matches the app theme globally.
//   BUY  (long)  → light: MyntColors.primary    dark: MyntColors.secondary
//   SELL (short) → light: MyntColors.tertiary   dark: MyntColors.errorDark

const PALETTES = {
  dark: {
    bg: '#0B0F14',
    gridSoft: '#1F2937',
    gridStrong: '#374151',
    axisText: '#6B7280',
    axisTextStrong: '#D1D5DB',
    long: '#0052CC',        // MyntColors.secondary
    longDisabled: '#103266', // ~50% of long blended on dark bg
    short: '#F85149',       // MyntColors.errorDark
    shortDisabled: '#823033', // ~50% of short blended on dark bg
    bull: '#059669',
    bear: '#EF4444',
    bullSoft: 'rgba(5,150,105,0.5)',
    bearSoft: 'rgba(239,68,68,0.5)',
    crosshair: 'rgba(203,213,225,0.55)',
    crosshairChip: '#21262D',
    chipText: '#C9D1D9',
    ohlcLabel: '#9CA3AF',
    ohlcValue: '#F3F4F6',
    statusLive: '#10B981',
    statusStale: '#EA580C',
  },
  light: {
    bg: '#FFFFFF',
    gridSoft: '#E2E8F0',
    gridStrong: '#94A3B8',
    axisText: '#64748B',
    axisTextStrong: '#0F172A',
    long: '#0037B7',        // MyntColors.primary
    longDisabled: '#809BDB', // ~50% of long blended on white bg
    short: '#C40024',       // MyntColors.tertiary
    shortDisabled: '#E48092', // ~50% of short blended on white bg
    bull: '#15803D',
    bear: '#DC2626',
    bullSoft: 'rgba(21,128,61,0.5)',
    bearSoft: 'rgba(220,38,38,0.5)',
    crosshair: 'rgba(71,85,105,0.55)',
    crosshairChip: '#0F172A',
    chipText: '#FFFFFF',
    ohlcLabel: '#64748B',
    ohlcValue: '#0F172A',
    statusLive: '#16A34A',
    statusStale: '#CA8A04',
  },
};

let CURRENT_PALETTE = 'dark';

function getPalette() { return PALETTES[CURRENT_PALETTE] || PALETTES.dark; }

function applyTheme(name) {
  if (name !== 'light' && name !== 'dark') return;
  CURRENT_PALETTE = name;
  document.documentElement.classList.toggle('light', name === 'light');
}
