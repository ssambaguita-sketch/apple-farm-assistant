from datetime import datetime
from threading import Lock

from sqlalchemy import select, desc, insert

import main
import phenology_calendar
import finance_manager


_CACHE = {}
_CACHE_LOCK = Lock()
_CACHE_TTL_SECONDS = 45


def _cache_get(key: str):
    now = datetime.now(main.TZ)
    with _CACHE_LOCK:
        item = _CACHE.get(key)
        if not item:
            return None
        if (now - item["at"]).total_seconds() > _CACHE_TTL_SECONDS:
            _CACHE.pop(key, None)
            return None
        return item["value"]


def _cache_set(key: str, value):
    with _CACHE_LOCK:
        _CACHE[key] = {"at": datetime.now(main.TZ), "value": value}


def invalidate_integrated_cache(orchard: str | None = None):
    with _CACHE_LOCK:
        if orchard:
            _CACHE.pop(orchard, None)
        else:
            _CACHE.clear()


def _pending_tasks(orchard: str):
    with main.engine.connect() as c:
        rows = c.execute(
            select(main.tasks)
            .where(main.tasks.c.orchard == orchard, main.tasks.c.status == "예정")
            .order_by(desc(main.tasks.c.priority), main.tasks.c.scheduled_at)
            .limit(30)
        ).mappings().all()
    return [dict(r) for r in rows]


def _observation_summary(orchard: str):
    with main.engine.connect() as c:
        rows = c.execute(
            select(main.observations)
            .where(main.observations.c.orchard == orchard)
            .order_by(desc(main.observations.c.id))
            .limit(20)
        ).mappings().all()
    data = [dict(r) for r in rows]
    max_risk = max([int(x.get("risk") or 0) for x in data], default=0)
    high = [x for x in data if int(x.get("risk") or 0) >= 3]
    return {
        "count": len(data),
        "max_risk": max_risk,
        "high_risk_count": len(high),
        "latest_high_risk": high[:3],
    }


def _coach_summary():
    data = main.coach()
    best_hours = list(data.get("best_hours") or [])
    best = best_hours[0] if best_hours else None
    return {
        "best_hour": best,
        "best_hours": best_hours[:3],
        "policy": data.get("policy"),
    }


def _build_action(title: str, category: str, priority: int, source: str, reason: str, when: str = "오늘"):
    return {
        "title": title,
        "category": category,
        "priority": priority,
        "source": source,
        "reason": reason,
        "scheduled_at": when,
    }


def _build_snapshot(orchard: str):
    annual = phenology_calendar.annual_phenology(orchard)
    current_month = int(annual.get("current_month") or datetime.now(main.TZ).month)
    months = list(annual.get("months") or [])
    current = next((x for x in months if int(x.get("month") or 0) == current_month), {})

    observations = _observation_summary(orchard)
    finance = finance_manager.finance_summary(orchard)
    coach = _coach_summary()
    pending = _pending_tasks(orchard)

    actions = []
    annual_tasks = list(current.get("tasks") or [])
    if annual_tasks:
        actions.append(_build_action(
            annual_tasks[0], "연간농작업", 4, "annual",
            f"{current_month}월 생육단계·기상·GDD 보정 연간 일정의 최우선 작업",
        ))
    if len(annual_tasks) > 1:
        actions.append(_build_action(
            annual_tasks[1], "연간농작업", 3, "annual",
            f"{current_month}월 통합 연간 일정에서 이어지는 작업",
        ))

    weed = list(current.get("weed_timing") or [])
    weed_status = str(current.get("weed_status") or "")
    if weed and "보류" not in weed_status:
        actions.append(_build_action(
            weed[0], "잡초", 3, "weed",
            f"연간 잡초 타이밍과 현재 기상 상태({weed_status or '월별 기준'})를 결합",
        ))

    foliar = list(current.get("foliar_timing") or [])
    foliar_status = str(current.get("foliar_status") or "")
    if foliar and "보류" not in foliar_status:
        actions.append(_build_action(
            foliar[0], "엽면시비", 2, "foliar",
            f"생육단계와 현재 기상 상태({foliar_status or '월별 기준'})를 결합한 검토 작업",
        ))

    if observations["max_risk"] >= 3:
        latest = observations["latest_high_risk"][0] if observations["latest_high_risk"] else {}
        category = str(latest.get("category") or "고위험 관찰")
        actions.insert(0, _build_action(
            f"고위험 예찰 재확인 · {category}", "예찰", 5, "diagnosis",
            f"최근 관찰 최고 위험도가 {observations['max_risk']}/5로 높아 연간 일정보다 우선 확인",
        ))

    if int(finance.get("entry_count") or 0) == 0:
        actions.append(_build_action(
            "이번 달 경영기록 시작", "경영", 1, "finance",
            "매출·비용·수확량 기록이 없어 작업 대비 수익성 분석을 시작할 데이터가 부족함",
        ))

    best_hour = coach.get("best_hour") or {}
    coach_hour = best_hour.get("hour")
    if coach_hour is not None:
        for item in actions:
            if item["scheduled_at"] == "오늘" and item["priority"] >= 3:
                item["scheduled_at"] = f"오늘 {int(coach_hour):02d}:00 전후"
                item["reason"] += f" · 코치 엔진 추천시간 {int(coach_hour):02d}시 반영"

    dedup = {}
    for item in actions:
        old = dedup.get(item["title"])
        if old is None or int(item["priority"]) > int(old["priority"]):
            dedup[item["title"]] = item
    actions = sorted(dedup.values(), key=lambda x: int(x["priority"]), reverse=True)[:8]

    existing_titles = {str(x.get("title") or "") for x in pending}
    for item in actions:
        item["already_in_tasks"] = item["title"] in existing_titles

    orchard_data = dict(annual.get("orchard") or {})
    return {
        "orchard": orchard_data,
        "generated_at": main.now_iso(),
        "cache_ttl_seconds": _CACHE_TTL_SECONDS,
        "annual": {
            "month": current_month,
            "stage": current.get("stage"),
            "goal": current.get("goal"),
            "adjustment_days": current.get("adjustment_days", 0),
            "solar_terms": current.get("solar_terms", []),
        },
        "weather": annual.get("weather") or {},
        "gdd": annual.get("gdd") or {},
        "observations": observations,
        "finance": finance,
        "coach": coach,
        "pending_task_count": len(pending),
        "actions": actions,
        "engine_links": {
            "annual_to_tasks": True,
            "diagnosis_to_tasks": True,
            "weed_to_annual": True,
            "foliar_to_annual": True,
            "finance_to_priority": True,
            "coach_to_schedule": True,
            "gps_weather_to_all": orchard_data.get("lat") is not None and orchard_data.get("lon") is not None,
        },
        "policy": "통합 엔진은 농작업 우선순위와 확인 작업을 연결합니다. 농약·비료 제품명, 희석배수, 혼용, 살포량은 자동 처방하지 않습니다.",
    }


@main.app.get("/api/integrated/briefing")
def integrated_briefing(orchard: str = "A과수원", refresh: bool = False):
    name = orchard.strip() or "A과수원"
    if not refresh:
        cached = _cache_get(name)
        if cached is not None:
            return {**cached, "cache_hit": True}
    value = _build_snapshot(name)
    _cache_set(name, value)
    return {**value, "cache_hit": False}


@main.app.post("/api/integrated/sync")
def integrated_sync(orchard: str = "A과수원"):
    name = orchard.strip() or "A과수원"
    snapshot = _build_snapshot(name)
    existing_titles = {str(x.get("title") or "") for x in _pending_tasks(name)}
    created = []

    with main.engine.begin() as c:
        for action in snapshot["actions"]:
            title = str(action["title"])
            if title in existing_titles:
                continue
            result = c.execute(insert(main.tasks).values(
                orchard=name,
                title=title,
                category=action["category"],
                priority=int(action["priority"]),
                scheduled_at=action["scheduled_at"],
                status="예정",
                notified=0,
                created_at=main.now_iso(),
            ))
            created.append({"id": result.inserted_primary_key[0], **action})
            existing_titles.add(title)

    # 작업 생성 이후 표시용 상태만 한 번 갱신하고 캐시에 넣어,
    # 클라이언트가 다시 briefing을 호출하지 않아도 되게 한다.
    if created:
        for action in snapshot["actions"]:
            if action["title"] in existing_titles:
                action["already_in_tasks"] = True
        snapshot["pending_task_count"] = int(snapshot.get("pending_task_count") or 0) + len(created)
        snapshot["generated_at"] = main.now_iso()
    _cache_set(name, snapshot)

    return {
        "ok": True,
        "orchard": name,
        "created_count": len(created),
        "created": created,
        "briefing": snapshot,
        "message": "통합 엔진의 새 우선 작업만 중복 없이 작업 메뉴에 반영했습니다.",
    }
