"""Real-provider regression, raw files/evidence stay in ignored _local/.

Usage: python scripts/verify_provider.py CLI [--file ECB_JSON]
Without --file this downloads a small fixed historical ECB series over HTTPS.
ECB currently serves JSON 1.0; this verifies the explicit provider adapter,
NOT native JSON 2.0 or full DSD/StructureMessage conformance.
"""
from pathlib import Path
from decimal import Decimal
import argparse
import datetime
import hashlib
import json
import subprocess
import urllib.request

URL = 'https://data-api.ecb.europa.eu/service/data/EXR/M.USD.EUR.SP00.A?startPeriod=2025-01&endPeriod=2025-03&format=jsondata'
FLOW = 'ECB:EXR(1.0)'


def verify(cli, source=None):
    root = Path(__file__).resolve().parents[1]
    cache = root / '_local/provider-interop'
    cache.mkdir(parents=True, exist_ok=True)
    content_type = None
    if source:
        raw = source.read_bytes()
    else:
        with urllib.request.urlopen(urllib.request.Request(URL, headers={'User-Agent': 'MoonSDMX-interop/1.0'}), timeout=30) as response:
            assert response.status == 200
            content_type = response.headers.get('Content-Type')
            raw = response.read(16777217)
    assert len(raw) <= 16777216
    path = cache / 'ecb-exr-original.json'
    path.write_bytes(raw)
    provider = json.loads(raw, parse_float=Decimal)
    assert 'header' in provider and 'structure' in provider and 'dataSets' in provider
    layout = provider['structure']
    dimensions = layout['dimensions']
    attributes = layout.get('attributes', {})
    def dictionary(component, token):
        if token is None:
            return None
        value = component['values'][token]
        return str(value.get('id', value.get('value', value.get('name'))))
    def dimensions_at(components, key):
        indexes = [int(x) for x in key.split(':')] if components else []
        assert len(indexes) == len(components)
        return [dictionary(c, index) for c, index in zip(components, indexes)]
    def attribute_values(components, values):
        assert len(values) <= len(components)
        return [dictionary(c, values[i] if i < len(values) else None) for i, c in enumerate(components)]
    expected = []
    for dataset in provider['dataSets']:
        rows = []
        assert not dimensions.get('dataSet'), 'This fixed provider oracle covers a series/observation layout'
        inherited = attribute_values(attributes.get('dataSet', []), dataset.get('attributes', []))
        for series_key, series in dataset.get('series', {}).items():
            prefix = dimensions_at(dimensions.get('series', []), series_key)
            series_attributes = attribute_values(attributes.get('series', []), series.get('attributes', []))
            for observation_key, observation in series['observations'].items():
                rows.append({'key': prefix + dimensions_at(dimensions.get('observation', []), observation_key),
                             'measures': [None if observation[0] is None else str(observation[0])],
                             'attributes': inherited + series_attributes + attribute_values(attributes.get('observation', []), observation[1:])})
        expected.append({'action': dataset.get('action', 'Information'), 'rows': sorted(rows, key=lambda r: r['key']),
                         'validFrom': dataset.get('validFrom'), 'validTo': dataset.get('validTo')})
    def run(*args):
        p = subprocess.run([str(cli.resolve()), *map(str, args)], cwd=root, capture_output=True, text=True, encoding='utf8')
        assert p.returncode == 0, p.stdout + p.stderr
        return p.stdout
    decoded = json.loads(run('inspect-provider-json1', path, FLOW))
    def normalized(items):
        return [{key: sorted(item[key], key=lambda r: r['key']) if key == 'rows' else item[key]
                 for key in ['action', 'rows', 'validFrom', 'validTo']} for item in items]
    assert normalized(decoded) == expected
    target = cache / 'ecb-normalized-json2.json'
    if target.exists(): target.unlink()  # Known generated file, never user source.
    run('provider-json1', path, FLOW, 'provider-check', 'LOCAL', '2026-11-06T00:00:00Z', '--output', target)
    reread = json.loads(run('inspect-bundle', target))
    assert normalized(reread) == expected
    evidence = {'provider': 'European Central Bank', 'url': URL, 'sha256': hashlib.sha256(raw).hexdigest(),
                'checked_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                'content_type': content_type, 'source_mode': 'supplied raw file' if source else 'HTTPS download',
                'wire_version': 'SDMX-JSON 1.0', 'adapter': 'decode_json1_provider', 'datasets': len(expected),
                'observations': sum(len(x['rows']) for x in expected), 'all_keys_measures_attributes_actions_and_validity_match': True,
                'normalized_json2_roundtrip': True, 'external_DSD_validated': False,
                'scope': 'Actual provider file; not a full standard/version conformance certification'}
    (cache / 'evidence.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps(evidence, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('cli', type=Path)
    parser.add_argument('--file', type=Path)
    args = parser.parse_args()
    verify(args.cli, args.file)
