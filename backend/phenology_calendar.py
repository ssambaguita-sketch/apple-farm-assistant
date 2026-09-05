from datetime import datetime

from sqlalchemy import Table, Column, Integer, Float, String, select, func, insert, update

import main


phenology_daily = Table(
    "phenology_daily",
    main.metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("orchard", String(120), nullable=False),
    Column("date", String(10), nullable=False),
    Column("mean_temp_c", Float, nullable=False),
    Column("gdd5", Float, nullable=False),
    Column("weather_source", String(30), nullable=False),
    Column("created_at", String(40), nullable=False),
)


SOLAR_TERMS = {
    1: [(5, "소한"), (20, "대한")],
    2: [(4, "입춘"), (19, "우수")],
    3: [(5, "경칩"), (20, "춘분")],
    4: [(5, "청명"), (20, "곡우")],
    5: [(5, "입하"), (21, "소만")],
    6: [(6, "망종"), (21, "하지")],
    7: [(7, "소서"), (23, "대서")],
    8: [(7, "입추"), (23, "처서")],
    9: [(8, "백로"), (23, "추분")],
    10: [(8, "한로"), (23, "상강")],
    11: [(7, "입동"), (22, "소설")],
    12: [(7, "대설"), (22, "동지")],
}


MONTHLY_PLAN = {
    1: {"stage": "휴면기", "goal": "결산·동해 점검", "tasks": ["전년도 수확·경영·병해충 기록 정리", "동해·수피 갈라짐·월동 해충 흔적 점검", "전정 계획과 구역별 우선순위 설정"]},
    2: {"stage": "휴면 후반", "goal": "동계전정", "tasks": ["동계전정과 수형 정리", "병든 가지·월동 감염원 표시", "배수로·시설·지주 점검"]},
    3: {"stage": "발아 준비", "goal": "발아 전 준비", "tasks": ["전정 마무리와 유인·지주 점검", "눈 발달과 늦서리 위험 확인", "봄 잡초 발생초기 촬영 시작"]},
    4: {"stage": "발아·개화", "goal": "개화·저온 관리", "tasks": ["꽃눈·개화 상태 확인", "강우 뒤 초기 병반 예찰", "서리·강풍·수분 상태 확인"]},
    5: {"stage": "착과", "goal": "착과·적과", "tasks": ["착과량 확인과 적과 시작", "신초·잎·유과 병해충 예찰", "수세 편차와 영양 불균형 징후 기록"]},
    6: {"stage": "초기 과실비대", "goal": "비대·장마 대비", "tasks": ["적과 마무리와 유인", "장마 전 배수·토양수분 확인", "잡초·응애·과실 병반 증가속도 점검"]},
    7: {"stage": "과실비대", "goal": "고온·수분 관리", "tasks": ["고온·가뭄·일소 위험 점검", "관수 필요성 확인", "여름잡초·탄저병·갈색무늬병 집중 예찰"]},
    8: {"stage": "착색 준비", "goal": "수확 전 품질관리", "tasks": ["과실 건전성과 착색 준비", "태풍·강풍 대비 지주 점검", "조생·중생 품종 수확 준비"]},
    9: {"stage": "착색·성숙", "goal": "수확 준비", "tasks": ["홍로·아리수 등 숙기별 성숙도 확인", "낙과·병반·태풍 위험 점검", "수확 동선·인력·출하 계획 정리"]},
    10: {"stage": "본격 수확", "goal": "수확·선별·출하", "tasks": ["감홍·시나노골드·후지 숙기별 수확", "수확량·품질·피해과 기록", "강우·저온 전후 수확 우선순위 조정"]},
    11: {"stage": "수확 후", "goal": "수확 후 정리", "tasks": ["후지 수확 마무리", "병든 잎·과실·잔재 정리", "수세·수확량·품질을 구역별 기록"]},
    12: {"stage": "휴면 진입", "goal": "결산·다음 해 준비", "tasks": ["매출·비용·순이익 결산", "연간 작업·제초·병해충 기록 분석", "다음 해 전정·시비·예찰 계획 확정"]},
}


VARIETY_HARVEST = {
    "루비에스": "8월 중심",
    "홍로": "8~9월 중심",
    "아리수": "9월 중심",
    "감홍": "9~10월 중심",
    "시나노골드": "10월 중심",
    "후지": "10~11월 중심",
}


STAGE_RANK = {
    "휴면": 0,
    "발아": 1,
    "개화": 2,
    "착과": 3,
    "비대": 4,
    "착색": 5,
    "성숙": 6,
    "수확": 7,
    "수확후": 8,
}


def _stage_rank(text: str):
    normalized = (text or "").replace(" ", "")
    for key, rank in STAGE_RANK.items():
        if key in normalized:
            return rank
    return None


def _forecast_summary(orchard_name: str):
    weather, source, warning, grid = main.orchard_weather(orchard_name)
    temps = [float(x.get("temp", 0) or 0) for x in weather]
    pops = [float(x.get("rain_probability", 0) or 0) for x in weather]
    winds = [float(x.get("wind", 0) or 0) for x in weather]
    mean_temp = round(sum(temps) / len(temps), 1) if temps else None
    return {
        "weather_source": source,
        "weather_warning": warning,
        "grid": grid,
        "forecast_mean_temp_c": mean_temp,
        "forecast_max_rain_probability_pct": round(max(pops), 0) if pops else None,
        "forecast_max_wind_ms": round(max(winds), 1) if winds else None,
    }


def _save_daily_temperature(orchard_name: str, summary: dict):
    if summary.get("weather_source") != "kma" or summary.get("forecast_mean_temp_c") is None:
        return False
    day = datetime.now(main.TZ).strftime("%Y-%m-%d")
    mean_temp = float(summary["forecast_mean_temp_c"])
    gdd5 = max(0.0, mean_temp - 5.0)
    with main.engine.begin() as c:
        row = c.execute(
            select(phenology_daily.c.id).where(
                phenology_daily.c.orchard == orchard_name,
                phenology_daily.c.date == day,
            )
        ).first()
        if row:
            c.execute(
                update(phenology_daily)
                .where(phenology_daily.c.id == row[0])
                .values(mean_temp_c=mean_temp, gdd5=gdd5, weather_source="kma", created_at=main.now_iso())
            )
        else:
            c.execute(insert(phenology_daily).values(
                orchard=orchard_name,
                date=day,
                mean_temp_c=mean_temp,
                gdd5=gdd5,
                weather_source="kma",
                created_at=main.now_iso(),
            ))
    return True


def _gdd_summary(orchard_name: str):
    year = datetime.now(main.TZ).year
    prefix = f"{year}-%"
    with main.engine.connect() as c:
        row = c.execute(
            select(
                func.count(phenology_daily.c.id),
                func.coalesce(func.sum(phenology_daily.c.gdd5), 0),
                func.coalesce(func.avg(phenology_daily.c.mean_temp_c), 0),
            ).where(
                phenology_daily.c.orchard == orchard_name,
                phenology_daily.c.date.like(prefix),
                phenology_daily.c.weather_source == "kma",
            )
        ).first()
    days = int(row[0] or 0)
    return {
        "base_temp_c": 5.0,
        "observed_days": days,
        "gdd5": round(float(row[1] or 0), 1),
        "observed_mean_temp_c": round(float(row[2] or 0), 1) if days else None,
        "coverage": "충분" if days >= 14 else "수집중" if days else "없음",
    }


def _adjustment(orchard: dict, month: int, forecast: dict, gdd: dict):
    reasons = []
    shift = 0

    actual_rank = _stage_rank(str(orchard.get("growth_stage") or ""))
    expected_rank = _stage_rank(MONTHLY_PLAN[month]["stage"])
    if actual_rank is not None and expected_rank is not None:
        delta = actual_rank - expected_rank
        if delta >= 2:
            shift -= 5
            reasons.append("실제 생육단계가 월 기준보다 빠름")
        elif delta == 1:
            shift -= 3
            reasons.append("실제 생육단계가 월 기준보다 약간 빠름")
        elif delta <= -2:
            shift += 5
            reasons.append("실제 생육단계가 월 기준보다 늦음")
        elif delta == -1:
            shift += 3
            reasons.append("실제 생육단계가 월 기준보다 약간 늦음")

    mean_temp = forecast.get("forecast_mean_temp_c")
    if month in range(3, 11) and mean_temp is not None:
        if mean_temp >= 27:
            shift -= 2
            reasons.append("단기 예보 평균기온이 높아 생육 진행을 앞당겨 확인")
        elif mean_temp <= 8:
            shift += 2
            reasons.append("단기 예보 평균기온이 낮아 생육 지연 가능성 반영")

    if gdd.get("observed_days", 0) >= 14:
        per_day = float(gdd.get("gdd5", 0)) / max(1, int(gdd["observed_days"]))
        if per_day >= 12:
            shift -= 1
            reasons.append("수집된 유효적산온도 증가 속도가 빠름")
        elif per_day <= 4 and month in range(3, 11):
            shift += 1
            reasons.append("수집된 유효적산온도 증가 속도가 느림")

    shift = max(-7, min(7, shift))
    if not reasons:
        reasons.append("실제 생육단계와 기상에서 큰 일정 보정 신호 없음")
    return shift, reasons


def _month_item(month: int, orchard: dict, shift: int, active: bool):
    plan = MONTHLY_PLAN[month]
    terms = [f"{day}일 전후 {name}" for day, name in SOLAR_TERMS[month]]
    varieties = [x.strip() for x in str(orchard.get("variety") or "후지").split(",") if x.strip()]
    tasks = list(plan["tasks"])
    if len(varieties) > 1:
        tasks.append(f"품종별 숙기 차이 반영: {' · '.join(varieties)}를 같은 날짜에 일괄 판단하지 않음")
    trees = int(orchard.get("tree_count") or 0)
    area = float(orchard.get("area_m2") or 0)
    if trees or area:
        scale = " · ".join([x for x in [f"{trees}주" if trees else "", f"{area:.0f}㎡" if area else ""] if x])
        tasks.append(f"{scale} 규모를 구역별로 나눠 작업 완료율 기록")
    return {
        "month": month,
        "solar_terms": terms,
        "stage": plan["stage"],
        "goal": plan["goal"],
        "tasks": tasks,
        "adjustment_days": shift if active else 0,
        "active_adjustment": active,
    }


@main.app.get("/api/annual/phenology")
def annual_phenology(orchard: str = "A과수원"):
    with main.engine.connect() as c:
        row = c.execute(select(main.orchards).where(main.orchards.c.name == orchard)).mappings().first()
    if not row:
        row = {
            "name": orchard,
            "variety": "후지",
            "area_m2": 0,
            "tree_count": 0,
            "growth_stage": "",
            "lat": None,
            "lon": None,
        }
    orchard_data = dict(row)
    forecast = _forecast_summary(orchard)
    _save_daily_temperature(orchard, forecast)
    gdd = _gdd_summary(orchard)
    now = datetime.now(main.TZ)
    shift, reasons = _adjustment(orchard_data, now.month, forecast, gdd)

    months = [
        _month_item(m, orchard_data, shift, active=(m in {now.month, (now.month % 12) + 1}))
        for m in range(1, 13)
    ]
    varieties = [x.strip() for x in str(orchard_data.get("variety") or "후지").split(",") if x.strip()]
    harvest = [f"{v} {VARIETY_HARVEST[v]}" for v in varieties if v in VARIETY_HARVEST]

    return {
        "orchard": {
            "name": orchard_data.get("name") or orchard,
            "variety": orchard_data.get("variety") or "후지",
            "varieties": varieties or ["후지"],
            "area_m2": float(orchard_data.get("area_m2") or 0),
            "tree_count": int(orchard_data.get("tree_count") or 0),
            "growth_stage": orchard_data.get("growth_stage") or "미등록",
            "lat": orchard_data.get("lat"),
            "lon": orchard_data.get("lon"),
            "harvest_hint": harvest,
        },
        "current_month": now.month,
        "current_adjustment_days": shift,
        "adjustment_reasons": reasons,
        "weather": forecast,
        "gdd": gdd,
        "months": months,
        "policy": (
            "24절기는 양력 월별 일정 안의 시기 표지로 사용합니다. 일정 보정은 등록된 실제 생육단계를 최우선으로 하고 "
            "기상청 단기예보와 앱이 실제 수집한 일평균 기온 기반 관리용 GDD(기준 5℃)를 보조 근거로 사용합니다. "
            "과거 미수집 기온은 임의로 채우지 않습니다."
        ),
    }
