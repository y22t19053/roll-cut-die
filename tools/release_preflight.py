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


def check(receipt, local, roaming, *, after_boot=False):
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
    if after_boot:
        log = isolated / 'rcd' / 'runtime.log'
        if not log.is_file() or log.resolve() != log.absolute():
            raise ValueError('expected isolated runtime log missing or redirected')
        lines = log.read_text('utf-8').splitlines()
        if any(re.match(r'\s*\d+\.\d+\s+error\b', line) for line in lines):
            raise ValueError('game reported an error in the isolated runtime log')
        messages = [line.split(None, 2)[2] for line in lines
                    if re.fullmatch(r'\s*\d+\.\d+\s+info\s+.+', line)]
        required = ['session ready, take 1', 'room built 24x18', 'roll mode -> ORBIT',
                    'main ready: 2 npcs, 4 evidence, ghosts 0']
        if messages[:4] != required or messages.count(required[0]) != 1:
            raise ValueError('isolated log lacks the expected single release startup')
    elif os.path.lexists(isolated):
        raise ValueError('expected user directory is no longer fresh; do not reuse this run')
    save = roaming / 'Godot' / 'app_userdata' / 'roll cut die' / 'rcd' / 'save.json'
    if digest(save) != r['production_save_before'].upper():
        raise ValueError('production save changed since preparation; do not restore')


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('receipt', type=Path)
    ap.add_argument('--after-boot', action='store_true', help='check isolated log after manual launch, before playing')
    args = ap.parse_args()
    try:
        check(args.receipt, Path(os.environ['LOCALAPPDATA']), Path(os.environ['APPDATA']), after_boot=args.after_boot)
    except (ValueError, OSError, KeyError, TypeError, AttributeError) as exc:
        ap.exit(1, f'STOP: {exc}\n')
    print('ISOLATED STARTUP LOG OK — no input or playthrough verified' if args.after_boot else
          'PREFLIGHT OK — not launched; runtime isolation still unverified')
