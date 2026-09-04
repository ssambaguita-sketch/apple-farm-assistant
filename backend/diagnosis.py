from typing import Optional

from pydantic import BaseModel
from sqlalchemy import select, insert

import main


class DiagnosisIn(BaseModel):
    orchard: str = "A과수원"
    has_photo: bool = False
    organ: str = "잎"
    leaf_age: str = "모름"          # 새잎 / 오래된잎 / 전체 / 모름
    pattern: str = "모름"           # 잎맥사이황화 / 가장자리마름 / 반점 / 구멍식흔 / 말림기형 / 전체황화 / 모름
    vein_state: str = "모름"        # 녹색유지 / 함께황화 / 모름
    lesion_shape: str = "없음"      # 없음 / 원형 / 불규칙 / 수침상 / 동심원
    symmetry: str = "모름"          # 대칭 / 불규칙 / 모름
    spread: str = "한잎"            # 한잎 / 한가지 / 한나무 / 여러나무
    insects_seen: str = "모름"      # 예 / 아니오 / 모름
    feeding_damage: str = "모름"    # 예 / 아니오 / 모름
    soil_condition: str = "보통"    # 보통 / 건조 / 과습 / 배수불량 / 모름
    note: str = ""


def _clamp(v: float, lo: int = 0, hi: int = 100) -> int:
    return int(max(lo, min(hi, round(v))))


def _risk_level(score: int) -> str:
    if score >= 75:
        return "긴급확인"
    if score >= 50:
        return "높음"
    if score >= 25:
        return "주의"
    return "낮음"


def _confidence(has_photo: bool, answered: int, weather_source: str, orchard_found: bool) -> str:
    points = answered * 8
    if has_photo:
        points += 12
    if weather_source == "kma":
        points += 12
    if orchard_found:
        points += 8
    if points >= 72:
        return "높음"
    if points >= 44:
        return "보통"
    return "낮음"


def assess_diagnosis(x: DiagnosisIn):
    orchard_name = x.orchard.strip() or "A과수원"
    with main.engine.connect() as c:
        orchard = c.execute(
            select(main.orchards).where(main.orchards.c.name == orchard_name)
        ).mappings().first()

    weather, weather_source, weather_warning, _grid = main.orchard_weather(orchard_name)
    max_temp = max([float(w.get("temp", 0) or 0) for w in weather], default=0)
    max_humidity = max([float(w.get("humidity", 0) or 0) for w in weather], default=0)
    max_pop = max([float(w.get("rain_probability", 0) or 0) for w in weather], default=0)
    growth_stage = str((orchard or {}).get("growth_stage") or "미등록")

    scores = {"영양결핍": 10.0, "병해": 10.0, "해충": 10.0, "환경장해": 10.0}
    evidence = []

    if x.leaf_age == "오래된잎":
        scores["영양결핍"] += 14
        evidence.append("오래된 잎에서 먼저 보여 이동성 양분 결핍 후보가 올라감")
    elif x.leaf_age == "새잎":
        scores["영양결핍"] += 10
        evidence.append("새잎에서 먼저 보여 미량원소 흡수장해 후보를 고려")

    if x.pattern == "잎맥사이황화":
        scores["영양결핍"] += 28
        evidence.append("잎맥 사이 황화 패턴")
    elif x.pattern == "가장자리마름":
        scores["영양결핍"] += 18
        scores["환경장해"] += 12
        evidence.append("잎 가장자리 마름은 양분 불균형과 수분 스트레스 모두 가능")
    elif x.pattern == "반점":
        scores["병해"] += 24
        evidence.append("국소 반점 패턴으로 병해 후보 상승")
    elif x.pattern == "구멍식흔":
        scores["해충"] += 34
        evidence.append("구멍·식흔 형태로 해충 피해 후보 상승")
    elif x.pattern == "말림기형":
        scores["해충"] += 15
        scores["영양결핍"] += 12
        scores["환경장해"] += 8
        evidence.append("말림·기형은 흡즙해충·결핍·환경 스트레스가 경쟁 후보")
    elif x.pattern == "전체황화":
        scores["영양결핍"] += 16
        scores["환경장해"] += 14
        evidence.append("전체 황화는 양분 또는 뿌리·수분 환경 문제 가능")

    if x.vein_state == "녹색유지" and x.pattern == "잎맥사이황화":
        scores["영양결핍"] += 18
        evidence.append("잎맥은 녹색을 유지해 잎맥 사이 황화형 결핍 근거 강화")

    if x.lesion_shape in {"원형", "불규칙", "수침상", "동심원"}:
        scores["병해"] += 22
        evidence.append(f"병반 형태가 '{x.lesion_shape}'로 관찰됨")

    if x.symmetry == "대칭":
        scores["영양결핍"] += 10
        scores["환경장해"] += 7
        evidence.append("비교적 대칭적인 증상은 전신성·생리성 원인 쪽 근거")
    elif x.symmetry == "불규칙":
        scores["병해"] += 10
        scores["해충"] += 6
        evidence.append("불규칙 분포로 국소 병해·해충 후보 상승")

    if x.insects_seen == "예":
        scores["해충"] += 38
        evidence.append("해충 또는 유충·알을 직접 관찰")
    if x.feeding_damage == "예":
        scores["해충"] += 28
        evidence.append("식흔·흡즙 등 피해 흔적 확인")

    if x.soil_condition in {"건조", "과습", "배수불량"}:
        scores["환경장해"] += 28
        scores["영양결핍"] += 8
        evidence.append(f"토양 상태가 '{x.soil_condition}'로 흡수장해·환경 스트레스 가능")

    if max_humidity >= 85 or max_pop >= 60:
        scores["병해"] += 12
        evidence.append(f"KMA/날씨 조건: 최고습도 {max_humidity:.0f}%, 최대 강수확률 {max_pop:.0f}%")
    if max_temp >= 32:
        scores["환경장해"] += 14
        evidence.append(f"예보 최고기온 {max_temp:.0f}℃로 고온 스트레스 조건")

    scores = {k: _clamp(v) for k, v in scores.items()}
    ranked = sorted(scores.items(), key=lambda kv: kv[1], reverse=True)

    nutrient_hint: Optional[str] = None
    if ranked[0][0] == "영양결핍":
        if x.leaf_age == "오래된잎" and x.pattern == "잎맥사이황화" and x.vein_state == "녹색유지":
            nutrient_hint = "마그네슘 결핍 패턴 의심"
        elif x.leaf_age == "새잎" and x.pattern == "잎맥사이황화" and x.vein_state == "녹색유지":
            nutrient_hint = "철 등 비이동성 미량원소 결핍 패턴 의심"
        elif x.pattern == "가장자리마름" and x.leaf_age == "오래된잎":
            nutrient_hint = "칼륨 불균형 패턴도 확인 필요"
        else:
            nutrient_hint = "영양 불균형 의심 — 토양·엽 분석으로 확인 필요"

    spread_points = {"한잎": 5, "한가지": 15, "한나무": 28, "여러나무": 45}.get(x.spread, 10)
    threat = spread_points + ranked[0][1] * 0.35
    if x.insects_seen == "예" or x.feeding_damage == "예":
        threat += 10
    if ranked[0][0] == "병해" and (max_humidity >= 85 or max_pop >= 60):
        threat += 10
    threat_score = _clamp(threat)

    answered_values = [x.leaf_age, x.pattern, x.vein_state, x.lesion_shape, x.symmetry, x.spread,
                       x.insects_seen, x.feeding_damage, x.soil_condition]
    answered = sum(1 for v in answered_values if v not in {"모름", "없음", ""})
    confidence = _confidence(x.has_photo, answered, weather_source, orchard is not None)

    missing = []
    if not x.has_photo:
        missing.append("현장 사진")
    if x.leaf_age == "모름":
        missing.append("증상이 새잎/오래된잎 중 어디서 시작했는지")
    if x.insects_seen == "모름":
        missing.append("잎 뒷면의 해충·알·유충 확인")
    if nutrient_hint:
        missing.append("토양검정 또는 엽분석")
    if weather_source != "kma":
        missing.append("실제 KMA 기상자료")

    next_checks = [
        "같은 나무의 정상 잎과 문제 잎을 함께 비교 촬영하세요.",
        "과원에서 떨어진 위치 3곳 이상을 확인해 발생 범위를 비교하세요.",
    ]
    if ranked[0][0] == "해충":
        next_checks.append("잎 뒷면·신초·과실 주변의 개체, 알, 유충, 식흔을 확대 확인하세요.")
    elif ranked[0][0] == "병해":
        next_checks.append("병반 경계와 확대 사진을 남기고 2~3일 뒤 확산 여부를 재확인하세요.")
    elif ranked[0][0] == "영양결핍":
        next_checks.append("시비 이력·토양 pH를 확인하고 가능하면 토양·엽 분석으로 검증하세요.")
    else:
        next_checks.append("관수·배수·고온·일소 등 환경조건이 증상 위치와 일치하는지 확인하세요.")

    result = {
        "orchard": orchard_name,
        "top_candidate": ranked[0][0],
        "top_score": ranked[0][1],
        "category_scores": [{"name": k, "score": v} for k, v in ranked],
        "nutrient_hint": nutrient_hint,
        "threat_score": threat_score,
        "threat_level": _risk_level(threat_score),
        "confidence": confidence,
        "evidence": evidence,
        "missing_evidence": missing,
        "next_checks": next_checks,
        "context": {
            "photo_recorded": x.has_photo,
            "photo_machine_analyzed": False,
            "weather_source": weather_source,
            "weather_warning": weather_warning,
            "forecast_max_temp_c": round(max_temp, 1),
            "forecast_max_humidity_pct": round(max_humidity, 0),
            "forecast_max_rain_probability_pct": round(max_pop, 0),
            "growth_stage": growth_stage,
        },
        "policy": "사진은 현재 버전에서 현장 증거로 기록하며 자동 영상판독은 하지 않습니다. 체크한 시각 특징·기상·생육정보를 종합한 의사결정 지원 결과입니다.",
    }

    risk_1_to_5 = max(1, min(5, (threat_score + 19) // 20))
    try:
        with main.engine.begin() as c:
            c.execute(insert(main.observations).values(
                orchard=orchard_name,
                category=f"진단:{ranked[0][0]}",
                risk=risk_1_to_5,
                note=f"후보점수 {ranked[0][1]}/100 · 위협도 {threat_score}/100 · 확신도 {confidence}",
                created_at=main.now_iso(),
            ))
    except Exception:
        pass

    return result


@main.app.post("/api/diagnosis/assess")
def diagnosis_assess(x: DiagnosisIn):
    return assess_diagnosis(x)
