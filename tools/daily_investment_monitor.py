import json
import os
import time
import zipfile
from datetime import date, timedelta
from io import BytesIO
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET

import pandas as pd
import yfinance as yf

DART = "https://opendart.fss.or.kr/api"
KEY = os.environ.get("OPENDART_API_KEY", "").strip()
OUT = Path(os.environ.get("INVESTMENT_OUTDIR", "investment_daily"))
WATCHLIST = Path(os.environ.get("INVESTMENT_WATCHLIST", "config/investment_watchlist.csv"))
RELEVANT = ("유상증자", "전환사채", "신주인수권부사채", "교환사채", "감자", "자기주식", "합병", "분할", "타법인주식", "소송", "부도", "회생절차")
MIN_LIQUIDITY_KRW = 1_000_000_000


def http_json(endpoint, params, timeout=25):
    params = dict(params)
    params["crtfc_key"] = KEY
    url = f"{DART}/{endpoint}?{urlencode(params)}"
    req = Request(url, headers={"User-Agent": "OpenDARTInvestmentMonitor/1.2"})
    with urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def corp_map():
    url = f"{DART}/corpCode.xml?{urlencode({'crtfc_key': KEY})}"
    req = Request(url, headers={"User-Agent": "OpenDARTInvestmentMonitor/1.2"})
    with urlopen(req, timeout=30) as r:
        raw = r.read()
    zf = zipfile.ZipFile(BytesIO(raw))
    root = ET.fromstring(zf.read(zf.namelist()[0]))
    by_stock = {}
    for node in root.findall("list"):
        stock = (node.findtext("stock_code") or "").strip()
        if stock:
            by_stock[stock.zfill(6)] = {
                "corp_code": (node.findtext("corp_code") or "").strip(),
                "corp_name": (node.findtext("corp_name") or "").strip(),
            }
    return by_stock


def fetch_prices(symbol, benchmark):
    hist = yf.download(symbol, period="3mo", interval="1d", auto_adjust=False, progress=False, threads=False)
    if hist is None or hist.empty:
        return {"price_status": "NO_DATA", "data_quality": "가격 데이터 없음"}
    if isinstance(hist.columns, pd.MultiIndex):
        hist.columns = hist.columns.get_level_values(0)
    hist = hist.dropna(subset=["Close"])
    if hist.empty:
        return {"price_status": "NO_DATA", "data_quality": "가격 데이터 없음"}

    close = hist["Close"].astype(float)
    volume = hist["Volume"].fillna(0).astype(float)
    latest_raw = float(close.iloc[-1])
    latest = round(latest_raw)
    quality = []

    # Korean cash equities trade in integer KRW price units. A material fractional close
    # is treated as a vendor/corporate-action anomaly until independently verified.
    if abs(latest_raw - latest) >= 0.01:
        quality.append("비정상 소수점 종가")
    if len(volume) >= 3 and float(volume.tail(3).sum()) == 0:
        quality.append("최근 3거래일 거래량 0")

    prev = float(close.iloc[-2]) if len(close) >= 2 else latest_raw
    ret1 = (latest_raw / prev - 1) * 100 if prev else None
    avg_tv = float((close.tail(20) * volume.tail(20)).mean()) if len(close) else None
    ret5 = (latest_raw / float(close.iloc[-6]) - 1) * 100 if len(close) >= 6 and float(close.iloc[-6]) else None

    bench5 = None
    try:
        b = yf.download(benchmark, period="1mo", interval="1d", auto_adjust=False, progress=False, threads=False)
        if isinstance(b.columns, pd.MultiIndex):
            b.columns = b.columns.get_level_values(0)
        bc = b["Close"].dropna().astype(float)
        if len(bc) >= 6 and float(bc.iloc[-6]):
            bench5 = (float(bc.iloc[-1]) / float(bc.iloc[-6]) - 1) * 100
    except Exception:
        pass
    rel5 = ret5 - bench5 if ret5 is not None and bench5 is not None else None

    status = "ANOMALY" if quality else "OK"
    return {
        "price_status": status,
        "data_quality": "; ".join(quality) if quality else "정상",
        "latest_close": latest,
        "latest_close_raw": latest_raw,
        "return_1d_pct": ret1,
        "return_5d_pct": ret5,
        "relative_return_5d_pct": rel5,
        "avg_trading_value_20d_krw": avg_tv,
        "latest_volume": float(volume.iloc[-1]),
        "price_date": str(close.index[-1].date()),
    }


def recent_filings(corp_code, days=21):
    end = date.today()
    start = end - timedelta(days=days)
    page = 1
    found = []
    while True:
        data = http_json("list.json", {
            "corp_code": corp_code,
            "bgn_de": start.strftime("%Y%m%d"),
            "end_de": end.strftime("%Y%m%d"),
            "page_no": page,
            "page_count": 100,
            "sort": "date",
            "sort_mth": "desc",
        })
        status = data.get("status")
        if status == "013":
            break
        if status != "000":
            raise RuntimeError(f"OpenDART status={status} message={data.get('message')}")
        for item in data.get("list") or []:
            title = item.get("report_nm", "")
            if any(k in title for k in RELEVANT):
                found.append(item)
        if page >= int(data.get("total_page") or 1):
            break
        page += 1
        time.sleep(0.1)
    return found


def classify(row):
    liq = row.get("avg_trading_value_20d_krw")
    ret1 = row.get("return_1d_pct")
    rel5 = row.get("relative_return_5d_pct")
    corr = int(row.get("correction_count") or 0)
    filings = int(row.get("relevant_filing_count_21d") or 0)
    risk = 0
    setup = 0
    reasons = []

    if row.get("price_status") == "NO_DATA":
        return 0, 100, "AVOID", "가격 데이터 없음"
    if row.get("price_status") == "ANOMALY":
        return 0, 100, "AVOID", f"시장데이터 이상: {row.get('data_quality')}"
    if liq is None or liq < MIN_LIQUIDITY_KRW:
        reasons.append("20일 평균 거래대금 10억원 미만")
        if corr >= 5:
            reasons.append(f"정정 {corr}회")
        if filings >= 8:
            reasons.append(f"21일 내 관련공시 {filings}건")
        return 0, 100, "AVOID", "; ".join(reasons)

    if corr >= 5:
        risk += 25
        reasons.append(f"정정 {corr}회")
    elif corr >= 2:
        risk += 10
    if filings >= 8:
        risk += 10
        reasons.append(f"21일 내 관련공시 {filings}건")
    if ret1 is not None and ret1 <= -5:
        setup += min(25, abs(ret1) * 2)
        reasons.append(f"1일 수익률 {ret1:.1f}%")
    if rel5 is not None and rel5 <= -5:
        setup += min(20, abs(rel5) * 1.5)
        reasons.append(f"5일 시장대비 {rel5:.1f}%p")

    risk = min(100, risk)
    setup = min(100, setup)
    if risk >= 70:
        state = "AVOID"
    else:
        # Price dislocation alone is not enough for WATCH. Detailed financing/event
        # terms (dilution, payment completion, use of proceeds, etc.) must be enriched first.
        state = "RESEARCH"
        if setup >= 35:
            reasons.append("가격 과매도 후보이나 상세 공시조건 검증 전")
    return setup, risk, state, "; ".join(reasons)


def main():
    if not KEY:
        raise SystemExit("OPENDART_API_KEY secret is missing")
    OUT.mkdir(parents=True, exist_ok=True)
    watch = pd.read_csv(WATCHLIST, dtype={"ticker": str})
    cmap = corp_map()
    rows = []
    filing_rows = []

    for _, w in watch.iterrows():
        ticker = str(w["ticker"]).zfill(6)
        symbol = ticker + str(w["yahoo_suffix"])
        benchmark = str(w["benchmark"])
        info = cmap.get(ticker, {})
        corp_code = info.get("corp_code")
        company = str(w["company"])
        px = fetch_prices(symbol, benchmark)
        filings = recent_filings(corp_code) if corp_code else []
        corr = sum(1 for f in filings if str(f.get("report_nm", "")).startswith("["))

        for f in filings:
            rcept_no = str(f.get("rcept_no") or "")
            filing_rows.append({
                "company": company, "ticker": ticker, "corp_code": corp_code,
                "rcept_no": rcept_no, "rcept_dt": f.get("rcept_dt"),
                "report_nm": f.get("report_nm"),
                "dart_url": f"https://dart.fss.or.kr/dsaf001/main.do?rcpNo={rcept_no}" if rcept_no else "",
            })

        latest_no = str(filings[0].get("rcept_no")) if filings else ""
        row = {
            "as_of": str(date.today()), "company": company, "ticker": ticker,
            "corp_code": corp_code, "symbol": symbol,
            "source": str(w.get("source", "static")),
            "discovery_score": w.get("discovery_score", ""),
            "discovery_filings": w.get("discovery_filings", ""),
            "discovery_reasons": w.get("discovery_reasons", ""),
            **px,
            "relevant_filing_count_21d": len(filings),
            "correction_count": corr,
            "latest_relevant_filing": filings[0].get("report_nm") if filings else "",
            "latest_rcept_no": latest_no,
            "latest_dart_url": f"https://dart.fss.or.kr/dsaf001/main.do?rcpNo={latest_no}" if latest_no else "",
        }
        setup, risk, state, reasons = classify(row)
        row.update({
            "market_setup_score": round(setup, 1),
            "opportunity_score": round(setup, 1),
            "risk_score": round(risk, 1),
            "state": state,
            "reasons": reasons,
            "max_position_pct": 0,
            "entry_rule": "상세조건 enrichment 완료 전 실거래 금지",
            "stop_rule": "향후 WATCH 승격 후에만 손절 규칙 적용",
            "time_stop": "상세조건 검증 대기",
        })
        rows.append(row)

    board = pd.DataFrame(rows).sort_values(["state", "market_setup_score", "risk_score"], ascending=[True, False, True])
    board.to_csv(OUT / "daily_decision_board.csv", index=False, encoding="utf-8-sig")
    pd.DataFrame(filing_rows).to_csv(OUT / "recent_relevant_filings.csv", index=False, encoding="utf-8-sig")
    summary = {
        "as_of": str(date.today()), "symbols": len(board),
        "watch": int((board["state"] == "WATCH").sum()),
        "research": int((board["state"] == "RESEARCH").sum()),
        "avoid": int((board["state"] == "AVOID").sum()),
        "price_date_max": str(board["price_date"].dropna().max()) if "price_date" in board else None,
        "data_anomalies": int((board["price_status"] == "ANOMALY").sum()) if "price_status" in board else 0,
    }
    (OUT / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
