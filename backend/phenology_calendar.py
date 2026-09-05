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
    1: {
        "stage": "휴면기",
        "goal": "결산·동해 점검",
        "tasks": ["전년도 수확·경영·병해충 기록 정리", "동해·수피 갈라짐·월동 해충 흔적 점검", "전정 계획과 구역별 우선순위 설정"],
        "weed": ["월동잡초 위치와 전년도 문제구역을 지도에 기록", "제초 작업보다 배수·토양상태 확인을 우선"],
        "foliar": ["휴면기 정기 엽면시비는 기본 일정에서 제외", "결핍 의심 시 토양·엽 분석 계획을 먼저 수립"],
    },
    2: {
        "stage": "휴면 후반",
        "goal": "동계전정",
        "tasks": ["동계전정과 수형 정리", "병든 가지·월동 감염원 표시", "배수로·시설·지주 점검"],
        "weed": ["월동잡초·다년생 잡초 발생 구역 예찰", "봄 1차 제초가 필요한 구역을 미리 표시"],
        "foliar": ["발아 전에는 정기 엽면시비보다 토양·수세 진단 우선", "미량원소 결핍 이력이 있는 구역만 사전 점검"],
    },
    3: {
        "stage": "발아 준비",
        "goal": "발아 전 준비",
        "tasks": ["전정 마무리와 유인·지주 점검", "눈 발달과 늦서리 위험 확인", "봄 잡초 발생초기 촬영 시작"],
        "weed": ["경칩~춘분 무렵 봄잡초 발생초기 예찰·촬영", "피복이 낮을 때 구역별 기계·수작업 제거 우선 검토", "제초제 사용 시 현재 등록사항·라벨과 강우·풍속을 확인"],
        "foliar": ["발아 전후는 엽면적이 작아 정기 엽면시비 효과가 제한적", "결핍 이력이 있으면 발아 진행과 기상 확인 후 필요성만 판단"],
    },
    4: {
        "stage": "발아·개화",
        "goal": "개화·저온 관리",
        "tasks": ["꽃눈·개화 상태 확인", "강우 뒤 초기 병반 예찰", "서리·강풍·수분 상태 확인"],
        "weed": ["청명~곡우 사이 봄 1차 잡초관리 핵심 창", "개화기 작업동선과 토양 노출을 고려해 필요한 구역만 제거"],
        "foliar": ["개화 전후는 꽃·수분에 영향을 줄 수 있어 불필요한 엽면 살포를 피함", "저온·강풍·강우 예보 시 엽면시비 보류", "붕소·아연 등은 분석·결핍근거가 있을 때만 등록된 자재 기준 확인"],
    },
    5: {
        "stage": "착과",
        "goal": "착과·적과",
        "tasks": ["착과량 확인과 적과 시작", "신초·잎·유과 병해충 예찰", "수세 편차와 영양 불균형 징후 기록"],
        "weed": ["봄 2차 재발생 잡초 확인", "군락형·전면확산 구역은 과원 바닥 경쟁이 커지기 전에 관리"],
        "foliar": ["잎이 충분히 전개된 뒤 결핍·수세·착과량 근거로 엽면시비 검토", "고온 한낮·강풍·강우 직전은 피하고 잎이 마를 시간을 확보", "정확한 자재·농도는 제품 라벨과 등록사항 확인"],
    },
    6: {
        "stage": "초기 과실비대",
        "goal": "비대·장마 대비",
        "tasks": ["적과 마무리와 유인", "장마 전 배수·토양수분 확인", "잡초·응애·과실 병반 증가속도 점검"],
        "weed": ["망종~하지 전후 초여름 잡초 재발생 관리", "장마 전에 통로·수관 하부의 과도한 잡초를 정리", "강우 직전 제초제 살포는 피하고 배수상태를 먼저 확인"],
        "foliar": ["초기 과실비대기에는 결핍 증상과 분석값을 근거로 엽면 보완 검토", "장마·고습기에는 잎 마름 시간이 부족하면 보류", "칼슘·마그네슘 등은 토양 공급과 길항관계까지 함께 점검"],
    },
    7: {
        "stage": "과실비대",
        "goal": "고온·수분 관리",
        "tasks": ["고온·가뭄·일소 위험 점검", "관수 필요성 확인", "여름잡초·탄저병·갈색무늬병 집중 예찰"],
        "weed": ["소서~대서 여름잡초 집중 관리", "왕성생육·결실 전 잡초는 종자 형성 전에 우선 제거", "고온·건조 스트레스가 심하면 과도한 토양 노출을 피함"],
        "foliar": ["고온기 엽면시비는 이른 아침·해질 무렵의 비교적 서늘한 조건에서만 검토", "수분스트레스가 있으면 관수·근권회복을 먼저 하고 엽면시비를 보류", "잎 손상·약해 가능성이 있으면 혼용하지 말고 단독 적합성 확인"],
    },
    8: {
        "stage": "착색 준비",
        "goal": "수확 전 품질관리",
        "tasks": ["과실 건전성과 착색 준비", "태풍·강풍 대비 지주 점검", "조생·중생 품종 수확 준비"],
        "weed": ["입추~처서 여름 2차 잡초관리 후보", "수확 동선과 낙과 확인에 방해되는 구역을 우선 정리", "수확이 임박한 품종 주변은 등록된 사용시기·안전사용기준을 반드시 확인"],
        "foliar": ["착색기에는 불필요한 질소성 엽면시비를 피함", "품질 목적의 보완도 분석·결핍 근거와 수확 예정일을 함께 확인", "고온·강풍·비 예보 시 살포 보류"],
    },
    9: {
        "stage": "착색·성숙",
        "goal": "수확 준비",
        "tasks": ["홍로·아리수 등 숙기별 성숙도 확인", "낙과·병반·태풍 위험 점검", "수확 동선·인력·출하 계획 정리"],
        "weed": ["백로~추분 수확 전 선택적 잡초관리", "수확 동선과 작업 안전을 해치는 구역만 우선 제거", "제초제는 품종별 수확 예정일과 안전사용기준을 충족하지 못하면 사용하지 않음"],
        "foliar": ["수확 직전 일률적 엽면시비는 하지 않음", "결핍 교정 필요성이 명확해도 수확 예정일·제품 라벨·잔류 안전성을 우선 확인", "수확 예정이 가까우면 다음 생육단계 관리로 넘길지 검토"],
    },
    10: {
        "stage": "본격 수확",
        "goal": "수확·선별·출하",
        "tasks": ["감홍·시나노골드·후지 숙기별 수확", "수확량·품질·피해과 기록", "강우·저온 전후 수확 우선순위 조정"],
        "weed": ["수확 중에는 작업동선·미끄럼·낙과 확인에 방해되는 잡초만 최소 제거", "광범위한 제초보다 수확 안전과 토양보호 우선"],
        "foliar": ["수확 중 정기 엽면시비는 기본 일정에서 제외", "수확 후 잎 기능 유지 필요성은 품종·수세·낙엽 진행을 보고 별도 판단"],
    },
    11: {
        "stage": "수확 후",
        "goal": "수확 후 정리",
        "tasks": ["후지 수확 마무리", "병든 잎·과실·잔재 정리", "수세·수확량·품질을 구역별 기록"],
        "weed": ["문제잡초·다년생 잡초 구역을 다음 해 관리지도에 기록", "종자 확산 우려 구역은 결실체 제거를 우선"],
        "foliar": ["낙엽이 빠르게 진행 중이면 엽면시비 효율이 낮으므로 중단", "수확 후 영양 보완은 토양·엽 분석과 수세를 기준으로 다음 해 계획에 반영"],
    },
    12: {
        "stage": "휴면 진입",
        "goal": "결산·다음 해 준비",
        "tasks": ["매출·비용·순이익 결산", "연간 작업·제초·병해충 기록 분석", "다음 해 전정·시비·예찰 계획 확정"],
        "weed": ["연간 제초 횟수·재발생 구역·생존잡초 이력 결산", "다음 해 봄 1차 관리 대상 구역을 확정"],
        "foliar": ["연간 엽면시비 기록과 반응을 결산", "분석 근거 없이 반복한 살포가 있었는지 점검하고 다음 해 기준을 정리"],
    },
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


def _timing_status(month: int, forecast: dict, active: bool):
    if not active:
        return {"weed": "월별 기준", "foliar": "월별 기준"}

    pop = float(forecast.get("forecast_max_rain_probability_pct") or 0)
    wind = float(forecast.get("forecast_max_wind_ms") or 0)
    mean_temp = forecast.get("forecast_mean_temp_c")
    mean_temp = float(mean_temp) if mean_temp is not None else None

    weed_status = "현장 확인 후 진행"
    foliar_status = "현장 확인 후 진행"
    if pop >= 60 or wind >= 5:
        weed_status = "살포형 제초는 보류"
        foliar_status = "엽면시비 보류"
    elif pop >= 40 or wind >= 3:
        weed_status = "기상 주의"
        foliar_status = "기상 주의"
    if mean_temp is not None and mean_temp >= 30:
        foliar_status = "고온 시간대 보류"
    return {"weed": weed_status, "foliar": foliar_status}


def _month_item(month: int, orchard: dict, shift: int, active: bool, forecast: dict):
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
    status = _timing_status(month, forecast, active)
    return {
        "month": month,
        "solar_terms": terms,
        "stage": plan["stage"],
        "goal": plan["goal"],
        "tasks": tasks,
        "weed_timing": list(plan["weed"]),
        "foliar_timing": list(plan["foliar"]),
        "weed_status": status["weed"],
        "foliar_status": status["foliar"],
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

    active_months = {now.month, (now.month % 12) + 1}
    months = [
        _month_item(m, orchard_data, shift, active=(m in active_months), forecast=forecast)
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
            "잡초 제거는 기계·수작업과 살포형 관리를 구분하며, 제초제 제품·농도·사용시기는 PSIS 등록사항과 제품 라벨을 확인해야 합니다. "
            "엽면시비는 결핍·분석·수세 근거를 우선하며 제품·농도·혼용을 자동 처방하지 않습니다. 과거 미수집 기온은 임의로 채우지 않습니다."
        ),
    }
