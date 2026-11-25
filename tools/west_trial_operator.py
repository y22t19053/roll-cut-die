"""Local operator tool: never launches Godot, alters security settings or writes a game save."""
import argparse, hashlib, json, os, subprocess, tempfile, time, uuid, zipfile
from pathlib import Path
from datetime import datetime, timezone


def digest(p):
    try:
        return hashlib.sha256(p.read_bytes()).hexdigest()
    except FileNotFoundError:
        return 'ABSENT'


def isolated_config(original, condition, token):
    import re
    refused = 'Unexpected project configuration; trial not prepared.'
    if condition not in ('A', 'B') or not re.fullmatch('[0-9a-f]{32}', token):
        raise ValueError(refused)

    scenes = {'"res://scenes/front/title.tscn"', '"res://scenes/main/main.tscn"'}
    section = ''
    found_scene = False
    output = []
    for line in original.splitlines(keepends=True):
        entry = line.strip()
        if not entry or entry.startswith(';'):
            output.append(line)
            continue
        if re.fullmatch(r'\[[\w/]+\]', entry):
            section = entry[1:-1]
        else:
            key, equals, value = entry.partition('=')
            key = key.strip()
            if not equals or not re.fullmatch(r'[\w/]+', key):
                raise ValueError(refused)
            value = value.strip()
            setting = f'{section}/{key}' if section else key
            if (key in ('config/use_custom_user_dir', 'config/custom_user_dir_name')
                    or setting in ('application/config/use_custom_user_dir',
                                   'application/config/custom_user_dir_name')):
                raise ValueError(refused)
            if key == 'McpInteractionServer':
                continue
            if key == 'run/main_scene' or setting == 'application/run/main_scene':
                if section != 'application' or key != 'run/main_scene' or found_scene or value not in scenes:
                    raise ValueError(refused)
                found_scene = True
                line = (f'run/main_scene="res://tools/corner_evidence_{condition.lower()}.tscn"\n'
                        f'config/use_custom_user_dir=true\n'
                        f'config/custom_user_dir_name="RCD-Research/isolated/{token}"\n')
            if setting.startswith('autoload/') and (setting, value) != (
                    'autoload/GameSession', '"*res://scripts/core/game_session.gd"'):
                raise ValueError(refused)
        output.append(line)
    if not found_scene:
        raise ValueError(refused)
    return ''.join(output)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('action', choices=['prepare', 'guard'])
    ap.add_argument('condition', choices=['A', 'B'])
    ap.add_argument('--participant', help='anonymous code P001..P99999 (guard only)')
    ap.add_argument('--order', choices=['first','second'], default='first')
    args = ap.parse_args()
    root = Path(os.environ['LOCALAPPDATA']) / 'RCD-Research'
    unique = uuid.uuid4().hex
    if args.action == 'prepare':
        src = Path(__file__).resolve().parents[1]
        rev = subprocess.check_output(['git','rev-parse','HEAD'],cwd=src,text=True).strip()
        user_dir = Path(os.environ['APPDATA']) / 'RCD-Research' / 'isolated' / unique
        if os.path.lexists(user_dir):
            ap.error('Trial user directory already exists; refusing to reuse data.')
        dest = root / 'runs' / unique / 'project'; dest.mkdir(parents=True)
        with tempfile.TemporaryFile() as tmp:
            subprocess.run(['git','archive','--format=zip',rev],cwd=src,stdout=tmp,check=True)
            tmp.seek(0)
            with zipfile.ZipFile(tmp) as z: z.extractall(dest)
        cfg = dest / 'project.godot'
        cfg.write_text(isolated_config(cfg.read_text('utf-8'), args.condition, unique), 'utf-8')
        receipt = {'status':'PREPARED_NOT_A_PARTICIPANT','source':rev,'project_config_sha256':digest(cfg),'condition':args.condition,'expected_user_dir':str(user_dir)}
        (dest.parent/'operator.json').write_text(json.dumps(receipt,indent=2),'utf-8'); print(dest); return
    import msvcrt, re
    if not re.fullmatch(r'P[0-9]{3,5}',args.participant or ''): ap.error('guard requires an anonymous --participant code')
    save = Path(os.environ['APPDATA'])/'Godot'/'app_userdata'/'roll cut die'/'rcd'/'save.json'
    initial = digest(save); out = root/'guards'/(unique+'.jsonl'); out.parent.mkdir(parents=True,exist_ok=True)
    with out.open('x',encoding='utf-8') as f:
        def emit(status, observed):
            f.write(json.dumps(dict(utc=datetime.now(timezone.utc).isoformat(),participant=args.participant,condition=args.condition,order=args.order,status=status,sha=observed))+'\n'); f.flush()
        emit('START',initial); print('Guard ready. Press Q in this console AFTER closing the game. Receipt:',out,flush=True)
        while True:
            h=digest(save)
            if h!=initial: emit('INVALID_SAVE_CHANGED',h); raise SystemExit('STOP trial immediately. Do not restore the save.')
            if msvcrt.kbhit() and msvcrt.getwch().lower()=='q':
                h=digest(save); emit('UNCHANGED' if h==initial else 'INVALID_SAVE_CHANGED',h); raise SystemExit(0 if h==initial else 2)
            time.sleep(.25)

if __name__=='__main__': main()
