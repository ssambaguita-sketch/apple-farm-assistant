import os
import tempfile

from fastapi.testclient import TestClient


def run():
    db_file = tempfile.NamedTemporaryFile(prefix='apple-integrated-', suffix='.db', delete=False)
    db_file.close()
    os.environ['DATABASE_URL'] = f"sqlite:///{db_file.name}"
    os.environ.pop('KMA_SERVICE_KEY', None)

    import start
    import main

    main.metadata.create_all(main.engine)
    client = TestClient(start.app)

    created = client.post('/api/orchards/multi', json={
        'name': 'INTEGRATED_TEST',
        'varieties': ['홍로'],
        'area_m2': 4200,
        'tree_count': 280,
        'growth_stage': '착색·성숙',
        'lat': 36.79,
        'lon': 127.98,
    })
    assert created.status_code == 200, created.text

    obs = client.post('/api/observations', json={
        'orchard': 'INTEGRATED_TEST',
        'category': '탄저병 의심',
        'risk': 4,
        'note': '통합 엔진 테스트',
    })
    assert obs.status_code == 200, obs.text

    finance = client.post('/api/finance/entry', json={
        'orchard': 'INTEGRATED_TEST',
        'type': 'revenue',
        'category': '테스트 출하',
        'amount': 100000,
        'quantity_kg': 50,
        'note': '통합 테스트',
    })
    assert finance.status_code == 200, finance.text

    coach = client.post('/api/coach/work', json={
        'task_type': '예찰',
        'hour': 8,
        'duration_min': 40,
        'completed': True,
        'effort': 2,
    })
    assert coach.status_code == 200, coach.text

    briefing = client.get('/api/integrated/briefing', params={'orchard': 'INTEGRATED_TEST', 'refresh': 'true'})
    assert briefing.status_code == 200, briefing.text
    data = briefing.json()

    assert data['orchard']['name'] == 'INTEGRATED_TEST'
    assert data['observations']['max_risk'] == 4
    assert data['finance']['revenue'] == 100000
    assert data['engine_links']['annual_to_tasks'] is True
    assert data['engine_links']['diagnosis_to_tasks'] is True
    assert data['engine_links']['weed_to_annual'] is True
    assert data['engine_links']['foliar_to_annual'] is True
    assert data['engine_links']['finance_to_priority'] is True
    assert data['engine_links']['coach_to_schedule'] is True
    assert any(x['source'] == 'diagnosis' and x['priority'] == 5 for x in data['actions'])
    assert any(x['source'] == 'annual' for x in data['actions'])

    sync1 = client.post('/api/integrated/sync', params={'orchard': 'INTEGRATED_TEST'})
    assert sync1.status_code == 200, sync1.text
    synced = sync1.json()
    assert synced['ok'] is True
    assert synced['created_count'] > 0
    assert isinstance(synced['briefing'], dict)

    tasks1 = client.get('/api/tasks', params={'orchard': 'INTEGRATED_TEST'}).json()
    count1 = len(tasks1)
    assert count1 >= synced['created_count']

    sync2 = client.post('/api/integrated/sync', params={'orchard': 'INTEGRATED_TEST'})
    assert sync2.status_code == 200, sync2.text
    assert sync2.json()['created_count'] == 0
    tasks2 = client.get('/api/tasks', params={'orchard': 'INTEGRATED_TEST'}).json()
    assert len(tasks2) == count1

    cached = client.get('/api/integrated/briefing', params={'orchard': 'INTEGRATED_TEST'})
    assert cached.status_code == 200
    assert cached.json()['cache_hit'] is True

    print('INTEGRATED_ENGINE_SMOKE_OK')
    print({
        'actions': len(data['actions']),
        'created': synced['created_count'],
        'max_risk': data['observations']['max_risk'],
        'profit': data['finance']['profit'],
        'cache_hit': cached.json()['cache_hit'],
    })


if __name__ == '__main__':
    run()
