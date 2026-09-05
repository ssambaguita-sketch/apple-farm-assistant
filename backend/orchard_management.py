from typing import List, Optional

from fastapi import HTTPException
from pydantic import BaseModel
from sqlalchemy import MetaData, Table, delete, inspect, select, update
from sqlalchemy.exc import IntegrityError

import main


class OrchardUpdateIn(BaseModel):
    name: str
    varieties: List[str] = []
    area_m2: float = 0
    tree_count: int = 0
    growth_stage: str = ""


class OrchardDeleteIn(BaseModel):
    confirm_name: str


def _run_secondary_update(statement):
    """Run a non-critical related-table update in its own transaction."""
    try:
        with main.engine.begin() as c:
            c.execute(statement)
    except Exception as exc:
        print(f"[orchard cascade warning] {type(exc).__name__}: {exc}")


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
    except Exception as exc:
        print(f"[orchard zones cascade warning] {type(exc).__name__}: {exc}")

    try:
        import weed_intelligence
        _run_secondary_update(
            update(weed_intelligence.weed_history)
            .where(weed_intelligence.weed_history.c.orchard == old_name)
            .values(orchard=new_name)
        )
    except Exception as exc:
        print(f"[weed cascade warning] {type(exc).__name__}: {exc}")


def _delete_linked_orchard_rows(connection, orchard_name: str):
    """Delete app records that explicitly belong to the orchard.

    Tables are reflected so newer modules that also store an `orchard` column
    are cleaned up without requiring this endpoint to know every feature table.
    The orchards table itself is intentionally excluded and removed last.
    """
    inspector = inspect(main.engine)
    metadata = MetaData()
    deleted = {}

    for table_name in inspector.get_table_names():
        if table_name == main.orchards.name:
            continue
        try:
            columns = {c["name"] for c in inspector.get_columns(table_name)}
            if "orchard" not in columns:
                continue
            table = Table(table_name, metadata, autoload_with=connection)
            result = connection.execute(delete(table).where(table.c.orchard == orchard_name))
            deleted[table_name] = max(0, int(result.rowcount or 0))
        except Exception as exc:
            print(f"[orchard linked delete warning] {table_name}: {type(exc).__name__}: {exc}")
            raise HTTPException(500, f"연결 데이터 정리 중 오류가 발생했습니다: {table_name}")

    return deleted


@main.app.put("/api/orchards/{orchard_id}")
def update_orchard(orchard_id: int, x: OrchardUpdateIn):
    name = x.name.strip()
    if not name:
        raise HTTPException(400, "과수원 이름이 필요합니다")

    varieties = [v.strip() for v in x.varieties if v.strip()]
    variety_text = ", ".join(dict.fromkeys(varieties)) or "후지"
    old_name = ""

    try:
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
        print(f"[orchard update error] {type(exc).__name__}: {exc}")
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


@main.app.delete("/api/orchards/{orchard_id}")
def delete_orchard(orchard_id: int, x: OrchardDeleteIn):
    """Permanently delete one orchard after an exact-name confirmation.

    At least one orchard must remain so the app always has a valid selection.
    All feature rows carrying the same `orchard` value are deleted in the same
    transaction before the orchard row itself is removed.
    """
    confirm_name = x.confirm_name.strip()
    try:
        with main.engine.begin() as c:
            row = c.execute(
                select(main.orchards).where(main.orchards.c.id == orchard_id)
            ).mappings().first()
            if not row:
                raise HTTPException(404, "과수원을 찾을 수 없습니다")

            orchard_name = str(row.get("name") or "")
            if not confirm_name or confirm_name != orchard_name:
                raise HTTPException(400, "삭제 확인용 과수원 이름이 일치하지 않습니다")

            orchard_count = c.execute(select(main.orchards.c.id)).all()
            if len(orchard_count) <= 1:
                raise HTTPException(409, "마지막 과수원은 삭제할 수 없습니다. 다른 과수원을 먼저 추가하세요")

            linked_deleted = _delete_linked_orchard_rows(c, orchard_name)
            c.execute(delete(main.orchards).where(main.orchards.c.id == orchard_id))

            next_row = c.execute(
                select(main.orchards).order_by(main.orchards.c.id.asc()).limit(1)
            ).mappings().first()

        return {
            "ok": True,
            "deleted_id": orchard_id,
            "deleted_name": orchard_name,
            "linked_deleted": linked_deleted,
            "next_orchard": dict(next_row) if next_row else None,
        }
    except HTTPException:
        raise
    except Exception as exc:
        print(f"[orchard delete error] {type(exc).__name__}: {exc}")
        raise HTTPException(500, f"과수원 삭제 중 서버 오류: {type(exc).__name__}")


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
    except Exception as exc:
        print(f"[orchard create error] {type(exc).__name__}: {exc}")
        raise HTTPException(500, f"과수원 생성 중 서버 오류: {type(exc).__name__}")
    return {"ok": True, "id": orchard_id, "name": name, "varieties": varieties or ["후지"]}
