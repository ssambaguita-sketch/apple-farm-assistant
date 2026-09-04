from datetime import datetime, timedelta

import httpx

import main


ISSUE_HOURS = (2, 5, 8, 11, 14, 17, 20, 23)


def _candidate_bases(limit: int = 6):
    """Return recent KMA village forecast issue times, newest first."""
    now = datetime.now(main.TZ)
    # KMA products can appear a little after the nominal issue time.
    safe = now - timedelta(minutes=55)
    candidates = []
    for day_delta in range(0, -3, -1):
        d = (safe + timedelta(days=day_delta)).date()
        for hour in ISSUE_HOURS:
            dt = datetime(d.year, d.month, d.day, hour, tzinfo=main.TZ)
            if dt <= safe:
                candidates.append(dt)
    candidates.sort(reverse=True)
    return candidates[:limit]


def _short_body(response: httpx.Response) -> str:
    try:
        text = response.text.strip().replace("\n", " ").replace("\r", " ")
    except Exception:
        return ""
    if not text:
        return ""
    # Never echo a URL/query or secrets. Only a short response-body hint.
    return text[:180]


def resilient_fetch_kma_forecast(nx: int, ny: int):
    if not main.KMA_SERVICE_KEY:
        return None, "KMA_SERVICE_KEY가 설정되지 않았습니다"

    errors = []
    with httpx.Client(timeout=12.0, follow_redirects=True) as client:
        for base in _candidate_bases():
            base_date = base.strftime("%Y%m%d")
            base_time = base.strftime("%H00")
            params = {
                "pageNo": 1,
                "numOfRows": 1000,
                "dataType": "JSON",
                "base_date": base_date,
                "base_time": base_time,
                "nx": nx,
                "ny": ny,
                "authKey": main.KMA_SERVICE_KEY,
            }
            try:
                response = client.get(main.KMA_URL, params=params)
            except httpx.TimeoutException:
                errors.append(f"{base_time} 시간초과")
                continue
            except httpx.RequestError as exc:
                errors.append(f"{base_time} 네트워크 오류({type(exc).__name__})")
                continue

            if response.status_code != 200:
                hint = _short_body(response)
                detail = f"HTTP {response.status_code}"
                if hint:
                    detail += f" · {hint}"
                errors.append(f"{base_time} {detail}")
                # Authentication/permission errors are unlikely to improve with an older base time.
                if response.status_code in {401, 403}:
                    break
                continue

            try:
                payload = response.json()
            except Exception:
                errors.append(f"{base_time} JSON 해석 실패")
                continue

            header = payload.get("response", {}).get("header", {})
            result_code = str(header.get("resultCode", ""))
            result_msg = str(header.get("resultMsg", "unknown"))
            if result_code and result_code != "00":
                errors.append(f"{base_time} KMA {result_code}: {result_msg}")
                continue

            items = payload.get("response", {}).get("body", {}).get("items", {}).get("item", [])
            if not items:
                errors.append(f"{base_time} 예보 데이터 없음")
                continue

            grouped = {}
            for item in items:
                key = (
                    str(item.get("fcstDate", "")),
                    str(item.get("fcstTime", "")).zfill(4),
                )
                grouped.setdefault(key, {})[str(item.get("category", ""))] = item.get("fcstValue")

            out = []
            cutoff = datetime.now(main.TZ) - timedelta(hours=1)
            for (date_s, time_s), values in sorted(grouped.items()):
                try:
                    dt = datetime.strptime(date_s + time_s, "%Y%m%d%H%M").replace(tzinfo=main.TZ)
                except ValueError:
                    continue
                if dt < cutoff:
                    continue
                out.append({
                    "time": dt.strftime("%m-%d %H:%M"),
                    "temp": main.parse_number(values.get("TMP")),
                    "humidity": main.parse_number(values.get("REH")),
                    "wind": main.parse_number(values.get("WSD")),
                    "rain_probability": main.parse_number(values.get("POP")),
                    "rain": main.parse_number(values.get("PCP")),
                })
                if len(out) >= 18:
                    break

            if out:
                return out, None
            errors.append(f"{base_time} 사용 가능한 미래 예보 없음")

    if not errors:
        return None, "기상청 예보를 가져오지 못했습니다"
    # Keep diagnostics compact but actionable; never include the auth key.
    return None, "기상청 호출 실패: " + " / ".join(errors[:3])


# Existing route functions in main resolve this global at call time, so replacing it
# upgrades /api/weather and /api/dashboard without duplicating the application.
main.fetch_kma_forecast = resilient_fetch_kma_forecast
main.app.version = "4.3.0"

app = main.app
