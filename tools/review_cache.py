#!/usr/bin/env python3
"""Read-only cache validation; --snapshot records navigation metadata, not review approval."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'docs/review/cache.json'
SUFFIXES = {'.gd', '.gdshader', '.tscn', '.tres', '.godot', '.cfg', '.ps1', '.bat', '.iss', '.py'}

def collect():
    tracked = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT).decode('utf-8').split('\0')
    names = sorted(set(tracked) | {'tools/review_cache.py'} | {p.relative_to(ROOT).as_posix() for p in (ROOT / 'docs/review').glob('*.gd')})
    result = {}
    for name in names:
        p = ROOT / name
        if not p.is_file() or (p.suffix not in SUFFIXES and name != 'AGENTS.md'):
            continue
        content = p.read_bytes()
        source = content.decode('utf-8-sig')
        result[name] = {
            'sha256': hashlib.sha256(content).hexdigest(),
            'lines': len(source.splitlines()),
            'functions': [{'line': i, 'signature': line.strip()} for i, line in enumerate(source.splitlines(), 1) if re.match(r'^(?:static )?func |^def |^function ', line)],
            'resources': sorted(set(re.findall(r'res://[^"\s)]+', source))),
            'autoload_dependencies': sorted(set(re.findall(r'/root/([A-Za-z_]+)', source))),
        }
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot', action='store_true', help='Replace navigation snapshot only after inspecting changes; does NOT renew review conclusions')
    args = parser.parse_args()
    files = collect()
    if args.snapshot:
        CACHE.write_text(json.dumps({'schema': 1, 'navigation_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip(), 'review_baseline': 'e5a5f551fcf1cd1b9675e7091ed6d4a802e970a7', 'restoration_baseline': 'baa39fd1d419c5f7d8e4242195c0a4252ee72432', 'files': files}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print('Navigation snapshot saved; review conclusions retain their original baseline.')
        return 0
    old = json.loads(CACHE.read_text(encoding='utf-8'))['files']
    changes = [(name, 'added' if name not in old else 'removed' if name not in files else 'changed') for name in sorted(old.keys() | files.keys()) if old.get(name, {}).get('sha256') != files.get(name, {}).get('sha256')]
    for name, kind in changes:
        print(f'{kind}: {name}')
    print(f'{len(changes)} changed code/config files; unchanged hashes do not prove correctness.')
    return int(bool(changes))

if __name__ == '__main__':
    raise SystemExit(main())
