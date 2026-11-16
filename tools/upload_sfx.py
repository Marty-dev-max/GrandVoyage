#!/usr/bin/env python3
"""Upload assets/sfx/*.wav to Roblox via the Open Cloud Assets API and write the ids into
src/shared/Config/Sounds.lua.

  ROBLOX_API_KEY=<key with asset:write> python3 tools/upload_sfx.py --user 1527424396 [--only UIClick,Coin]

Already-uploaded sounds are remembered in assets/sfx/uploaded.json and skipped.
"""
import argparse, json, os, re, sys, time, uuid, urllib.request, urllib.error

ROOT = os.path.join(os.path.dirname(__file__), '..')
SFX = os.path.join(ROOT, 'assets', 'sfx')
SOUNDS_LUA = os.path.join(ROOT, 'src', 'shared', 'Config', 'Sounds.lua')
CACHE = os.path.join(SFX, 'uploaded.json')
API = 'https://apis.roblox.com/assets/v1'
KEY = os.environ.get('ROBLOX_API_KEY', '')

def call(method, url, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers={'x-api-key': KEY, **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read() or b'{}')
    except urllib.error.HTTPError as e:
        return e.code, {'error': e.read().decode(errors='replace')[:400]}

def upload(path, name, user):
    boundary = uuid.uuid4().hex
    meta = {'assetType': 'Audio', 'displayName': f'GrandVoyage {name}', 'description': f'Grand Voyage sound effect: {name}',
            'creationContext': {'creator': {'userId': str(user)}}}
    data = open(path, 'rb').read()
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n'
            f'{json.dumps(meta)}\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{name}.wav"\r\n'
            f'Content-Type: audio/wav\r\n\r\n').encode() + data + f'\r\n--{boundary}--\r\n'.encode()
    status, res = call('POST', f'{API}/assets', body, {'Content-Type': f'multipart/form-data; boundary={boundary}'})
    if status >= 300:
        return None, f'HTTP {status}: {res}'
    op = res.get('path') or res.get('operationId')
    for _ in range(40):
        if res.get('done'):
            break
        time.sleep(2)
        status, res = call('GET', f'{API}/{op}' if op.startswith('operations/') else f'{API}/operations/{op}')
    asset = (res.get('response') or {}).get('assetId')
    return (asset, None) if asset else (None, f'operation not finished / no asset id: {res}')

def write_ids(ids):
    s = open(SOUNDS_LUA, encoding='utf-8').read()
    block = '\n'.join(f'S.{k}.id = "rbxassetid://{v}"' for k, v in sorted(ids.items()))
    marker = '-- ===== uploaded asset ids (written by tools/upload_sfx.py) ====='
    s = re.sub(re.escape(marker) + r'.*?(?=\nreturn S)', '', s, flags=re.S)
    s = s.replace('\nreturn S', f'\n{marker}\n{block}\n\nreturn S')
    open(SOUNDS_LUA, 'w', encoding='utf-8').write(s)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--user', required=True)
    ap.add_argument('--only', default='')
    a = ap.parse_args()
    ids = json.load(open(CACHE)) if os.path.exists(CACHE) else {}
    only = set(filter(None, a.only.split(',')))
    for f in sorted(os.listdir(SFX)):
        if not f.endswith('.wav'):
            continue
        name = f[:-4]
        if (only and name not in only) or name in ids:
            continue
        asset, err = upload(os.path.join(SFX, f), name, a.user)
        if asset:
            ids[name] = asset
            print(f'OK   {name:16} rbxassetid://{asset}')
            json.dump(ids, open(CACHE, 'w'), indent=1)
        else:
            print(f'FAIL {name:16} {err}')
    write_ids(ids)
    print(f'{len(ids)} ids written to Sounds.lua')

if __name__ == '__main__':
    main()
