import json
import math
from pathlib import Path

import pandas as pd

OUT = Path('investment_daily')
STATS = OUT / 'backtest_stats.csv'
EVENTS = OUT / 'event_backtest_5y.csv'
TARGET = OUT / 'learned_weights.json'

MAP = {
    '유상증자': 'RIGHTS', '전환사채': 'CB', '신주인수권부사채': 'BW', '교환사채': 'EB',
    '자기주식': 'TREASURY_BUY', '합병': 'MERGER', '분할': 'SPLIT', '소송': 'LITIGATION',
    '회생절차': 'DISTRESS', '부도': 'DISTRESS', '감자': 'CAPITAL_REDUCTION',
}

MIN_SAMPLE = 30
POS_WIN_GATE = 52.0
NEG_WIN_GATE = 45.0
MAX_ABS_ADJ = 10.0


def family_name(event_type):
    typ = str(event_type or '')
    return next((v for k, v in MAP.items() if k in typ), typ or 'OTHER')


def winsorized_mean(series, q=0.10):
    s = pd.to_numeric(series, errors='coerce').dropna()
    if s.empty:
        return 0.0
    lo = float(s.quantile(q))
    hi = float(s.quantile(1 - q))
    return float(s.clip(lower=lo, upper=hi).mean())


def main():
    if not STATS.exists() or not EVENTS.exists():
        TARGET.write_text('{}', encoding='utf-8')
        print('{}')
        return

    stats = pd.read_csv(STATS)
    events = pd.read_csv(EVENTS)
    weights = {}

    for _, r in stats.iterrows():
        typ = str(r.get('event_type') or '')
        fam = family_name(typ)
        group = events[events['event_type'].astype(str) == typ]
        s = pd.to_numeric(group.get('relative_20d_pct'), errors='coerce').dropna()
        n = int(len(s))

        mean = float(s.mean()) if n else 0.0
        median = float(s.median()) if n else 0.0
        win_rate = float((s > 0).mean() * 100) if n else 0.0
        winsor = winsorized_mean(s)

        # Robust signal deliberately gives the median the largest weight.
        # Mean-only calibration is vulnerable to a handful of extreme winners.
        robust = 0.50 * median + 0.30 * winsor + 0.20 * mean
        sample_confidence = min(1.0, math.sqrt(n / 100.0)) if n else 0.0

        enabled = n >= MIN_SAMPLE
        gate = 'insufficient_sample'
        adjustment = 0.0

        if enabled:
            # Positive adjustment requires agreement across median, winsorized mean,
            # and win rate. A positive arithmetic mean alone can never add points.
            if median > 0 and winsor > 0 and win_rate >= POS_WIN_GATE:
                gate = 'positive_consensus'
                adjustment = max(0.0, min(MAX_ABS_ADJ, (robust / 2.0) * sample_confidence))
            # Negative evidence is allowed when the typical outcome and win rate agree.
            elif median < 0 and winsor < 0 and win_rate <= NEG_WIN_GATE:
                gate = 'negative_consensus'
                adjustment = min(0.0, max(-MAX_ABS_ADJ, (robust / 2.0) * sample_confidence))
            else:
                gate = 'mixed_neutral'
                adjustment = 0.0

        rec = {
            'n': n,
            'avg_relative_20d_pct': round(mean, 2),
            'median_relative_20d_pct': round(median, 2),
            'winsorized_mean_20d_pct': round(winsor, 2),
            'win_rate_20d_pct': round(win_rate, 1),
            'robust_signal_20d': round(robust, 2),
            'sample_confidence': round(sample_confidence, 3),
            'setup_adjustment': round(adjustment, 2),
            'gate': gate,
            'enabled': bool(enabled),
        }
        prev = weights.get(fam)
        if prev is None or n > prev.get('n', 0):
            weights[fam] = rec

    TARGET.write_text(json.dumps(weights, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(weights, ensure_ascii=False))


if __name__ == '__main__':
    main()
