from typing import Optional

from fastapi import HTTPException
from pydantic import BaseModel
from sqlalchemy import select, insert, func, desc

import main


class FinanceEntryIn(BaseModel):
    orchard: str
    type: str
    category: str = ""
    amount: float = 0
    quantity_kg: float = 0
    note: str = ""


def _normalize_type(value: str) -> str:
    t = value.strip().lower()
    if t not in {"revenue", "expense"}:
        raise HTTPException(400, "type은 revenue 또는 expense여야 합니다")
    return t


@main.app.get("/api/finance")
def finance_list(orchard: str, limit: int = 100):
    safe_limit = max(1, min(limit, 300))
    q = (
        select(main.finance)
        .where(main.finance.c.orchard == orchard)
        .order_by(desc(main.finance.c.id))
        .limit(safe_limit)
    )
    with main.engine.connect() as c:
        rows = c.execute(q).mappings().all()
    return [dict(r) for r in rows]


@main.app.get("/api/finance/summary")
def finance_summary(orchard: str):
    with main.engine.connect() as c:
        revenue = c.execute(
            select(func.coalesce(func.sum(main.finance.c.amount), 0)).where(
                main.finance.c.orchard == orchard,
                main.finance.c.type == "revenue",
            )
        ).scalar_one()
        expense = c.execute(
            select(func.coalesce(func.sum(main.finance.c.amount), 0)).where(
                main.finance.c.orchard == orchard,
                main.finance.c.type == "expense",
            )
        ).scalar_one()
        harvest_kg = c.execute(
            select(func.coalesce(func.sum(main.finance.c.quantity_kg), 0)).where(
                main.finance.c.orchard == orchard,
                main.finance.c.type == "revenue",
            )
        ).scalar_one()
        count = c.execute(
            select(func.count()).select_from(main.finance).where(main.finance.c.orchard == orchard)
        ).scalar_one()
        by_category = c.execute(
            select(
                main.finance.c.type,
                main.finance.c.category,
                func.coalesce(func.sum(main.finance.c.amount), 0).label("amount"),
                func.coalesce(func.sum(main.finance.c.quantity_kg), 0).label("quantity_kg"),
            )
            .where(main.finance.c.orchard == orchard)
            .group_by(main.finance.c.type, main.finance.c.category)
            .order_by(main.finance.c.type, desc(func.sum(main.finance.c.amount)))
        ).mappings().all()

    revenue_f = float(revenue or 0)
    expense_f = float(expense or 0)
    harvest_f = float(harvest_kg or 0)
    profit = revenue_f - expense_f
    profit_rate = (profit / revenue_f * 100.0) if revenue_f > 0 else 0.0

    return {
        "orchard": orchard,
        "revenue": round(revenue_f, 0),
        "expense": round(expense_f, 0),
        "profit": round(profit, 0),
        "profit_rate_pct": round(profit_rate, 1),
        "harvest_kg": round(harvest_f, 1),
        "entry_count": int(count or 0),
        "by_category": [dict(r) for r in by_category],
    }


@main.app.post("/api/finance/entry")
def finance_add_entry(x: FinanceEntryIn):
    t = _normalize_type(x.type)
    if x.amount < 0:
        raise HTTPException(400, "금액은 0 이상이어야 합니다")
    if x.quantity_kg < 0:
        raise HTTPException(400, "수확량은 0 이상이어야 합니다")
    with main.engine.begin() as c:
        result = c.execute(
            insert(main.finance).values(
                orchard=x.orchard.strip() or "A과수원",
                type=t,
                category=x.category.strip(),
                amount=float(x.amount),
                quantity_kg=float(x.quantity_kg),
                note=x.note.strip(),
                created_at=main.now_iso(),
            )
        )
        entry_id = result.inserted_primary_key[0]
    return {"ok": True, "id": entry_id}


@main.app.get("/api/finance/check")
def finance_check(orchard: Optional[str] = None):
    name = (orchard or "").strip()
    try:
        with main.engine.connect() as c:
            total = c.execute(select(func.count()).select_from(main.finance)).scalar_one()
            if name:
                orchard_total = c.execute(
                    select(func.count()).select_from(main.finance).where(main.finance.c.orchard == name)
                ).scalar_one()
            else:
                orchard_total = total
        return {
            "ok": True,
            "table": "finance",
            "readable": True,
            "write_endpoint": "/api/finance/entry",
            "summary_endpoint": "/api/finance/summary",
            "total_entries": int(total or 0),
            "orchard_entries": int(orchard_total or 0),
        }
    except Exception as e:
        return {"ok": False, "table": "finance", "readable": False, "error": type(e).__name__}
