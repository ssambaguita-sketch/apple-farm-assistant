import os
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy import (
    create_engine, MetaData, Table, Column, Integer, Float, String, Text,
    select, insert, update, func, desc
)
from sqlalchemy.exc import IntegrityError

TZ = ZoneInfo("Asia/Seoul")
DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = "postgresql://" + DATABASE_URL[len("postgres://"):]
if not DATABASE_URL:
    DATABASE_URL = "sqlite:////tmp/apple_farm.db"

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    connect_args={"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {},
)
metadata = MetaData()

orchards = Table(
    "orchards", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("name", String(120), nullable=False, unique=True),
    Column("variety", String(80), default="후지"),
    Column("area_m2", Float, default=0),
    Column("tree_count", Integer, default=0),
    Column("growth_stage", String(120), default=""),
    Column("lat", Float), Column("lon", Float),
    Column("nx", Integer), Column("ny", Integer),
    Column("created_at", String(40), nullable=False),
)

tasks = Table(
    "tasks", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("orchard", String(120), nullable=False),
    Column("title", String(200), nullable=False),
    Column("category", String(80), default="일반"),
    Column("priority", Integer, default=2),
    Column("scheduled_at", String(60)),
    Column("status", String(40), default="예정"),
    Column("notified", Integer, default=0),
    Column("created_at", String(40), nullable=False),
    Column("completed_at", String(40)),
)

observations = Table(
    "observations", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("orchard", String(120), nullable=False),
    Column("category", String(100), nullable=False),
    Column("risk", Integer, default=1),
    Column("note", Text, default=""),
    Column("created_at", String(40), nullable=False),
)

finance = Table(
    "finance", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("orchard", String(120), nullable=False),
    Column("type", String(30), nullable=False),
    Column("category", String(100), default=""),
    Column("amount", Float, default=0),
    Column("quantity_kg", Float, default=0),
    Column("note", Text, default=""),
    Column("created_at", String(40), nullable=False),
)

work_events = Table(
    "work_events", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("task_type", String(100), default=""),
    Column("hour", Integer, nullable=False),
    Column("duration_min", Integer, default=0),
    Column("completed", Integer, default=1),
    Column("effort", Integer, default=3),
    Column("created_at", String(40), nullable=False),
)

app = FastAPI(title="Apple Farm Assistant API", version="4.0.0")


def now_iso() -> str:
    return datetime.now(TZ).isoformat(timespec="seconds")


@app.on_event("startup")
def startup():
    metadata.create_all(engine)


class OrchardIn(BaseModel):
    name: str
    variety: str = "후지"
    area_m2: float = 0
    tree_count: int = 0
    growth_stage: str = ""
    lat: Optional[float] = None
    lon: Optional[float] = None
    nx: Optional[int] = None
    ny: Optional[int] = None


class TaskIn(BaseModel):
    orchard: str
    title: str
    category: str = "일반"
    priority: int = 2
    scheduled_at: Optional[str] = None


class ObsIn(BaseModel):
    orchard: str
    category: str
    risk: int = 1
    note: str = ""


class FinanceIn(BaseModel):
    orchard: str
    type: str
    category: str = ""
    amount: float = 0
    quantity_kg: float = 0
    note: str = ""


class WorkIn(BaseModel):
    task_type: str = ""
    hour: int
    duration_min: int = 0
    completed: bool = True
    effort: int = 3


class WeedAdviceIn(BaseModel):
    orchard: str = "A과수원"
    weed_type: str = "미상 잡초"
    days_after: int = 7
    survival: str = "높음"
    growth_stage: str = "왕성생육"
    weather_issue: str = "없음"
    coverage_issue: str = "없음"
    repeated_mode: bool = False


def demo_weather():
    base = datetime.now(TZ).replace(minute=0, second=0, microsecond=0)
    out = []
    for i in range(12):
        t = base + timedelta(hours=i)
        out.append({
            "time": t.strftime("%m-%d %H:%M"),
            "temp": 22 + (i % 5),
            "humidity": 65,
            "wind": 1.8 + (i % 3) * 0.4,
            "rain_probability": 10 if i < 6 else 20,
            "rain": 0.0,
        })
    return out


def work_score(w):
    score = 100
    pop = float(w.get("rain_probability", 0) or 0)
    rain = float(w.get("rain", 0) or 0)
    wind = float(w.get("wind", 0) or 0)
    temp = float(w.get("temp", 0) or 0)
    hum = float(w.get("humidity", 0) or 0)
    if pop >= 60 or rain >= 3:
        score -= 50
    elif pop >= 30:
        score -= 20
    if wind >= 5:
        score -= 45
    elif wind >= 3:
        score -= 15
    if temp >= 32:
        score -= 15
    if hum >= 90:
        score -= 10
    score = max(0, score)
    grade = "적합" if score >= 80 else "주의" if score >= 60 else "부적합"
    return {**w, "score": score, "grade": grade}


@app.get("/")
def root():
    return {"service": "apple-farm-assistant", "ok": True, "time": now_iso()}


@app.get("/health")
def health():
    db_kind = "postgresql" if DATABASE_URL.startswith("postgresql") else "sqlite"
    try:
        with engine.connect() as c:
            c.execute(select(func.count()).select_from(orchards)).scalar_one()
        db_ok = True
    except Exception:
        db_ok = False
    return {"ok": True, "version": "4.0.0", "time": now_iso(), "database": db_kind, "database_ok": db_ok}


@app.get("/api/orchards")
def list_orchards():
    with engine.connect() as c:
        rows = c.execute(select(orchards).order_by(desc(orchards.c.id))).mappings().all()
    return [dict(r) for r in rows]


@app.post("/api/orchards")
def add_orchard(x: OrchardIn):
    try:
        with engine.begin() as c:
            c.execute(insert(orchards).values(
                name=x.name, variety=x.variety, area_m2=x.area_m2,
                tree_count=x.tree_count, growth_stage=x.growth_stage,
                lat=x.lat, lon=x.lon, nx=x.nx, ny=x.ny, created_at=now_iso()
            ))
    except IntegrityError:
        raise HTTPException(409, "이미 존재하는 과수원 이름입니다")
    return {"ok": True}


@app.post("/api/tasks")
def add_task(x: TaskIn):
    with engine.begin() as c:
        result = c.execute(insert(tasks).values(
            orchard=x.orchard, title=x.title, category=x.category,
            priority=x.priority, scheduled_at=x.scheduled_at,
            status="예정", notified=0, created_at=now_iso()
        ))
        task_id = result.inserted_primary_key[0]
    return {"ok": True, "id": task_id}


@app.get("/api/tasks")
def list_tasks(orchard: Optional[str] = None):
    q = select(tasks)
    if orchard:
        q = q.where(tasks.c.orchard == orchard)
    q = q.order_by(desc(tasks.c.priority), tasks.c.scheduled_at)
    with engine.connect() as c:
        rows = c.execute(q).mappings().all()
    return [dict(r) for r in rows]


@app.post("/api/tasks/{task_id}/complete")
def complete_task(task_id: int):
    with engine.begin() as c:
        c.execute(update(tasks).where(tasks.c.id == task_id).values(status="완료", completed_at=now_iso()))
    return {"ok": True}


@app.post("/api/observations")
def add_observation(x: ObsIn):
    with engine.begin() as c:
        c.execute(insert(observations).values(
            orchard=x.orchard, category=x.category,
            risk=max(0, min(5, x.risk)), note=x.note, created_at=now_iso()
        ))
    return {"ok": True}


@app.post("/api/finance")
def add_finance(x: FinanceIn):
    if x.type not in {"revenue", "expense"}:
        raise HTTPException(400, "type은 revenue 또는 expense여야 합니다")
    with engine.begin() as c:
        c.execute(insert(finance).values(
            orchard=x.orchard, type=x.type, category=x.category,
            amount=x.amount, quantity_kg=x.quantity_kg,
            note=x.note, created_at=now_iso()
        ))
    return {"ok": True}


@app.post("/api/coach/work")
def add_work(x: WorkIn):
    with engine.begin() as c:
        c.execute(insert(work_events).values(
            task_type=x.task_type, hour=max(0, min(23, x.hour)),
            duration_min=x.duration_min, completed=1 if x.completed else 0,
            effort=max(1, min(5, x.effort)), created_at=now_iso()
        ))
    return {"ok": True}


@app.get("/api/coach")
def coach():
    q = select(
        work_events.c.hour,
        func.count().label("samples"),
        func.avg(work_events.c.completed).label("completion"),
        func.avg(work_events.c.effort).label("effort"),
    ).group_by(work_events.c.hour)
    with engine.connect() as c:
        rows = c.execute(q).mappings().all()
    best = []
    for r in rows:
        completion = float(r["completion"] or 0)
        effort = float(r["effort"] or 3)
        score = round(completion * 70 + ((6 - effort) / 5) * 30, 1)
        best.append({"hour": r["hour"], "samples": r["samples"], "score": score})
    if not best:
        best = [
            {"hour": 8, "samples": 0, "score": 82.0},
            {"hour": 9, "samples": 0, "score": 80.0},
            {"hour": 16, "samples": 0, "score": 76.0},
        ]
    best.sort(key=lambda x: x["score"], reverse=True)
    return {"best_hours": best[:5], "policy": "작업기록·체감난이도만 사용; 생체정보 추론 없음"}


@app.post("/api/weeds/survivor-advice")
def survivor_advice(x: WeedAdviceIn):
    causes = []
    if x.days_after < 3:
        causes.append("처리 후 효과가 충분히 나타나기 전일 수 있음")
    if x.weather_issue != "없음":
        causes.append("처리 전후 기상조건 영향 가능성")
    if x.coverage_issue != "없음":
        causes.append("약액 도달·살포 균일성 문제 가능성")
    if x.growth_stage in {"왕성생육", "성숙", "개화", "결실"}:
        causes.append("잡초가 커진 뒤 처리되어 방제 난도가 높았을 가능성")
    if x.repeated_mode:
        causes.append("같은 작용기작 반복 사용에 따른 감수성 저하 가능성")
    if not causes:
        causes.append("잡초 종류 오인 또는 처리조건 불일치 가능성")
    actions = [
        "남은 잡초의 잎·줄기·생육형을 다시 확인해 잡초를 재동정하세요.",
        "처리 당시 강우·풍속·고온 여부와 노즐 막힘·압력·사각지대를 점검하세요.",
        "농촌진흥청 PSIS에서 사과에 등록된 제초제인지, 해당 잡초와 사용시기·횟수·작용기작을 확인하세요.",
        "등록 범위 안에서 동일 작용기작의 연속 반복을 피하고, 예초·멀칭 같은 비화학적 방법을 함께 고려하세요.",
        "임의 증량이나 짧은 간격의 재살포는 하지 말고 제품 라벨의 안전사용기준을 따르세요.",
    ]
    return {"possible_causes": causes, "actions": actions}


@app.get("/api/dashboard")
def dashboard(orchard: str = "A과수원"):
    with engine.connect() as c:
        task_rows = c.execute(
            select(tasks)
            .where(tasks.c.orchard == orchard, tasks.c.status == "예정")
            .order_by(desc(tasks.c.priority), tasks.c.scheduled_at)
            .limit(5)
        ).mappings().all()
        obs_rows = c.execute(
            select(observations)
            .where(observations.c.orchard == orchard)
            .order_by(desc(observations.c.id))
            .limit(10)
        ).mappings().all()
        rev = c.execute(select(func.coalesce(func.sum(finance.c.amount), 0)).where(
            finance.c.orchard == orchard, finance.c.type == "revenue"
        )).scalar_one()
        exp = c.execute(select(func.coalesce(func.sum(finance.c.amount), 0)).where(
            finance.c.orchard == orchard, finance.c.type == "expense"
        )).scalar_one()
    task_list = [dict(r) for r in task_rows]
    obs_list = [dict(r) for r in obs_rows]
    risk_score = sum(int(o.get("risk", 0)) for o in obs_list)
    weather = demo_weather()
    best = sorted([work_score(w) for w in weather], key=lambda x: x["score"], reverse=True)[:5]
    return {
        "orchard": orchard,
        "risk_score": risk_score,
        "profit": round(float(rev) - float(exp), 0),
        "tasks": task_list,
        "observations": obs_list,
        "best_work_times": best,
        "weather_source": "demo",
        "server_time": now_iso(),
        "database": "postgresql" if DATABASE_URL.startswith("postgresql") else "sqlite",
    }
