'use strict';

const PALETTES = {
  dark: {
    bg: '#0B0F14',
    gridSoft: '#1F2937',
    gridStrong: '#374151',
    axisText: '#6B7280',
    axisTextStrong: '#D1D5DB',
    long: '#3B82F6',
    short: '#EF4444',
    bull: '#10B981',
    bear: '#EF4444',
    bullSoft: 'rgba(16,185,129,0.5)',
    bearSoft: 'rgba(239,68,68,0.5)',
    crosshair: 'rgba(203,213,225,0.55)',
    crosshairChip: '#1F2937',
    chipText: '#0B0F14',
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
    long: '#2563EB',
    short: '#DC2626',
    bull: '#16A34A',
    bear: '#DC2626',
    bullSoft: 'rgba(22,163,74,0.5)',
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
