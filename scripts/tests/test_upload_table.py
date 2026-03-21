"""Tests for upload_table schema pass-through."""
import unittest
from unittest.mock import MagicMock, patch, call
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from google.cloud import bigquery
from generate_synthetic_data import upload_table


class TestUploadTableSchemaConversion(unittest.TestCase):
    def _make_field(self, name, field_type, mode="NULLABLE"):
        return bigquery.SchemaField(name, field_type, mode=mode)

    def test_schema_passed_through_unchanged(self):
        schema = [
            self._make_field("id", "STRING"),
            self._make_field("properties", "STRING"),
            self._make_field("count", "INTEGER"),
        ]
        client = MagicMock()
        client.project = "test-project"
        job = MagicMock()
        job.result.return_value = None
        client.load_table_from_dataframe.return_value = job
        client.get_table.return_value.num_rows = 0

        import pandas as pd
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
        client = MagicMock()
        client.project = "test-project"
        job = MagicMock()
        job.result.return_value = None
        client.load_table_from_dataframe.return_value = job
        client.get_table.return_value.num_rows = 0

        import pandas as pd
        df = pd.DataFrame({"id": [], "ts": []})

        upload_table(client, "ds", "tbl", df, schema)

        _, kwargs = client.load_table_from_dataframe.call_args
        load_schema = kwargs["job_config"].schema
        types = {f.name: f.field_type for f in load_schema}
        self.assertEqual(types["id"], "STRING")
        self.assertEqual(types["ts"], "TIMESTAMP")


if __name__ == "__main__":
    unittest.main()
