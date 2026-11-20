"""Deterministic observer tests. No Windows handles, real focus or trial files."""
import unittest

from tools.observe_trial_focus import observe


class FocusObserverTests(unittest.TestCase):
    def replay(self, states):
        now = [0.0]
        feed = iter(states)
        rows = []

        def advance(dt):
            now[0] += dt

        verdict = observe(lambda: next(feed), rows.append, .025 * (len(states) - .5),
                          clock=lambda: now[0], sleep=advance)
        return verdict, [row['game_foreground'] for row in rows]

    def test_other_without_prior_game_does_not_prove_loss(self):
        self.assertEqual(self.replay([None, False, False]),
                         ('GAME_NEVER_CONFIRMED_FOREGROUND', [None, False]))

    def test_unavailable_owner_after_game_is_not_a_switch(self):
        self.assertEqual(self.replay([True, True, None, None]),
                         ('NO_CONFIRMED_LOSS', [True, None]))

    def test_unknown_gap_allowed_but_both_owners_must_be_observed(self):
        self.assertEqual(self.replay([False, True, None, False, True]),
                         ('OBSERVED_GAME_TO_OTHER', [False, True, None, False]))
