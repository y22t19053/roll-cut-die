"""Prepare a new local QA copy of the pinned release; never launch or restore anything."""
import json
import os
from pathlib import Path
import shutil
import uuid

if __package__:
    from . import release_preflight as gate
else:
    import release_preflight as gate


def prepare(source, local, roaming):
    if gate.digest(source) != gate.SHA:
        raise ValueError('source differs from the pinned release')
    suffix = Path('RCD-Research/release') / uuid.uuid4().hex
    run = local / suffix
    isolated = roaming / suffix
    if os.path.lexists(isolated):
        raise ValueError('user namespace already exists')
    save = roaming / 'Godot/app_userdata/roll cut die/rcd/save.json'
    before = gate.digest(save)
    run.mkdir(parents=True, exist_ok=False)
    game = run / 'game'
    game.mkdir()
    shutil.copyfile(source, game / 'RCD-ORBIT30.exe')
    (game / 'override.cfg').write_text('[application]\nconfig/use_custom_user_dir=true\n'
        f'config/custom_user_dir_name="{suffix.as_posix()}"\n', encoding='utf-8')
    receipt = run / 'receipt.json'
    receipt.write_text(json.dumps(dict(build='6bab995', status='PREPARED_NOT_STARTED',
        directory=str(game), expected_user_dir=str(isolated), sha256=gate.SHA,
        production_save_before=before), indent=2), encoding='utf-8')
    gate.check(receipt, local, roaming)
    return receipt


if __name__ == '__main__':
    try:
        print(prepare(Path(__file__).resolve().parents[1] / 'builds/RCD-ORBIT30.exe',
                      Path(os.environ['LOCALAPPDATA']), Path(os.environ['APPDATA'])))
    except (ValueError, OSError, KeyError) as exc:
        raise SystemExit(f'STOP: {exc}')
