from datetime import datetime

from pydantic import BaseModel
from sqlalchemy import Table, Column, Integer, Float, String, Text, MetaData, select, desc, insert

import main


weed_history = Table(
    "weed_history",
    main.metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("orchard", String(120), nullable=False),
    Column("zone", String(120), default=""),
    Column("coverage_pct", Float, default=0),
    Column("coverage_label", String(40), default=""),
    Column("distribution", String(40), default=""),
    Column("growth_stage", String(60), default=""),
    Column("weed_group", String(60), default=""),
    Column("survivor_seen", Integer, default=0),
    Column("recommendation", String(80), default=""),
    Column("priority_score", Integer, default=0),
    Column("note", Text, default=""),
    Column("created_at", String(40), nullable=False),
)


ANNUAL_WEED_WINDOWS = {
    1: ("월동잡초 기록 정리", "살포보다 전년도 문제구역과 월동잡초 흔적을 기록합니다."),
    2: ("월동잡초 예찰", "월동잡초와 지난해 재발생 구역을 확인합니다."),
    3: ("봄 1차 제초 준비", "새로 나온 잡초가 어릴 때 피복도와 분포를 확인합니다."),
    4: ("봄 1차 핵심 제초 후보", "발생초기 잡초 비율이 높으면 살포 적기 후보로 올립니다."),
    5: ("봄 2차 보정", "1차 처리 후 재발생·생존 잡초를 구역별로 재평가합니다."),
    6: ("초여름 재발생 관리", "장마 전후 잡초 증가와 강우 창을 함께 확인합니다."),
    7: ("여름 집중 관리", "고온기 빠른 재발생과 생존 잡초를 집중 추적합니다."),
    8: ("여름 2차 제초 후보", "피복도가 빠르게 증가하는 구역을 우선 예찰합니다."),
    9: ("수확 전 선택 관리", "수확 동선과 품종 숙기를 고려해 필요한 구역만 관리합니다."),
    10: ("수확기 최소 개입", "수확에 방해되는 구역 위주로 관리하고 불필요한 반복 살포는 피합니다."),
    11: ("문제잡초 지도 작성", "생존·재발생 구역을 기록해 다음 해 계획에 반영합니다."),
    12: ("연간 제초 결산", "살포 횟수·재발생·생존 잡초 이력을 정리합니다."),
}


class WeedAssessIn(BaseModel):
    orchard: str = "A과수원"
    zone: str = ""
    coverage_pct: float = 0
    distribution: str = "군락형"
    growth_stage: str = "생육초기"
    weed_group: str = "미상"
    survivor_seen: bool = False
    days_after_last_spray: int = 999
    photo_count: int = 0
    note: str = ""


def _coverage_label(pct: float) -> str:
    if pct < 15:
        return "낮음"
    if pct < 40:
        return "중간"
    return "높음"


def _recent_history(orchard: str, zone: str):
    try:
        with main.engine.connect() as c:
            q = select(weed_history).where(weed_history.c.orchard == orchard)
            if zone:
                q = q.where(weed_history.c.zone == zone)
            rows = c.execute(q.order_by(desc(weed_history.c.id)).limit(8)).mappings().all()
        return [dict(r) for r in rows]
    except Exception:
        return []


def _weather_context(orchard: str):
    weather, source, warning, _ = main.orchard_weather(orchard)
    max_pop = max([float(x.get("rain_probability", 0) or 0) for x in weather[:18]], default=0)
    max_wind = max([float(x.get("wind", 0) or 0) for x in weather[:18]], default=0)
    max_temp = max([float(x.get("temp", 0) or 0) for x in weather[:18]], default=0)
    return {
        "source": source,
        "warning": warning,
        "max_pop": max_pop,
        "max_wind": max_wind,
        "max_temp": max_temp,
    }


def _assess(x: WeedAssessIn):
    orchard = x.orchard.strip() or "A과수원"
    zone = x.zone.strip()
    pct = max(0.0, min(100.0, float(x.coverage_pct)))
    label = _coverage_label(pct)
    month = datetime.now(main.TZ).month
    annual_title, annual_note = ANNUAL_WEED_WINDOWS[month]
    weather = _weather_context(orchard)
    history = _recent_history(orchard, zone)

    score = 30
    reasons = []
    cautions = []

    if pct >= 40:
        score += 28
        reasons.append(f"자동 피복도 추정 {pct:.0f}%로 높은 편")
    elif pct >= 15:
        score += 15
        reasons.append(f"자동 피복도 추정 {pct:.0f}%로 중간 수준")
    else:
        score += 4
        reasons.append(f"자동 피복도 추정 {pct:.0f}%로 낮은 편")

    if x.distribution == "전면확산":
        score += 18
        reasons.append("잡초가 구역 전반으로 확산")
    elif x.distribution == "군락형":
        score += 10
        reasons.append("군락형 분포로 구역별 관리 필요")
    else:
        reasons.append("산발형 분포로 부분 관리 우선")

    if x.growth_stage in {"발생초기", "생육초기"}:
        score += 14
        reasons.append("잡초가 어린 단계라 방제 적기 후보")
    elif x.growth_stage in {"왕성생육", "개화·결실"}:
        score -= 8
        reasons.append("잡초가 커져 단순 반복 살포보다 방법 재검토 필요")
        cautions.append("큰 잡초는 예초·기계제초 병행 여부도 검토하세요.")

    if x.days_after_last_spray < 7:
        score -= 25
        cautions.append("직전 살포 후 기간이 짧아 재살포를 서두르지 마세요.")
    elif x.days_after_last_spray < 14:
        score -= 8
        reasons.append("직전 살포 후 효과 판정 기간을 더 지켜볼 필요가 있음")

    if x.survivor_seen:
        score -= 12
        reasons.append("직전 처리 후 생존 잡초가 관찰됨")
        cautions.append("동일 작용기작 반복보다 잡초종·피복·살포 조건을 먼저 점검하세요.")

    if weather["max_pop"] >= 60:
        score -= 25
        cautions.append(f"최대 강수확률 {weather['max_pop']:.0f}%로 살포 보류가 유리")
    if weather["max_wind"] >= 5:
        score -= 20
        cautions.append(f"최대 풍속 {weather['max_wind']:.1f}m/s로 비산 위험 확인 필요")
    if weather["max_temp"] >= 32:
        score -= 8
        cautions.append("고온 시간대를 피하고 작업 적합시간을 다시 확인하세요.")

    recurrence = 0
    if history:
        high_count = sum(1 for r in history if float(r.get("coverage_pct", 0) or 0) >= 40)
        survivor_count = sum(1 for r in history if int(r.get("survivor_seen", 0) or 0) == 1)
        recurrence = min(100, high_count * 18 + survivor_count * 22)
        if recurrence >= 40:
            reasons.append("최근 기록에서 높은 피복도/생존 잡초가 반복됨")

    score = max(0, min(100, int(round(score))))
    if weather["max_pop"] >= 60 or weather["max_wind"] >= 5:
        recommendation = "살포 보류"
        window = "기상 안정 후 재평가"
    elif score >= 75:
        recommendation = "살포 적기 후보"
        window = "오늘~2일 내 현장 확인 후 검토"
    elif score >= 50:
        recommendation = "곧 살포 검토"
        window = "2~5일 내 재촬영·재평가"
    else:
        recommendation = "예찰 지속"
        window = "현재는 관찰·부분관리 우선"

    return {
        "orchard": orchard,
        "zone": zone,
        "coverage_pct": round(pct, 1),
        "coverage_label": label,
        "priority_score": score,
        "recommendation": recommendation,
        "recommended_window": window,
        "annual_phase": annual_title,
        "annual_note": annual_note,
        "recurrence_score": recurrence,
        "history_count": len(history),
        "reasons": reasons,
        "cautions": cautions,
        "weather_source": weather["source"],
        "policy": "사진 기반 피복도는 초기 보조 추정치이며 잡초종 확정 판정이 아닙니다. 제품·농도·혼용은 자동 처방하지 않고 PSIS 등록사항과 라벨을 확인해야 합니다.",
    }


@main.app.post("/api/weeds/camera-assess")
def camera_assess(x: WeedAssessIn):
    result = _assess(x)
    with main.engine.begin() as c:
        c.execute(insert(weed_history).values(
            orchard=result["orchard"],
            zone=result["zone"],
            coverage_pct=result["coverage_pct"],
            coverage_label=result["coverage_label"],
            distribution=x.distribution,
            growth_stage=x.growth_stage,
            weed_group=x.weed_group,
            survivor_seen=1 if x.survivor_seen else 0,
            recommendation=result["recommendation"],
            priority_score=result["priority_score"],
            note=x.note,
            created_at=main.now_iso(),
        ))
    return result


@main.app.get("/api/weeds/history")
def weed_history_list(orchard: str = "A과수원", zone: str = ""):
    rows = _recent_history(orchard.strip() or "A과수원", zone.strip())
    return rows


@main.app.get("/api/weeds/annual-plan")
def annual_plan():
    return [
        {"month": month, "title": value[0], "note": value[1]}
        for month, value in sorted(ANNUAL_WEED_WINDOWS.items())
    ]
