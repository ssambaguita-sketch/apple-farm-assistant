import json
import math
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

SRC = Path('investment_daily')
OUT = Path('public')
OUT.mkdir(parents=True, exist_ok=True)


def sanitize(value):
    if value is None:
        return None
    if isinstance(value, dict):
        return {k: sanitize(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [sanitize(v) for v in value]
    try:
        if pd.isna(value):
            return None
    except (TypeError, ValueError):
        pass
    if isinstance(value, float) and not math.isfinite(value):
        return None
    if hasattr(value, 'item'):
        try:
            return sanitize(value.item())
        except Exception:
            pass
    return value


def records(path):
    if not path.exists():
        return []
    df = pd.read_csv(path, dtype={'ticker': str})
    return sanitize(df.to_dict(orient='records'))


def load_json(path):
    return sanitize(json.loads(path.read_text(encoding='utf-8'))) if path.exists() else {}

board = records(SRC / 'daily_decision_board.csv')
filings = records(SRC / 'recent_relevant_filings.csv')
watchlist = records(SRC / 'generated_watchlist.csv')
event_chains = records(SRC / 'event_chains.csv')
backtest_stats = records(SRC / 'backtest_stats.csv')
paper_portfolio = records(SRC / 'paper_portfolio.csv')
summary = load_json(SRC / 'summary.json')
discovery = load_json(SRC / 'discovery_summary.json')
v2_summary = load_json(SRC / 'v2_summary.json')
advanced_summary = load_json(SRC / 'advanced_summary.json')
paper_summary = load_json(SRC / 'paper_portfolio_summary.json')
backtest_summary = load_json(SRC / 'backtest_summary.json')
learned_weights = load_json(SRC / 'learned_weights.json')

payload = sanitize({
    'generated_at_utc': datetime.now(timezone.utc).isoformat(),
    'summary': summary,
    'discovery': discovery,
    'v2_summary': v2_summary,
    'advanced_summary': advanced_summary,
    'paper_portfolio_summary': paper_summary,
    'paper_portfolio': paper_portfolio[-200:],
    'backtest_summary': backtest_summary,
    'backtest_stats': backtest_stats,
    'learned_weights': learned_weights,
    'event_chains': event_chains[:300],
    'board': board,
    'watchlist': watchlist,
})

(OUT / 'data.json').write_text(json.dumps(payload, ensure_ascii=False, separators=(',', ':'), allow_nan=False), encoding='utf-8')
(OUT / 'filings.json').write_text(json.dumps({'filings': filings}, ensure_ascii=False, separators=(',', ':'), allow_nan=False), encoding='utf-8')
print(json.dumps({
    'board': len(board), 'filings': len(filings), 'watchlist': len(watchlist),
    'event_chains': len(event_chains), 'backtest_groups': len(backtest_stats),
    'paper_signals': len(paper_portfolio), 'auto_discovered': discovery.get('auto_discovered'),
    'v2': v2_summary, 'advanced': advanced_summary,
}, ensure_ascii=False, allow_nan=False))
