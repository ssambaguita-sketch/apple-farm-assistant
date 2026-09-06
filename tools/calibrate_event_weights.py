import json
from pathlib import Path
import pandas as pd

OUT=Path('investment_daily')
STATS=OUT/'backtest_stats.csv'
TARGET=OUT/'learned_weights.json'

MAP={
    '유상증자':'RIGHTS','전환사채':'CB','신주인수권부사채':'BW','교환사채':'EB',
    '자기주식':'TREASURY_BUY','합병':'MERGER','분할':'SPLIT','소송':'LITIGATION',
    '회생절차':'DISTRESS','부도':'DISTRESS'
}

def main():
    if not STATS.exists():
        TARGET.write_text('{}',encoding='utf-8'); print('{}'); return
    df=pd.read_csv(STATS)
    weights={}
    for _,r in df.iterrows():
        typ=str(r.get('event_type') or '')
        fam=next((v for k,v in MAP.items() if k in typ),typ or 'OTHER')
        n=int(r.get('n') or 0)
        # Prefer 20d benchmark-relative mean; cap impact to avoid overfitting.
        mean=r.get('avg_rel_20d')
        try: mean=float(mean)
        except Exception: mean=0.0
        adj=max(-15.0,min(15.0,mean/2.0)) if n>=30 else 0.0
        prev=weights.get(fam)
        rec={'n':n,'avg_relative_20d_pct':round(mean,2),'setup_adjustment':round(adj,2),'enabled':bool(n>=30)}
        if prev is None or n>prev.get('n',0): weights[fam]=rec
    TARGET.write_text(json.dumps(weights,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(weights,ensure_ascii=False))

if __name__=='__main__': main()
