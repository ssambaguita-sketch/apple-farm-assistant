from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, StrictBool, StrictStr, field_validator

import main


class FirstRuntimeOutput(BaseModel):
    """Fail-closed contract for the first externally observed runtime response."""

    model_config = ConfigDict(extra="forbid", strict=True)

    ok: StrictBool
    version: StrictStr
    time: StrictStr
    database: Literal["sqlite", "postgresql"]
    database_ok: StrictBool
    kma_configured: StrictBool

    @field_validator("ok")
    @classmethod
    def validate_ok(cls, value: bool) -> bool:
        if value is not True:
            raise ValueError("ok must be exactly true")
        return value

    @field_validator("time")
    @classmethod
    def validate_time(cls, value: str) -> str:
        try:
            parsed = datetime.fromisoformat(value)
        except ValueError as exc:
            raise ValueError("time must be ISO-8601") from exc
        if parsed.tzinfo is None or parsed.utcoffset() is None:
            raise ValueError("time must include timezone information")
        return value


def validate_first_runtime_output(payload: object) -> dict:
    validated = FirstRuntimeOutput.model_validate(payload, strict=True)
    if validated.version != main.app.version:
        raise ValueError(
            f"runtime version mismatch: output={validated.version!r}, app={main.app.version!r}"
        )
    return validated.model_dump()


def build_first_runtime_output() -> dict:
    """Produce the runtime payload in canonical form before any validation.

    This is deliberately the only producer used by the external /health route.
    No defaults, migrations, coercion, or field repair happen between production
    and strict validation.
    """

    database = "postgresql" if main.DATABASE_URL.startswith("postgresql") else "sqlite"
    try:
        with main.engine.connect() as connection:
            connection.execute(
                main.select(main.func.count()).select_from(main.orchards)
            ).scalar_one()
        database_ok = True
    except Exception:
        database_ok = False

    return {
        "ok": True,
        "version": main.app.version,
        "time": main.now_iso(),
        "database": database,
        "database_ok": database_ok,
        "kma_configured": bool(main.KMA_SERVICE_KEY),
    }


def first_runtime_output() -> dict:
    """Single choke point: raw producer output is validated unchanged."""

    payload = build_first_runtime_output()
    return validate_first_runtime_output(payload)


def _install_strict_health_contract() -> None:
    routes = [r for r in main.app.routes if getattr(r, "path", None) == "/health"]
    if len(routes) != 1:
        raise RuntimeError(
            f"exactly one /health route is required, found {len(routes)}"
        )

    route = routes[0]
    route.endpoint = first_runtime_output
    if getattr(route, "dependant", None) is not None:
        route.dependant.call = first_runtime_output


_install_strict_health_contract()
