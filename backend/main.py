import os
import re
import sqlite3
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from typing import Optional

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

TZ = ZoneInfo("Asia/Seoul")
DB_PATH = os.getenv("APPLE_FARM_DB", "/tmp/apple_farm.db")
KMA_SERVICE_KEY = os.getenv("KMA_SERVICE_KEY", "")
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")

app = FastAPI(title="Apple Farm Assistant API", version="3.0.0")


def now_iso() -> str:
    return datetime.now(TZ).isoformat(timespec="seconds")


def conn():
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    return c


def init_db():
    c = conn()
    c.executescript(
        """
        CREATE TABLE IF NOT EXISTS orchards(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            variety TEXT DEFAULT '후지',
            area_m2 REAL DEFAULT 0,
            tree_count INTEGER DEFAULT 0,
            growth_stage TEXT DEFAULT '',
            lat REAL, lon REAL, nx INTEGER, ny INTEGER,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            orchard TEXT NOT NULL,
            title TEXT NOT NULL,
            category TEXT DEFAULT '일반',
            priority INTEGER DEFAULT 2,
            scheduled_at TEXT,
            status TEXT DEFAULT '예정',
            notified INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            completed_at TEXT
        );
        CREATE TABLE IF NOT EXISTS observations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            orchard TEXT NOT NULL,
            category TEXT NOT NULL,
            risk INTEGER DEFAULT 1,
            note TEXT DEFAULT '',
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS finance(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            orchard TEXT NOT NULL,
            type TEXT NOT NULL,
            category TEXT DEFAULT '',
            amount REAL DEFAULT 0,
            quantity_kg REAL DEFAULT 0,
            note TEXT DEFAULT '',
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS work_events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_type TEXT DEFAULT '',
            hour INTEGER NOT NULL,
            duration_min INTEGER DEFAULT 0,
            completed INTEGER DEFAULT 1,
            effort INTEGER DEFAULT 3,
            created_at TEXT NOT NULL
        );
        """
    )
    c.commit()
    c.close()


@app.on_event("startup")
def startup():
    init_db()


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
    return {"ok": True, "version": "3.0.0", "time": now_iso()}


@app.get("/api/orchards")
def list_orchards():
    c = conn(); rows = c.execute("SELECT * FROM orchards ORDER BY id DESC").fetchall(); c.close()
    return [dict(r) for r in rows]


@app.post("/api/orchards")
def add_orchard(x: OrchardIn):
    c = conn()
    try:
        c.execute("INSERT INTO orchards(name,variety,area_m2,tree_count,growth_stage,lat,lon,nx,ny,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
                  (x.name,x.variety,x.area_m2,x.tree_count,x.growth_stage,x.lat,x.lon,x.nx,x.ny,now_iso()))
        c.commit()
    except sqlite3.IntegrityError:
        raise HTTPException(409, "이미 존재하는 과수원 이름입니다")
    finally:
        c.close()
    return {"ok": True}


@app.post("/api/tasks")
def add_task(x: TaskIn):
    c = conn(); cur = c.execute("INSERT INTO tasks(orchard,title,category,priority,scheduled_at,status,notified,created_at) VALUES(?,?,?,?,?,'예정',0,?)",
        (x.orchard,x.title,x.category,x.priority,x.scheduled_at,now_iso())); c.commit(); task_id=cur.lastrowid; c.close()
    return {"ok": True, "id": task_id}


@app.get("/api/tasks")
def list_tasks(orchard: Optional[str] = None):
    c=conn()
    if orchard:
        rows=c.execute("SELECT * FROM tasks WHERE orchard=? ORDER BY priority DESC, scheduled_at",(orchard,)).fetchall()
    else:
        rows=c.execute("SELECT * FROM tasks ORDER BY priority DESC, scheduled_at").fetchall()
    c.close(); return [dict(r) for r in rows]


@app.post("/api/tasks/{task_id}/complete")
def complete_task(task_id: int):
    c=conn(); c.execute("UPDATE tasks SET status='완료', completed_at=? WHERE id=?",(now_iso(),task_id)); c.commit(); c.close(); return {"ok":True}


@app.post("/api/observations")
def add_observation(x: ObsIn):
    c=conn(); c.execute("INSERT INTO observations(orchard,category,risk,note,created_at) VALUES(?,?,?,?,?)",(x.orchard,x.category,max(0,min(5,x.risk)),x.note,now_iso())); c.commit(); c.close(); return {"ok":True}


@app.post("/api/finance")
def add_finance(x: FinanceIn):
    if x.type not in {"revenue","expense"}:
        raise HTTPException(400, "type은 revenue 또는 expense여야 합니다")
    c=conn(); c.execute("INSERT INTO finance(orchard,type,category,amount,quantity_kg,note,created_at) VALUES(?,?,?,?,?,?,?)",(x.orchard,x.type,x.category,x.amount,x.quantity_kg,x.note,now_iso())); c.commit(); c.close(); return {"ok":True}


@app.post("/api/coach/work")
def add_work(x: WorkIn):
    c=conn(); c.execute("INSERT INTO work_events(task_type,hour,duration_min,completed,effort,created_at) VALUES(?,?,?,?,?,?)",(x.task_type,max(0,min(23,x.hour)),x.duration_min,1 if x.completed else 0,max(1,min(5,x.effort)),now_iso())); c.commit(); c.close(); return {"ok":True}


@app.get("/api/coach")
def coach():
    c=conn(); rows=c.execute("SELECT hour, COUNT(*) samples, AVG(completed) completion, AVG(effort) effort FROM work_events GROUP BY hour").fetchall(); c.close()
    best=[]
    for r in rows:
        completion=float(r["completion"] or 0)
        effort=float(r["effort"] or 3)
        score=round(completion*70 + ((6-effort)/5)*30,1)
        best.append({"hour":r["hour"],"samples":r["samples"],"score":score})
    if not best:
        best=[{"hour":8,"samples":0,"score":82.0},{"hour":9,"samples":0,"score":80.0},{"hour":16,"samples":0,"score":76.0}]
    best.sort(key=lambda x:x["score"], reverse=True)
    return {"best_hours":best[:5],"policy":"작업기록·체감난이도만 사용; 생체정보 추론 없음"}


@app.post("/api/weeds/survivor-advice")
def survivor_advice(x: WeedAdviceIn):
    causes=[]
    if x.days_after < 3:
        causes.append("처리 후 효과가 충분히 나타나기 전일 수 있음")
    if x.weather_issue != "없음":
        causes.append("처리 전후 기상조건 영향 가능성")
    if x.coverage_issue != "없음":
        causes.append("약액 도달·살포 균일성 문제 가능성")
    if x.growth_stage in {"왕성생육","성숙","개화","결실"}:
        causes.append("잡초가 커진 뒤 처리되어 방제 난도가 높았을 가능성")
    if x.repeated_mode:
        causes.append("같은 작용기작 반복 사용에 따른 감수성 저하 가능성")
    if not causes:
        causes.append("잡초 종류 오인 또는 처리조건 불일치 가능성")
    actions=[
        "남은 잡초의 잎·줄기·생육형을 다시 확인해 잡초를 재동정하세요.",
        "처리 당시 강우·풍속·고온 여부와 노즐 막힘·압력·사각지대를 점검하세요.",
        "농촌진흥청 PSIS에서 사과에 등록된 제초제인지, 해당 잡초와 사용시기·횟수·작용기작을 확인하세요.",
        "등록 범위 안에서 동일 작용기작의 연속 반복을 피하고, 예초·멀칭 같은 비화학적 방법을 함께 고려하세요.",
        "임의 증량이나 짧은 간격의 재살포는 하지 말고 제품 라벨의 안전사용기준을 따르세요."
    ]
    return {"possible_causes":causes,"actions":actions}


@app.get("/api/dashboard")
def dashboard(orchard: str = "A과수원"):
    c=conn()
    tasks=[dict(r) for r in c.execute("SELECT * FROM tasks WHERE orchard=? AND status='예정' ORDER BY priority DESC, scheduled_at LIMIT 5",(orchard,)).fetchall()]
    obs=[dict(r) for r in c.execute("SELECT * FROM observations WHERE orchard=? ORDER BY id DESC LIMIT 10",(orchard,)).fetchall()]
    rev=c.execute("SELECT COALESCE(SUM(amount),0) v FROM finance WHERE orchard=? AND type='revenue'",(orchard,)).fetchone()["v"]
    exp=c.execute("SELECT COALESCE(SUM(amount),0) v FROM finance WHERE orchard=? AND type='expense'",(orchard,)).fetchone()["v"]
    c.close()
    risk_score=sum(int(o.get("risk",0)) for o in obs)
    weather=demo_weather()
    best=sorted([work_score(w) for w in weather], key=lambda x:x["score"], reverse=True)[:5]
    return {"orchard":orchard,"risk_score":risk_score,"profit":round(float(rev)-float(exp),0),"tasks":tasks,"observations":obs,"best_work_times":best,"weather_source":"demo","server_time":now_iso()}
