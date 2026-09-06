import csv
import json
import os
from datetime import date, timedelta
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

DART = "https://opendart.fss.or.kr/api/list.json"
KEY = os.environ.get("OPENDART_API_KEY", "").strip()
BASE_WATCHLIST = Path(os.environ.get("BASE_WATCHLIST", "config/investment_watchlist.csv"))
OUT = Path(os.environ.get("DISCOVERY_OUT", "investment_daily/generated_watchlist.csv"))
DAYS = int(os.environ.get("DISCOVERY_DAYS", "3"))
MAX_CANDIDATES = int(os.environ.get("DISCOVERY_MAX", "30"))
KEYWORDS = ("유상증자", "전환사채", "신주인수권부사채", "교환사채", "감자", "자기주식", "합병", "분할", "타법인주식", "소송", "부도", "회생절차")

WEIGHT = {
    "부도": 100, "회생절차": 95, "감자": 80, "유상증자": 70,
    "전환사채": 65, "신주인수권부사채": 65, "교환사채": 60,
    "소송": 55, "합병": 50, "분할": 45, "타법인주식": 40, "자기주식": 30,
}


def api(params):
    q = dict(params)
    q["crtfc_key"] = KEY
    req = Request(f"{DART}?{urlencode(q)}", headers={"User-Agent": "OpenDARTAutoDiscovery/1.0"})
    with urlopen(req, timeout=25) as r:
        return json.loads(r.read().decode("utf-8"))


def score_title(title):
    score = 0
    hits = []
    for k, w in WEIGHT.items():
        if k in title:
            score = max(score, w)
            hits.append(k)
    if title.startswith("["):
        score += 10
    return score, "/".join(hits)


def load_base():
    rows = []
    if BASE_WATCHLIST.exists():
        with BASE_WATCHLIST.open(encoding="utf-8-sig") as f:
            rows = list(csv.DictReader(f))
    return rows


def main():
    if not KEY:
        raise SystemExit("OPENDART_API_KEY secret is missing")
    end = date.today()
    start = end - timedelta(days=DAYS)
    page = 1
    found = {}
    while True:
        data = api({
            "bgn_de": start.strftime("%Y%m%d"),
            "end_de": end.strftime("%Y%m%d"),
            "pblntf_ty": "B",
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
            stock = (item.get("stock_code") or "").strip().zfill(6)
            cls = item.get("corp_cls")
            if not stock or stock == "000000" or cls not in ("Y", "K"):
                continue
            if not any(k in title for k in KEYWORDS):
                continue
            s, hits = score_title(title)
            rec = found.setdefault(stock, {
                "company": item.get("corp_name", ""),
                "ticker": stock,
                "yahoo_suffix": ".KS" if cls == "Y" else ".KQ",
                "benchmark": "^KS11" if cls == "Y" else "^KQ11",
                "discovery_score": 0,
                "discovery_filings": 0,
                "discovery_reasons": set(),
            })
            rec["discovery_score"] = max(rec["discovery_score"], s)
            rec["discovery_filings"] += 1
            if hits:
                rec["discovery_reasons"].update(hits.split("/"))
        if page >= int(data.get("total_page") or 1):
            break
        page += 1

    ranked = sorted(found.values(), key=lambda x: (x["discovery_score"], x["discovery_filings"]), reverse=True)[:MAX_CANDIDATES]
    base = load_base()
    merged = {}
    for r in base:
        t = str(r.get("ticker", "")).zfill(6)
        if t:
            merged[t] = {
                "company": r.get("company", ""), "ticker": t,
                "yahoo_suffix": r.get("yahoo_suffix", ".KQ"),
                "benchmark": r.get("benchmark", "^KQ11"),
                "source": "static", "discovery_score": "", "discovery_filings": "", "discovery_reasons": ""
            }
    for r in ranked:
        merged[r["ticker"]] = {
            "company": r["company"], "ticker": r["ticker"],
            "yahoo_suffix": r["yahoo_suffix"], "benchmark": r["benchmark"],
            "source": "auto", "discovery_score": r["discovery_score"],
            "discovery_filings": r["discovery_filings"],
            "discovery_reasons": "/".join(sorted(r["discovery_reasons"])),
        }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    fields = ["company", "ticker", "yahoo_suffix", "benchmark", "source", "discovery_score", "discovery_filings", "discovery_reasons"]
    with OUT.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader(); w.writerows(merged.values())
    summary = {
        "as_of": str(end), "window_days": DAYS, "auto_discovered": len(ranked),
        "static": len(base), "combined": len(merged), "max_auto_candidates": MAX_CANDIDATES,
    }
    (OUT.parent / "discovery_summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
