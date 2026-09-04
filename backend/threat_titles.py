import app as base_app


_previous_build = base_app.build_today_recommendations


def _classify(rec: dict):
    category = str(rec.get("annual_category") or "").strip()
    title = str(rec.get("title") or "")
    reason = str(rec.get("reason") or "")
    text = f"{title} {reason}"

    if category == "영양결핍":
        return "영양결핍 위협", "nutrition"
    if category == "해충":
        return "해충 위협", "pest"
    if category == "병해":
        return "병해 위협", "disease"
    if category == "환경위협":
        return "환경 위협", "environment"
    if category == "병해충":
        return "복합 병해충 위협", "pest_disease"
    if category == "핵심농작업":
        return "연간 핵심작업", "annual_work"

    if any(k in text for k in ("강우 대비", "배수로", "토양 수분", "관수 필요", "강풍", "낙과 위험", "지주·유인끈", "고온")):
        return "환경 위협", "environment"
    if any(k in text for k in ("병반", "부패", "감염", "병해")):
        return "병해 위협", "disease"
    if any(k in text for k in ("해충", "응애", "나방", "진딧물", "식흔", "유충", "알")):
        return "해충 위협", "pest"
    if any(k in text for k in ("황화", "결핍", "영양", "Mg", "Fe", "엽연괴사")):
        return "영양결핍 위협", "nutrition"
    if "잡초" in text:
        return "잡초 경쟁 위협", "weed"
    if "이상 징후" in text:
        return "복합 위협", "combined"
    if "날씨 연결" in text:
        return "데이터 품질 경고", "data_quality"
    if "예찰" in text:
        return "종합 예찰", "general_scout"
    return "작업 추천", "work"


def build_today_recommendations_with_clear_threat_titles(orchard_name: str):
    recs, context, confidence = _previous_build(orchard_name)
    out = []
    for raw in recs:
        rec = dict(raw)
        label, threat_type = _classify(rec)
        original = str(rec.get("title") or "").replace("[자동추천] ", "").strip()
        # Remove older generic month/category prefix when the explicit label already says it.
        rec["title"] = f"[자동추천] [{label}] {original}"
        rec["threat_type"] = threat_type
        rec["threat_label"] = label
        out.append(rec)
    return out, context, confidence


base_app.build_today_recommendations = build_today_recommendations_with_clear_threat_titles
