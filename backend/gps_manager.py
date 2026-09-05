from fastapi import HTTPException
from pydantic import BaseModel
from sqlalchemy import select, update

import main


class GpsSaveIn(BaseModel):
    orchard: str
    lat: float
    lon: float


def _read_location(name: str):
    with main.engine.connect() as c:
        row = c.execute(
            select(
                main.orchards.c.id,
                main.orchards.c.name,
                main.orchards.c.lat,
                main.orchards.c.lon,
                main.orchards.c.nx,
                main.orchards.c.ny,
            ).where(main.orchards.c.name == name)
        ).mappings().first()
    return dict(row) if row else None


@main.app.get('/api/gps/status')
def gps_status(orchard: str):
    name = orchard.strip()
    if not name:
        raise HTTPException(400, '과수원 이름이 필요합니다')
    row = _read_location(name)
    if not row:
        raise HTTPException(404, '등록된 과수원을 찾을 수 없습니다')
    return {
        'ok': True,
        'orchard': name,
        'saved': row.get('lat') is not None and row.get('lon') is not None,
        'lat': row.get('lat'),
        'lon': row.get('lon'),
        'nx': row.get('nx'),
        'ny': row.get('ny'),
    }


@main.app.post('/api/gps/save')
def gps_save(x: GpsSaveIn):
    name = x.orchard.strip()
    if not name:
        raise HTTPException(400, '과수원 이름이 필요합니다')
    if not (-90 <= x.lat <= 90 and -180 <= x.lon <= 180):
        raise HTTPException(400, '유효하지 않은 위도/경도입니다')

    before = _read_location(name)
    if not before:
        # GPS 저장이 오타로 새 과수원을 만들어버리지 않도록 명시적으로 실패시킨다.
        raise HTTPException(404, f"'{name}' 과수원이 등록되어 있지 않습니다")

    nx, ny = main.latlon_to_grid(float(x.lat), float(x.lon))
    with main.engine.begin() as c:
        result = c.execute(
            update(main.orchards)
            .where(main.orchards.c.name == name)
            .values(lat=float(x.lat), lon=float(x.lon), nx=nx, ny=ny)
        )
        if result.rowcount != 1:
            raise HTTPException(500, 'GPS DB 업데이트 행 수가 올바르지 않습니다')

    saved = _read_location(name)
    if not saved:
        raise HTTPException(500, 'GPS 저장 후 과수원 재조회에 실패했습니다')

    lat_ok = saved.get('lat') is not None and abs(float(saved['lat']) - float(x.lat)) < 0.000001
    lon_ok = saved.get('lon') is not None and abs(float(saved['lon']) - float(x.lon)) < 0.000001
    if not (lat_ok and lon_ok):
        raise HTTPException(500, 'GPS 저장 후 DB 검증값이 일치하지 않습니다')

    return {
        'ok': True,
        'verified': True,
        'orchard': name,
        'lat': saved['lat'],
        'lon': saved['lon'],
        'nx': saved['nx'],
        'ny': saved['ny'],
    }


app = main.app
