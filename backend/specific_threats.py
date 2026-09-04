from datetime import datetime

from sqlalchemy import select, desc

import app as base_app
import main


_previous_build = base_app.build_today_recommendations


# 시기별 우선 예찰 후보. '확진'이 아니라 생육시기·기상조건으로 우선순위를 정하는 후보군이다.
DISEASE_BY_MONTH = {
    3: [("검은별무늬병", 42), ("점무늬낙엽병", 34)],
    4: [("검은별무늬병", 58), ("점무늬낙엽병", 48)],
    5: [("갈색무늬병", 60), ("붉은별무늬병", 52), ("점무늬낙엽병", 50), ("겹무늬썩음병", 42), ("탄저병", 38)],
    6: [("갈색무늬병", 64), ("겹무늬썩음병", 60), ("탄저병", 55), ("점무늬낙엽병", 48)],
    7: [("탄저병", 74), ("갈색무늬병", 68), ("겹무늬썩음병", 62), ("점무늬낙엽병", 46)],
    8: [("탄저병", 82), ("갈색무늬병", 70), ("겹무늬썩음병", 64)],
    9: [("탄저병", 68), ("갈색무늬병", 66), ("겹무늬썩음병", 56)],
    10: [("갈색무늬병", 52), ("과실 부패성 병해", 44)],
}

PEST_BY_MONTH = {
    3: [("사과응애 월동알", 62), ("사과면충", 48), ("깍지벌레류", 48)],
    4: [("사과혹진딧물", 60), ("잎말이나방류", 52), ("은무늬굴나방", 45), ("장님노린재류", 44), ("복숭아순나방", 42)],
    5: [("복숭아순나방", 68), ("사과응애", 58), ("조팝나무진딧물", 52), ("은무늬굴나방", 46)],
    6: [("복숭아순나방", 66), ("사과응애", 62), ("노린재류", 48)],
    7: [("사과응애", 72), ("복숭아순나방", 66), ("노린재류", 56)],
    8: [("복숭아순나방", 64), ("노린재류", 58), ("사과응애", 54)],
    9: [("복숭아순나방", 52), ("노린재류", 50)],
}

NUTRITION_BY_MONTH = {
    4: [("철 결핍", 48, "새잎의 잎맥 사이 황화가 있을 때 우선 확인"), ("붕소 등 미량원소 불균형", 36, "신초·꽃·새잎 기형이 있을 때 확인")],
    5: [("철 결핍", 46, "새잎 황화가 잎맥 사이에 나타나는지 확인"), ("붕소 등 미량원소 불균형", 38, "신초·착과 이상과 함께 확인")],
    6: [("마그네슘 결핍", 58, "오래된 잎의 잎맥 사이 황화 여부 확인"), ("칼륨 불균형", 44, "오래된 잎 가장자리 마름 여부 확인")],
    7: [("마그네슘 결핍", 66, "과실비대기 오래된 잎 황화·잎맥 녹색 유지 여부 확인"), ("칼륨 불균형", 48, "잎 가장자리 마름·과실비대 불균일 여부 확인")],
    8: [("마그네슘 결핍", 68, "오래된 잎의 잎맥 사이 황화와 조기낙엽 여부 확인"), ("칼륨 불균형", 48, "엽연괴사·착색 불균일과 함께 확인")],
    9: [("마그네슘 결핍", 54, "수확기 증상 기록용으로 확인; 보정은 분석 후 판단"), ("칼륨 불균형", 42, "착색·엽연괴사 기록 후 분석")],
}

ENV_BY_MONTH = {
    3: "늦서리·배수불량",
    4: "저온·서리 피해",
    5: "강풍·과습·착과 스트레스",
    6: "과습·수분 스트레스",
    7: "고온·일소·가뭄 스트레스",
    8: "일소·강풍·낙과 스트레스",
    9: "태풍·강풍·낙과 스트레스",
    10: "강우·저온 수확 스트레스",
}


def _latest_observation_text(orchard_name: str) -> str:
    try:
        with main.engine.connect() as c:
            rows = c.execute(
                select(main.observations)
                .where(main.observations.c.orchard == orchard_name)
                .order_by(desc(main.observations.c.id))
                .limit(8)
            ).mappings().all()
        return " ".join(f"{r.get('category', '')} {r.get('note', '')}" for r in rows)
    except Exception:
        return ""


def _rank_diseases(month: int, context: dict):
    candidates = [list(x) for x in DISEASE_BY_MONTH.get(month, [])]
    rain = float(context.get("forecast_max_rain_probability_pct") or 0)
    if rain >= 60:
        for c in candidates:
            if c[0] in {"탄저병", "갈색무늬병", "겹무늬썩음병", "점무늬낙엽병"}:
                c[1] += 12
    return sorted(candidates, key=lambda x: x[1], reverse=True)


def _rank_pests(month: int, context: dict):
    candidates = [list(x) for x in PEST_BY_MONTH.get(month, [])]
    temp = float(context.get("forecast_max_temp_c") or 0)
    if temp >= 27:
        for c in candidates:
            if c[0] in {"사과응애", "복숭아순나방"}:
                c[1] += 6
    return sorted(candidates, key=lambda x: x[1], reverse=True)


def _rank_nutrition(month: int, observation_text: str):
    candidates = [list(x) for x in NUTRITION_BY_MONTH.get(month, [])]
    text = observation_text
    for c in candidates:
        name = c[0]
        if name == "마그네슘 결핍" and any(k in text for k in ("마그네슘", "오래된잎", "잎맥사이황화", "잎맥 사이 황화")):
            c[1] += 24
        elif name == "철 결핍" and any(k in text for k in ("철", "새잎", "잎맥사이황화", "잎맥 사이 황화")):
            c[1] += 24
        elif name == "칼륨 불균형" and any(k in text for k in ("칼륨", "가장자리마름", "엽연괴사")):
            c[1] += 22
    return sorted(candidates, key=lambda x: x[1], reverse=True)


def _specific_for(rec: dict, month: int, context: dict, obs_text: str):
    threat_type = str(rec.get("threat_type") or "")
    category = str(rec.get("annual_category") or "")
    title = str(rec.get("title") or "")
    reason = str(rec.get("reason") or "")
    text = f"{title} {reason}"

    if threat_type == "disease" or category == "병해" or "병해" in text:
        ranked = _rank_diseases(month, context)
        if ranked:
            return ranked[0][0], ranked, "시기·강수조건 기반 병해 예찰 후보"

    if threat_type == "pest" or category == "해충" or any(k in text for k in ("해충", "응애", "나방", "진딧물")):
        ranked = _rank_pests(month, context)
        if ranked:
            return ranked[0][0], ranked, "시기·기온조건 기반 해충 예찰 후보"

    if threat_type == "nutrition" or category == "영양결핍" or any(k in text for k in ("결핍", "황화", "영양")):
        ranked = _rank_nutrition(month, obs_text)
        if ranked:
            return ranked[0][0], ranked, "생육시기 + 최근 관찰기록 기반 결핍 예찰 후보"

    if threat_type == "environment" or category == "환경위협":
        name = ENV_BY_MONTH.get(month)
        if name:
            return name, [[name, 70]], "시기·기상조건 기반 환경위협 후보"

    return None, [], None


def build_today_recommendations_with_specific_threats(orchard_name: str):
    recs, context, confidence = _previous_build(orchard_name)
    month = int(context.get("annual_month") or datetime.now(main.TZ).month)
    obs_text = _latest_observation_text(orchard_name)
    out = []

    for raw in recs:
        rec = dict(raw)
        specific, ranked, basis = _specific_for(rec, month, context, obs_text)
        if specific:
            # generic 위협 라벨은 남기되, 실제 사용자가 먼저 읽는 제목에는 구체 후보명을 표시한다.
            old = str(rec.get("title") or "")
            body = old
            if "] " in old:
                body = old.split("] ", 2)[-1]
            rec["title"] = f"[자동추천] [예측위협 후보: {specific}] {body}"
            rec["specific_threat"] = specific
            rec["specific_threat_candidates"] = [
                {"name": c[0], "score": int(min(100, c[1]))} for c in ranked[:4]
            ]
            rec["prediction_basis"] = basis
            rec["prediction_status"] = "예찰후보"
            rec["reason"] = (
                f"{rec.get('reason', '')} 구체 후보 '{specific}'은 {basis}로 우선순위를 올린 것이며 확진이 아닙니다. "
                "현장 증상·사진·발생범위를 확인해 판정을 갱신하세요."
            ).strip()
        out.append(rec)

    return out, context, confidence


base_app.build_today_recommendations = build_today_recommendations_with_specific_threats
