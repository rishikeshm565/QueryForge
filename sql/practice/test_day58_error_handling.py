
"""QueryForge Day 58: 21 unit tests. No real database writes."""

import hashlib
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import MagicMock, patch

import pandas as pd
import day58_error_handling as app


class Day58Tests(unittest.TestCase):
    def sample(self):
        return pd.DataFrame({
            "customer_id": [1, 2],
            "customer_name": ["Asha", "Rohan"],
            "city": ["Hyderabad", "Mumbai"],
            "email": ["asha@example.com", "rohan@example.com"],
            "credit_limit": [1000, 2000],
        })

    def test_01_valid_dataframe(self):
        app.validate_dataframe(self.sample())

    def test_02_missing_column(self):
        with self.assertRaisesRegex(app.UploadValidationError, "Missing required"):
            app.validate_dataframe(self.sample().drop(columns=["email"]))

    def test_03_empty_dataframe(self):
        with self.assertRaisesRegex(app.UploadValidationError, "no data rows"):
            app.validate_dataframe(self.sample().iloc[:0])

    def test_04_duplicate_id(self):
        df = self.sample()
        df.loc[1, "customer_id"] = 1
        with self.assertRaisesRegex(app.UploadValidationError, "Duplicate"):
            app.validate_dataframe(df)

    def test_05_invalid_ids(self):
        for value in (0, -1, 1.5, "abc", None, float("inf")):
            with self.subTest(value=value):
                df = self.sample().astype({"customer_id": "object"})
                df.loc[0, "customer_id"] = value
                with self.assertRaisesRegex(app.UploadValidationError, "customer_id"):
                    app.validate_dataframe(df)

    def test_06_blank_text_fields(self):
        for column in ("customer_name", "city", "email"):
            with self.subTest(column=column):
                df = self.sample()
                df.loc[0, column] = "  "
                with self.assertRaisesRegex(app.UploadValidationError, "Blank"):
                    app.validate_dataframe(df)

    def test_07_invalid_email(self):
        df = self.sample()
        df.loc[0, "email"] = "not-an-email"
        with self.assertRaisesRegex(app.UploadValidationError, "Invalid email"):
            app.validate_dataframe(df)

    def test_08_invalid_credits(self):
        for value in (-10, "abc", None, float("inf"), float("-inf")):
            with self.subTest(value=value):
                df = self.sample().astype({"credit_limit": "object"})
                df.loc[0, "credit_limit"] = value
                with self.assertRaisesRegex(app.UploadValidationError, "credit_limit"):
                    app.validate_dataframe(df)

    def test_09_read_valid_excel(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "customers.xlsx"
            self.sample().to_excel(path, index=False)
            self.assertEqual(len(app.read_excel_safe(str(path))), 2)

    def test_10_missing_file(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "missing.xlsx"
            with self.assertRaisesRegex(app.UploadValidationError, "does not exist"):
                app.read_excel_safe(str(path))

    def test_11_wrong_extension(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "data.csv"
            path.write_text("hello")
            with self.assertRaisesRegex(app.UploadValidationError, "xlsx"):
                app.read_excel_safe(str(path))

    def test_12_corrupt_excel(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "corrupt.xlsx"
            path.write_bytes(b"not a workbook")
            with self.assertRaisesRegex(app.UploadValidationError, "could not be read"):
                app.read_excel_safe(str(path))

    def test_13_sha256_hash(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "test.xlsx"
            path.write_bytes(b"hello")
            self.assertEqual(app.calculate_file_hash(str(path)),
                             hashlib.sha256(b"hello").hexdigest())

    def test_14_registry_no_early_commit(self):
        conn = MagicMock()
        app.create_upload_registry(conn)
        cursor = conn.cursor.return_value.__enter__.return_value
        self.assertEqual(cursor.execute.call_count, 2)
        conn.commit.assert_not_called()

    def test_15_register_success(self):
        conn = MagicMock()
        cursor = conn.cursor.return_value.__enter__.return_value
        cursor.fetchone.return_value = (42,)
        result = app.register_file(conn, "customers.xlsx", "abc123")
        self.assertEqual(result, 42)
        sql, params = cursor.execute.call_args.args
        self.assertIn("ON CONFLICT", sql)
        self.assertEqual(params, ("customers.xlsx", "abc123"))
        conn.commit.assert_not_called()

    def test_16_register_duplicate(self):
        conn = MagicMock()
        cursor = conn.cursor.return_value.__enter__.return_value
        cursor.fetchone.return_value = None
        with self.assertRaisesRegex(app.UploadValidationError, "Duplicate file"):
            app.register_file(conn, "customers.xlsx", "abc123")

    def test_17_workflow_success(self):
        with (patch.object(app, "calculate_file_hash", side_effect=["a", "a"]),
              patch.object(app, "read_excel_safe", return_value=self.sample()),
              patch.object(app, "connect_db") as connect,
              patch.object(app, "create_upload_registry") as create,
              patch.object(app, "register_file", return_value=11) as register,
              redirect_stdout(StringIO())):
            self.assertEqual(app.process_upload("customers.xlsx"), 0)
            create.assert_called_once()
            register.assert_called_once_with(
                connect.return_value.__enter__.return_value,
                "customers.xlsx", "a"
            )

    def test_18_validation_error_exit(self):
        with (patch.object(app, "calculate_file_hash", return_value="a"),
              patch.object(app, "read_excel_safe",
                           side_effect=app.UploadValidationError("bad")),
              patch.object(app, "connect_db") as connect,
              redirect_stdout(StringIO())):
            self.assertEqual(app.process_upload("customers.xlsx"), 2)
            connect.assert_not_called()

    def test_19_db_error_exit(self):
        with (patch.object(app, "calculate_file_hash", side_effect=["a", "a"]),
              patch.object(app, "read_excel_safe", return_value=self.sample()),
              patch.object(app, "connect_db",
                           side_effect=app.DatabaseOperationError("offline")),
              redirect_stdout(StringIO())):
            self.assertEqual(app.process_upload("customers.xlsx"), 3)

    def test_20_file_changed_exit(self):
        with (patch.object(app, "calculate_file_hash", side_effect=["a", "b"]),
              patch.object(app, "read_excel_safe", return_value=self.sample()),
              patch.object(app, "connect_db") as connect,
              redirect_stdout(StringIO())):
            self.assertEqual(app.process_upload("customers.xlsx"), 2)
            connect.assert_not_called()

    def test_21_unexpected_error_exit(self):
        with (patch.object(app, "calculate_file_hash",
                           side_effect=RuntimeError("unexpected")),
              redirect_stdout(StringIO())):
            self.assertEqual(app.process_upload("customers.xlsx"), 4)


if __name__ == "__main__":
    unittest.main()
