import os
import tempfile

from fastapi.testclient import TestClient
from pydantic import ValidationError


def _expect_rejected(validate, payload, expected_exception=(ValidationError, ValueError)):
    try:
        validate(payload)
    except expected_exception:
        return
    raise AssertionError(f"strict runtime contract unexpectedly accepted: {payload!r}")


def run():
    db_file = tempfile.NamedTemporaryFile(
        prefix="apple-first-runtime-", suffix=".db", delete=False
    )
    db_file.close()
    os.environ["DATABASE_URL"] = f"sqlite:///{db_file.name}"
    os.environ.pop("KMA_SERVICE_KEY", None)

    import start
    import runtime_contract

    # The external runtime output must have exactly one route and that route must
    # terminate at the strict producer+validator choke point.
    health_routes = [
        route for route in start.app.routes if getattr(route, "path", None) == "/health"
    ]
    assert len(health_routes) == 1
    health_route = health_routes[0]
    assert health_route.endpoint is runtime_contract.first_runtime_output
    assert health_route.dependant.call is runtime_contract.first_runtime_output

    # Producer output is validated unchanged: no migration/default/repair layer.
    raw_produced = runtime_contract.build_first_runtime_output()
    validated_produced = runtime_contract.validate_first_runtime_output(raw_produced)
    assert validated_produced == raw_produced

    with TestClient(start.app) as client:
        response = client.get("/health")

    assert response.status_code == 200, response.text
    first_runtime_output = response.json()

    # Positive contract: exact keys, strict primitive types, timezone-aware ISO time,
    # and the version actually running in start.app.
    assert set(first_runtime_output) == {
        "ok",
        "version",
        "time",
        "database",
        "database_ok",
        "kma_configured",
    }
    assert first_runtime_output["ok"] is True
    assert type(first_runtime_output["version"]) is str
    assert first_runtime_output["version"] == start.app.version == "6.0.0"
    assert type(first_runtime_output["time"]) is str
    assert first_runtime_output["database"] == "sqlite"
    assert type(first_runtime_output["database_ok"]) is bool
    assert first_runtime_output["database_ok"] is True
    assert type(first_runtime_output["kma_configured"]) is bool
    assert first_runtime_output["kma_configured"] is False

    validated = runtime_contract.validate_first_runtime_output(first_runtime_output)
    assert validated == first_runtime_output

    # Negative matrix: fail closed. No coercion, defaults, unknown fields,
    # stale versions, malformed timestamps, or missing fields are accepted.
    cases = []

    extra = dict(first_runtime_output)
    extra["debug"] = True
    cases.append(extra)

    missing = dict(first_runtime_output)
    missing.pop("database_ok")
    cases.append(missing)

    wrong_bool = dict(first_runtime_output)
    wrong_bool["database_ok"] = 1
    cases.append(wrong_bool)

    wrong_ok = dict(first_runtime_output)
    wrong_ok["ok"] = 1
    cases.append(wrong_ok)

    wrong_database = dict(first_runtime_output)
    wrong_database["database"] = "postgres"
    cases.append(wrong_database)

    stale_version = dict(first_runtime_output)
    stale_version["version"] = "4.2.0"
    cases.append(stale_version)

    naive_time = dict(first_runtime_output)
    naive_time["time"] = "2026-09-06T22:00:00"
    cases.append(naive_time)

    for payload in cases:
        _expect_rejected(runtime_contract.validate_first_runtime_output, payload)

    # Regression: stale raw producer data is rejected rather than repaired.
    stale_raw = dict(raw_produced)
    stale_raw["version"] = "4.2.0"
    _expect_rejected(runtime_contract.validate_first_runtime_output, stale_raw)

    print("FIRST_RUNTIME_OUTPUT_STRICT_OK")
    print(
        {
            "version": first_runtime_output["version"],
            "database": first_runtime_output["database"],
            "negative_cases_rejected": len(cases) + 1,
            "single_choke_point": True,
            "keys": sorted(first_runtime_output),
        }
    )


if __name__ == "__main__":
    run()
