"""Failing tests for P1-P6 fixes."""
import inspect
import os
import sys
import unittest
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import generate_synthetic_data as mod
from google.cloud import bigquery
from generate_synthetic_data import (
    EVENTS_SCHEMA,
    INVOICES_SCHEMA,
    build_invoices_df,
    generate_all_events,
    main,
    make_parser,
)


class TestP1SchemaTypes(unittest.TestCase):
    """JSON fields must be declared STRING — they are serialised via json.dumps before upload."""

    def test_experiment_flags_is_string(self):
        f = next(x for x in EVENTS_SCHEMA if x.name == "experiment_flags")
        self.assertEqual(f.field_type, "STRING")

    def test_properties_is_string(self):
        f = next(x for x in EVENTS_SCHEMA if x.name == "properties")
        self.assertEqual(f.field_type, "STRING")

    def test_line_items_is_string(self):
        f = next(x for x in INVOICES_SCHEMA if x.name == "line_items")
        self.assertEqual(f.field_type, "STRING")


class TestP2ParameterRename(unittest.TestCase):
    """batch_size was a log interval, not a batch size. Must be renamed."""

    def test_log_interval_param_exists(self):
        sig = inspect.signature(generate_all_events)
        self.assertIn("log_interval", sig.parameters)

    def test_batch_size_param_removed(self):
        sig = inspect.signature(generate_all_events)
        self.assertNotIn("batch_size", sig.parameters)


class TestP3BannerText(unittest.TestCase):
    """Banner must say b2b-saas-dbt, not the old name."""

    def test_banner_does_not_contain_old_name(self):
        src = inspect.getsource(main)
        self.assertNotIn("Analytics-dbt", src)


class TestP4InvoicePlanLookup(unittest.TestCase):
    """build_invoices_df must apply the correct plan at each invoice date."""

    def setUp(self):
        self._rng_state = mod.rng
        mod.rng = mod.np.random.default_rng(99)

    def tearDown(self):
        mod.rng = self._rng_state

    def _account_subs(self, sub_start, upgrade_time):
        lifecycle = [
            {
                "event_type": "trial_start",
                "event_time": sub_start - timedelta(days=14),
                "plan": "starter", "previous_plan": None, "billing_cycle": "monthly",
                "mrr_amount": 0, "cancel_reason": None, "is_voluntary": None,
            },
            {
                "event_type": "subscription_start",
                "event_time": sub_start,
                "plan": "starter", "previous_plan": None, "billing_cycle": "monthly",
                "mrr_amount": 49, "cancel_reason": None, "is_voluntary": None,
            },
            {
                "event_type": "upgrade",
                "event_time": upgrade_time,
                "plan": "pro", "previous_plan": "starter", "billing_cycle": "monthly",
                "mrr_amount": 149, "cancel_reason": None, "is_voluntary": None,
            },
        ]
        return {"acc_test": {
            "subscription_id": "sub_test", "owner_user_id": "usr_test",
            "lifecycle": lifecycle, "currency": "USD", "eur_rate": 1.0,
        }}

    def test_first_invoice_uses_starter_price(self):
        sub_start = datetime(2024, 3, 15, 10, 0, tzinfo=timezone.utc)
        upgrade_time = datetime(2024, 4, 20, 10, 0, tzinfo=timezone.utc)  # after first invoice
        df = build_invoices_df(self._account_subs(sub_start, upgrade_time))
        first = float(df.sort_values("issued_at").iloc[0]["amount"])
        self.assertEqual(first, 49.0)

    def test_invoice_after_upgrade_uses_pro_price(self):
        sub_start = datetime(2024, 3, 15, 10, 0, tzinfo=timezone.utc)
        upgrade_time = datetime(2024, 3, 20, 10, 0, tzinfo=timezone.utc)  # before next invoice
        df = build_invoices_df(self._account_subs(sub_start, upgrade_time))
        amounts = [float(a) for a in df["amount"].tolist()]
        self.assertIn(149.0, amounts)


    def test_paid_at_never_exceeds_end_date(self):
        end_dt = datetime.combine(mod.END_DATE, datetime.min.time(),
                                  tzinfo=timezone.utc)
        sub_start = end_dt - timedelta(days=35)
        lifecycle = [
            {
                "event_type": "subscription_start",
                "event_time": sub_start,
                "plan": "starter", "previous_plan": None, "billing_cycle": "monthly",
                "mrr_amount": 49, "cancel_reason": None, "is_voluntary": None,
            },
        ]
        account_subs = {"acc_boundary": {
            "subscription_id": "sub_boundary", "owner_user_id": "usr_boundary",
            "lifecycle": lifecycle, "currency": "USD", "eur_rate": 1.0,
        }}
        df = build_invoices_df(account_subs)
        paid_rows = df[df["paid_at"].notna()]
        for _, row in paid_rows.iterrows():
            self.assertLessEqual(row["paid_at"], end_dt,
                                 f"paid_at {row['paid_at']} exceeds END_DATE {end_dt}")


class TestP5TablesArgument(unittest.TestCase):
    """main() must expose --tables to allow partial uploads."""

    def test_tables_flag_single(self):
        parser = make_parser()
        args = parser.parse_args(["--dry-run", "--tables", "events"])
        self.assertEqual(args.tables, ["events"])

    def test_tables_flag_multiple(self):
        parser = make_parser()
        args = parser.parse_args(["--dry-run", "--tables", "events", "subscriptions"])
        self.assertEqual(args.tables, ["events", "subscriptions"])

    def test_tables_flag_default_is_none(self):
        parser = make_parser()
        args = parser.parse_args(["--dry-run"])
        self.assertIsNone(args.tables)


if __name__ == "__main__":
    unittest.main()
