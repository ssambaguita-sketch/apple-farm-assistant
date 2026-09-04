from datetime import datetime

import app as base_app
import main


ANNUAL_FLOW = {
    1: {
        "stage": "휴면기",
        "goal": "연간계획·시설점검",
        "core": ["전년도 기록 정리", "올해 작업계획 수립", "농기계·시설 점검"],
        "nutrition": "전년도 결핍 이력과 토양검정 계획 확인",
        "pest": "월동 해충 흔적·알·피해가지 예찰",
        "disease": "병든 가지·수간 병반·월동 감염원 점검",
        "environment": "동해·수간 피해와 시설 상태 확인",
    },
    2: {
        "stage": "휴면기",
        "goal": "동계전정",
        "core": ["동계전정", "수형 정리", "가지·수간 상태 점검"],
        "nutrition": "수세가 약한 구역과 전년도 결핍 반복구역 표시",
        "pest": "전정 중 월동 해충·피해 흔적 확인",
        "disease": "병든 가지와 궤양성 병반 여부 확인",
        "environment": "동해·가지 갈라짐·지주 손상 확인",
    },
    3: {
        "stage": "발아 준비",
        "goal": "발아 전 준비",
        "core": ["전정 마무리", "유인·지주 점검", "토양·배수 상태 확인"],
        "nutrition": "발아 전 토양 pH·배수·뿌리환경과 결핍 이력 점검",
        "pest": "발아 전 월동 해충 발생 여부 확인",
        "disease": "강우 전후 수간·가지 병반과 감염원 확인",
        "environment": "늦서리·과습·배수불량 위험 구역 확인",
    },
    4: {
        "stage": "발아·개화",
        "goal": "개화·저온 관리",
        "core": ["꽃눈·개화 상태 관찰", "저온·서리 위험 확인", "수분 상태 관찰"],
        "nutrition": "새잎 황화·왜소·잎맥 사이 황화 등 초기 결핍 패턴 예찰",
        "pest": "꽃·신초의 흡즙성 해충과 피해 흔적 예찰",
        "disease": "개화기 강우·고습 후 꽃·잎 병반 발생 여부 확인",
        "environment": "저온·서리·강풍 피해와 개화 불균일 확인",
    },
    5: {
        "stage": "착과",
        "goal": "착과·적과 시작",
        "core": ["착과 상태 확인", "적과 시작", "신초·병해충 예찰"],
        "nutrition": "신초·새잎의 황화·기형과 착과 후 영양 불균형 징후 확인",
        "pest": "신초·잎·유과의 해충·식흔·알·유충 예찰",
        "disease": "낙화 후 잎·유과 병반과 강우 후 확산 여부 확인",
        "environment": "착과 불균일·강풍·과습·토양 수분 변동 확인",
    },
    6: {
        "stage": "초기 과실비대",
        "goal": "과실비대 관리",
        "core": ["적과 마무리", "유인 작업", "관수·토양수분 점검", "잡초 관리"],
        "nutrition": "오래된 잎/새잎의 황화 위치를 구분해 Mg·Fe 등 결핍 패턴 예찰",
        "pest": "잎·과실의 식흔·흡즙 흔적과 해충 밀도 변화 확인",
        "disease": "고습·강우 후 잎·과실 병반 증가 여부 확인",
        "environment": "수분 스트레스·과습·배수불량·가지 처짐 확인",
    },
    7: {
        "stage": "과실비대",
        "goal": "고온·수분 관리",
        "core": ["고온·가뭄 대응", "관수 필요성 점검", "잡초 관리", "과실·가지 예찰"],
        "nutrition": "황화·엽연괴사·생육 불균일과 실제 결핍 여부를 구분해 예찰",
        "pest": "응애·나방류 등 피해 흔적과 증가속도 확인",
        "disease": "고온다습·강우 후 병반 확대와 새 감염부위 확인",
        "environment": "일소·가뭄·과습·뿌리 스트레스·고온 피해 확인",
    },
    8: {
        "stage": "과실비대·착색 준비",
        "goal": "수확 전 품질관리",
        "core": ["과실 상태 확인", "가지 처짐·지주 점검", "착색 준비"],
        "nutrition": "착색·과실비대 불균일과 잎 황화가 영양 문제인지 확인",
        "pest": "과실 피해·흡즙·천공 흔적과 수확 전 해충 밀도 확인",
        "disease": "과실 병반·부패 징후와 비 온 뒤 확산 여부 확인",
        "environment": "일소·강풍·낙과·수분 스트레스 확인",
    },
    9: {
        "stage": "착색·성숙",
        "goal": "수확 준비",
        "core": ["착색 상태 확인", "성숙도 관찰", "낙과·강풍 위험 점검", "수확 계획"],
        "nutrition": "수확기 불필요한 보정보다 잎·과실 증상 기록과 다음 해 분석자료 확보",
        "pest": "수확 전 과실 피해·해충 흔적을 집중 예찰하고 안전사용기준 확인",
        "disease": "과실 부패·반점과 강우 후 확산 여부를 수확 전 집중 확인",
        "environment": "태풍·강풍·낙과·과습·일소 피해 확인",
    },
    10: {
        "stage": "본격 수확",
        "goal": "수확·선별·출하",
        "core": ["수확 적기 확인", "수확", "선별·출하", "수확량 기록"],
        "nutrition": "수확 과실과 잎의 결핍 의심 증상을 구역별로 기록",
        "pest": "피해과 비율과 해충 흔적을 선별 과정에서 기록",
        "disease": "부패·병반 과실 비율과 발생구역 기록",
        "environment": "비·강풍·저온에 따른 수확 작업 위험과 낙과 확인",
    },
    11: {
        "stage": "수확 후",
        "goal": "수확 후 정리",
        "core": ["수확 마무리", "낙엽·잔재 관리", "수세·수확 결과 기록"],
        "nutrition": "올해 결핍 의심 구역을 정리하고 토양·엽 분석 계획 수립",
        "pest": "피해 흔적과 월동 가능 해충 발생구역 기록",
        "disease": "병든 잎·과실·가지와 감염원 잔재 확인",
        "environment": "수확 후 수세·토양 수분·배수상태 확인",
    },
    12: {
        "stage": "휴면 진입",
        "goal": "결산·다음 해 준비",
        "core": ["비용·수익 결산", "작업기록 분석", "다음 해 개선계획"],
        "nutrition": "연간 결핍 의심 기록과 토양검정 결과를 다음 해 시비계획에 반영",
        "pest": "연간 해충 발생시기·피해구역을 정리해 다음 해 예찰시점 설정",
        "disease": "연간 병 발생시기·기상조건·피해구역을 정리",
        "environment": "동해 대비와 시설·배수·토양 문제 개선계획 수립",
    },
}


_original_build_today_recommendations = base_app.build_today_recommendations


def _annual_task(title: str, reason: str, priority: int, context: dict, category: str):
    item = base_app._auto_task(title, reason, priority, context.get("best_work_time") or "오늘")
    item["annual_flow"] = True
    item["annual_category"] = category
    item["reason"] = reason
    return item


def _choose_scout(plan: dict, context: dict):
    max_pop = float(context.get("forecast_max_rain_probability_pct") or 0)
    max_temp = float(context.get("forecast_max_temp_c") or 0)
    max_wind = float(context.get("forecast_max_wind_ms") or 0)
    recent_risk = int(context.get("recent_max_risk") or 0)

    if max_pop >= 60:
        return "병해", plan["disease"], 1, f"오늘 최대 강수확률 {max_pop:.0f}%로 병해 예찰 우선도를 올렸습니다."
    if max_temp >= 30 or max_wind >= 5:
        trigger = f"최고기온 {max_temp:.0f}℃" if max_temp >= 30 else f"최대풍속 {max_wind:.1f}m/s"
        return "환경위협", plan["environment"], 1, f"오늘 {trigger} 조건으로 환경장해 예찰 우선도를 올렸습니다."
    if recent_risk >= 3:
        return "병해충", f"{plan['pest']} / {plan['disease']}", 1, f"최근 관찰 최고 위험도 {recent_risk}/5로 병해충 재확인을 우선합니다."

    day = datetime.now(main.TZ).day
    rotation = day % 3
    if rotation == 0:
        return "영양결핍", plan["nutrition"], 2, "이번 달 연간 플로우의 영양결핍 예찰 시점입니다."
    if rotation == 1:
        return "해충", plan["pest"], 2, "이번 달 연간 플로우의 해충 예찰 시점입니다."
    return "병해", plan["disease"], 2, "이번 달 연간 플로우의 병해 예찰 시점입니다."


def build_today_recommendations_with_annual_flow(orchard_name: str):
    recs, context, confidence = _original_build_today_recommendations(orchard_name)
    month = datetime.now(main.TZ).month
    plan = ANNUAL_FLOW[month]

    context = dict(context)
    context.update({
        "annual_month": month,
        "annual_stage": plan["stage"],
        "annual_goal": plan["goal"],
    })

    annual_core = _annual_task(
        f"연간플로우 · {plan['core'][0]}",
        f"{month}월 생육단계 '{plan['stage']}'의 핵심목표는 '{plan['goal']}'입니다. 이번 달 핵심작업 중 '{plan['core'][0]}'을 오늘 확인하세요.",
        2,
        context,
        "핵심농작업",
    )

    scout_category, scout_text, scout_priority, trigger_reason = _choose_scout(plan, context)
    annual_scout = _annual_task(
        f"{month}월 {scout_category} 예찰",
        f"{trigger_reason} 확인 항목: {scout_text}",
        scout_priority,
        context,
        scout_category,
    )

    merged = [annual_core, annual_scout] + list(recs)
    deduped = []
    seen = set()
    for rec in sorted(merged, key=lambda x: (int(x.get("priority", 3)), 0 if x.get("annual_flow") else 1)):
        key = str(rec.get("title", "")).replace("[자동추천] ", "").strip()
        if key in seen:
            continue
        seen.add(key)
        deduped.append(rec)
        if len(deduped) >= 5:
            break

    for rec in deduped:
        rec["decision_evidence"] = dict(context)
        rec["confidence"] = confidence
        original_when = rec.get("recommended_time") or rec.get("scheduled_at") or "오늘"
        rec["recommended_time"] = original_when
        # Keep old installed clients informative while avoiding repeated evidence strings.
        if " · 근거:" not in str(rec.get("scheduled_at", "")):
            rec["scheduled_at"] = f"{original_when} · 근거: {rec.get('reason', '')} · 신뢰도 {confidence}"

    return deduped, context, confidence


base_app.build_today_recommendations = build_today_recommendations_with_annual_flow
