import csv, json, os, sys, time
from datetime import date, timedelta
from urllib.parse import urlencode
from urllib.request import urlopen, Request

BASE = "https://opendart.fss.or.kr/api/list.json"
KEY = os.environ.get("OPENDART_API_KEY", "").strip()
EVENTS = (
    "전환사채권발행결정", "신주인수권부사채권발행결정", "교환사채권발행결정",
    "유상증자결정", "무상증자결정", "감자결정", "자기주식취득결정",
    "자기주식처분결정", "영업양수도", "타법인주식및출자증권취득결정",
    "회사합병결정", "회사분할결정", "소송등의제기", "부도발생", "회생절차개시신청"
)

if not KEY:
    print("OPENDART_API_KEY secret is missing", file=sys.stderr)
    sys.exit(2)


def call(params):
    params = dict(params)
    params["crtfc_key"] = KEY
    url = BASE + "?" + urlencode(params)
    req = Request(url, headers={"User-Agent": "OpenDARTBulkCollector/1.0"})
    with urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def ranges(start, end, days=90):
    cur = start
    while cur <= end:
        nxt = min(cur + timedelta(days=days-1), end)
        yield cur, nxt
        cur = nxt + timedelta(days=1)


def main():
    today = date.today()
    start = today - timedelta(days=365*5)
    rows = {}
    calls = 0
    for bgn, end in ranges(start, today):
        page = 1
        while True:
            data = call({
                "bgn_de": bgn.strftime("%Y%m%d"),
                "end_de": end.strftime("%Y%m%d"),
                "page_no": page,
                "page_count": 100,
            })
            calls += 1
            status = data.get("status")
            if status == "013":
                break
            if status != "000":
                raise RuntimeError(f"OpenDART status={status} message={data.get('message')}")
            items = data.get("list") or []
            for item in items:
                title = item.get("report_nm", "")
                if any(ev in title for ev in EVENTS):
                    rows[item.get("rcept_no")] = {
                        "rcept_no": item.get("rcept_no"),
                        "rcept_dt": item.get("rcept_dt"),
                        "corp_name": item.get("corp_name"),
                        "stock_code": item.get("stock_code"),
                        "corp_cls": item.get("corp_cls"),
                        "report_nm": title,
                        "flr_nm": item.get("flr_nm"),
                        "rm": item.get("rm"),
                    }
            total_page = int(data.get("total_page") or 1)
            if page >= total_page:
                break
            page += 1
            time.sleep(0.08)

    out = sorted(rows.values(), key=lambda x: (x.get("rcept_dt") or "", x.get("rcept_no") or ""), reverse=True)
    os.makedirs("artifacts", exist_ok=True)
    with open("artifacts/korea_financial_events_bulk.jsonl", "w", encoding="utf-8") as f:
        for row in out:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    fields = ["rcept_no","rcept_dt","corp_name","stock_code","corp_cls","report_nm","flr_nm","rm"]
    with open("artifacts/korea_financial_events_bulk.csv", "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader(); w.writerows(out)
    with open("artifacts/summary.json", "w", encoding="utf-8") as f:
        json.dump({"rows": len(out), "api_calls": calls, "period_start": str(start), "period_end": str(today)}, f, ensure_ascii=False, indent=2)
    print(json.dumps({"rows": len(out), "api_calls": calls}, ensure_ascii=False))

if __name__ == "__main__":
    main()
