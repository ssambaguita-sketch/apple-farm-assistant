from datetime import datetime, timedelta

import httpx
from sqlalchemy import select, desc

import main


ISSUE_HOURS = (2, 5, 8, 11, 14, 17, 20, 23)


def _candidate_bases(limit: int = 6):
    """Return recent KMA village forecast issue times, newest first."""
    now = datetime.now(main.TZ)
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
    return None, "기상청 호출 실패: " + " / ".join(errors[:3])


main.fetch_kma_forecast = resilient_fetch_kma_forecast


def _auto_task(title: str, reason: str, priority: int, when: str = "오늘"):
    return {
        "id": None,
        "orchard": "",
        "title": f"[자동추천] {title}",
        "category": "자동추천",
        "priority": priority,
        "scheduled_at": when,
        "status": "추천",
        "reason": reason,
        "auto_recommended": True,
    }


def build_today_recommendations(orchard_name: str):
    """Transparent, non-prescriptive daily orchard work suggestions."""
    with main.engine.connect() as c:
        orchard = c.execute(
            select(main.orchards).where(main.orchards.c.name == orchard_name)
        ).mappings().first()
        observations = c.execute(
            select(main.observations)
            .where(main.observations.c.orchard == orchard_name)
            .order_by(desc(main.observations.c.id))
            .limit(10)
        ).mappings().all()

    weather, source, warning, _grid = main.orchard_weather(orchard_name)
    scored = sorted([main.work_score(w) for w in weather], key=lambda x: x["score"], reverse=True)
    best = scored[0] if scored else None
    best_time = best.get("time", "오늘") if best else "오늘"

    max_temp = max([float(w.get("temp", 0) or 0) for w in weather], default=0)
    max_pop = max([float(w.get("rain_probability", 0) or 0) for w in weather], default=0)
    max_wind = max([float(w.get("wind", 0) or 0) for w in weather], default=0)
    recent_risk = max([int(o.get("risk", 0) or 0) for o in observations], default=0)
    growth_stage = str((orchard or {}).get("growth_stage") or "").strip()

    recs = []

    if recent_risk >= 3:
        recs.append(_auto_task(
            "이상 징후 재확인·사진 기록",
            "최근 관찰 기록의 위험도가 높아 변화 여부를 먼저 확인하는 것이 좋습니다.",
            1,
            best_time,
        ))
    else:
        recs.append(_auto_task(
            "과원 순회 예찰",
            "잎·과실·가지·수간과 잡초 상태를 짧게 순회 확인해 오늘 상태를 기록하세요.",
            2,
            best_time,
        ))

    if max_pop >= 60:
        recs.append(_auto_task(
            "강우 대비 배수로·토양 상태 점검",
            f"예보상 강수확률이 최대 {int(max_pop)}%입니다. 배수 불량 구역과 물고임 가능성을 확인하세요.",
            1,
            "비 오기 전",
        ))
    elif max_temp >= 30:
        recs.append(_auto_task(
            "토양 수분·관수 필요성 점검",
            f"예보상 기온이 최대 {max_temp:.0f}℃까지 올라갈 수 있습니다. 토양 수분을 확인한 뒤 관수 여부를 판단하세요.",
            2,
            best_time,
        ))

    if max_wind >= 5:
        recs.append(_auto_task(
            "지주·유인끈·낙과 위험 점검",
            f"예보상 풍속이 최대 {max_wind:.1f}m/s입니다. 지주와 유인 상태를 확인하고 바람이 강한 시간의 살포 작업은 피하세요.",
            1,
            "강풍 전",
        ))

    stage = growth_stage.replace(" ", "")
    if any(k in stage for k in ("수확", "성숙", "착색")):
        recs.append(_auto_task(
            "착색·성숙도·낙과 상태 확인",
            f"현재 생육단계가 '{growth_stage}'로 등록되어 있습니다. 수확 판단에 필요한 과실 상태를 구역별로 확인하세요.",
            2,
            best_time,
        ))
    elif any(k in stage for k in ("비대", "결실", "과실")):
        recs.append(_auto_task(
            "과실 비대·수분 스트레스 예찰",
            f"현재 생육단계가 '{growth_stage}'로 등록되어 있습니다. 과실 비대 편차와 수분 스트레스 징후를 확인하세요.",
            2,
            best_time,
        ))
    elif any(k in stage for k in ("개화", "꽃")):
        recs.append(_auto_task(
            "개화·수분 상태 예찰",
            f"현재 생육단계가 '{growth_stage}'로 등록되어 있습니다. 개화 균일도와 이상 꽃·가지 상태를 확인하세요.",
            2,
            best_time,
        ))

    weed_obs = [o for o in observations if "잡초" in str(o.get("category", ""))]
    if weed_obs and max(int(o.get("risk", 0) or 0) for o in weed_obs) >= 2:
        recs.append(_auto_task(
            "잡초 발생 구역 재확인",
            "최근 잡초 관찰 기록이 있습니다. 살아남은 구역을 다시 확인하고 예초·멀칭 등 비화학적 관리도 함께 검토하세요.",
            3,
            best_time,
        ))

    if source != "kma":
        recs.append(_auto_task(
            "날씨 연결 상태 확인",
            warning or "현재 실제 기상청 예보가 아니므로 시간 추천은 참고용입니다.",
            3,
            "오늘",
        ))

    # Keep the home screen concise: at most five auto recommendations.
    recs = sorted(recs, key=lambda x: x["priority"])[:5]
    return recs


# Enhance the already-registered /api/dashboard route so current installed APKs
# immediately receive automatic recommendations without requiring an app update.
_dashboard_route = next((r for r in main.app.routes if getattr(r, "path", None) == "/api/dashboard"), None)
if _dashboard_route is not None:
    _original_dashboard = _dashboard_route.endpoint

    def _enhanced_dashboard(orchard: str = "A과수원"):
        data = _original_dashboard(orchard)
        auto = build_today_recommendations(orchard)
        existing = list(data.get("tasks") or [])
        data["today_recommendations"] = auto
        data["tasks"] = auto + existing
        data["recommendation_policy"] = (
            "생육단계·최근 관찰·기상·작업기록 기반 의사결정 지원입니다. "
            "농약 제품·농도·혼용·재살포 간격은 자동 처방하지 않습니다."
        )
        return data

    _dashboard_route.endpoint = _enhanced_dashboard
    if getattr(_dashboard_route, "dependant", None) is not None:
        _dashboard_route.dependant.call = _enhanced_dashboard


@main.app.get("/api/today-recommendations")
def today_recommendations(orchard: str = "A과수원"):
    return {
        "orchard": orchard,
        "date": datetime.now(main.TZ).strftime("%Y-%m-%d"),
        "recommendations": build_today_recommendations(orchard),
        "policy": (
            "기상·생육단계·관찰기록을 이용한 작업 우선순위 지원이며, "
            "농약 제품·농도·혼용·재살포 간격은 자동 처방하지 않습니다."
        ),
    }


# Keep app metadata current. /health remains backward-compatible with main.py output.
main.app.version = "4.4.0"
app = main.app
