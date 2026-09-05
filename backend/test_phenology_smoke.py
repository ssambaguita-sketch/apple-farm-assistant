import os
import tempfile

from fastapi.testclient import TestClient


def run():
    db_file = tempfile.NamedTemporaryFile(prefix='apple-phenology-', suffix='.db', delete=False)
    db_file.close()
    os.environ['DATABASE_URL'] = f"sqlite:///{db_file.name}"
    os.environ.pop('KMA_SERVICE_KEY', None)

    import start
    import main

    main.metadata.create_all(main.engine)
    client = TestClient(start.app)

    created = client.post('/api/orchards/multi', json={
        'name': 'PHENOLOGY_TEST',
        'varieties': ['홍로', '후지'],
        'area_m2': 5000,
        'tree_count': 320,
        'growth_stage': '수확',
        'lat': 36.79,
        'lon': 127.98,
    })
    assert created.status_code == 200, created.text

    response = client.get('/api/annual/phenology', params={'orchard': 'PHENOLOGY_TEST'})
    assert response.status_code == 200, response.text
    data = response.json()

    assert data['orchard']['name'] == 'PHENOLOGY_TEST'
    assert data['orchard']['tree_count'] == 320
    assert data['orchard']['area_m2'] == 5000
    assert data['orchard']['growth_stage'] == '수확'
    assert data['orchard']['varieties'] == ['홍로', '후지']
    assert len(data['months']) == 12
    assert data['months'][0]['month'] == 1
    assert '소한' in data['months'][0]['solar_terms'][0]
    assert '대한' in data['months'][0]['solar_terms'][1]
    assert data['gdd']['observed_days'] == 0
    assert data['weather']['weather_source'] == 'demo'

    current = data['months'][data['current_month'] - 1]
    assert current['active_adjustment'] is True
    assert '320주' in ' '.join(current['tasks'])
    assert '홍로' in ' '.join(current['tasks'])
    assert isinstance(current['weed_timing'], list) and current['weed_timing']
    assert isinstance(current['foliar_timing'], list) and current['foliar_timing']
    assert current['weed_status']
    assert current['foliar_status']

    april = data['months'][3]
    july = data['months'][6]
    september = data['months'][8]
    assert '잡초' in ' '.join(april['weed_timing'])
    assert '엽면' in ' '.join(april['foliar_timing'])
    assert '여름잡초' in ' '.join(july['weed_timing'])
    assert '수확' in ' '.join(september['foliar_timing'])
    assert 'PSIS' in data['policy']

    print('PHENOLOGY_SMOKE_OK')
    print({
        'current_month': data['current_month'],
        'adjustment_days': data['current_adjustment_days'],
        'weed_status': current['weed_status'],
        'foliar_status': current['foliar_status'],
        'gdd': data['gdd'],
        'weather_source': data['weather']['weather_source'],
    })


if __name__ == '__main__':
    run()
