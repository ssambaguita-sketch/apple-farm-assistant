import time
import threading

import main

_CACHE_TTL_SECONDS = 300
_cache = {}
_lock = threading.Lock()
_original_orchard_weather = main.orchard_weather


def cached_orchard_weather(orchard_name: str):
    key = orchard_name.strip() or "A과수원"
    now = time.monotonic()
    with _lock:
        item = _cache.get(key)
        if item and now - item[0] < _CACHE_TTL_SECONDS:
            return item[1]
    result = _original_orchard_weather(key)
    with _lock:
        _cache[key] = (now, result)
    return result


main.orchard_weather = cached_orchard_weather


@main.app.get("/api/performance")
def performance_status():
    with _lock:
        active = len(_cache)
    return {
        "ok": True,
        "weather_cache_ttl_seconds": _CACHE_TTL_SECONDS,
        "cached_orchards": active,
        "policy": "날씨 조회만 짧게 캐시하며 작업·경영·관찰 데이터는 실시간 DB 조회를 유지합니다.",
    }
