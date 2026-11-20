"""Fail closed even under python -O; no real participant or save needed."""
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from west_trial_operator import isolated_config


class Prepare(unittest.TestCase):
    original = (ROOT / 'project.godot').read_text('utf-8')
    token = '0123456789abcdef' * 2
    scene = 'run/main_scene="res://scenes/main/main.tscn"'

    def test_production_template(self):
        for arm in ('A', 'B'):
            cfg = isolated_config(self.original, arm, self.token)
            self.assertIn('config/use_custom_user_dir=true', cfg)
            self.assertIn(f'RCD-Research/isolated/{self.token}"', cfg)
            self.assertIn(f'corner_evidence_{arm.lower()}.tscn"', cfg)

    def test_refuse_ambiguous_or_preconfigured_template(self):
        for cfg in (self.original.replace(self.scene, ';' + self.scene),
                    self.original + '\n' + self.scene,
                    self.original + '\nconfig/use_custom_user_dir=false',
                    self.original + '\nMcpInteractionServer="*res://debug.gd"'):
            with self.subTest(cfg=cfg[-55:]), self.assertRaises(ValueError):
                isolated_config(cfg, 'A', self.token)

    def test_invalid_condition_or_namespace(self):
        for arm, token in [('C', self.token), ('A', '../shared'), ('B', self.token.upper())]:
            with self.assertRaises(ValueError):
                isolated_config(self.original, arm, token)


if __name__ == '__main__':
    unittest.main()
