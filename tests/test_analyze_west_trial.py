"""Synthetic in-memory recorder streams only; never access a real trial or save."""
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from tools import analyze_west_trial as trial


def row(kind, t, frame=0, **fields):
    return dict(type=kind, t_us=t, frame=frame, **fields)


def header(c='B', source='synthetic_QA'):
    return row('header', 0, schema='west-corner-v1', session='ab'*16,
               condition=c, source=source, config=dict(protocol='B3-B/1',
               wall_xz=[0.4, 6, 3.35, 6.35], paint_xz=[] if c == 'A' else
               [[2.66, 6.90, 2.74, 7.55], [2.70, 6.86, 4.04, 6.94], [4.00, 5.65, 4.08, 6.90]]))


def sample(t, hit):
    return row('sample', t, wall_contact=hit)


def key(t, name, down=True):
    return row('key', t, key=name, pressed=down)


def outcome():
    return row('outcome', 500, reason='operator_stop', script_page_taken=False)


def report(*rows, **kwargs):
    raw = '\n'.join(x if isinstance(x, str) else json.dumps(x) for x in rows)
    with patch.object(Path, 'open', return_value=io.StringIO(raw)) as op:
        result = trial.analyze(Path('trial.jsonl'), **kwargs)
        op.assert_called_once_with(encoding='utf-8')
        return result


class WestTrialTests(unittest.TestCase):
    def test_receipt_digest_is_optional_for_archives_but_never_inferred(self):
        h = header()
        self.assertEqual('ok', report(h, outcome())['status'])
        self.assertEqual('unknown', report(h, outcome(), config_sha256='a'*64)['status'])
        for stored, status in [('a'*64, 'ok'), ('b'*64, 'invalid'), ('bad', 'invalid')]:
            h['config']['project_config_sha256'] = stored
            self.assertEqual(status, report(h, outcome(), config_sha256='a'*64)['status'])

    def test_independent_first_observations(self):
        r = report(header(), key(9, 'D'), sample(10, False), sample(20, True),
                   key(20, 'D', False), key(21, 'UP'), sample(22, True),
                   sample(29, False), sample(30, True), key(35, 'RIGHT'), key(45, 'A'), outcome())
        self.assertEqual(('ok', 20, 'RIGHT', 15, 9), tuple(r[k] for k in
                         ('status', 'first_contact_us', 'first_lateral_key', 'contact_to_lateral_us', 'contact_to_release_us')))

    def test_observed_recontacts_not_inferred_attempts(self):
        for hits, expected in [([], None), ([False], None), ([True, True], 0),
                               ([False, True, False, False, True, True, False, True], 2)]:
            r = report(header(), *(sample(i, hit) for i, hit in enumerate(hits)), outcome())
            self.assertEqual(expected, r['observed_wall_recontacts'])
        for bad in [row('sample', 2), sample(2, 1), row('key', -1)]:
            self.assertIsNone(report(header(), sample(1, True), bad, outcome())['observed_wall_recontacts'])

    def test_only_confirm_orbit30_on_known_samples_and_rate(self):
        for rate, modes, expected in [(30,[2,2],'matched_samples'), (30,[2,1,2],'off_protocol'),
                (45,[2],'off_protocol'), (30,[],'unknown'), (None,[2],'unknown'),
                (30,[2,None],'unknown'), (30,[True],'unknown')]:
            h = header(); h['config']['orbit_deg_s'] = rate
            rows = [dict(sample(i, False), roll_mode=m) for i,m in enumerate(modes)]
            r = report(h, *rows, outcome())
            self.assertEqual((r['status'], r['orbit30_observation']), ('ok', expected))

    def test_ties_frame_and_file_order(self):
        for name in ('A', 'D', 'LEFT', 'RIGHT'):
            r = report(header('A'), key(10, 'W'), key(10, 'D'), sample(10, True), key(10, name), sample(10, False), outcome())
            self.assertEqual((name, 0, 0), (r['first_lateral_key'], r['contact_to_lateral_us'], r['contact_to_release_us']))

    def test_lateral_order_is_not_recovery_attribution(self):
        for events, expected in [([key(10,'D'), sample(10,False)], True),
                                 ([sample(10,False), key(10,'D')], False),
                                 ([key(10,'D')], None), ([sample(10,False)], None),
                                 ([key(10,'D'), sample(10,False), key(3,'A')], None)]:
            r = report(header(), sample(9,True), *events, outcome())
            self.assertIs(expected, r['first_lateral_before_observed_release'])

    def test_unobserved_and_censored(self):
        for samples in [[], [sample(5, False)], [sample(5, True)]]:
            r = report(header(), *samples, outcome())
            self.assertEqual('ok', r['status'])
            self.assertIsNone(r['contact_to_release_us'])
            self.assertIsNone(r['contact_to_lateral_us'])
        r = report(header(), sample(5, True), key(9, 'D'), outcome())
        self.assertEqual(4, r['contact_to_lateral_us'])
        self.assertIsNone(r['contact_to_release_us'])

    def test_missing_observation_cannot_be_skipped(self):
        r = report(header(), row('sample', 1), sample(5, True), key(6, 'D'), outcome())
        self.assertIsNone(r['first_contact_us'])
        r = report(header(), sample(3, True), row('key', 4, key='D'), key(6, 'D'), row('sample', 7), sample(8, False), outcome())
        self.assertEqual('unknown', r['status'])
        self.assertIsNone(r['contact_to_release_us'])
        self.assertIsNone(r['contact_to_lateral_us'])

    def test_source_is_only_a_recorder_label(self):
        for source in ('operator_opt_in', 'synthetic_QA'):
            r = report(header('A', source), outcome(), condition='A', source=source)
            self.assertEqual(('ok', source, None, None), (r['status'], r['source'], r['participant_identity'], r['comprehension']))
        h = header(); del h['source']
        r = report(h, outcome())
        self.assertEqual(('unknown', None), (r['status'], r['source']))

    def test_reject_condition_and_source_conflicts(self):
        a = header('A'); a['config']['paint_xz'] = header()['config']['paint_xz']
        b = header(); b['config']['wall_xz'][1] = 7
        for h, options in [(a, {}), (b, {}), (header(), {'condition':'A'}), (header(), {'source':'operator_opt_in'})]:
            self.assertEqual('invalid', report(h, outcome(), **options)['status'])

    def test_timing_and_types_fail_closed(self):
        for bad in [dict(key(4, 'D'), frame=1), dict(key(5, 'D'), frame=-1), dict(key(5, 'D'), frame=0),
                    dict(sample(6, 0), frame=1), dict(key(6, 'D', 1), frame=1),
                    dict(key(6, 'F8'), frame=1), dict(key(True, 'D'), frame=1)]:
            r = report(header(), dict(sample(5, True), frame=1), bad, dict(outcome(), frame=2))
            self.assertEqual('invalid', r['status'])
            self.assertIsNone(r['first_contact_us'])
        r = report(header(), {'type':'sample', 'frame':0, 'wall_contact':True}, outcome())
        self.assertEqual('unknown', r['status'])
        self.assertIsNone(r['first_contact_us'])

    def test_reject_broken_envelope_json_and_outcome(self):
        for rows in [[], [header()], [outcome()], [header(), header(), outcome()], [header(), outcome(), sample(8, False)],
                     [header(), outcome(), outcome()], [header(), '{', outcome()], [header(), 'null', outcome()],
                     [header(), '{"type":"key","type":"outcome"}'], [header(), dict(outcome(), reason='collected')]]:
            self.assertEqual('invalid', report(*rows)['status'])

    def test_only_accept_sealed_filename(self):
        with patch.object(Path, 'open') as opened:
            for name in ('trial.partial', 'save.json', '.'):
                self.assertEqual('invalid', trial.analyze(name)['status'])
            opened.assert_not_called()


if __name__ == '__main__':
    unittest.main()
