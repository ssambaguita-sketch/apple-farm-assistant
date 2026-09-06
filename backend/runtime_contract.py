from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, StrictBool, StrictStr, field_validator

import main


class FirstRuntimeOutput(BaseModel):
    """Fail-closed contract for the first externally observed runtime response."""

    model_config = ConfigDict(extra="forbid", strict=True)

    ok: Literal[True]
    version: StrictStr
    time: StrictStr
    database: Literal["sqlite", "postgresql"]
    database_ok: StrictBool
    kma_configured: StrictBool

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


def _install_strict_health_contract() -> None:
    route = next(
        (r for r in main.app.routes if getattr(r, "path", None) == "/health"),
        None,
    )
    if route is None:
        raise RuntimeError("/health route is required for runtime contract validation")

    original_health = route.endpoint

    def strict_health():
        payload = original_health()
        if not isinstance(payload, dict):
            raise RuntimeError("/health must return a JSON object")

        # main.py historically hard-coded an older version. The runtime contract
        # uses the actual FastAPI application version set by start.py.
        candidate = {**payload, "version": main.app.version}
        return validate_first_runtime_output(candidate)

    route.endpoint = strict_health
    if getattr(route, "dependant", None) is not None:
        route.dependant.call = strict_health


_install_strict_health_contract()
