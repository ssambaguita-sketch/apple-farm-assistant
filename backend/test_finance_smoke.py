import os
import tempfile

from fastapi.testclient import TestClient


def run():
    db_file = tempfile.NamedTemporaryFile(prefix='apple-finance-', suffix='.db', delete=False)
    db_file.close()
    os.environ['DATABASE_URL'] = f"sqlite:///{db_file.name}"

    import start
    import main

    main.metadata.create_all(main.engine)
    client = TestClient(start.app)

    orchard = 'SMOKE_TEST_ORCHARD'

    r = client.post('/api/finance/entry', json={
        'orchard': orchard,
        'type': 'revenue',
        'category': '사과 판매',
        'amount': 150000,
        'quantity_kg': 120,
        'note': 'smoke revenue',
    })
    assert r.status_code == 200, r.text

    r = client.post('/api/finance/entry', json={
        'orchard': orchard,
        'type': 'expense',
        'category': '포장·운송',
        'amount': 40000,
        'quantity_kg': 0,
        'note': 'smoke expense',
    })
    assert r.status_code == 200, r.text

    summary = client.get('/api/finance/summary', params={'orchard': orchard})
    assert summary.status_code == 200, summary.text
    data = summary.json()
    assert data['revenue'] == 150000
    assert data['expense'] == 40000
    assert data['profit'] == 110000
    assert data['harvest_kg'] == 120
    assert data['entry_count'] == 2

    listing = client.get('/api/finance', params={'orchard': orchard})
    assert listing.status_code == 200, listing.text
    assert len(listing.json()) == 2

    check = client.get('/api/finance/check', params={'orchard': orchard})
    assert check.status_code == 200, check.text
    assert check.json()['ok'] is True
    assert check.json()['orchard_entries'] == 2

    performance = client.get('/api/performance')
    assert performance.status_code == 200, performance.text
    assert performance.json()['weather_cache_ttl_seconds'] == 300

    dashboard = client.get('/api/dashboard', params={'orchard': orchard})
    assert dashboard.status_code == 200, dashboard.text
    assert dashboard.json()['profit'] == 110000

    print('FINANCE_SMOKE_OK')
    print(data)


if __name__ == '__main__':
    run()
