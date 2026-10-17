
"""QueryForge Day 66 - Integration Tests."""

import shutil

import pandas as pd
import pytest

from day58_error_handling import (
    UploadValidationError,
    calculate_file_hash,
    read_excel_safe,
)

from day66_end_to_end_validation import (
    assess_metrics,
    create_sample_excel,
)


def sample_dataframe():
    return pd.DataFrame({
        "customer_id": [1, 2],
        "customer_name": ["Rahul", "Meera"],
        "city": ["Hyderabad", "Mumbai"],
        "email": [
            "rahul@example.com",
            "meera@example.com",
        ],
        "credit_limit": [50000, 60000],
    })


def sample_metrics():
    return {
        "registered_files": 1,
        "customer_rows": 2,
        "matched_rows": 2,
        "orphan_rows": 0,
        "duplicate_file_hashes": 0,
        "duplicate_customer_keys": 0,
        "null_customer_ids": 0,
        "empty_uploads": 0,
    }


def test_01_sample_excel_pipeline():
    assert create_sample_excel() == 2


def test_02_excel_read(tmp_path):
    path = tmp_path / "sample.xlsx"
    sample_dataframe().to_excel(path, index=False)

    result = read_excel_safe(str(path))

    assert len(result) == 2


def test_03_missing_email_column(tmp_path):
    path = tmp_path / "missing.xlsx"

    df = sample_dataframe().drop(columns=["email"])
    df.to_excel(path, index=False)

    with pytest.raises(UploadValidationError):
        read_excel_safe(str(path))


def test_04_duplicate_customer_id(tmp_path):
    path = tmp_path / "duplicate.xlsx"

    df = sample_dataframe()
    df.loc[1, "customer_id"] = 1
    df.to_excel(path, index=False)

    with pytest.raises(UploadValidationError):
        read_excel_safe(str(path))


def test_05_invalid_email(tmp_path):
    path = tmp_path / "invalid.xlsx"

    df = sample_dataframe()
    df.loc[0, "email"] = "invalid-email"
    df.to_excel(path, index=False)

    with pytest.raises(UploadValidationError):
        read_excel_safe(str(path))


def test_06_negative_credit(tmp_path):
    path = tmp_path / "credit.xlsx"

    df = sample_dataframe()
    df.loc[0, "credit_limit"] = -100
    df.to_excel(path, index=False)

    with pytest.raises(UploadValidationError):
        read_excel_safe(str(path))


def test_07_identical_file_hash(tmp_path):
    original = tmp_path / "original.xlsx"
    copied = tmp_path / "copied.xlsx"

    sample_dataframe().to_excel(original, index=False)
    shutil.copyfile(original, copied)

    assert (
        calculate_file_hash(str(original))
        == calculate_file_hash(str(copied))
    )


def test_08_healthy_database():
    status, problems = assess_metrics(
        sample_metrics()
    )

    assert status == "PASS"
    assert problems == []


def test_09_no_data():
    metrics = {
        key: 0 for key in sample_metrics()
    }

    status, _ = assess_metrics(metrics)

    assert status == "NO DATA"


def test_10_orphan_detection():
    metrics = sample_metrics()
    metrics["orphan_rows"] = 1
    metrics["matched_rows"] = 1

    status, _ = assess_metrics(metrics)

    assert status == "FAIL"


def test_11_duplicate_customer_detection():
    metrics = sample_metrics()
    metrics["duplicate_customer_keys"] = 1

    status, _ = assess_metrics(metrics)

    assert status == "FAIL"


def test_12_duplicate_file_detection():
    metrics = sample_metrics()
    metrics["duplicate_file_hashes"] = 1

    status, _ = assess_metrics(metrics)

    assert status == "FAIL"


def test_13_empty_upload_warning():
    metrics = sample_metrics()
    metrics["empty_uploads"] = 1

    status, _ = assess_metrics(metrics)

    assert status == "WARNING"
