import csv
import json
import os
import sys
import time
from datetime import date, timedelta
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

BASE = "https://opendart.fss.or.kr/api/list.json"
KEY = os.environ.get("OPENDART_API_KEY", "").strip()
CHUNK_INDEX = int(os.environ.get("OPENDART_CHUNK_INDEX", "0"))
WINDOW_DAYS = int(os.environ.get("OPENDART_WINDOW_DAYS", "90"))
REQUEST_TIMEOUT = int(os.environ.get("OPENDART_REQUEST_TIMEOUT", "20"))
MAX_RETRIES = int(os.environ.get("OPENDART_MAX_RETRIES", "4"))
PBLNTF_TYPES = tuple(x.strip() for x in os.environ.get("OPENDART_PBLNTF_TYPES", "B,I").split(",") if x.strip())

EVENTS = (
    "전환사채권발행결정", "신주인수권부사채권발행결정", "교환사채권발행결정",
    "유상증자결정", "무상증자결정", "감자결정", "자기주식취득결정",
    "자기주식처분결정", "영업양수도", "타법인주식및출자증권취득결정",
    "회사합병결정", "회사분할결정", "소송등의제기", "부도발생", "회생절차개시신청"
)
FIELDS = ["rcept_no", "rcept_dt", "corp_name", "stock_code", "corp_cls", "report_nm", "flr_nm", "rm"]

if not KEY:
    print("OPENDART_API_KEY secret is missing", file=sys.stderr)
    sys.exit(2)


def call(params):
    params = dict(params)
    params["crtfc_key"] = KEY
    url = BASE + "?" + urlencode(params)
    req = Request(url, headers={"User-Agent": "OpenDARTBulkCollector/2.0"})

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            with urlopen(req, timeout=REQUEST_TIMEOUT) as r:
                return json.loads(r.read().decode("utf-8"))
        except (HTTPError, URLError, TimeoutError, json.JSONDecodeError) as exc:
            if attempt >= MAX_RETRIES:
                raise
            delay = min(2 ** (attempt - 1), 8)
            print(f"retry attempt={attempt}/{MAX_RETRIES} delay={delay}s error={exc!r}", flush=True)
            time.sleep(delay)


def ranges(start, end, days=90):
    cur = start
    while cur <= end:
        nxt = min(cur + timedelta(days=days - 1), end)
        yield cur, nxt
        cur = nxt + timedelta(days=1)


def atomic_write(path, text, encoding="utf-8"):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding=encoding, newline="") as f:
        f.write(text)
    os.replace(tmp, path)


def save(rows, summary):
    os.makedirs("artifacts", exist_ok=True)
    out = sorted(rows.values(), key=lambda x: (x.get("rcept_dt") or "", x.get("rcept_no") or ""), reverse=True)

    jsonl = "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in out)
    atomic_write("artifacts/korea_financial_events_bulk.jsonl", jsonl)

    csv_tmp = "artifacts/korea_financial_events_bulk.csv.tmp"
    with open(csv_tmp, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(out)
    os.replace(csv_tmp, "artifacts/korea_financial_events_bulk.csv")

    summary = dict(summary)
    summary["rows"] = len(out)
    atomic_write("artifacts/summary.json", json.dumps(summary, ensure_ascii=False, indent=2) + "\n")


def main():
    today = date.today()
    chunk_end = today - timedelta(days=365 * CHUNK_INDEX)
    chunk_start = chunk_end - timedelta(days=364)
    rows = {}
    calls = 0
    summary = {
        "status": "running",
        "chunk_index": CHUNK_INDEX,
        "period_start": str(chunk_start),
        "period_end": str(chunk_end),
        "pblntf_types": list(PBLNTF_TYPES),
        "api_calls": 0,
    }
    save(rows, summary)

    try:
        for pblntf_ty in PBLNTF_TYPES:
            for bgn, end in ranges(chunk_start, chunk_end, WINDOW_DAYS):
                page = 1
                while True:
                    data = call({
                        "bgn_de": bgn.strftime("%Y%m%d"),
                        "end_de": end.strftime("%Y%m%d"),
                        "pblntf_ty": pblntf_ty,
                        "page_no": page,
                        "page_count": 100,
                        "sort": "date",
                        "sort_mth": "asc",
                    })
                    calls += 1
                    status = data.get("status")
                    if status == "013":
                        print(f"progress type={pblntf_ty} window={bgn}..{end} page={page} empty rows={len(rows)} calls={calls}", flush=True)
                        break
                    if status != "000":
                        raise RuntimeError(f"OpenDART status={status} message={data.get('message')}")

                    items = data.get("list") or []
                    for item in items:
                        title = item.get("report_nm", "")
                        if any(ev in title for ev in EVENTS):
                            rcept_no = item.get("rcept_no")
                            if rcept_no:
                                rows[rcept_no] = {field: item.get(field) for field in FIELDS}
                                rows[rcept_no]["report_nm"] = title

                    total_page = int(data.get("total_page") or 1)
                    summary.update({
                        "api_calls": calls,
                        "current_type": pblntf_ty,
                        "current_window_start": str(bgn),
                        "current_window_end": str(end),
                        "current_page": page,
                        "current_total_page": total_page,
                    })
                    save(rows, summary)
                    print(
                        f"progress type={pblntf_ty} window={bgn}..{end} page={page}/{total_page} rows={len(rows)} calls={calls}",
                        flush=True,
                    )

                    if page >= total_page:
                        break
                    page += 1
                    time.sleep(0.10)

        summary.update({"status": "complete", "api_calls": calls})
        save(rows, summary)
        print(json.dumps({"status": "complete", "chunk_index": CHUNK_INDEX, "rows": len(rows), "api_calls": calls}, ensure_ascii=False), flush=True)
    except Exception as exc:
        summary.update({"status": "failed", "api_calls": calls, "error": repr(exc)})
        save(rows, summary)
        print(json.dumps({"status": "failed", "chunk_index": CHUNK_INDEX, "rows": len(rows), "api_calls": calls, "error": repr(exc)}, ensure_ascii=False), file=sys.stderr, flush=True)
        raise


if __name__ == "__main__":
    main()
