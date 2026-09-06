import json
import math
import os
from datetime import date
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

import pandas as pd
import yfinance as yf

OUT = Path(os.environ.get('INVESTMENT_OUTDIR', 'investment_daily'))
BOARD = OUT / 'daily_decision_board.csv'
WEIGHTS = OUT / 'learned_weights.json'
PERSIST = Path('research/paper_signals.csv')
KEY = os.environ.get('OPENDART_API_KEY', '').strip()
DART = 'https://opendart.fss.or.kr/api'
MIN_LIQ = 1_000_000_000


def num(v):
    try:
        x = float(v)
        return x if math.isfinite(x) else None
    except Exception:
        return None


def clean_reason_text(v):
    s = str(v or '').strip()
    if s.lower() in {'nan', 'none', 'null'}:
        return ''
    parts = []
    for x in s.split(';'):
        x = x.strip()
        if x and x.lower() not in {'nan', 'none', 'null'}:
            parts.append(x)
    return '; '.join(dict.fromkeys(parts))


def max_dilution(row):
    vals = [num(row.get('rights_post_dilution_pct')), num(row.get('cb_potential_dilution_pct'))]
    vals = [x for x in vals if x is not None]
    return max(vals) if vals else None


def dart_company(corp_code, timeout=20):
    if not KEY:
        return {}
    q = urlencode({'crtfc_key': KEY, 'corp_code': str(corp_code).split('.')[0].zfill(8)})
    req = Request(f'{DART}/company.json?{q}', headers={'User-Agent': 'OpenDARTAdvancedLayer/2.2'})
    try:
        with urlopen(req, timeout=timeout) as r:
            d = json.loads(r.read().decode('utf-8'))
        return d if d.get('status') == '000' else {}
    except (HTTPError, URLError, TimeoutError):
        return {}


def batch_prices(symbols):
    symbols = [s for s in dict.fromkeys(symbols) if s and s != 'nan']
    if not symbols:
        return {}
    try:
        raw = yf.download(symbols, period='3mo', interval='1d', auto_adjust=False,
                          progress=False, threads=True, group_by='ticker')
    except Exception:
        return {}
    out = {}
    if raw is None or raw.empty:
        return out
    if len(symbols) == 1:
        df = raw.copy()
        if isinstance(df.columns, pd.MultiIndex):
            df.columns = df.columns.get_level_values(-1)
        out[symbols[0]] = df
        return out
    if not isinstance(raw.columns, pd.MultiIndex):
        return out
    top = set(raw.columns.get_level_values(0))
    for sym in symbols:
        if sym in top:
            try:
                out[sym] = raw[sym].copy()
            except Exception:
                pass
    return out


def microstructure(h):
    try:
        if h is None or h.empty:
            return {}
        h = h.dropna(subset=['Close'])
        if len(h) < 21:
            return {}
        c = h['Close'].astype(float); hi = h['High'].astype(float); lo = h['Low'].astype(float)
        op = h['Open'].astype(float); vol = h['Volume'].fillna(0).astype(float)
        prev = c.shift(1)
        tr = pd.concat([(hi-lo).abs(), (hi-prev).abs(), (lo-prev).abs()], axis=1).max(axis=1)
        atr20 = float(tr.tail(20).mean())
        close = float(c.iloc[-1]); open_ = float(op.iloc[-1]); high = float(hi.iloc[-1]); low = float(lo.iloc[-1])
        prev_close = float(c.iloc[-2]) if len(c) >= 2 else close
        atr_move = ((close-prev_close)/atr20) if atr20 > 0 else None
        vol20 = float(vol.iloc[-21:-1].mean()) if len(vol) >= 21 else None
        volume_ratio = float(vol.iloc[-1]/vol20) if vol20 and vol20 > 0 else None
        gap = (open_/prev_close-1)*100 if prev_close else None
        recovery = (close-low)/(high-low)*100 if high > low else None
        range_pct = (high-low)/prev_close*100 if prev_close else None
        return {
            'atr20_krw': round(atr20,2),
            'atr_move_1d': round(atr_move,2) if atr_move is not None else None,
            'volume_ratio_20d': round(volume_ratio,2) if volume_ratio is not None else None,
            'gap_pct': round(gap,2) if gap is not None else None,
            'close_recovery_pct': round(recovery,1) if recovery is not None else None,
            'intraday_range_pct': round(range_pct,2) if range_pct is not None else None,
        }
    except Exception:
        return {}


def event_family(title):
    t = str(title or '')
    if '유상증자' in t: return 'RIGHTS'
    if '전환사채' in t: return 'CB'
    if '신주인수권부사채' in t: return 'BW'
    if '교환사채' in t: return 'EB'
    if '자기주식취득' in t or '자기주식 취득' in t: return 'TREASURY_BUY'
    if '자기주식처분' in t or '자기주식 처분' in t: return 'TREASURY_SELL'
    if '합병' in t: return 'MERGER'
    if '분할' in t: return 'SPLIT'
    if '소송' in t: return 'LITIGATION'
    if any(x in t for x in ('회생절차','부도','파산')): return 'DISTRESS'
    return 'OTHER'


def learned_weights():
    if not WEIGHTS.exists(): return {}
    try: return json.loads(WEIGHTS.read_text(encoding='utf-8'))
    except Exception: return {}


def event_adjustment(row, weights):
    fam = row.get('event_family','OTHER')
    risk = 0.0; setup = 0.0; notes = []
    if fam == 'RIGHTS':
        d = num(row.get('rights_post_dilution_pct')); disc = num(row.get('rights_issue_discount_pct'))
        if d is not None and d >= 25: risk += 25; notes.append('유증 대규모 희석')
        if d is not None and d <= 10: risk -= 5
        if disc is not None and disc <= -25: risk += 8; notes.append('발행가 할인폭 큼')
    elif fam == 'CB':
        over = num(row.get('cb_overhang_days')); convd = num(row.get('cb_conversion_discount_pct'))
        if over is not None and over >= 20: risk += 18; notes.append('CB 오버행 큼')
        if convd is not None and convd <= -20: risk += 10; notes.append('전환가 할인폭 큼')
        ch = num(row.get('cb_conversion_price_change_pct'))
        if ch is not None and ch < -10: risk += 10; notes.append('전환가 하향 정정')
    elif fam == 'TREASURY_BUY':
        setup += 10; risk -= 5; notes.append('자기주식 취득 이벤트')
    elif fam in ('TREASURY_SELL','LITIGATION'):
        risk += 10
    elif fam == 'DISTRESS':
        risk += 60; notes.append('회생/부도 계열 이벤트')
    elif fam in ('MERGER','SPLIT'):
        risk += 5
    w = weights.get(fam) or {}
    if int(w.get('n',0)) >= 30:
        adj = max(-15,min(15,float(w.get('setup_adjustment',0))))
        setup += adj; notes.append(f'5년 백테스트 보정 {adj:+.1f}')
    return setup, risk, notes


def update_paper_history(df):
    cols=['signal_date','company','ticker','symbol','entry_price','latest_price','return_pct','state','confidence_score','risk_score','market_setup_score','last_update']
    if PERSIST.exists():
        try: hist=pd.read_csv(PERSIST,dtype={'ticker':str})
        except Exception: hist=pd.DataFrame(columns=cols)
    else: hist=pd.DataFrame(columns=cols)
    today=str(date.today()); current={str(r['ticker']).zfill(6):r for _,r in df.iterrows()}
    if not hist.empty:
        for i,r in hist.iterrows():
            t=str(r.get('ticker','')).zfill(6); cur=current.get(t)
            if cur is not None:
                lp=num(cur.get('latest_close')); ep=num(r.get('entry_price'))
                if lp is not None: hist.at[i,'latest_price']=lp
                if lp is not None and ep: hist.at[i,'return_pct']=round((lp/ep-1)*100,2)
                hist.at[i,'state']=cur.get('state'); hist.at[i,'symbol']=cur.get('symbol'); hist.at[i,'last_update']=today
    existing=set(zip(hist.get('signal_date',pd.Series(dtype=str)).astype(str),hist.get('ticker',pd.Series(dtype=str)).astype(str))) if not hist.empty else set()
    adds=[]
    for _,r in df[df['state']=='PAPER_BUY'].iterrows():
        key=(today,str(r['ticker']).zfill(6))
        if key in existing: continue
        ep=num(r.get('latest_close'))
        adds.append({'signal_date':today,'company':r.get('company'),'ticker':key[1],'symbol':r.get('symbol'),'entry_price':ep,'latest_price':ep,'return_pct':0.0,'state':'PAPER_BUY','confidence_score':r.get('confidence_score'),'risk_score':r.get('risk_score'),'market_setup_score':r.get('market_setup_score'),'last_update':today})
    if adds: hist=pd.concat([hist,pd.DataFrame(adds)],ignore_index=True)
    PERSIST.parent.mkdir(parents=True,exist_ok=True)
    hist.to_csv(PERSIST,index=False,encoding='utf-8-sig'); hist.to_csv(OUT/'paper_portfolio.csv',index=False,encoding='utf-8-sig')
    returns=pd.to_numeric(hist.get('return_pct',pd.Series(dtype=float)),errors='coerce').dropna()
    summary={'signals':len(hist),'active_paper_buy':int((hist.get('state',pd.Series(dtype=str))=='PAPER_BUY').sum()),'avg_return_pct':round(float(returns.mean()),2) if len(returns) else None,'win_rate_pct':round(float((returns>0).mean()*100),1) if len(returns) else None}
    (OUT/'paper_portfolio_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    return summary


def main():
    if not BOARD.exists(): raise SystemExit(f'missing {BOARD}')
    df=pd.read_csv(BOARD,dtype={'ticker':str,'corp_code':str})
    weights=learned_weights()
    symbols=[str(x or '') for x in df.get('symbol',pd.Series(dtype=str)).tolist()]
    prices=batch_prices(symbols)
    industry_cache={}
    micro=[]; industries=[]
    for _,r in df.iterrows():
        symbol=str(r.get('symbol') or '')
        micro.append(microstructure(prices.get(symbol)))
        corp=str(r.get('corp_code') or '').split('.')[0].zfill(8)
        if corp not in industry_cache:
            industry_cache[corp]=dart_company(corp)
        info=industry_cache[corp]
        industries.append(str(info.get('induty_code') or 'UNKNOWN'))
    mdf=pd.DataFrame(micro,index=df.index)
    for c in mdf.columns: df[c]=mdf[c]
    df['industry_code']=industries
    suffix=df.get('symbol',pd.Series('',index=df.index)).astype(str).str.extract(r'(\.KS|\.KQ)$',expand=False).fillna('')
    df['peer_group_proxy']=df['industry_code'].astype(str)+'|'+suffix
    ret=pd.to_numeric(df.get('return_5d_pct'),errors='coerce'); df['_ret5']=ret
    counts=df.groupby('peer_group_proxy')['peer_group_proxy'].transform('size')
    med=df.groupby('peer_group_proxy')['_ret5'].transform('median')
    df['sector_relative_5d_pct']=((df['_ret5']-med).where(counts>=2)).round(2)
    df['sector_proxy']=df['industry_code']
    df.drop(columns=['_ret5'],inplace=True)
    for i,row in df.iterrows():
        fam=event_family(row.get('latest_relevant_filing')); df.at[i,'event_family']=fam
        setup_adj,risk_adj,notes=event_adjustment({**row.to_dict(),'event_family':fam},weights)
        setup=(num(row.get('market_setup_score')) or 0)+setup_adj; risk=(num(row.get('risk_score')) or 0)+risk_adj
        vr=num(df.at[i,'volume_ratio_20d']) if 'volume_ratio_20d' in df else None
        am=num(df.at[i,'atr_move_1d']) if 'atr_move_1d' in df else None
        rec=num(df.at[i,'close_recovery_pct']) if 'close_recovery_pct' in df else None
        sr=num(df.at[i,'sector_relative_5d_pct'])
        dilution=max_dilution(row)
        if vr is not None and vr>=3: setup+=5; notes.append(f'거래량 {vr:.1f}배')
        if am is not None and am<=-2: setup+=7; notes.append(f'ATR 대비 {am:.1f}σ 하락')
        if rec is not None and rec>=70 and am is not None and am<0: setup+=4; notes.append('장중 저점 회복')
        if sr is not None and sr<=-8: setup+=5; notes.append(f'OpenDART 동종업종 대비 {sr:.1f}%p')
        setup=max(0,min(100,setup)); risk=max(0,min(100,risk)); conf=num(row.get('confidence_score')) or 0
        state=str(row.get('state') or 'RESEARCH'); liq=num(row.get('avg_trading_value_20d_krw')) or 0
        hard_dilution = dilution is not None and dilution >= 30
        if hard_dilution:
            state='AVOID'; risk=max(risk,90); notes.append(f'하드필터: 최대 희석 {dilution:.1f}%')
        elif fam=='DISTRESS' or risk>=70 or liq<MIN_LIQ or row.get('price_status')!='OK':
            state='AVOID'
        elif state!='PAPER_BUY':
            state='WATCH' if setup>=25 and conf>=65 and risk<=50 else 'RESEARCH'
        df.at[i,'market_setup_score']=round(setup,1); df.at[i,'opportunity_score']=round(setup,1); df.at[i,'risk_score']=round(risk,1); df.at[i,'state']=state
        base=clean_reason_text(row.get('reasons')); extra=clean_reason_text('; '.join(notes)); df.at[i,'reasons']='; '.join(x for x in [base,extra] if x)
    rank={'PAPER_BUY':0,'WATCH':1,'RESEARCH':2,'AVOID':3}; df['_rank']=df['state'].map(rank).fillna(9)
    df=df.sort_values(['_rank','confidence_score','market_setup_score'],ascending=[True,False,False]).drop(columns=['_rank'])
    df.to_csv(BOARD,index=False,encoding='utf-8-sig'); paper=update_paper_history(df)
    known=int((df.industry_code!='UNKNOWN').sum())
    peer_group_count=int(df.loc[counts>=2,'peer_group_proxy'].nunique()) if len(df) else 0
    summary={'rows':len(df),'paper_buy':int((df.state=='PAPER_BUY').sum()),'watch':int((df.state=='WATCH').sum()),'research':int((df.state=='RESEARCH').sum()),'avoid':int((df.state=='AVOID').sum()),'industry_code_known':known,'peer_groups_with_2plus':peer_group_count,'paper_portfolio':paper}
    (OUT/'advanced_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False))

if __name__=='__main__': main()
