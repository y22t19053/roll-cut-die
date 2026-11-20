"""Read one explicitly supplied, finalized west-corner-v1 trial.jsonl; print JSON.

Times are observed event/sample offsets (microseconds), not interpolated physics
or a measure of comprehension. For ties, file order decides. Both intervals start
at the first positive contact sample and are measured independently until outcome.
Null = unknown/not observed. Exit 0: valid envelope, 1: missing evidence,
2: invalid or unreadable. An unobserved endpoint alone is not a damaged log.
"""
import argparse
import json
import math
from pathlib import Path
import re


SCHEMA = 'west-corner-v1'
SOURCES = ('synthetic_QA', 'operator_opt_in')
LATERAL = {'A', 'D', 'LEFT', 'RIGHT'}
KEYS = LATERAL | {'W', 'S', 'UP', 'DOWN', 'E'}
REASONS = ('hint_required', 'operator_stop', 'collected', 'focus_lost', 'scene_exit', 'time_limit')
# B3-B/1, tools/corner_evidence.gd: A and B share a wall, B adds three marks.
WALL = [0.4, 6.0, 3.35, 6.35]
PAINT = [[2.66, 6.90, 2.74, 7.55], [2.70, 6.86, 4.04, 6.94], [4.00, 5.65, 4.08, 6.90]]


def matches(actual, expected):
    if isinstance(expected, list):
        return (isinstance(actual, list) and len(actual) == len(expected)
                and all(matches(a, b) for a, b in zip(actual, expected)))
    return type(actual) in (int, float) and math.isclose(actual, expected, rel_tol=0, abs_tol=1e-6)


def unique_fields(pairs):
    fields = dict(pairs)
    if len(fields) != len(pairs):
        raise ValueError('duplicate JSON field')
    return fields


def analyze(path, condition=None, source=None, config_sha256=None, expected_session=None):
    r = dict(status='ok', condition=None, source=None, session=None, reason=None,
             script_page_taken=None, first_contact_us=None, first_lateral_key=None,
             contact_to_lateral_us=None, contact_to_release_us=None,
             first_lateral_before_observed_release=None,
             participant_identity=None, comprehension=None, issues=[])
    clock_ok = True
    first_contact_possible = lateral_possible = release_possible = True
    last = {'frame': -1, 't_us': -1}
    # Count observed recontacts only, not failed attempts or inferred intent.
    previous_contact = None
    recontacts = 0
    contact_series_complete = True
    # Preserve off-protocol trials; do not pool them with confirmed ORBIT30.
    orbit_rate = None
    saw_mode = missing_mode = non_orbit = False
    lateral_line = release_line = None
    ended = False
    n = 0

    def issue(status, text):
        if r['status'] != 'invalid':
            r['status'] = status
        if len(r['issues']) < 24:
            r['issues'].append(f'line {n}: {text}')

    def field(row, name, check):
        if name not in row:
            issue('unknown', f'missing {name}')
        elif not check(row[name]):
            issue('invalid', f'invalid {name}')
        else:
            return row[name]
        return None

    try:
        path = Path(path)
        if path.name != 'trial.jsonl' or path.is_symlink() or path.resolve().name != 'trial.jsonl':
            raise ValueError('expected a finalized trial.jsonl, not a partial file or file link')
        with path.open(encoding='utf-8') as stream:
            for n, line in enumerate(stream, 1):
                row = json.loads(line, object_pairs_hook=unique_fields, parse_constant=reject_constant)
                if not isinstance(row, dict):
                    raise ValueError('expected JSON object')
                kind = row.get('type')
                if ended or ((n == 1) != (kind == 'header')):
                    raise ValueError('expected single initial header and final outcome')
                for k in last:
                    value = field(row, k, lambda x: type(x) is int and x >= 0)
                    if value is None:
                        clock_ok = False
                    elif value < last[k]:
                        raise ValueError(f'non-monotonic {k}')
                    else:
                        last[k] = value
                t = row.get('t_us') if clock_ok else None
                if kind == 'header':
                    field(row, 'schema', lambda x: x == SCHEMA)
                    r['session'] = field(row, 'session', lambda x: isinstance(x, str) and re.fullmatch('[0-9a-f]{32}', x))
                    if expected_session is not None and r['session'] is not None and r['session'] != expected_session:
                        issue('invalid', 'session differs from the ID noted at recording start')
                    c = r['condition'] = field(row, 'condition', lambda x: x in ('A', 'B'))
                    s = r['source'] = field(row, 'source', lambda x: x in SOURCES)
                    if condition and c and c != condition:
                        issue('invalid', 'condition differs from expected')
                    if source and s and s != source:
                        issue('invalid', 'source differs from expected')
                    cfg = field(row, 'config', lambda x: isinstance(x, dict))
                    if cfg is not None:
                        field(cfg, 'protocol', lambda x: x == 'B3-B/1')
                        if config_sha256 is not None or 'project_config_sha256' in cfg:
                            digest = field(cfg, 'project_config_sha256', lambda v: isinstance(v, str) and re.fullmatch('[0-9a-f]{64}', v))
                            if digest and config_sha256 is not None and digest != config_sha256:
                                issue('invalid', 'project configuration differs from preparation receipt')
                        orbit_rate = cfg.get('orbit_deg_s')
                        field(cfg, 'wall_xz', lambda x: matches(x, WALL))
                        if c:
                            field(cfg, 'paint_xz', lambda x: matches(x, PAINT if c == 'B' else []))
                elif kind == 'sample':
                    mode = row.get('roll_mode')
                    if type(mode) is not int or mode not in (0, 1, 2):
                        missing_mode = True
                    else:
                        saw_mode = True
                        non_orbit |= mode != 2
                    hit = field(row, 'wall_contact', lambda x: type(x) is bool)
                    if hit is None:
                        contact_series_complete = False
                    elif hit and previous_contact is False and r['first_contact_us'] is not None:
                        recontacts += 1
                    previous_contact = hit
                    if r['first_contact_us'] is None:
                        if hit is None:
                            first_contact_possible = False
                        elif first_contact_possible and hit:
                            r['first_contact_us'] = t
                    elif r['contact_to_release_us'] is None:
                        if hit is None:
                            release_possible = False
                        elif release_possible and not hit and t is not None:
                            r['contact_to_release_us'] = t - r['first_contact_us']
                            release_line = n
                elif kind == 'key':
                    key = field(row, 'key', lambda x: isinstance(x, str) and x in KEYS)
                    down = field(row, 'pressed', lambda x: type(x) is bool)
                    if r['first_contact_us'] is not None and r['first_lateral_key'] is None:
                        if (key is None or key in LATERAL) and down is not False:
                            if key is None or down is None:
                                lateral_possible = False
                            elif lateral_possible and t is not None:
                                lateral_line = n
                                r['first_lateral_key'] = key
                                r['contact_to_lateral_us'] = t - r['first_contact_us']
                elif kind == 'outcome':
                    ended = True
                    reason = r['reason'] = field(row, 'reason', lambda x: x in REASONS)
                    taken = r['script_page_taken'] = field(row, 'script_page_taken', lambda x: type(x) is bool)
                    if reason and taken is not None and taken != (reason == 'collected'):
                        issue('invalid', 'outcome contradicts script_page_taken')
                else:
                    raise ValueError('unrecognized record type')
        if not ended:
            raise ValueError('missing final outcome; not a finalized stream')
    except (ValueError, OSError, OverflowError, RecursionError) as error:
        issue('invalid', str(error))
    if r['status'] == 'invalid' or not clock_ok:
        for k in ('first_contact_us', 'first_lateral_key', 'contact_to_lateral_us', 'contact_to_release_us'):
            r[k] = None
    elif lateral_line is not None and release_line is not None:
        # File order disambiguates equal clocks; this is observation order, not causation.
        r['first_lateral_before_observed_release'] = lateral_line < release_line
    r['observed_wall_recontacts'] = (recontacts if r['status'] != 'invalid' and clock_ok
                                     and contact_series_complete and r['first_contact_us'] is not None else None)
    rate_known = type(orbit_rate) in (int, float)
    r['orbit30_observation'] = ('unknown' if r['status'] == 'invalid' else
                                'off_protocol' if non_orbit or (rate_known and orbit_rate != 30) else
                                'matched_samples' if saw_mode and not missing_mode and rate_known else 'unknown')
    return r


def reject_constant(_):
    raise ValueError('non-finite JSON constant')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('trial', type=Path)
    p.add_argument('--condition', choices=('A', 'B'), help='expected condition')
    p.add_argument('--source', choices=SOURCES, help='expected recorder label; not identity verification')
    p.add_argument('--config-sha256', help='expected project_config_sha256 from the preparation receipt')
    p.add_argument('--session', help='expected anonymous ID noted at F8, not the participant code')
    args = p.parse_args()
    if args.session is not None and not re.fullmatch('[0-9a-f]{32}', args.session):
        p.error('--session must be the 32 lowercase hexadecimal digits shown at F8')
    if args.config_sha256 is not None and not re.fullmatch('[0-9a-fA-F]{64}', args.config_sha256):
        p.error('--config-sha256 must be a 64-digit hexadecimal digest')
    report = analyze(args.trial, args.condition, args.source, args.config_sha256.lower() if args.config_sha256 else None, args.session)
    print(json.dumps(report, indent=2))
    return {'ok': 0, 'unknown': 1, 'invalid': 2}[report['status']]


if __name__ == '__main__':
    raise SystemExit(main())
