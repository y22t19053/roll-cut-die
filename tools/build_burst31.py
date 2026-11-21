#!/usr/bin/env python3
"""Stage and verify immutable BURST 3.1 release/experiment exports; never launches Godot."""

import argparse
import hashlib
import io
import json
import re
import shutil
import struct
import subprocess
import sys
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
BUILDS = ROOT / 'builds'
ARCHIVE = BUILDS / 'RCD-ORBIT30.exe'
ARCHIVE_SHA = 'a56f2d1622d7d31de74d4923ade5aa85b80b114b4c75c3346e0d2a49f1e165bc'
# Key: stage project, preset, staged entry point, public destination.
TARGETS = {
    'DEV': ('dev', 'BURST 3.1 Dev', 'scenes/front/title.tscn', 'RCD-DEV-3.1.exe'),
    'A': ('trial-01', 'BURST 3.1 Test 01', 'tools/corner_evidence_a.tscn', 'RCD-TEST/RCD-TEST-01.exe'),
    'B': ('trial-02', 'BURST 3.1 Test 02', 'tools/corner_evidence_b.tscn', 'RCD-TEST/RCD-TEST-02.exe'),
}
TRIAL_SCRIPTS = {f'tools/trial_{name}.gd' for name in ('build', 'consent', 'controller', 'recorder')}
REQUIRED_RAW = {'data/case.json', 'data/routes.json', 'data/studio_map.json', 'assets/fonts/OFL.txt'}
CONFIG = 'tools/trial_build_config.json'
DEV_USER = 'ROLL CUT DIE/Dev-3.1'


def require(ok, msg):
    if not ok:
        raise ValueError(msg)


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])


def sha(data):
    return hashlib.sha256(data).hexdigest()


def fingerprint(file):
    with file.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def check_archive():
    require(ARCHIVE.is_file() and fingerprint(ARCHIVE) == ARCHIVE_SHA,
            f'Original archive missing or modified: {ARCHIVE}')


def json_bytes(obj):
    return (json.dumps(obj, indent=2, ensure_ascii=False) + '\n').encode('utf-8')


def job(label):
    require(re.fullmatch(r'[a-z0-9][a-z0-9_-]{0,55}', label), 'Invalid staging label')
    path = BUILDS / '.burst31' / label
    require(path.resolve() == path, f'Staging path resolves elsewhere: {path}')
    return path


def change_setting(text, section, key, value):
    header = re.search(rf'^\[{re.escape(section)}\]\s*$', text, re.M)
    if header is None:
        require(value is not None, f'Missing [{section}]')
        return text.rstrip() + f'\n\n[{section}]\n\n{key}={value}\n'
    start = header.end()
    next_header = re.search(r'^\[', text[start:], re.M)
    end = start + next_header.start() if next_header else len(text)
    body = text[start:end]
    rx = rf'^[ \t]*{re.escape(key)}=[^\n]*(?:\n|$)'
    replacement = '' if value is None else f'{key}={value}\n'
    body, count = re.subn(rx, lambda _: replacement, body, flags=re.M)
    require(count <= 1, f'Duplicate setting [{section}] {key}')
    if not count and replacement:
        body = '\n' + body.strip('\n') + '\n' + replacement + '\n'
    return text[:start] + body + text[end:]


def snapshot(ref):
    commit = git('rev-parse', '--verify', '--end-of-options', f'{ref}^{{commit}}').decode().strip()
    for needed in ('b96a483', 'd918a06', '2a5a45e'):
        require(subprocess.run(['git', '-C', str(ROOT), 'merge-base', '--is-ancestor', needed, commit]).returncode == 0,
                f'Snapshot must include {needed}')
    content = {}
    with zipfile.ZipFile(io.BytesIO(git('archive', '--format=zip', commit))) as archive:
        for entry in archive.infolist():
            if entry.is_dir():
                continue
            name = entry.filename
            path = PurePosixPath(name)
            require(not path.is_absolute() and '..' not in path.parts and '\\' not in name,
                    f'Invalid archive path: {name}')
            if name in ('project.godot', 'export_presets.cfg', 'icon.svg', 'icon.svg.import') or (
                path.parts[0] in {'assets', 'data', 'scenes', 'scripts'}
            ) or name in TRIAL_SCRIPTS | {'tools/corner_evidence.gd', TARGETS['A'][2], TARGETS['B'][2]}:
                require((entry.external_attr >> 16) & 0o170000 != 0o120000, f'Symlink in source: {name}')
                content[name] = archive.read(entry)
    required = REQUIRED_RAW | TRIAL_SCRIPTS | {'project.godot', 'export_presets.cfg', 'icon.svg',
               'assets/fonts/RCD-Noto.otf', 'tools/corner_evidence.gd'} | {target[2] for target in TARGETS.values()}
    require(required <= content.keys(), f'Missing required files: {required - content.keys()}')
    return commit, content


def build_inputs(content, condition, commit, label):
    folder, preset_name, scene, _ = TARGETS[condition]
    trial = condition != 'DEV'
    user_dir = (f'RCD-Research/isolated/{sha(f"{commit}:{label}:{condition}".encode())[:32]}'
                if trial else DEV_USER)
    project = content['project.godot'].decode('utf-8').replace('\r\n', '\n')
    require(not re.search(r'^\[research\]|McpInteractionServer|res://autoload/', project, re.M),
            'Snapshot unexpectedly enables research or debug tooling')
    project = change_setting(project, 'application', 'run/main_scene', f'"res://{scene}"')
    project = change_setting(project, 'application', 'config/use_custom_user_dir', 'true')
    project = change_setting(project, 'application', 'config/custom_user_dir_name', f'"{user_dir}"')
    if trial:
        for key in ('file_logging/enable_file_logging', 'file_logging/enable_file_logging.pc'):
            project = change_setting(project, 'debug', key, 'false')
        project = change_setting(project, 'research', 'west_trial/enabled', 'true')
        project = change_setting(project, 'research', 'west_trial/git_commit', f'"{commit}"')
    project_bytes = project.encode('utf-8')
    files = {name: data for name, data in content.items() if name not in ('project.godot', 'export_presets.cfg')
             and (not name.startswith('tools/') or (trial and (name in TRIAL_SCRIPTS or name in (scene, 'tools/corner_evidence.gd'))))}
    includes = sorted(name for name in files if name.startswith('data/') and name.endswith('.json'))
    includes += ['assets/fonts/OFL.txt']
    config_sha = None
    if trial:
        files[CONFIG] = json_bytes({'condition': condition, 'git_commit': commit,
                                    'project_godot_sha256': sha(project_bytes)})
        config_sha = sha(files[CONFIG])
        includes += [CONFIG]
    candidate = f'{folder}-candidate.exe'
    preset = content['export_presets.cfg'].decode('utf-8').replace('\r\n', '\n')
    require(re.findall(r'^\[preset\.(\d+)\]', preset, re.M) == ['0'], 'Expected one source preset')
    for key, value in {
        'name': f'"{preset_name}"', 'platform': '"Windows Desktop"', 'export_filter': '"all_resources"',
        'include_filter': json.dumps(', '.join(includes)), 'exclude_filter': '"autoload/*, tests/*, shots/*"',
        'export_path': f'"../candidates/{candidate}"', 'encrypt_pck': 'false', 'encrypt_directory': 'false',
    }.items():
        preset = change_setting(preset, 'preset.0', key, value)
    for key, value in {'binary_format/embed_pck': 'true', 'debug/export_console_wrapper': '0',
                       'binary_format/architecture': '"x86_64"'}.items():
        preset = change_setting(preset, 'preset.0.options', key, value)
    files.update({'project.godot': project_bytes, 'export_presets.cfg': preset.encode('utf-8')})
    meta = {'project': folder, 'preset': preset_name, 'candidate': f'candidates/{candidate}',
            'entry_scene': f'res://{scene}', 'user_dir': user_dir, 'project_godot_sha256': sha(project_bytes),
            'preset_sha256': sha(files['export_presets.cfg']), 'config_sha256': config_sha}
    return files, meta


def stage(ref, label):
    check_archive()
    base = job(label)
    require(not base.exists(), f'Staging already exists: {base}')
    commit, content = snapshot(ref)
    planned = {k: build_inputs(content, k, commit, label) for k in TARGETS}
    base.mkdir(parents=True, exist_ok=False)
    (base / 'candidates').mkdir()
    for files, meta in planned.values():
        project = base / meta['project']
        (project / 'builds').mkdir(parents=True)
        for name, data in files.items():
            path = project / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    (base / 'staging.json').write_bytes(json_bytes({'git_commit': commit, 'targets': {k: v[1] for k, v in planned.items()}}))
    print(json.dumps({k: {'project_path': str(base / meta['project']), 'preset_name': meta['preset'],
                          'output_path': str(base / meta['candidate'])} for k, (_, meta) in planned.items()}, indent=2))


def pack_index(blob):
    require(blob[:2] == b'MZ', 'Export is not a Windows executable')
    pe, = struct.unpack_from('<I', blob, 60)
    require(blob[pe:pe+6] == b'PE\0\0\x64\x86', 'Export is not Windows x64 PE')
    count, = struct.unpack_from('<H', blob, pe + 6)
    opt, = struct.unpack_from('<H', blob, pe + 20)
    start = None
    for i in range(count):
        pos = pe + 24 + opt + 40 * i
        if blob[pos:pos+8].rstrip(b'\0') == b'pck':
            ofs, = struct.unpack_from('<I', blob, pos + 20)
            start = next((i for i in range(ofs, ofs+8) if blob[i:i+4] == b'GDPC'), None)
            break
    require(start is not None, 'No embedded PCK in PE')
    version, major, minor, patch, flags, file_base = struct.unpack_from('<IIIIIQ', blob, start + 4)
    require((version, major, minor) == (2, 4, 3) and flags in (0, 2),
            f'Expected unencrypted Godot 4.3 PCK v2; got {(version, major, minor, patch, flags)}')
    if flags == 2:
        file_base += start
    count, = struct.unpack_from('<I', blob, start + 96)
    pos = start + 100
    require(0 < count < 100_000 and pos < file_base <= len(blob), 'Invalid embedded PCK index')
    index = {}
    for _ in range(count):
        n, = struct.unpack_from('<I', blob, pos)
        require(0 < n < 8192 and pos + 40 + n <= file_base, 'Invalid embedded PCK filename')
        name = blob[pos+4:pos+4+n].rstrip(b'\0').decode().removeprefix('res://')
        offset, size, md5, entry_flags = struct.unpack_from('<QQ16sI', blob, pos + 4 + n)
        require(not entry_flags and name not in index and file_base + offset + size <= len(blob),
                f'Invalid embedded PCK entry: {name}')
        data = blob[file_base+offset:file_base+offset+size]
        require(hashlib.md5(data, usedforsecurity=False).digest() == md5, f'Corrupt PCK entry: {name}')
        index[name] = data
        pos += 40 + n
    return index


def project_settings(blob):
    require(blob.startswith(b'ECFG'), 'Missing project.binary')
    count, = struct.unpack_from('<I', blob, 4)
    require(count <= 10_000, 'Invalid project.binary settings count')
    settings = {}
    pos = 8
    for _ in range(count):
        n, = struct.unpack_from('<I', blob, pos)
        pos += 4
        key = blob[pos:pos+n].decode('utf-8')
        pos += n
        size, = struct.unpack_from('<I', blob, pos)
        pos += 4
        require(key not in settings and size >= 4 and pos + size <= len(blob), 'Invalid project.binary entry')
        data = blob[pos:pos+size]
        pos += size
        kind, = struct.unpack_from('<I', data)
        if kind in (1, 4):
            value, = struct.unpack_from('<I', data, 4)
            if kind == 1:
                require(size == 8 and value in (0, 1), 'Invalid project.binary bool')
                settings[key] = bool(value)
            else:
                require(size >= 8 + value and size <= 11 + value, 'Invalid project.binary string')
                settings[key] = data[8:8+value].decode('utf-8')
        else:
            settings[key] = data
    require(pos == len(blob), 'Unexpected project.binary trailer')
    return settings


def verify_pack(index, files, meta, condition):
    raw = {path for path in files if path.startswith('data/') and path.endswith('.json')} | {'assets/fonts/OFL.txt'}
    if condition != 'DEV':
        raw.add(CONFIG)
    for path in raw:
        require(index.get(path) == files[path], f'Missing or changed raw packed resource: {path}')
    for name in index:
        require('mcp_interaction' not in name.lower(), f'Debug resource in pack: {name}')
        if name == 'project.binary' or name.startswith(('.godot/imported/', '.godot/exported/')) or name in (
            '.godot/global_script_class_cache.cfg', '.godot/uid_cache.bin',
        ):
            continue
        source = name.removesuffix('.remap')
        if source.endswith('.gdc'):
            source = source[:-1]
        require(source in files or source.removesuffix('.import') in files, f'Unexpected resource in pack: {name}')
    font = 'assets/fonts/RCD-Noto.otf'
    font_remap = index.get(font + '.import', b'')
    imported_font = re.search(rb'^path="res://([^"\r\n]+)"', font_remap, re.M)
    require(index.get(font) == files[font] or (imported_font and index.get(imported_font[1].decode())),
            'Font bytes missing from embedded pack')
    for path in (meta['entry_scene'].removeprefix('res://'), 'scenes/main/main.tscn'):
        require(any(name in index for name in (path, path + '.remap', path + '.import')), f'Missing packed resource: {path}')
    if condition != 'DEV':
        for path in TRIAL_SCRIPTS | {'tools/corner_evidence.gd'}:
            require(any(name in index for name in (path, path + '.remap', path + 'c')), f'Missing trial script: {path}')
    settings = project_settings(index.get('project.binary', b''))
    expected = {'application/run/main_scene': meta['entry_scene'], 'application/config/use_custom_user_dir': True,
                'application/config/custom_user_dir_name': meta['user_dir'],
                'gui/theme/custom_font': 'res://assets/fonts/RCD-Noto.otf'}
    if condition != 'DEV':
        expected.update({'research/west_trial/enabled': True,
                         'research/west_trial/git_commit': json.loads(files[CONFIG])['git_commit'],
                         'debug/file_logging/enable_file_logging.pc': False})
        # Godot strips the base value if it is identical to the engine default.
        require(settings.get('debug/file_logging/enable_file_logging', False) is False,
                'Engine logging is enabled in trial')
    else:
        require(not any(key.startswith('research/') for key in settings), 'Research enabled in DEV')
    for key, value in expected.items():
        require(settings.get(key) == value, f'Unexpected packaged project setting: {key}: {settings.get(key)!r}')
    require({key: value for key, value in settings.items() if key.startswith('autoload/')} == {
        'autoload/GameSession': '*res://scripts/core/game_session.gd'}, 'Unexpected autoload in pack')


def check_stage(label):
    check_archive()
    base = job(label)
    receipt = json.loads((base / 'staging.json').read_bytes())
    commit, source = snapshot(receipt['git_commit'])
    builds = {}
    for condition, (_, _, _, final) in TARGETS.items():
        files, meta = build_inputs(source, condition, commit, label)
        require(meta == receipt['targets'][condition], f'Mismatched staging receipt: {condition}')
        for name, data in files.items():
            require((base / meta['project'] / name).read_bytes() == data, f'Modified staging input: {condition}/{name}')
        candidate = base / meta['candidate']
        require(not candidate.is_symlink() and candidate.resolve() == candidate, f'Unsafe candidate path: {candidate}')
        blob = candidate.read_bytes()
        index = pack_index(blob)
        verify_pack(index, files, meta, condition)
        builds[condition] = {**meta, 'file': f'builds/{final}', 'exe_sha256': sha(blob), 'bytes': len(blob),
                             'packed_files': sorted(index)}
    return base, {'schema': 'rcd-burst31-build-v1', 'git_commit': commit, 'stage': label,
                  'historical_exe_sha256': ARCHIVE_SHA, 'targets': builds}


def copy_new(base, manifest, candidate_set=False):
    manifest_path = base / ('candidate-manifest.json' if candidate_set else 'final-manifest.json')
    if candidate_set:
        for item in manifest['targets'].values():
            item['file'] = (base / 'delivery' / item['file'].removeprefix('builds/')).relative_to(ROOT).as_posix()
    destinations = [(base / item['candidate'], ROOT / item['file'], item['exe_sha256'])
                    for item in manifest['targets'].values()]
    for dest in [manifest_path, *(item[1] for item in destinations)]:
        require(dest.resolve() == dest and not dest.exists(), f'Refusing to overwrite or follow redirect: {dest}')
    created = []
    try:
        for src, dest, expected_sha in destinations:
            dest.parent.mkdir(parents=True, exist_ok=True)
            with src.open('rb') as stream, dest.open('xb') as output:
                created.append(dest)
                shutil.copyfileobj(stream, output)
            require(fingerprint(dest) == expected_sha, f'Promoted file hash differs: {dest}')
        check_archive()
        with manifest_path.open('xb') as output:
            created.append(manifest_path)
            output.write(json_bytes(manifest))
    except Exception:
        for dest in reversed(created):
            dest.unlink()
        raise
    print(manifest_path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest='action', required=True)
    create = subs.add_parser('stage')
    create.add_argument('--ref', required=True)
    create.add_argument('--label', required=True)
    for action in ('verify', 'finalize', 'deliver-candidates'):
        sub = subs.add_parser(action)
        sub.add_argument('--label', required=True)
    args = parser.parse_args()
    try:
        if args.action == 'stage':
            stage(args.ref, args.label)
        else:
            base, manifest = check_stage(args.label)
            if args.action == 'verify':
                sys.stdout.buffer.write(json_bytes(manifest))
            else:
                copy_new(base, manifest, candidate_set=args.action == 'deliver-candidates')
    except (OSError, ValueError, KeyError, struct.error, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Build failed: {error}\n')


if __name__ == '__main__':
    main()
