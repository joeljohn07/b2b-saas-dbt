"""Tests for upload_table schema pass-through and NUMERIC conversion."""
import unittest
from decimal import Decimal
from unittest.mock import MagicMock, patch, call
import sys
import os

import pandas as pd

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from google.cloud import bigquery
from generate_synthetic_data import upload_table


class TestUploadTableSchemaConversion(unittest.TestCase):
    def _make_field(self, name, field_type, mode="NULLABLE"):
        return bigquery.SchemaField(name, field_type, mode=mode)

    def _mock_client(self):
        client = MagicMock()
        client.project = "test-project"
        job = MagicMock()
        job.result.return_value = None
        client.load_table_from_dataframe.return_value = job
        client.get_table.return_value.num_rows = 0
        return client

    def test_schema_passed_through_unchanged(self):
        schema = [
            self._make_field("id", "STRING"),
            self._make_field("properties", "STRING"),
            self._make_field("count", "INTEGER"),
        ]
        client = self._mock_client()
        df = pd.DataFrame({"id": [], "properties": [], "count": []})

        upload_table(client, "ds", "tbl", df, schema)

        _, kwargs = client.load_table_from_dataframe.call_args
        job_config = kwargs["job_config"]
        self.assertEqual(job_config.schema, schema)

    def test_no_json_fields_unchanged(self):
        schema = [
            self._make_field("id", "STRING"),
            self._make_field("ts", "TIMESTAMP"),
        ]
        client = self._mock_client()
        df = pd.DataFrame({"id": [], "ts": []})

        upload_table(client, "ds", "tbl", df, schema)

        _, kwargs = client.load_table_from_dataframe.call_args
        load_schema = kwargs["job_config"].schema
        types = {f.name: f.field_type for f in load_schema}
        self.assertEqual(types["id"], "STRING")
        self.assertEqual(types["ts"], "TIMESTAMP")

    def test_numeric_columns_cast_to_decimal(self):
        schema = [
            self._make_field("id", "STRING"),
            self._make_field("amount", "NUMERIC"),
        ]
        client = self._mock_client()
        df = pd.DataFrame({"id": ["a", "b"], "amount": [49.0, 0]})

        upload_table(client, "ds", "tbl", df, schema)

        uploaded_df = client.load_table_from_dataframe.call_args[0][0]
        for val in uploaded_df["amount"]:
            self.assertIsInstance(val, Decimal)
        self.assertEqual(uploaded_df["amount"].iloc[0], Decimal("49.0"))
        self.assertEqual(uploaded_df["amount"].iloc[1], Decimal("0"))

    def test_upload_does_not_mutate_original_df(self):
        schema = [
            self._make_field("id", "STRING"),
            self._make_field("amount", "NUMERIC"),
        ]
        client = self._mock_client()
        df = pd.DataFrame({"id": ["a"], "amount": [99.0]})

        upload_table(client, "ds", "tbl", df, schema)

        self.assertIsInstance(df["amount"].iloc[0], float)


if __name__ == "__main__":
    unittest.main()
