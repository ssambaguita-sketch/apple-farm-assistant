from datetime import datetime, timedelta

from pydantic import BaseModel
from sqlalchemy import Table, Column, Integer, Float, String, select, insert

import main


behavior_checkins = Table(
    "behavior_checkins",
    main.metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("planned_tasks", Integer, default=0),
    Column("completed_tasks", Integer, default=0),
    Column("start_delay_min", Integer, default=0),
    Column("task_switches", Integer, default=0),
    Column("estimated_duration_min", Integer, default=0),
    Column("actual_duration_min", Integer, default=0),
    Column("attention_difficulty", Integer, default=0),
    Column("low_mood", Integer, default=0),
    Column("low_interest", Integer, default=0),
    Column("function_difficulty", Integer, default=0),
    Column("created_at", String(40), nullable=False),
    extend_existing=True,
)


class BehaviorCheckinIn(BaseModel):
    planned_tasks: int = 0
    completed_tasks: int = 0
    start_delay_min: int = 0
    task_switches: int = 0
    estimated_duration_min: int = 0
    actual_duration_min: int = 0
    attention_difficulty: int = 0  # 0 없음 ~ 3 매우 자주
    low_mood: int = 0              # 자기보고 0~3
    low_interest: int = 0          # 자기보고 0~3
    function_difficulty: int = 0   # 자기보고 0~3


def _clamp(v: int, lo: int, hi: int) -> int:
    return max(lo, min(hi, int(v)))


def _avg(rows, key):
    vals = [float(r.get(key) or 0) for r in rows]
    return sum(vals) / len(vals) if vals else 0.0


def _behavior_analysis(rows):
    if not rows:
        return {
            "sample_count": 0,
            "patterns": [],
            "attention_signal": {"level": "데이터 부족", "score": 0, "evidence": [], "related_area": "ADHD 관련 주의·실행기능 선별 신호", "not_diagnosis": True},
            "mood_signal": {"level": "데이터 부족", "score": 0, "evidence": [], "related_area": "우울 관련 기분·활동 저하 선별 신호", "not_diagnosis": True},
            "interventions": ["며칠간 작업행동과 자기보고를 기록하면 개인화 분석을 시작합니다."],
            "policy": "의학적 진단이 아닙니다. 행동기록과 사용자가 직접 입력한 자기보고만 사용합니다.",
        }

    planned = sum(int(r.get("planned_tasks") or 0) for r in rows)
    completed = sum(int(r.get("completed_tasks") or 0) for r in rows)
    completion_ratio = completed / planned if planned > 0 else 1.0
    avg_delay = _avg(rows, "start_delay_min")
    avg_switches = _avg(rows, "task_switches")
    avg_attention = _avg(rows, "attention_difficulty")
    avg_mood = _avg(rows, "low_mood")
    avg_interest = _avg(rows, "low_interest")
    avg_function = _avg(rows, "function_difficulty")

    duration_errors = []
    for r in rows:
        est = float(r.get("estimated_duration_min") or 0)
        actual = float(r.get("actual_duration_min") or 0)
        if est > 0:
            duration_errors.append(abs(actual - est) / est)
    avg_duration_error = sum(duration_errors) / len(duration_errors) if duration_errors else 0.0

    patterns = []
    interventions = []
    attention_evidence = []
    attention_points = 0

    if avg_delay >= 30:
        patterns.append({"name": "착수 지연", "evidence": f"최근 평균 시작 지연 {avg_delay:.0f}분"})
        attention_evidence.append(f"평균 시작 지연 {avg_delay:.0f}분")
        attention_points += 22
        interventions.append("중요 작업은 '도구 준비 → 첫 구역 5분 시작'처럼 첫 행동을 5분 단위로 줄이세요.")
    if avg_switches >= 3:
        patterns.append({"name": "집중 분산", "evidence": f"작업당 평균 전환 {avg_switches:.1f}회"})
        attention_evidence.append(f"작업 전환 평균 {avg_switches:.1f}회")
        attention_points += 22
        interventions.append("한 번에 활성 작업을 1개로 제한하고 25~40분 단일 작업 구간을 사용하세요.")
    if completion_ratio < 0.6:
        patterns.append({"name": "계획 과부하", "evidence": f"계획 대비 완료율 {completion_ratio*100:.0f}%"})
        attention_evidence.append(f"계획 대비 완료율 {completion_ratio*100:.0f}%")
        attention_points += 18
        interventions.append("하루 핵심작업을 3개 이하로 줄이고 나머지는 대기 목록으로 이동하세요.")
    if avg_duration_error >= 0.5:
        patterns.append({"name": "시간예측 오차", "evidence": f"예상-실제 시간 오차 평균 {avg_duration_error*100:.0f}%"})
        attention_evidence.append(f"시간예측 오차 {avg_duration_error*100:.0f}%")
        attention_points += 16
        interventions.append("다음 계획에는 최근 실제시간의 중앙값 또는 1.3배를 예상시간으로 사용해 보세요.")
    if avg_attention >= 2:
        attention_evidence.append(f"주의 유지 어려움 자기보고 평균 {avg_attention:.1f}/3")
        attention_points += 28

    attention_score = min(100, attention_points)
    if len(rows) < 3:
        attention_level = "데이터 부족"
    elif attention_score >= 65:
        attention_level = "높은 선별 신호"
    elif attention_score >= 35:
        attention_level = "관찰 필요"
    else:
        attention_level = "낮음"

    mood_evidence = []
    mood_points = 0
    if avg_mood >= 2:
        mood_evidence.append(f"기분 저하 자기보고 평균 {avg_mood:.1f}/3")
        mood_points += 35
    if avg_interest >= 2:
        mood_evidence.append(f"흥미·의욕 저하 자기보고 평균 {avg_interest:.1f}/3")
        mood_points += 35
    if avg_function >= 1.5:
        mood_evidence.append(f"일상 기능 어려움 자기보고 평균 {avg_function:.1f}/3")
        mood_points += 30

    mood_score = min(100, mood_points)
    # 행동만으로 우울 관련 신호를 만들지 않는다. 최소 3회 자기보고가 있어야 한다.
    if len(rows) < 3:
        mood_level = "데이터 부족"
    elif mood_score >= 70:
        mood_level = "전문가 평가 고려"
    elif mood_score >= 35:
        mood_level = "추적 관찰"
    else:
        mood_level = "낮음"

    if mood_level in {"전문가 평가 고려", "추적 관찰"}:
        interventions.append("기분·흥미·일상 기능 변화가 계속되는지 기록하고, 지속되거나 생활에 영향을 주면 의료·정신건강 전문가 상담을 고려하세요.")

    if not interventions:
        interventions.append("현재 기록에서는 뚜렷한 행동 교정 신호가 적습니다. 현재 리듬을 유지하며 주간 추세를 확인하세요.")

    return {
        "sample_count": len(rows),
        "window_days": 14,
        "metrics": {
            "completion_ratio_pct": round(completion_ratio * 100, 1),
            "avg_start_delay_min": round(avg_delay, 1),
            "avg_task_switches": round(avg_switches, 1),
            "avg_duration_error_pct": round(avg_duration_error * 100, 1),
        },
        "patterns": patterns,
        "attention_signal": {
            "level": attention_level,
            "score": attention_score,
            "evidence": attention_evidence,
            "related_area": "ADHD 관련 주의·실행기능 선별 신호",
            "not_diagnosis": True,
        },
        "mood_signal": {
            "level": mood_level,
            "score": mood_score,
            "evidence": mood_evidence,
            "related_area": "우울 관련 기분·활동 저하 선별 신호",
            "not_diagnosis": True,
            "basis": "사용자 자기보고만 사용; 작업행동만으로 우울 관련 신호를 추정하지 않음",
        },
        "interventions": interventions[:5],
        "experiment": {
            "duration_days": 5,
            "instruction": interventions[0],
            "measure": "시작 지연·완료율·작업전환 변화를 5일 후 비교",
        },
        "policy": "의학적 진단이 아닙니다. ADHD·우울증 여부를 확정하지 않으며 행동기록과 사용자의 직접 자기보고를 기반으로 선별 신호만 제공합니다.",
    }


@main.app.post("/api/coach/behavior-checkin")
def behavior_checkin(x: BehaviorCheckinIn):
    with main.engine.begin() as c:
        c.execute(insert(behavior_checkins).values(
            planned_tasks=max(0, x.planned_tasks),
            completed_tasks=max(0, min(x.completed_tasks, max(x.planned_tasks, x.completed_tasks))),
            start_delay_min=max(0, x.start_delay_min),
            task_switches=max(0, x.task_switches),
            estimated_duration_min=max(0, x.estimated_duration_min),
            actual_duration_min=max(0, x.actual_duration_min),
            attention_difficulty=_clamp(x.attention_difficulty, 0, 3),
            low_mood=_clamp(x.low_mood, 0, 3),
            low_interest=_clamp(x.low_interest, 0, 3),
            function_difficulty=_clamp(x.function_difficulty, 0, 3),
            created_at=main.now_iso(),
        ))
    return {"ok": True}


@main.app.get("/api/coach/behavior-analysis")
def behavior_analysis():
    since = (datetime.now(main.TZ) - timedelta(days=14)).isoformat(timespec="seconds")
    with main.engine.connect() as c:
        rows = c.execute(
            select(behavior_checkins)
            .where(behavior_checkins.c.created_at >= since)
            .order_by(behavior_checkins.c.id.desc())
            .limit(30)
        ).mappings().all()
    return _behavior_analysis([dict(r) for r in rows])
