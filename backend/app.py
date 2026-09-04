from datetime import datetime, timedelta

import httpx
from sqlalchemy import select, desc

import main


ISSUE_HOURS = (2, 5, 8, 11, 14, 17, 20, 23)


def _candidate_bases(limit: int = 6):
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
    return text[:180] if text else ""


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

    weather, source, warning, grid = main.orchard_weather(orchard_name)
    scored = sorted([main.work_score(w) for w in weather], key=lambda x: x["score"], reverse=True)
    best = scored[0] if scored else None
    best_time = best.get("time", "오늘") if best else "오늘"

    max_temp = max([float(w.get("temp", 0) or 0) for w in weather], default=0)
    max_pop = max([float(w.get("rain_probability", 0) or 0) for w in weather], default=0)
    max_wind = max([float(w.get("wind", 0) or 0) for w in weather], default=0)
    recent_risk = max([int(o.get("risk", 0) or 0) for o in observations], default=0)
    growth_stage = str((orchard or {}).get("growth_stage") or "").strip()

    context = {
        "weather_source": source,
        "weather_grid": grid,
        "weather_warning": warning,
        "forecast_max_temp_c": round(max_temp, 1),
        "forecast_max_rain_probability_pct": round(max_pop, 0),
        "forecast_max_wind_ms": round(max_wind, 1),
        "best_work_time": best_time,
        "best_work_score": best.get("score") if best else None,
        "growth_stage": growth_stage or "미등록",
        "recent_observation_count": len(observations),
        "recent_max_risk": recent_risk,
    }

    recs = []

    if recent_risk >= 3:
        recs.append(_auto_task(
            "이상 징후 재확인·사진 기록",
            f"최근 관찰 {len(observations)}건 중 최고 위험도가 {recent_risk}/5로 높습니다.",
            1,
            best_time,
        ))
    else:
        recs.append(_auto_task(
            "과원 순회 예찰",
            f"최근 관찰 최고 위험도는 {recent_risk}/5입니다. 새로운 변화가 없는지 기본 예찰을 권합니다.",
            2,
            best_time,
        ))

    if max_pop >= 60:
        recs.append(_auto_task(
            "강우 대비 배수로·토양 상태 점검",
            f"기상 예보의 최대 강수확률이 {int(max_pop)}%입니다.",
            1,
            "비 오기 전",
        ))
    elif max_temp >= 30:
        recs.append(_auto_task(
            "토양 수분·관수 필요성 점검",
            f"기상 예보의 최고기온이 {max_temp:.0f}℃입니다. 실제 토양 수분을 확인한 뒤 관수 여부를 판단하세요.",
            2,
            best_time,
        ))

    if max_wind >= 5:
        recs.append(_auto_task(
            "지주·유인끈·낙과 위험 점검",
            f"기상 예보의 최대 풍속이 {max_wind:.1f}m/s입니다.",
            1,
            "강풍 전",
        ))

    stage = growth_stage.replace(" ", "")
    if any(k in stage for k in ("수확", "성숙", "착색")):
        recs.append(_auto_task(
            "착색·성숙도·낙과 상태 확인",
            f"등록된 생육단계가 '{growth_stage}'입니다.",
            2,
            best_time,
        ))
    elif any(k in stage for k in ("비대", "결실", "과실")):
        recs.append(_auto_task(
            "과실 비대·수분 스트레스 예찰",
            f"등록된 생육단계가 '{growth_stage}'입니다.",
            2,
            best_time,
        ))
    elif any(k in stage for k in ("개화", "꽃")):
        recs.append(_auto_task(
            "개화·수분 상태 예찰",
            f"등록된 생육단계가 '{growth_stage}'입니다.",
            2,
            best_time,
        ))

    weed_obs = [o for o in observations if "잡초" in str(o.get("category", ""))]
    if weed_obs and max(int(o.get("risk", 0) or 0) for o in weed_obs) >= 2:
        weed_risk = max(int(o.get("risk", 0) or 0) for o in weed_obs)
        recs.append(_auto_task(
            "잡초 발생 구역 재확인",
            f"최근 잡초 관찰 기록 {len(weed_obs)}건, 최고 위험도 {weed_risk}/5가 있습니다.",
            3,
            best_time,
        ))

    if source != "kma":
        recs.append(_auto_task(
            "날씨 연결 상태 확인",
            warning or "현재 실제 기상청 예보가 아니어서 시간 추천은 참고용입니다.",
            3,
            "오늘",
        ))

    recs = sorted(recs, key=lambda x: x["priority"])[:5]

    confidence = "높음" if source == "kma" and orchard is not None else "보통"
    if source != "kma":
        confidence = "낮음"

    # Make the evidence visible even in already-installed clients that only show
    # title + scheduled_at + priority. Newer clients can use the structured fields.
    for rec in recs:
        original_when = rec.get("scheduled_at") or "오늘"
        rec["recommended_time"] = original_when
        rec["confidence"] = confidence
        rec["decision_evidence"] = dict(context)
        rec["scheduled_at"] = f"{original_when} · 근거: {rec['reason']} · 신뢰도 {confidence}"

    return recs, context, confidence


_dashboard_route = next((r for r in main.app.routes if getattr(r, "path", None) == "/api/dashboard"), None)
if _dashboard_route is not None:
    _original_dashboard = _dashboard_route.endpoint

    def _enhanced_dashboard(orchard: str = "A과수원"):
        data = _original_dashboard(orchard)
        auto, context, confidence = build_today_recommendations(orchard)
        existing = list(data.get("tasks") or [])
        data["today_recommendations"] = auto
        data["tasks"] = auto + existing
        data["decision_context"] = context
        data["recommendation_confidence"] = confidence
        data["recommendation_policy"] = (
            "추천마다 사용한 기상·생육단계·최근 관찰 위험도를 공개합니다. "
            "추천은 의사결정 지원이며 농약 제품·농도·혼용·재살포 간격은 자동 처방하지 않습니다."
        )
        return data

    _dashboard_route.endpoint = _enhanced_dashboard
    if getattr(_dashboard_route, "dependant", None) is not None:
        _dashboard_route.dependant.call = _enhanced_dashboard


@main.app.get("/api/today-recommendations")
def today_recommendations(orchard: str = "A과수원"):
    recs, context, confidence = build_today_recommendations(orchard)
    return {
        "orchard": orchard,
        "date": datetime.now(main.TZ).strftime("%Y-%m-%d"),
        "recommendations": recs,
        "decision_context": context,
        "confidence": confidence,
        "policy": (
            "판단에 사용한 실제 입력값을 공개하는 설명 가능한 작업추천입니다. "
            "농약 제품·농도·혼용·재살포 간격은 자동 처방하지 않습니다."
        ),
    }


main.app.version = "4.5.0"
app = main.app
