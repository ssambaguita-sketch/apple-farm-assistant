from datetime import datetime

from pydantic import BaseModel
from sqlalchemy import select, desc

import main
import specific_threats


class RecommendationDiagnosisIn(BaseModel):
    orchard: str = "A과수원"
    specific_threat: str
    threat_type: str = ""


def _level(score: int) -> str:
    if score >= 75:
        return "높음"
    if score >= 50:
        return "주의"
    if score >= 25:
        return "관찰"
    return "낮음"


def _recent_text(orchard_name: str) -> tuple[str, int]:
    try:
        with main.engine.connect() as c:
            rows = c.execute(
                select(main.observations)
                .where(main.observations.c.orchard == orchard_name)
                .order_by(desc(main.observations.c.id))
                .limit(10)
            ).mappings().all()
        text = " ".join(f"{r.get('category', '')} {r.get('note', '')}" for r in rows)
        risk = max([int(r.get('risk', 0) or 0) for r in rows], default=0)
        return text, risk
    except Exception:
        return "", 0


def _seasonal_score(name: str, month: int, context: dict, obs_text: str) -> tuple[int, list[str]]:
    evidence = []

    for candidate in specific_threats._rank_diseases(month, context):
        if candidate[0] == name:
            evidence.append(f"{month}월 병해 발생시기 후보")
            return int(min(100, candidate[1])), evidence

    for candidate in specific_threats._rank_pests(month, context):
        if candidate[0] == name:
            evidence.append(f"{month}월 해충 발생시기 후보")
            return int(min(100, candidate[1])), evidence

    for candidate in specific_threats._rank_nutrition(month, obs_text):
        if candidate[0] == name:
            evidence.append(f"{month}월 생육단계의 영양결핍 후보")
            if len(candidate) >= 3:
                evidence.append(str(candidate[2]))
            return int(min(100, candidate[1])), evidence

    env_name = specific_threats.ENV_BY_MONTH.get(month)
    if env_name and name in env_name:
        evidence.append(f"{month}월 환경위협 후보")
        return 70, evidence

    return 30, ["자동추천에서 전달된 예찰 후보"]


def assess_recommendation_candidate(x: RecommendationDiagnosisIn):
    orchard_name = x.orchard.strip() or "A과수원"
    threat = x.specific_threat.strip()
    weather, source, warning, _ = main.orchard_weather(orchard_name)
    month = datetime.now(main.TZ).month

    max_temp = max([float(w.get("temp", 0) or 0) for w in weather], default=0)
    max_humidity = max([float(w.get("humidity", 0) or 0) for w in weather], default=0)
    max_pop = max([float(w.get("rain_probability", 0) or 0) for w in weather], default=0)

    obs_text, recent_risk = _recent_text(orchard_name)
    base, evidence = _seasonal_score(threat, month, {
        "forecast_max_temp_c": max_temp,
        "forecast_max_humidity_pct": max_humidity,
        "forecast_max_rain_probability_pct": max_pop,
    }, obs_text)

    score = base
    threat_type = (x.threat_type or "").strip()

    if threat_type == "disease" or any(k in threat for k in ("병", "썩음", "무늬")):
        if max_humidity >= 85:
            score += 8
            evidence.append(f"최고습도 {max_humidity:.0f}%")
        if max_pop >= 60:
            score += 10
            evidence.append(f"최대 강수확률 {max_pop:.0f}%")
    elif threat_type == "pest" or any(k in threat for k in ("응애", "나방", "진딧물", "노린재", "충")):
        if max_temp >= 27:
            score += 6
            evidence.append(f"최고기온 {max_temp:.0f}℃")
    elif threat_type == "nutrition" or "결핍" in threat or "불균형" in threat:
        if threat in obs_text:
            score += 18
            evidence.append("최근 관찰기록에 동일 후보명 존재")
        if "마그네슘" in threat and any(k in obs_text for k in ("오래된잎", "잎맥사이황화", "잎맥 사이 황화")):
            score += 20
            evidence.append("오래된 잎·잎맥 사이 황화 기록")
        if "철" in threat and any(k in obs_text for k in ("새잎", "잎맥사이황화", "잎맥 사이 황화")):
            score += 20
            evidence.append("새잎·잎맥 사이 황화 기록")

    if recent_risk >= 3:
        score += 8
        evidence.append(f"최근 관찰 최고 위험도 {recent_risk}/5")

    score = max(0, min(100, int(round(score))))
    confidence_points = 30
    if source == "kma":
        confidence_points += 25
    if recent_risk > 0:
        confidence_points += 15
    if score >= 70:
        confidence_points += 10
    confidence = "높음" if confidence_points >= 70 else "보통" if confidence_points >= 45 else "낮음"

    missing = []
    if source != "kma":
        missing.append("실제 KMA 기상자료")
    missing.extend([
        "현장 카메라 사진",
        "증상 부위·분포·확대 사진",
    ])
    if threat_type == "nutrition" or "결핍" in threat or "불균형" in threat:
        missing.append("토양검정 또는 엽분석")

    return {
        "orchard": orchard_name,
        "candidate": threat,
        "diagnosis_stage": "자동추천 사전진단",
        "score": score,
        "level": _level(score),
        "confidence": confidence,
        "evidence": evidence,
        "missing_evidence": missing,
        "camera_confirmation_required": True,
        "context": {
            "month": month,
            "weather_source": source,
            "weather_warning": warning,
            "forecast_max_temp_c": round(max_temp, 1),
            "forecast_max_humidity_pct": round(max_humidity, 0),
            "forecast_max_rain_probability_pct": round(max_pop, 0),
            "recent_max_risk": recent_risk,
        },
        "policy": "사전진단은 시기·기상·최근 기록으로 예찰 우선순위를 계산한 것이며 확진이 아닙니다. 카메라 현장증거와 필요 시 토양·엽 분석으로 다시 검증합니다.",
    }


@main.app.post("/api/diagnosis/recommendation-assess")
def recommendation_assess(x: RecommendationDiagnosisIn):
    return assess_recommendation_candidate(x)
