import json
from datetime import datetime, timezone
from pathlib import Path
import pandas as pd

SRC = Path('investment_daily')
OUT = Path('public')
OUT.mkdir(parents=True, exist_ok=True)


def records(path):
    if not path.exists():
        return []
    df = pd.read_csv(path, dtype={'ticker': str})
    df = df.where(pd.notna(df), None)
    return df.to_dict(orient='records')


def load_json(path):
    return json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}

board = records(SRC / 'daily_decision_board.csv')
filings = records(SRC / 'recent_relevant_filings.csv')
watchlist = records(SRC / 'generated_watchlist.csv')
summary = load_json(SRC / 'summary.json')
discovery = load_json(SRC / 'discovery_summary.json')

payload = {
    'generated_at_utc': datetime.now(timezone.utc).isoformat(),
    'summary': summary,
    'discovery': discovery,
    'board': board,
    'watchlist': watchlist,
}
(OUT / 'data.json').write_text(json.dumps(payload, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
(OUT / 'filings.json').write_text(json.dumps({'filings': filings}, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
print(json.dumps({
    'board': len(board), 'filings': len(filings), 'watchlist': len(watchlist),
    'auto_discovered': discovery.get('auto_discovered'),
}, ensure_ascii=False))
