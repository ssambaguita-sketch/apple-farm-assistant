from typing import Optional

from fastapi import HTTPException
from pydantic import BaseModel
from sqlalchemy import Table, Column, Integer, Float, String, select, insert, update, delete

import main


orchard_zones = Table(
    "orchard_zones",
    main.metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("orchard", String(120), nullable=False, index=True),
    Column("zone_name", String(120), nullable=False),
    Column("variety", String(80), nullable=False),
    Column("tree_count", Integer, default=0),
    Column("area_m2", Float, default=0),
    Column("growth_stage", String(120), default=""),
    Column("note", String(240), default=""),
    Column("created_at", String(40), nullable=False),
)


class ZoneIn(BaseModel):
    orchard: str
    zone_name: str
    variety: str
    tree_count: int = 0
    area_m2: float = 0
    growth_stage: str = ""
    note: str = ""


class ZoneUpdateIn(BaseModel):
    zone_name: str
    variety: str
    tree_count: int = 0
    area_m2: float = 0
    growth_stage: str = ""
    note: str = ""


def _clean_zone_values(zone_name: str, variety: str):
    zone = zone_name.strip()
    variety = variety.strip()
    if not zone:
        raise HTTPException(400, "구역 이름이 필요합니다")
    if not variety:
        raise HTTPException(400, "품종이 필요합니다")
    return zone, variety


@main.app.get("/api/orchard-zones")
def list_orchard_zones(orchard: str):
    name = orchard.strip()
    with main.engine.connect() as c:
        rows = c.execute(
            select(orchard_zones)
            .where(orchard_zones.c.orchard == name)
            .order_by(orchard_zones.c.zone_name, orchard_zones.c.id)
        ).mappings().all()
    return [dict(r) for r in rows]


@main.app.post("/api/orchard-zones")
def create_orchard_zone(x: ZoneIn):
    orchard = x.orchard.strip()
    zone, variety = _clean_zone_values(x.zone_name, x.variety)
    if not orchard:
        raise HTTPException(400, "과수원 이름이 필요합니다")
    with main.engine.begin() as c:
        orchard_exists = c.execute(select(main.orchards.c.id).where(main.orchards.c.name == orchard)).first()
        if not orchard_exists:
            raise HTTPException(404, "등록된 과수원을 찾을 수 없습니다")
        duplicate = c.execute(
            select(orchard_zones.c.id).where(
                orchard_zones.c.orchard == orchard,
                orchard_zones.c.zone_name == zone,
            )
        ).first()
        if duplicate:
            raise HTTPException(409, "같은 이름의 구역이 이미 있습니다")
        result = c.execute(insert(orchard_zones).values(
            orchard=orchard,
            zone_name=zone,
            variety=variety,
            tree_count=max(0, x.tree_count),
            area_m2=max(0, x.area_m2),
            growth_stage=x.growth_stage.strip(),
            note=x.note.strip(),
            created_at=main.now_iso(),
        ))
        zone_id = result.inserted_primary_key[0]
    return {"ok": True, "id": zone_id}


@main.app.put("/api/orchard-zones/{zone_id}")
def update_orchard_zone(zone_id: int, x: ZoneUpdateIn):
    zone, variety = _clean_zone_values(x.zone_name, x.variety)
    with main.engine.begin() as c:
        current = c.execute(select(orchard_zones).where(orchard_zones.c.id == zone_id)).mappings().first()
        if not current:
            raise HTTPException(404, "구역을 찾을 수 없습니다")
        duplicate = c.execute(
            select(orchard_zones.c.id).where(
                orchard_zones.c.orchard == current["orchard"],
                orchard_zones.c.zone_name == zone,
                orchard_zones.c.id != zone_id,
            )
        ).first()
        if duplicate:
            raise HTTPException(409, "같은 이름의 구역이 이미 있습니다")
        c.execute(update(orchard_zones).where(orchard_zones.c.id == zone_id).values(
            zone_name=zone,
            variety=variety,
            tree_count=max(0, x.tree_count),
            area_m2=max(0, x.area_m2),
            growth_stage=x.growth_stage.strip(),
            note=x.note.strip(),
        ))
    return {"ok": True, "id": zone_id}


@main.app.delete("/api/orchard-zones/{zone_id}")
def delete_orchard_zone(zone_id: int):
    with main.engine.begin() as c:
        result = c.execute(delete(orchard_zones).where(orchard_zones.c.id == zone_id))
    if result.rowcount == 0:
        raise HTTPException(404, "구역을 찾을 수 없습니다")
    return {"ok": True}


def zone_targets_for_orchard(orchard_name: str):
    try:
        with main.engine.connect() as c:
            rows = c.execute(
                select(orchard_zones).where(orchard_zones.c.orchard == orchard_name)
            ).mappings().all()
        return [dict(r) for r in rows]
    except Exception:
        return []
