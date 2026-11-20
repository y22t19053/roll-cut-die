"""Read-only pre-launch check. Never starts the game or certifies a playthrough."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path

SHA = 'A56F2D1622D7D31DE74D4923ADE5AA85B80B114B4C75C3346E0D2A49F1E165BC'


def digest(path):
    if not path.exists():
        return 'ABSENT'
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            h.update(block)
    return h.hexdigest().upper()


def check(receipt, local, roaming):
    r = json.loads(receipt.read_text(encoding='utf-8-sig'))
    token = receipt.parent.name
    if not re.fullmatch('[0-9a-f]{32}', token):
        raise ValueError('invalid run identifier')
    root = local / 'RCD-Research' / 'release' / token
    game = root / 'game'
    isolated = roaming / 'RCD-Research' / 'release' / token
    if (receipt.resolve() != (root / 'receipt.json').resolve() or
            Path(r['directory']).resolve() != game.resolve() or
            Path(r['expected_user_dir']).resolve() != isolated.resolve()):
        raise ValueError('unexpected receipt paths')
    if r['sha256'] != SHA or r['build'] != '6bab995' or r['status'] != 'PREPARED_NOT_STARTED':
        raise ValueError('unsupported release receipt')
    if {p.name for p in game.iterdir()} != {'RCD-ORBIT30.exe', 'override.cfg'}:
        raise ValueError('unexpected game directory contents')
    if digest(game / 'RCD-ORBIT30.exe') != SHA:
        raise ValueError('release binary changed')
    expected = ['[application]', 'config/use_custom_user_dir=true',
                f'config/custom_user_dir_name="RCD-Research/release/{token}"']
    if (game / 'override.cfg').read_text('utf-8').splitlines() != expected:
        raise ValueError('override does not match this run')
    if isolated.exists():
        raise ValueError('expected user directory is no longer fresh; do not reuse this run')
    save = roaming / 'Godot' / 'app_userdata' / 'roll cut die' / 'rcd' / 'save.json'
    if digest(save) != r['production_save_before'].upper():
        raise ValueError('production save changed since preparation; do not restore')


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('receipt', type=Path)
    args = ap.parse_args()
    try:
        check(args.receipt, Path(os.environ['LOCALAPPDATA']), Path(os.environ['APPDATA']))
    except (ValueError, OSError, KeyError, TypeError, AttributeError) as exc:
        ap.exit(1, f'STOP: {exc}\n')
    print('PREFLIGHT OK — not launched; runtime isolation still unverified')
