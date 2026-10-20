#!/usr/bin/env python3
"""Upload release assets (chunked parts) to GitHub Release v1.0.0.
Token: ~/.gh-token   (chmod 600, one line PAT)
Usage: python3 work/upload_release.py [--publish]
"""
import glob, json, os, subprocess, sys, time

TOKEN_PATH = os.path.expanduser('~/.gh-token')
TOKEN = open(TOKEN_PATH).read().strip()
REPO = 'bzbk/orangepi-zero4-arch'
REL = '416957812'
BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'upload5')
LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'upload_release.log')
DONE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'upload_release_done.json')
API = f'https://api.github.com/repos/{REPO}/releases/{REL}'

def log(msg):
    with open(LOG, 'a') as f:
        f.write(f"{time.strftime('%F %T')} {msg}\n")

def files():
    out = []
    for pat in ('arch-tty.img.zst.part*', 'arch-fxce.img.zst.part*', 'arch-kde.img.zst.part*'):
        out += sorted(glob.glob(os.path.join(BASE, pat)))
    p = os.path.join(BASE, 'SHA256SUMS.parts')
    if os.path.exists(p):
        out.append(p)
    return [(f, os.path.basename(f)) for f in out]

def done_set():
    try:
        return set(json.load(open(DONE)))
    except Exception:
        return set()

def curl(args, timeout=900):
    env = dict(os.environ)
    env.setdefault('https_proxy', 'http://127.0.0.1:7897')
    env.setdefault('http_proxy', 'http://127.0.0.1:7897')
    return subprocess.run(['curl', '-sS', '--max-time', str(timeout)] + args,
                          capture_output=True, text=True, env=env)

def upload(name, path):
    size = os.path.getsize(path)
    t0 = time.time()
    p = curl(['-X', 'POST', '-H', f'Authorization: Bearer {TOKEN}',
              '-H', 'Accept: application/vnd.github+json',
              '-H', 'Content-Type: application/octet-stream',
              '--data-binary', f'@{path}',
              f'https://uploads.github.com/repos/{REPO}/releases/{REL}/assets?name={name}'])
    dt = time.time() - t0
    try:
        resp = json.loads(p.stdout or '{}')
    except Exception:
        resp = {}
    ok = bool(resp.get('id')) and resp.get('size') == size
    log(f"{'OK  ' if ok else 'FAIL'} {name} {size}B {dt:.0f}s rc={p.returncode} err={p.stderr[:150]} resp={str(resp)[:150]}")
    return ok

def api(args):
    return curl(args, timeout=60)

def asset_states():
    p = api(['-H', f'Authorization: Bearer {TOKEN}', API + '/assets'])
    try:
        return {a['name']: a['state'] for a in json.loads(p.stdout)}
    except Exception:
        return {}

if __name__ == '__main__':
    if '--publish' in sys.argv:
        p = api(['-X', 'PATCH', '-H', f'Authorization: Bearer {TOKEN}',
                 '-H', 'Accept: application/vnd.github+json',
                 '-d', json.dumps({'draft': False}),
                 f'https://api.github.com/repos/{REPO}/releases/{REL}'])
        print('publish:', p.returncode, p.stdout[:300])
        sys.exit(0)
    done = done_set()
    for path, name in files():
        if name in done:
            continue
        for attempt in range(1, 9):
            if upload(name, path):
                done.add(name)
                json.dump(sorted(done), open(DONE, 'w'))
                break
            time.sleep(5)
        else:
            log(f'GIVEUP {name}')
    log('ALL_DONE')
