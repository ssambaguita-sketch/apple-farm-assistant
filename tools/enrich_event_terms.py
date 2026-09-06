import json
import math
import os
from datetime import date, timedelta
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

import pandas as pd

DART = "https://opendart.fss.or.kr/api"
KEY = os.environ.get("OPENDART_API_KEY", "").strip()
SRC = Path(os.environ.get("INVESTMENT_OUTDIR", "investment_daily"))
BOARD_PATH = SRC / "daily_decision_board.csv"
OUT_PATH = SRC / "daily_decision_board.csv"
LOOKBACK_DAYS = int(os.environ.get("DETAIL_LOOKBACK_DAYS", "120"))


def api(endpoint, params, timeout=25):
    q = dict(params)
    q["crtfc_key"] = KEY
    req = Request(f"{DART}/{endpoint}?{urlencode(q)}", headers={"User-Agent": "OpenDARTEventTerms/1.0"})
    with urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def num(v):
    if v is None:
        return None
    s = str(v).replace(",", "").strip()
    if not s or s in {"-", "null", "None"}:
        return None
    try:
        x = float(s)
        return x if math.isfinite(x) else None
    except Exception:
        return None


def latest(endpoint, corp_code, start, end):
    data = api(endpoint, {
        "corp_code": str(corp_code).zfill(8),
        "bgn_de": start.strftime("%Y%m%d"),
        "end_de": end.strftime("%Y%m%d"),
    })
    if data.get("status") == "013":
        return None
    if data.get("status") != "000":
        return None
    rows = data.get("list") or []
    return rows[-1] if rows else None


def enrich_rights(rec):
    new_common = num(rec.get("nstk_ostk_cnt")) or 0
    new_other = num(rec.get("nstk_estk_cnt")) or 0
    pre_common = num(rec.get("bfic_tisstk_ostk")) or 0
    pre_other = num(rec.get("bfic_tisstk_estk")) or 0
    new_shares = new_common + new_other
    pre_shares = pre_common + pre_other
    dilution_post = (new_shares / (pre_shares + new_shares) * 100) if new_shares > 0 and pre_shares > 0 else None
    uses = {
        "facility": num(rec.get("fdpp_fclt")) or 0,
        "operating": num(rec.get("fdpp_op")) or 0,
        "debt": num(rec.get("fdpp_dtrp")) or 0,
        "acquisition": num(rec.get("fdpp_ocsa")) or 0,
        "other": num(rec.get("fdpp_etc")) or 0,
    }
    return {
        "rights_rcept_no": rec.get("rcept_no"),
        "rights_new_shares": new_shares or None,
        "rights_pre_shares": pre_shares or None,
        "rights_post_dilution_pct": round(dilution_post, 2) if dilution_post is not None else None,
        "rights_method": rec.get("ic_mthn"),
        "rights_use_facility_krw": uses["facility"],
        "rights_use_operating_krw": uses["operating"],
        "rights_use_debt_krw": uses["debt"],
        "rights_use_acquisition_krw": uses["acquisition"],
        "rights_use_other_krw": uses["other"],
    }


def enrich_cb(rec):
    return {
        "cb_rcept_no": rec.get("rcept_no"),
        "cb_amount_krw": num(rec.get("bd_fta")),
        "cb_conversion_price": num(rec.get("cv_prc")),
        "cb_potential_shares": num(rec.get("cvisstk_cnt")),
        "cb_potential_dilution_pct": num(rec.get("cvisstk_tisstk_vs")),
        "cb_reset_floor": num(rec.get("act_mktprcfl_cvprc_lwtrsprc")),
        "cb_payment_date": rec.get("pymd"),
        "cb_convert_start": rec.get("cvrqpd_bgd"),
        "cb_convert_end": rec.get("cvrqpd_edd"),
        "cb_use_facility_krw": num(rec.get("fdpp_fclt")) or 0,
        "cb_use_operating_krw": num(rec.get("fdpp_op")) or 0,
        "cb_use_debt_krw": num(rec.get("fdpp_dtrp")) or 0,
        "cb_use_acquisition_krw": num(rec.get("fdpp_ocsa")) or 0,
        "cb_use_other_krw": num(rec.get("fdpp_etc")) or 0,
    }


def reclassify(row):
    state = row.get("state", "RESEARCH")
    if state == "AVOID":
        return state, row.get("reasons", "")
    reasons = [x for x in str(row.get("reasons") or "").split("; ") if x]
    rights_d = num(row.get("rights_post_dilution_pct"))
    cb_d = num(row.get("cb_potential_dilution_pct"))
    liq = num(row.get("avg_trading_value_20d_krw")) or 0
    setup = num(row.get("market_setup_score")) or num(row.get("opportunity_score")) or 0

    if rights_d is not None and rights_d >= 30:
        reasons.append(f"유상증자 희석 {rights_d:.1f}%")
        return "AVOID", "; ".join(dict.fromkeys(reasons))
    if cb_d is not None and cb_d >= 30:
        reasons.append(f"CB 잠재희석 {cb_d:.1f}%")
        return "AVOID", "; ".join(dict.fromkeys(reasons))
    if rights_d is not None:
        reasons.append(f"유상증자 희석 {rights_d:.1f}%")
    if cb_d is not None:
        reasons.append(f"CB 잠재희석 {cb_d:.1f}%")

    # WATCH requires verified event terms, adequate liquidity, manageable dilution, and a meaningful dislocation.
    has_terms = rights_d is not None or cb_d is not None
    max_d = max([x for x in [rights_d, cb_d] if x is not None], default=None)
    if has_terms and liq >= 1_000_000_000 and (max_d is None or max_d <= 15) and setup >= 20:
        return "WATCH", "; ".join(dict.fromkeys(reasons))
    return "RESEARCH", "; ".join(dict.fromkeys(reasons))


def main():
    if not KEY:
        raise SystemExit("OPENDART_API_KEY secret is missing")
    if not BOARD_PATH.exists():
        raise SystemExit(f"missing {BOARD_PATH}")

    df = pd.read_csv(BOARD_PATH, dtype={"ticker": str, "corp_code": str})
    end = date.today()
    start = end - timedelta(days=LOOKBACK_DAYS)
    enriched = []
    for _, r in df.iterrows():
        row = r.to_dict()
        corp_code = str(row.get("corp_code") or "").split(".")[0].zfill(8)
        if not corp_code or corp_code == "00000000":
            enriched.append(row)
            continue
        rights = latest("piicDecsn.json", corp_code, start, end)
        cb = latest("cvbdIsDecsn.json", corp_code, start, end)
        if rights:
            row.update(enrich_rights(rights))
        if cb:
            row.update(enrich_cb(cb))
        state, reasons = reclassify(row)
        row["state"] = state
        row["reasons"] = reasons
        row["terms_verified"] = bool(rights or cb)
        enriched.append(row)

    out = pd.DataFrame(enriched)
    out.to_csv(OUT_PATH, index=False, encoding="utf-8-sig")
    print(json.dumps({
        "rows": len(out),
        "terms_verified": int(out.get("terms_verified", pd.Series(dtype=bool)).fillna(False).sum()),
        "watch": int((out["state"] == "WATCH").sum()),
        "research": int((out["state"] == "RESEARCH").sum()),
        "avoid": int((out["state"] == "AVOID").sum()),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
