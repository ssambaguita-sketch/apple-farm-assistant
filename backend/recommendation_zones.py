import app as base_app
import orchard_zones


_previous_build = base_app.build_today_recommendations


def _targets(orchard_name: str, rec: dict):
    zones = orchard_zones.zone_targets_for_orchard(orchard_name)
    if not zones:
        return []

    threat = str(rec.get("specific_threat") or "")
    threat_type = str(rec.get("threat_type") or "")
    focus = rec.get("variety_focus") or {}

    out = []
    for z in zones:
        variety = str(z.get("variety") or "").strip()
        stage = str(z.get("growth_stage") or "").strip()
        priority = 2
        reasons = []

        # 품종 숙기 보정이 있는 추천은 해당 품종 구역을 한 단계 우선한다.
        if isinstance(focus, dict) and variety in focus:
            priority = 1
            reasons.append("품종별 숙기 보정 대상")

        # 과실·수확 관련 후보는 실제 생육단계가 성숙/착색/수확이면 우선한다.
        if any(k in threat for k in ("탄저병", "썩음", "복숭아순나방", "노린재", "낙과")) and any(
            k in stage for k in ("착색", "성숙", "수확")
        ):
            priority = 1
            reasons.append(f"구역 생육단계 {stage}")

        if threat_type == "nutrition" and stage:
            reasons.append(f"구역 생육단계 {stage}에서 증상 확인")

        out.append({
            "zone_id": z.get("id"),
            "zone_name": z.get("zone_name"),
            "variety": variety,
            "tree_count": int(z.get("tree_count") or 0),
            "area_m2": float(z.get("area_m2") or 0),
            "growth_stage": stage,
            "zone_priority": priority,
            "target_reason": " · ".join(reasons) if reasons else "과수원 내 해당 품종 구역 예찰 대상",
        })

    out.sort(key=lambda x: (x["zone_priority"], -x["tree_count"], str(x["zone_name"])))
    return out


def build_today_recommendations_with_zone_targets(orchard_name: str):
    recs, context, confidence = _previous_build(orchard_name)
    out = []
    all_zones = orchard_zones.zone_targets_for_orchard(orchard_name)
    for raw in recs:
        rec = dict(raw)
        targets = _targets(orchard_name, rec)
        if targets:
            rec["zone_targets"] = targets
            rec["primary_zone_target"] = targets[0]
            primary = targets[0]
            rec["reason"] = (
                f"{rec.get('reason', '')} 우선 현장확인 구역: "
                f"{primary.get('zone_name')}({primary.get('variety')}, {primary.get('tree_count')}주)."
            ).strip()
        out.append(rec)
    context = dict(context)
    context["orchard_zone_count"] = len(all_zones)
    context["orchard_zone_tree_count"] = sum(int(z.get("tree_count") or 0) for z in all_zones)
    return out, context, confidence


base_app.build_today_recommendations = build_today_recommendations_with_zone_targets
