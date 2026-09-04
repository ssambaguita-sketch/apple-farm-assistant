from typing import List, Optional

from fastapi import HTTPException
from pydantic import BaseModel
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError

import app as main


class OrchardUpdateIn(BaseModel):
    name: str
    varieties: List[str] = []
    area_m2: float = 0
    tree_count: int = 0
    growth_stage: str = ""


def _run_secondary_update(statement):
    """Run a non-critical related-table update in its own transaction.

    PostgreSQL marks a transaction as failed after a SQL error. Keeping each
    optional cascade in a separate transaction prevents a missing/legacy
    secondary table from poisoning the orchard update transaction itself.
    """
    try:
        with main.engine.begin() as c:
            c.execute(statement)
    except Exception:
        # Secondary history data must never block editing the orchard itself.
        pass


def _cascade_orchard_name(old_name: str, new_name: str):
    """Keep orchard-linked records attached when an orchard is renamed."""
    if not old_name or old_name == new_name:
        return

    for table in (main.tasks, main.observations, main.finance):
        if "orchard" in table.c:
            _run_secondary_update(
                update(table)
                .where(table.c.orchard == old_name)
                .values(orchard=new_name)
            )

    try:
        import orchard_zones
        _run_secondary_update(
            update(orchard_zones.orchard_zones)
            .where(orchard_zones.orchard_zones.c.orchard == old_name)
            .values(orchard=new_name)
        )
    except Exception:
        pass

    try:
        import weed_intelligence
        _run_secondary_update(
            update(weed_intelligence.weed_history)
            .where(weed_intelligence.weed_history.c.orchard == old_name)
            .values(orchard=new_name)
        )
    except Exception:
        pass


@main.app.put("/api/orchards/{orchard_id}")
def update_orchard(orchard_id: int, x: OrchardUpdateIn):
    name = x.name.strip()
    if not name:
        raise HTTPException(400, "과수원 이름이 필요합니다")

    varieties = [v.strip() for v in x.varieties if v.strip()]
    variety_text = ", ".join(dict.fromkeys(varieties)) or "후지"
    old_name = ""

    try:
        # Commit the primary orchard edit first. Optional cascade failures must
        # not roll this transaction back.
        with main.engine.begin() as c:
            row = c.execute(
                select(main.orchards).where(main.orchards.c.id == orchard_id)
            ).mappings().first()
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

            old_name = str(row.get("name") or "")
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
    except HTTPException:
        raise
    except IntegrityError:
        raise HTTPException(409, "이미 존재하는 과수원 이름입니다")
    except Exception as exc:
        raise HTTPException(500, f"과수원 수정 중 서버 오류: {type(exc).__name__}")

    _cascade_orchard_name(old_name, name)

    return {
        "ok": True,
        "id": orchard_id,
        "name": name,
        "varieties": varieties or ["후지"],
        "area_m2": max(0, x.area_m2),
        "tree_count": max(0, x.tree_count),
        "growth_stage": x.growth_stage.strip(),
    }


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
    except IntegrityError:
        raise HTTPException(409, "이미 존재하는 과수원 이름입니다")
    return {"ok": True, "id": orchard_id, "name": name, "varieties": varieties or ["후지"]}
