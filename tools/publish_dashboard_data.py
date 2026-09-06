import json
import math
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

SRC = Path('investment_daily')
OUT = Path('public')
OUT.mkdir(parents=True, exist_ok=True)


def sanitize(value):
    """Convert pandas/numpy NaN/NA and non-finite floats to JSON null."""
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
    raw = df.to_dict(orient='records')
    return sanitize(raw)


def load_json(path):
    return sanitize(json.loads(path.read_text(encoding='utf-8'))) if path.exists() else {}


board = records(SRC / 'daily_decision_board.csv')
filings = records(SRC / 'recent_relevant_filings.csv')
watchlist = records(SRC / 'generated_watchlist.csv')
summary = load_json(SRC / 'summary.json')
discovery = load_json(SRC / 'discovery_summary.json')

payload = sanitize({
    'generated_at_utc': datetime.now(timezone.utc).isoformat(),
    'summary': summary,
    'discovery': discovery,
    'board': board,
    'watchlist': watchlist,
})

# allow_nan=False deliberately fails the workflow if an invalid JSON number ever slips through.
(OUT / 'data.json').write_text(
    json.dumps(payload, ensure_ascii=False, separators=(',', ':'), allow_nan=False),
    encoding='utf-8',
)
(OUT / 'filings.json').write_text(
    json.dumps({'filings': filings}, ensure_ascii=False, separators=(',', ':'), allow_nan=False),
    encoding='utf-8',
)
print(json.dumps({
    'board': len(board), 'filings': len(filings), 'watchlist': len(watchlist),
    'auto_discovered': discovery.get('auto_discovered'),
}, ensure_ascii=False, allow_nan=False))
