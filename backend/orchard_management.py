from typing import List, Optional

from fastapi import HTTPException
from pydantic import BaseModel
from sqlalchemy import select, update

import app as main


class OrchardUpdateIn(BaseModel):
    name: str
    varieties: List[str] = []
    area_m2: float = 0
    tree_count: int = 0
    growth_stage: str = ""


@main.app.put("/api/orchards/{orchard_id}")
def update_orchard(orchard_id: int, x: OrchardUpdateIn):
    name = x.name.strip()
    if not name:
        raise HTTPException(400, "과수원 이름이 필요합니다")
    varieties = [v.strip() for v in x.varieties if v.strip()]
    variety_text = ", ".join(dict.fromkeys(varieties)) or "후지"
    with main.engine.begin() as c:
        row = c.execute(select(main.orchards).where(main.orchards.c.id == orchard_id)).mappings().first()
        if not row:
            raise HTTPException(404, "과수원을 찾을 수 없습니다")
        duplicate = c.execute(
            select(main.orchards.c.id).where(
                main.orchards.c.name == name,
                main.orchards.c.id != orchard_id,
            )
        ).first()
        if duplicate:
            raise HTTPException(409, "이미 존재하는 과수원 이름입니다")
        c.execute(
            update(main.orchards)
            .where(main.orchards.c.id == orchard_id)
            .values(
                name=name,
                variety=variety_text,
                area_m2=max(0, x.area_m2),
                tree_count=max(0, x.tree_count),
                growth_stage=x.growth_stage.strip(),
            )
        )
    return {"ok": True, "id": orchard_id, "name": name, "varieties": varieties or ["후지"]}


class OrchardCreateMultiIn(BaseModel):
    name: str
    varieties: List[str] = []
    area_m2: float = 0
    tree_count: int = 0
    growth_stage: str = ""
    lat: Optional[float] = None
    lon: Optional[float] = None


@main.app.post("/api/orchards/multi")
def create_multi_orchard(x: OrchardCreateMultiIn):
    name = x.name.strip()
    if not name:
        raise HTTPException(400, "과수원 이름이 필요합니다")
    varieties = [v.strip() for v in x.varieties if v.strip()]
    variety_text = ", ".join(dict.fromkeys(varieties)) or "후지"
    nx = ny = None
    if x.lat is not None and x.lon is not None:
        if not (-90 <= x.lat <= 90 and -180 <= x.lon <= 180):
            raise HTTPException(400, "유효하지 않은 위도/경도입니다")
        nx, ny = main.latlon_to_grid(x.lat, x.lon)
    try:
        with main.engine.begin() as c:
            result = c.execute(main.insert(main.orchards).values(
                name=name,
                variety=variety_text,
                area_m2=max(0, x.area_m2),
                tree_count=max(0, x.tree_count),
                growth_stage=x.growth_stage.strip(),
                lat=x.lat,
                lon=x.lon,
                nx=nx,
                ny=ny,
                created_at=main.now_iso(),
            ))
            orchard_id = result.inserted_primary_key[0]
    except main.IntegrityError:
        raise HTTPException(409, "이미 존재하는 과수원 이름입니다")
    return {"ok": True, "id": orchard_id, "name": name, "varieties": varieties or ["후지"]}
