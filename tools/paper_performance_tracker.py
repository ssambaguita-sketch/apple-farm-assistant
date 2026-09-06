import json
from datetime import date, timedelta
from pathlib import Path

import pandas as pd
import yfinance as yf

PERSIST=Path('research/paper_signals.csv')
OUT=Path('investment_daily')
BOARD=OUT/'daily_decision_board.csv'


def history(symbol,start):
    try:
        end=date.today()+timedelta(days=1)
        df=yf.download(symbol,start=start,end=end.isoformat(),interval='1d',auto_adjust=False,progress=False,threads=False)
        if df is None or df.empty:return None
        if isinstance(df.columns,pd.MultiIndex):df.columns=df.columns.get_level_values(0)
        return df.dropna(subset=['Close'])
    except Exception:return None


def main():
    if not PERSIST.exists():
        OUT.mkdir(parents=True,exist_ok=True)
        pd.DataFrame().to_csv(OUT/'paper_portfolio_performance.csv',index=False)
        (OUT/'paper_performance_summary.json').write_text(json.dumps({'signals':0},indent=2),encoding='utf-8')
        print('{"signals":0}');return
    hist=pd.read_csv(PERSIST,dtype={'ticker':str})
    if hist.empty:
        hist.to_csv(OUT/'paper_portfolio_performance.csv',index=False,encoding='utf-8-sig');return
    symbols={}
    if BOARD.exists():
        b=pd.read_csv(BOARD,dtype={'ticker':str})
        symbols={str(r.get('ticker','')).zfill(6):str(r.get('symbol') or '') for _,r in b.iterrows()}
    for i,r in hist.iterrows():
        ticker=str(r.get('ticker','')).zfill(6); symbol=str(r.get('symbol') or symbols.get(ticker) or '')
        if symbol and symbol!='nan': hist.at[i,'symbol']=symbol
        else: continue
        start=str(r.get('signal_date') or '')
        if not start or start=='nan':continue
        df=history(symbol,start)
        if df is None or df.empty:continue
        closes=df['Close'].astype(float); highs=df['High'].astype(float); lows=df['Low'].astype(float)
        entry=float(r.get('entry_price') or closes.iloc[0]); latest=float(closes.iloc[-1])
        hist.at[i,'latest_price']=latest;hist.at[i,'return_pct']=round((latest/entry-1)*100,2)
        hist.at[i,'max_gain_pct']=round((float(highs.max())/entry-1)*100,2)
        hist.at[i,'max_drawdown_pct']=round((float(lows.min())/entry-1)*100,2)
        hist.at[i,'trading_days']=len(closes)-1
        if len(closes)>20:
            hist.at[i,'return_20d_pct']=round((float(closes.iloc[20])/entry-1)*100,2)
            hist.at[i,'tracking_status']='CLOSED_20D'
        else:
            hist.at[i,'tracking_status']='ACTIVE'
        hist.at[i,'last_update']=str(date.today())
    hist.to_csv(PERSIST,index=False,encoding='utf-8-sig')
    hist.to_csv(OUT/'paper_portfolio_performance.csv',index=False,encoding='utf-8-sig')
    ret=pd.to_numeric(hist.get('return_pct'),errors='coerce').dropna();r20=pd.to_numeric(hist.get('return_20d_pct'),errors='coerce').dropna()
    summary={'signals':len(hist),'active':int((hist.get('tracking_status',pd.Series(dtype=str))=='ACTIVE').sum()),'closed_20d':int((hist.get('tracking_status',pd.Series(dtype=str))=='CLOSED_20D').sum()),'avg_current_return_pct':round(float(ret.mean()),2) if len(ret) else None,'win_rate_current_pct':round(float((ret>0).mean()*100),1) if len(ret) else None,'avg_20d_return_pct':round(float(r20.mean()),2) if len(r20) else None,'win_rate_20d_pct':round(float((r20>0).mean()*100),1) if len(r20) else None}
    (OUT/'paper_performance_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False))

if __name__=='__main__':main()
