"""Synthetic release receipts; no real executable, user directory or save access."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools import release_preflight as gate


class ReleaseGateTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.local = Path(tmp.name) / 'local'
        self.roaming = Path(tmp.name) / 'roaming'
        token = 'a' * 32
        suffix = Path('RCD-Research') / 'release' / token
        self.game = self.local / suffix / 'game'
        self.game.mkdir(parents=True)
        self.isolated = self.roaming / suffix
        self.exe = self.game / 'RCD-ORBIT30.exe'
        self.exe.write_bytes(b'synthetic release')
        self.cfg = self.game / 'override.cfg'
        self.cfg.write_text('[application]\nconfig/use_custom_user_dir=true\n'
                            f'config/custom_user_dir_name="{suffix.as_posix()}"\n', encoding='utf-8')
        self.receipt = self.game.parent / 'receipt.json'
        sha = gate.digest(self.exe)
        p = patch.object(gate, 'SHA', sha)
        p.start()
        self.addCleanup(p.stop)
        self.receipt.write_text(json.dumps(dict(directory=str(self.game), expected_user_dir=str(self.isolated),
                                sha256=sha, build='6bab995', status='PREPARED_NOT_STARTED',
                                production_save_before='ABSENT')), encoding='utf-8-sig')

    def check(self):
        gate.check(self.receipt, self.local, self.roaming)

    def test_clean_receipt_never_creates_user_directory(self):
        self.check()
        self.assertFalse(self.roaming.exists())

    def test_changed_binary(self):
        self.exe.write_bytes(b'other build')
        with self.assertRaisesRegex(ValueError, 'binary changed'): self.check()

    def test_adjacent_pck(self):
        (self.game / 'RCD-ORBIT30.pck').touch()
        with self.assertRaisesRegex(ValueError, 'directory contents'): self.check()

    def test_wrong_override(self):
        self.cfg.write_text('[application]\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'override'): self.check()

    def test_preexisting_directory_even_if_empty(self):
        self.isolated.mkdir(parents=True)
        with self.assertRaisesRegex(ValueError, 'no longer fresh'): self.check()

    def test_new_save_is_left_intact(self):
        save = self.roaming / 'Godot/app_userdata/roll cut die/rcd/save.json'
        save.parent.mkdir(parents=True)
        save.write_bytes(b'new player progress')
        with self.assertRaisesRegex(ValueError, 'production save changed'): self.check()
        self.assertEqual(save.read_bytes(), b'new player progress')
