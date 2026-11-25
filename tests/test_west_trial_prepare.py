"""Fail closed even under python -O; no real participant or save needed."""
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from west_trial_operator import isolated_config


class Prepare(unittest.TestCase):
    original = (ROOT / 'project.godot').read_text('utf-8')
    token = '0123456789abcdef' * 2
    scene = 'run/main_scene="res://scenes/front/title.tscn"'
    legacy_scene = 'run/main_scene="res://scenes/main/main.tscn"'

    def test_prepared_receipt_describes_actual_config_without_starting_game(self):
        with tempfile.TemporaryDirectory() as tmp:
            scratch = Path(tmp)
            env = dict(os.environ, LOCALAPPDATA=str(scratch / 'local'), APPDATA=str(scratch / 'roaming'))
            rev = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
            seen_dirs = set()
            for arm in ('A', 'B'):
                output = subprocess.check_output([sys.executable, str(ROOT / 'tools/west_trial_operator.py'),
                                                  'prepare', arm], env=env, text=True)
                project = Path(output.strip())
                receipt = json.loads((project.parent / 'operator.json').read_text('utf-8'))
                cfg = (project / 'project.godot').read_bytes()
                self.assertEqual(receipt['project_config_sha256'], hashlib.sha256(cfg).hexdigest())
                self.assertEqual((receipt['status'], receipt['condition'], receipt['source']),
                                 ('PREPARED_NOT_A_PARTICIPANT', arm, rev))
                expected = scratch / 'roaming' / 'RCD-Research' / 'isolated' / project.parent.name
                self.assertEqual(Path(receipt['expected_user_dir']), expected)
                self.assertFalse(expected.exists())
                self.assertNotIn(expected, seen_dirs)
                seen_dirs.add(expected)
                self.assertIn(f'corner_evidence_{arm.lower()}.tscn"', cfg.decode('utf-8'))
                self.assertNotIn(b'McpInteractionServer', cfg)

    def test_existing_user_namespace_is_not_reused_or_modified(self):
        from unittest.mock import patch
        import west_trial_operator as op
        import uuid
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            user = base / 'roaming' / 'RCD-Research' / 'isolated' / self.token
            user.mkdir(parents=True)
            marker = user / 'sentinel'
            marker.write_bytes(b'prior data')
            with patch.dict(os.environ, LOCALAPPDATA=str(base/'local'), APPDATA=str(base/'roaming')), patch.object(op.uuid, 'uuid4', return_value=uuid.UUID(self.token)), patch.object(sys, 'argv', ['operator', 'prepare', 'A']), self.assertRaises(SystemExit) as refused:
                op.main()
            self.assertEqual(refused.exception.code, 2)
            self.assertEqual(marker.read_bytes(), b'prior data')
            self.assertFalse((base/'local').exists())

    def test_production_template(self):
        for arm in ('A', 'B'):
            cfg = isolated_config(self.original, arm, self.token)
            self.assertIn('config/use_custom_user_dir=true', cfg)
            self.assertIn(f'RCD-Research/isolated/{self.token}"', cfg)
            self.assertIn(f'corner_evidence_{arm.lower()}.tscn"', cfg)
            self.assertIn('GameSession="*res://scripts/core/game_session.gd"', cfg)
            self.assertNotIn('McpInteractionServer', cfg)
            with self.assertRaises(ValueError):
                isolated_config(cfg, arm, self.token)

    def test_legacy_scene_and_dev_autoload(self):
        template = ('[application]\n' + self.legacy_scene + '\n[autoload]\n'
                    'McpInteractionServer = "*res://debug.gd"\n')
        cfg = isolated_config(template, 'A', self.token)
        self.assertIn('run/main_scene="res://tools/corner_evidence_a.tscn"', cfg)
        self.assertNotIn('debug.gd', cfg)

    def test_refuse_ambiguous_or_preconfigured_template(self):
        for cfg in (self.original.replace(self.scene, ';' + self.scene),
                    self.original.replace(self.scene, self.scene + '\n' + self.legacy_scene),
                    self.original.replace(self.scene, 'run/main_scene="res://unknown.tscn"'),
                    self.original + '\nconfig/use_custom_user_dir=false',
                    self.original + '\nconfig/custom_user_dir_name="shared"',
                    self.original.replace('[autoload]', '[autoload]\nExtra="*res://debug.gd"'),
                    self.original.replace('scripts/core/game_session.gd', 'debug.gd')):
            with self.subTest(cfg=cfg[-55:]), self.assertRaises(ValueError):
                isolated_config(cfg, 'A', self.token)

    def test_invalid_condition_or_namespace(self):
        for arm, token in [('C', self.token), ('A', '../shared'), ('B', self.token.upper())]:
            with self.assertRaises(ValueError):
                isolated_config(self.original, arm, token)


if __name__ == '__main__':
    unittest.main()
