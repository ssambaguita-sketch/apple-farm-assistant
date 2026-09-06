import json
import os
import re
import time
from datetime import date, timedelta
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

import pandas as pd
import yfinance as yf

DART="https://opendart.fss.or.kr/api"
KEY=os.environ.get("OPENDART_API_KEY","").strip()
OUT=Path(os.environ.get("INVESTMENT_OUTDIR","investment_daily"))
WATCH=Path(os.environ.get("INVESTMENT_WATCHLIST","investment_daily/generated_watchlist.csv"))
YEARS=int(os.environ.get("BACKTEST_YEARS","5"))
EVENTS=("유상증자","전환사채","신주인수권부사채","교환사채","감자","자기주식","합병","분할","소송","회생절차","부도")
CORR=re.compile(r"^\[(?:기재정정|첨부정정|정정)\]\s*")


def api(params,timeout=25):
    q=dict(params); q["crtfc_key"]=KEY
    req=Request(f"{DART}/list.json?{urlencode(q)}",headers={"User-Agent":"OpenDARTBacktest/1.0"})
    try:
        with urlopen(req,timeout=timeout) as r: return json.loads(r.read().decode("utf-8"))
    except (HTTPError,URLError,TimeoutError) as e:
        raise RuntimeError(f"OpenDART list failed type={type(e).__name__}") from None


def event_type(title):
    t=str(title or "")
    for k in EVENTS:
        if k in t:return k
    return "OTHER"


def norm(title):
    return re.sub(r"\s+","",CORR.sub("",str(title or "")))


def date_chunks(start,end,days=90):
    cur=start
    while cur<=end:
        nxt=min(end,cur+timedelta(days=days-1)); yield cur,nxt; cur=nxt+timedelta(days=1)


def fetch_events(corp,company,ticker):
    end=date.today(); start=end-timedelta(days=YEARS*366); rows=[]
    for a,b in date_chunks(start,end):
        page=1
        while True:
            d=api({"corp_code":str(corp).zfill(8),"bgn_de":a.strftime("%Y%m%d"),"end_de":b.strftime("%Y%m%d"),"page_no":page,"page_count":100,"sort":"date","sort_mth":"asc"})
            if d.get("status")=="013":break
            if d.get("status")!="000":break
            for x in d.get("list") or []:
                typ=event_type(x.get("report_nm"))
                if typ!="OTHER": rows.append({"company":company,"ticker":ticker,"event_date":x.get("rcept_dt"),"rcept_no":x.get("rcept_no"),"report_nm":x.get("report_nm"),"event_type":typ,"normalized_title":norm(x.get("report_nm"))})
            if page>=int(d.get("total_page") or 1):break
            page+=1; time.sleep(.03)
    # correction-chain collapse: keep final disclosure in each same-day-ish normalized chain by latest receipt date/no
    df=pd.DataFrame(rows)
    if df.empty:return df
    df=df.sort_values(["event_date","rcept_no"]).drop_duplicates(["event_type","normalized_title","event_date"],keep="last")
    return df


def market_history(symbol,benchmark):
    px=yf.download(symbol,period=f"{YEARS+1}y",interval="1d",auto_adjust=False,progress=False,threads=False)
    bm=yf.download(benchmark,period=f"{YEARS+1}y",interval="1d",auto_adjust=False,progress=False,threads=False)
    for d in (px,bm):
        if isinstance(d.columns,pd.MultiIndex):d.columns=d.columns.get_level_values(0)
    return px,bm


def forward_returns(px,bm,event_date):
    if px is None or px.empty:return {}
    close=px["Close"].dropna().astype(float); bclose=bm["Close"].dropna().astype(float) if bm is not None and not bm.empty else pd.Series(dtype=float)
    dt=pd.to_datetime(str(event_date))
    pos=close.index.searchsorted(dt)
    if pos>=len(close):return {}
    base=float(close.iloc[pos]); out={"market_entry_date":str(close.index[pos].date()),"market_entry_close":base}
    for h in (1,5,20,60):
        if pos+h<len(close):
            r=(float(close.iloc[pos+h])/base-1)*100; out[f"return_{h}d_pct"]=r
            if len(bclose):
                bp=bclose.index.searchsorted(close.index[pos])
                if bp<len(bclose) and bp+h<len(bclose) and float(bclose.iloc[bp]):
                    br=(float(bclose.iloc[bp+h])/float(bclose.iloc[bp])-1)*100; out[f"relative_{h}d_pct"]=r-br
    return out


def main():
    if not KEY: raise SystemExit("OPENDART_API_KEY missing")
    if not WATCH.exists(): raise SystemExit(f"missing {WATCH}")
    watch=pd.read_csv(WATCH,dtype={"ticker":str,"corp_code":str})
    board=OUT/"daily_decision_board.csv"
    cmap={}
    if board.exists():
        b=pd.read_csv(board,dtype={"ticker":str,"corp_code":str})
        cmap={str(r.ticker).zfill(6):str(r.corp_code).split('.')[0].zfill(8) for _,r in b.iterrows() if str(r.get('corp_code','')) not in ('','nan')}
    allrows=[]
    for _,w in watch.iterrows():
        ticker=str(w["ticker"]).zfill(6); corp=cmap.get(ticker)
        if not corp:continue
        ev=fetch_events(corp,str(w["company"]),ticker)
        if ev.empty:continue
        symbol=ticker+str(w.get("yahoo_suffix","")); benchmark=str(w.get("benchmark","^KS11"))
        try:px,bm=market_history(symbol,benchmark)
        except Exception:continue
        for _,e in ev.iterrows(): allrows.append({**e.to_dict(),**forward_returns(px,bm,e.event_date)})
    out=pd.DataFrame(allrows)
    out.to_csv(OUT/"event_backtest_5y.csv",index=False,encoding="utf-8-sig")
    stats=[]
    if not out.empty:
        for typ,g in out.groupby("event_type"):
            rec={"event_type":typ,"n":len(g)}
            for h in (1,5,20,60):
                c=f"relative_{h}d_pct"
                if c in g:
                    s=pd.to_numeric(g[c],errors="coerce").dropna()
                    if len(s):rec.update({f"avg_rel_{h}d":round(float(s.mean()),2),f"median_rel_{h}d":round(float(s.median()),2),f"win_rate_{h}d":round(float((s>0).mean()*100),1)})
            stats.append(rec)
    pd.DataFrame(stats).to_csv(OUT/"backtest_stats.csv",index=False,encoding="utf-8-sig")
    (OUT/"backtest_summary.json").write_text(json.dumps({"events":len(out),"groups":len(stats),"years":YEARS},ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({"events":len(out),"groups":len(stats),"years":YEARS},ensure_ascii=False))

if __name__=="__main__":main()
