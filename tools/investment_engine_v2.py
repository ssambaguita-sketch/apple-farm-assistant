import json
import math
import os
import re
import time
from collections import Counter, defaultdict
from datetime import date, timedelta
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

import pandas as pd

DART = "https://opendart.fss.or.kr/api"
KEY = os.environ.get("OPENDART_API_KEY", "").strip()
OUT = Path(os.environ.get("INVESTMENT_OUTDIR", "investment_daily"))
BOARD = OUT / "daily_decision_board.csv"
LOOKBACK = int(os.environ.get("V2_LOOKBACK_DAYS", "365"))
MIN_LIQ = 1_000_000_000
CORRECTION_PREFIX = re.compile(r"^\[(?:기재정정|첨부정정|정정)\]\s*")

EVENT_PATTERNS = {
    "RIGHTS": ("유상증자",),
    "CB": ("전환사채",),
    "BW": ("신주인수권부사채",),
    "EB": ("교환사채",),
    "TREASURY_BUY": ("자기주식취득", "자기주식 취득"),
    "TREASURY_SELL": ("자기주식처분", "자기주식 처분"),
    "MERGER": ("합병",),
    "SPLIT": ("분할",),
    "LITIGATION": ("소송",),
    "DISTRESS": ("회생절차", "부도", "파산"),
}


def safe_api(endpoint, params, timeout=25):
    if not KEY:
        raise RuntimeError("OPENDART_API_KEY missing")
    q = dict(params)
    q["crtfc_key"] = KEY
    req = Request(f"{DART}/{endpoint}?{urlencode(q)}", headers={"User-Agent": "OpenDARTInvestmentV2/2.0"})
    try:
        with urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError) as e:
        raise RuntimeError(f"OpenDART request failed endpoint={endpoint} type={type(e).__name__}") from None


def num(v):
    if v is None:
        return None
    s = str(v).replace(",", "").replace("%", "").strip()
    if not s or s in {"-", "null", "None", "nan"}:
        return None
    try:
        x = float(s)
        return x if math.isfinite(x) else None
    except Exception:
        return None


def family(title):
    t = str(title or "")
    for k, pats in EVENT_PATTERNS.items():
        if any(p in t for p in pats):
            return k
    return "OTHER"


def norm_title(title):
    t = CORRECTION_PREFIX.sub("", str(title or "")).strip()
    t = re.sub(r"\s+", "", t)
    t = re.sub(r"\(.*?\)", "", t)
    return t


def list_filings(corp_code, days=365):
    end = date.today()
    start = end - timedelta(days=days)
    rows, page = [], 1
    while True:
        d = safe_api("list.json", {
            "corp_code": str(corp_code).zfill(8), "bgn_de": start.strftime("%Y%m%d"),
            "end_de": end.strftime("%Y%m%d"), "page_no": page, "page_count": 100,
            "sort": "date", "sort_mth": "asc",
        })
        if d.get("status") == "013":
            break
        if d.get("status") != "000":
            break
        rows.extend(d.get("list") or [])
        if page >= int(d.get("total_page") or 1):
            break
        page += 1
        time.sleep(0.05)
    return rows


def detail_rows(endpoint, corp_code, days=365):
    end = date.today(); start = end - timedelta(days=days)
    d = safe_api(endpoint, {"corp_code": str(corp_code).zfill(8), "bgn_de": start.strftime("%Y%m%d"), "end_de": end.strftime("%Y%m%d")})
    return (d.get("list") or []) if d.get("status") == "000" else []


def rights_metrics(rows, market_price):
    if not rows:
        return {}
    first, last = rows[0], rows[-1]
    new = (num(last.get("nstk_ostk_cnt")) or 0) + (num(last.get("nstk_estk_cnt")) or 0)
    pre = (num(last.get("bfic_tisstk_ostk")) or 0) + (num(last.get("bfic_tisstk_estk")) or 0)
    dilution = new / (pre + new) * 100 if new and pre else None
    # Some OpenDART variants expose issue price under one of these keys. Keep tolerant.
    issue_price = None
    for k in ("nstk_ostk_ism", "nstk_estk_ism", "iss_prc", "nstk_ostk_prc"):
        issue_price = num(last.get(k))
        if issue_price:
            break
    terp = None
    discount = None
    if market_price and issue_price and new and pre:
        terp = (pre * market_price + new * issue_price) / (pre + new)
        discount = (issue_price / market_price - 1) * 100
    first_new = (num(first.get("nstk_ostk_cnt")) or 0) + (num(first.get("nstk_estk_cnt")) or 0)
    change = ((new / first_new - 1) * 100) if first_new and new else None
    uses = {
        "facility": num(last.get("fdpp_fclt")) or 0,
        "operating": num(last.get("fdpp_op")) or 0,
        "debt": num(last.get("fdpp_dtrp")) or 0,
        "acquisition": num(last.get("fdpp_ocsa")) or 0,
        "business_acq": num(last.get("fdpp_bsninh")) or 0,
        "other": num(last.get("fdpp_etc")) or 0,
    }
    return {
        "rights_terms_count": len(rows), "rights_rcept_no": last.get("rcept_no"),
        "rights_new_shares": new or None, "rights_pre_shares": pre or None,
        "rights_post_dilution_pct": round(dilution, 2) if dilution is not None else None,
        "rights_issue_price": issue_price, "rights_terp": round(terp, 2) if terp else None,
        "rights_issue_discount_pct": round(discount, 2) if discount is not None else None,
        "rights_new_shares_change_pct": round(change, 2) if change is not None else None,
        "rights_method": last.get("ic_mthn"), **{f"rights_use_{k}_krw": v for k,v in uses.items()},
    }


def cb_metrics(rows, avg_volume, market_price):
    if not rows:
        return {}
    first, last = rows[0], rows[-1]
    amount = num(last.get("bd_fta")); conv = num(last.get("cv_prc")); shares = num(last.get("cvisstk_cnt")); dilution = num(last.get("cvisstk_tisstk_vs")); floor = num(last.get("act_mktprcfl_cvprc_lwtrsprc"))
    days_to_absorb = shares / avg_volume if shares and avg_volume and avg_volume > 0 else None
    conv_discount = (conv / market_price - 1) * 100 if conv and market_price else None
    first_amount = num(first.get("bd_fta")); amount_change = ((amount / first_amount - 1) * 100) if amount and first_amount else None
    first_conv = num(first.get("cv_prc")); conv_change = ((conv / first_conv - 1) * 100) if conv and first_conv else None
    uses = {
        "facility": num(last.get("fdpp_fclt")) or 0,
        "operating": num(last.get("fdpp_op")) or 0,
        "debt": num(last.get("fdpp_dtrp")) or 0,
        "acquisition": num(last.get("fdpp_ocsa")) or 0,
        "business_acq": num(last.get("fdpp_bsninh")) or 0,
        "other": num(last.get("fdpp_etc")) or 0,
    }
    return {
        "cb_terms_count": len(rows), "cb_rcept_no": last.get("rcept_no"), "cb_amount_krw": amount,
        "cb_conversion_price": conv, "cb_potential_shares": shares, "cb_potential_dilution_pct": dilution,
        "cb_reset_floor": floor, "cb_payment_date": last.get("pymd"), "cb_convert_start": last.get("cvrqpd_bgd"), "cb_convert_end": last.get("cvrqpd_edd"),
        "cb_overhang_days": round(days_to_absorb, 1) if days_to_absorb else None,
        "cb_conversion_discount_pct": round(conv_discount, 2) if conv_discount is not None else None,
        "cb_amount_change_pct": round(amount_change, 2) if amount_change is not None else None,
        "cb_conversion_price_change_pct": round(conv_change, 2) if conv_change is not None else None,
        **{f"cb_use_{k}_krw": v for k,v in uses.items()},
    }


def infer_payment(filings):
    titles = [str(x.get("report_nm") or "") for x in filings]
    if any("증권발행결과" in t or "납입완료" in t or "발행결과" in t for t in titles):
        return "CONFIRMED_OR_RESULT_FILED"
    if any("철회" in t or "취소" in t for t in titles):
        return "CANCELLED_OR_WITHDRAWN"
    return "UNVERIFIED"


def build_chains(filings):
    chains = defaultdict(list)
    for f in filings:
        fam = family(f.get("report_nm"))
        if fam == "OTHER":
            continue
        key = (fam, norm_title(f.get("report_nm")))
        chains[key].append(f)
    out = []
    for (fam, title), rows in chains.items():
        rows = sorted(rows, key=lambda x: str(x.get("rcept_dt") or ""))
        corrections = sum(1 for x in rows if CORRECTION_PREFIX.match(str(x.get("report_nm") or "")))
        out.append({"family": fam, "normalized_title": title, "filings": len(rows), "corrections": corrections,
                    "first_date": rows[0].get("rcept_dt"), "last_date": rows[-1].get("rcept_dt"),
                    "latest_rcept_no": rows[-1].get("rcept_no")})
    return sorted(out, key=lambda x: str(x.get("last_date") or ""), reverse=True)


def financial_health(corp_code):
    years = [str(date.today().year - 1), str(date.today().year - 2)]
    rows = None; used_year = None; used_fs = None
    for y in years:
        for fs in ("CFS", "OFS"):
            d = safe_api("fnlttSinglAcntAll.json", {"corp_code": str(corp_code).zfill(8), "bsns_year": y, "reprt_code": "11011", "fs_div": fs})
            if d.get("status") == "000" and d.get("list"):
                rows = d["list"]; used_year = y; used_fs = fs; break
        if rows: break
    if not rows:
        return {"financials_verified": False}

    def find_amount(names, ids=()):
        for r in rows:
            aid = str(r.get("account_id") or "")
            an = str(r.get("account_nm") or "")
            if aid in ids or any(n in an for n in names):
                x = num(r.get("thstrm_amount"))
                if x is not None: return x
        return None
    cash = find_amount(("현금및현금성자산",), ("ifrs-full_CashAndCashEquivalents",))
    assets = find_amount(("자산총계",), ("ifrs-full_Assets",))
    liabilities = find_amount(("부채총계",), ("ifrs-full_Liabilities",))
    equity = find_amount(("자본총계",), ("ifrs-full_Equity",))
    revenue = find_amount(("매출액", "영업수익"), ("ifrs-full_Revenue",))
    op_income = find_amount(("영업이익", "영업손실"), ())
    ocf = find_amount(("영업활동현금흐름", "영업활동으로인한현금흐름"), ())
    debt_ratio = liabilities / equity * 100 if liabilities is not None and equity and equity > 0 else None
    cash_assets = cash / assets * 100 if cash is not None and assets and assets > 0 else None
    return {"financials_verified": True, "financial_year": used_year, "financial_fs_div": used_fs,
            "cash_krw": cash, "assets_krw": assets, "liabilities_krw": liabilities, "equity_krw": equity,
            "revenue_krw": revenue, "operating_income_krw": op_income, "operating_cashflow_krw": ocf,
            "debt_ratio_pct": round(debt_ratio,2) if debt_ratio is not None else None,
            "cash_to_assets_pct": round(cash_assets,2) if cash_assets is not None else None}


def confidence(row):
    checks = [
        row.get("price_status") == "OK",
        bool(row.get("terms_verified_v2")),
        row.get("payment_status") != "UNVERIFIED",
        bool(row.get("financials_verified")),
        bool(row.get("event_chain_count")),
        (num(row.get("avg_trading_value_20d_krw")) or 0) >= MIN_LIQ,
    ]
    return round(sum(bool(x) for x in checks) / len(checks) * 100)


def score(row):
    risk = num(row.get("risk_score")) or 0
    setup = num(row.get("market_setup_score")) or 0
    reasons = [x for x in str(row.get("reasons") or "").split("; ") if x]
    rd = num(row.get("rights_post_dilution_pct")); cd = num(row.get("cb_potential_dilution_pct"))
    debt = num(row.get("debt_ratio_pct")); ocf = num(row.get("operating_cashflow_krw"))
    repeats = int(num(row.get("financing_events_365d")) or 0); chain_corr = int(num(row.get("event_chain_corrections")) or 0)
    payment = row.get("payment_status")
    overhang = num(row.get("cb_overhang_days"))

    if max([x for x in (rd,cd) if x is not None], default=0) >= 30:
        risk += 45; reasons.append("희석률 30% 이상")
    elif max([x for x in (rd,cd) if x is not None], default=0) >= 15:
        risk += 20; reasons.append("희석률 15% 이상")
    if repeats >= 4:
        risk += 20; reasons.append(f"1년 자금조달 이벤트 {repeats}회")
    if chain_corr >= 5:
        risk += 15; reasons.append(f"동일 이벤트 정정 {chain_corr}회")
    if payment == "CANCELLED_OR_WITHDRAWN":
        risk += 40; reasons.append("철회/취소 공시 탐지")
    elif payment == "CONFIRMED_OR_RESULT_FILED":
        risk = max(0, risk-10); reasons.append("발행결과/납입 관련 공시 확인")
    if debt is not None and debt >= 300:
        risk += 15; reasons.append(f"부채비율 {debt:.0f}%")
    if ocf is not None and ocf < 0:
        risk += 10; reasons.append("영업현금흐름 음수")
    if overhang is not None and overhang >= 20:
        risk += 15; reasons.append(f"CB 오버행 {overhang:.1f} 거래일")
    if num(row.get("rights_terp")) and num(row.get("latest_close")):
        terp_gap = (num(row.get("latest_close"))/num(row.get("rights_terp"))-1)*100
        row["rights_price_vs_terp_pct"] = round(terp_gap,2)
        if terp_gap <= -8: setup += 15; reasons.append(f"TERP 대비 {terp_gap:.1f}%")
    risk = min(100, max(0, risk)); setup = min(100, max(0, setup))
    conf = confidence(row)

    if row.get("price_status") != "OK" or (num(row.get("avg_trading_value_20d_krw")) or 0) < MIN_LIQ or risk >= 70:
        state = "AVOID"
    elif setup >= 20 and conf >= 60 and risk <= 55:
        state = "WATCH"
    else:
        state = "RESEARCH"
    paper = state == "WATCH" and conf >= 80 and risk <= 40 and payment == "CONFIRMED_OR_RESULT_FILED" and max([x for x in (rd,cd) if x is not None], default=0) <= 10 and setup >= 25
    if paper:
        state = "PAPER_BUY"
        reasons.append("가상진입 조건 충족")
    return setup, risk, conf, state, "; ".join(dict.fromkeys(reasons))


def main():
    if not BOARD.exists():
        raise SystemExit(f"missing {BOARD}")
    df = pd.read_csv(BOARD, dtype={"ticker":str,"corp_code":str})
    result=[]; chains_all=[]
    for _, rec in df.iterrows():
        row = rec.to_dict(); corp = str(row.get("corp_code") or "").split(".")[0].zfill(8)
        if not corp or corp == "00000000":
            result.append(row); continue
        try:
            filings = list_filings(corp, LOOKBACK)
            chains = build_chains(filings)
            financing = [f for f in filings if family(f.get("report_nm")) in {"RIGHTS","CB","BW","EB"}]
            row["event_chain_count"] = len(chains)
            row["event_chain_corrections"] = max([c["corrections"] for c in chains], default=0)
            row["financing_events_365d"] = len({(family(f.get("report_nm")), norm_title(f.get("report_nm"))) for f in financing})
            row["payment_status"] = infer_payment(filings)
            for c in chains[:10]: chains_all.append({"company":row.get("company"),"ticker":row.get("ticker"),**c})
            rights = detail_rows("piicDecsn.json", corp, LOOKBACK)
            cb = detail_rows("cvbdIsDecsn.json", corp, LOOKBACK)
            avgvol = None
            tv = num(row.get("avg_trading_value_20d_krw")); px = num(row.get("latest_close"))
            if tv and px: avgvol = tv/px
            row.update(rights_metrics(rights, px))
            row.update(cb_metrics(cb, avgvol, px))
            row["terms_verified_v2"] = bool(rights or cb)
            try: row.update(financial_health(corp))
            except Exception: row["financials_verified"] = False
            setup,risk,conf,state,reasons = score(row)
            row.update({"market_setup_score":round(setup,1),"opportunity_score":round(setup,1),"risk_score":round(risk,1),"confidence_score":conf,"state":state,"reasons":reasons,
                        "max_position_pct": 1 if state=="PAPER_BUY" else 0,
                        "entry_rule":"PAPER_BUY는 실거래가 아닌 가상 포트폴리오 신호",
                        "stop_rule":"가상진입가 대비 -8% 또는 가정 훼손 시 종료",
                        "time_stop":"20거래일"})
        except Exception as e:
            row["v2_error"] = type(e).__name__
            row["confidence_score"] = min(num(row.get("confidence_score")) or 0, 40)
            if row.get("state") not in {"AVOID"}: row["state"] = "RESEARCH"
        result.append(row)
    out = pd.DataFrame(result)
    order = pd.Categorical(out["state"], categories=["PAPER_BUY","WATCH","RESEARCH","AVOID"], ordered=True)
    out = out.assign(_o=order).sort_values(["_o","confidence_score","market_setup_score"], ascending=[True,False,False]).drop(columns=["_o"])
    out.to_csv(BOARD,index=False,encoding="utf-8-sig")
    pd.DataFrame(chains_all).to_csv(OUT/"event_chains.csv",index=False,encoding="utf-8-sig")
    summary={"rows":len(out),"paper_buy":int((out.state=="PAPER_BUY").sum()),"watch":int((out.state=="WATCH").sum()),"research":int((out.state=="RESEARCH").sum()),"avoid":int((out.state=="AVOID").sum()),"avg_confidence":round(float(out["confidence_score"].fillna(0).mean()),1)}
    (OUT/"v2_summary.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps(summary,ensure_ascii=False))

if __name__ == "__main__": main()
