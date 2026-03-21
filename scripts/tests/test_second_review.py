"""Failing tests for second-pass review fixes."""
import inspect
import os
import sys
import unittest
from datetime import date, datetime, timedelta, timezone
from unittest.mock import MagicMock

import pandas as pd

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import generate_synthetic_data as mod
from generate_synthetic_data import (
    build_subscriptions_df,
    generate_accounts,
    assign_journeys,
    simulate_subscriptions,
    upload_table,
    main,
)
from google.cloud import bigquery


class TestDeadCodeRemoved(unittest.TestCase):

    def test_weighted_choices_not_in_module(self):
        self.assertFalse(hasattr(mod, "weighted_choices"),
                         "weighted_choices is dead code and should be removed")

    def test_user_by_id_not_in_generate_accounts(self):
        src = inspect.getsource(generate_accounts)
        self.assertNotIn("user_by_id", src,
                         "user_by_id is never read — dead dict")

    def test_days_since_signup_not_in_assign_journeys(self):
        src = inspect.getsource(assign_journeys)
        self.assertNotIn("days_since_signup", src,
                         "days_since_signup is never read — dead variable")

    def test_build_subscriptions_df_has_no_accounts_param(self):
        sig = inspect.signature(build_subscriptions_df)
        self.assertNotIn("accounts", sig.parameters,
                         "accounts param is never used inside build_subscriptions_df")

    def test_upload_table_no_json_string_swap(self):
        src = inspect.getsource(upload_table)
        self.assertNotIn("load_schema", src,
                         "JSON→STRING load_schema swap was removed — schema passed through directly")


class TestSimulateSubscriptionsUsesDict(unittest.TestCase):
    """O(n) user scan replaced with O(1) dict lookup."""

    def test_simulate_subscriptions_source_uses_user_dict(self):
        src = inspect.getsource(simulate_subscriptions)
        self.assertIn("user_dict", src,
                      "simulate_subscriptions should use a dict for O(1) user lookup")

    def test_simulate_subscriptions_correctness(self):
        """Regression: dict lookup must produce same results as linear scan."""
        rng_state = mod.rng
        mod.rng = mod.np.random.default_rng(42)
        try:
            users = mod.generate_users(200)
            users = assign_journeys(users)
            accounts = generate_accounts(users)
            account_subs = simulate_subscriptions(users, accounts)

            # Basic sanity: all owner_user_ids in account_subs are real user_ids
            user_ids = {u["user_id"] for u in users}
            for acct_id, sub_info in account_subs.items():
                self.assertIn(sub_info["owner_user_id"], user_ids)
                self.assertTrue(len(sub_info["lifecycle"]) > 0)
        finally:
            mod.rng = rng_state


class TestBannerOutputLabel(unittest.TestCase):

    def test_banner_says_output_not_tables(self):
        src = inspect.getsource(main)
        self.assertNotIn('"  Tables:', src,
                         "Banner label should say 'Output:' not 'Tables:'")
        self.assertIn("Output:", src)


if __name__ == "__main__":
    unittest.main()
