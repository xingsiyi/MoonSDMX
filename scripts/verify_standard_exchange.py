"""Offline standard registry/bundle/CSV regression on original synthetic data.
Optionally validate against the pinned official SDMX 2.0 schemas with --schemas.
"""
from pathlib import Path
import argparse
import json
import subprocess
import tempfile


def verify(cli, schemas=None):
    root = Path(__file__).resolve().parents[1]
    registry_path = root / 'examples/data/registry-json2.json'
    registry = json.loads(registry_path.read_bytes())
    cli = cli.resolve()
    def run(*args, success=True):
        p = subprocess.run([str(cli), *map(str, args)], cwd=root, capture_output=True, text=True, encoding='utf8')
        assert (p.returncode == 0) == success, p.stdout + p.stderr
        return p.stdout
    if schemas:
        import jsonschema
        schema = json.loads((schemas / 'structure-message/tools/schemas/2.0.0/sdmx-json-structure-schema.json').read_bytes())
        jsonschema.Draft7Validator(schema).validate(registry)
    with tempfile.TemporaryDirectory(prefix='moonsdmx-standard-') as temp:
        p = Path(temp)
        # Split codelists/concepts into an external standard message; no custom profile input.
        external = {'meta': registry['meta'], 'data': {k: registry['data'][k] for k in ['codelists', 'conceptSchemes']}}
        definitions = {'meta': registry['meta'], 'data': {k: registry['data'][k] for k in ['dataStructures', 'dataflows']}}
        ext = p / 'external.json'; dsd = p / 'definitions.json'
        ext.write_text(json.dumps(external), encoding='utf8'); dsd.write_text(json.dumps(definitions), encoding='utf8')
        profile = json.loads(run('registry-dsd', dsd, 'DEMO:DSD(1.0)', ext))
        assert profile['reference'] == 'DEMO:DSD(1.0)'
        area = next(c for c in profile['components'] if c['id'] == 'AREA')
        assert [x['id'] for x in area['representation']['codes']] == ['A', 'B']
        run('registry-dsd', dsd, 'DEMO:DSD(1.0)', success=False)
        csv = p / 'multi.csv'
        csv.write_bytes(b'STRUCTURE,STRUCTURE_ID,ACTION,AREA,TIME_PERIOD,OBS_VALUE,UNIT\r\n'
                        b'dataflow,DEMO:FLOW(1.0),A,A,2026-01,1.20,kWh\r\n'
                        b'dataflow,DEMO:FLOW(1.0),R,A,2026-01,2.30,kWh\r\n'
                        b'dataflow,DEMO:FLOW_ALT(1.0),I,B,,9.00,kWh\r\n')
        decoded = json.loads(run('validate-registry-csv', registry_path, csv))
        assert [x['action'] for x in decoded] == ['Append', 'Replace', 'Information']
        assert decoded[2]['rows'][0]['key'] == ['B']
        assert decoded[0]['rows'][0]['measures'] == ['1.20']
        def structure(reference, time):
            dims = [{'id': 'AREA', 'keyPosition': 0, 'values': [{'id': 'A', 'name': 'Area A'}, {'id': 'B', 'name': 'Area B'}]}]
            if time: dims += [{'id': 'TIME_PERIOD', 'keyPosition': 1, 'roles': ['TIME_PERIOD'], 'values': [{'id': '2026-01', 'name': 'January 2026'}]}]
            return {'links': [{'urn': 'urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=DEMO:' + reference + '(1.0)', 'rel': 'dataflow'}],
                    'dimensions': {'observation': dims},
                    'measures': {'observation': [{'id': 'OBS_VALUE', 'format': {'dataType': 'Decimal'}}]},
                    'attributes': {'observation': [{'id': 'UNIT', 'relationship': {'dimensions': ['AREA']}}]}}
        data = {'meta': {'schema': 'https://json.sdmx.org/2.0.0/sdmx-json-data-schema.json', 'id': 'multi', 'sender': {'id': 'DEMO'}, 'prepared': '2026-11-06T00:00:00Z'},
                'data': {'structures': [structure('FLOW', True), structure('FLOW_ALT', False)],
                         'dataSets': [{'structure': 0, 'action': 'Append', 'observations': {'0:0': ['1.20', 'kWh']}},
                                      {'structure': 0, 'action': 'Replace', 'observations': {'0:0': ['2.30', 'kWh']}},
                                      {'structure': 1, 'action': 'Information', 'observations': {'1': ['9.00', 'kWh']}}]}}
        for dataset in data['data']['dataSets']:
            dataset['links'] = data['data']['structures'][dataset['structure']]['links']
        source = p / 'multi.json'; source.write_text(json.dumps(data), encoding='utf8')
        if schemas:
            schema = json.loads((schemas / 'data-message/tools/schemas/2.0.0/sdmx-json-data-schema.json').read_bytes())
            jsonschema.Draft7Validator(schema).validate(data)
        actual = json.loads(run('inspect-bundle', source, registry_path))
        assert actual == decoded
        output = p / 'roundtrip.json'
        run('reencode-bundle', source, 'roundtrip', 'DEMO', '2026-11-06T00:00:00Z', '--output', output)
        assert json.loads(run('inspect-bundle', output, registry_path)) == decoded
        if schemas: jsonschema.Draft7Validator(schema).validate(json.loads(output.read_bytes()))
        data['data']['dataSets'][2]['structure'] = 2
        source.write_text(json.dumps(data), encoding='utf8')
        run('inspect-bundle', source, registry_path, success=False)
    print('PASS: standard StructureMessage external DSD/codelists, 2 distinct DSDs, 3 ordered dataSets/actions, CSV2 and JSON2 roundtrips; invalid indexes and unresolved references refused')
    if schemas: print('PASS: pinned official JSON2 StructureMessage/DataMessage schema validation (synthetic inputs and encoded output)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('cli', type=Path)
    parser.add_argument('--schemas', type=Path)
    args = parser.parse_args()
    verify(args.cli, args.schemas)
