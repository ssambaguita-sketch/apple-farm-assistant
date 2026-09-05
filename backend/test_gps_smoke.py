import os
import tempfile

from fastapi.testclient import TestClient


def run():
    db_file = tempfile.NamedTemporaryFile(prefix='apple-gps-', suffix='.db', delete=False)
    db_file.close()
    os.environ['DATABASE_URL'] = f"sqlite:///{db_file.name}"

    import start
    import main

    main.metadata.create_all(main.engine)
    client = TestClient(start.app)

    orchard = 'GPS_SMOKE_ORCHARD'
    created = client.post('/api/orchards/multi', json={
        'name': orchard,
        'varieties': ['후지'],
        'area_m2': 1000,
        'tree_count': 100,
        'growth_stage': '과실비대',
    })
    assert created.status_code == 200, created.text

    before = client.get('/api/gps/status', params={'orchard': orchard})
    assert before.status_code == 200, before.text
    assert before.json()['saved'] is False

    saved = client.post('/api/gps/save', json={
        'orchard': orchard,
        'lat': 36.79121,
        'lon': 127.98341,
    })
    assert saved.status_code == 200, saved.text
    data = saved.json()
    assert data['ok'] is True
    assert data['verified'] is True
    assert abs(data['lat'] - 36.79121) < 0.000001
    assert abs(data['lon'] - 127.98341) < 0.000001
    assert data['nx'] is not None
    assert data['ny'] is not None

    after = client.get('/api/gps/status', params={'orchard': orchard})
    assert after.status_code == 200, after.text
    result = after.json()
    assert result['saved'] is True
    assert abs(result['lat'] - 36.79121) < 0.000001
    assert abs(result['lon'] - 127.98341) < 0.000001

    missing = client.post('/api/gps/save', json={
        'orchard': 'NOT_REGISTERED',
        'lat': 36.7,
        'lon': 127.9,
    })
    assert missing.status_code == 404, missing.text

    print('GPS_SMOKE_OK')
    print(result)


if __name__ == '__main__':
    run()
