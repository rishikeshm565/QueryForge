# QueryForge
# Day 11 - Reconciliation
# Source Excel vs PostgreSQL Target

from pathlib import Path
import os

import pandas as pd
import psycopg
from dotenv import load_dotenv


# ============================================================
# 1. PROJECT PATHS
# ============================================================

project_root = Path(__file__).resolve().parents[2]

source_file = project_root / "data" / "day10_customer_source.xlsx"
env_file = project_root / ".env"


# ============================================================
# 2. LOAD DATABASE CONFIGURATION
# ============================================================

load_dotenv(env_file)

db_host = os.getenv("DB_HOST")
db_port = os.getenv("DB_PORT")
db_name = os.getenv("DB_NAME")
db_user = os.getenv("DB_USER")
db_password = os.getenv("DB_PASSWORD")


# ============================================================
# 3. READ SOURCE FILE
# ============================================================

df = pd.read_excel(source_file)

print("\nDay 11 - Reconciliation")
print("=" * 50)

source_rows = len(df)

print(f"Source Rows: {source_rows}")


# ============================================================
# 4. FIND DUPLICATE ROWS
# ============================================================

duplicate_mask = df.duplicated(
    subset=["customer_id"],
    keep="first"
)

duplicate_rows = int(duplicate_mask.sum())

print(f"Duplicate Rows: {duplicate_rows}")


# ============================================================
# 5. FIND INVALID / REJECTED ROWS
# ============================================================

required_columns = [
    "customer_id",
    "full_name",
    "email"
]

invalid_mask = df[required_columns].isna().any(axis=1)

# A duplicate row is counted as duplicate,
# not again as rejected.
rejected_mask = (~duplicate_mask) & invalid_mask

rejected_rows = int(rejected_mask.sum())

print(f"Rejected Rows: {rejected_rows}")


# ============================================================
# 6. CALCULATE EXPECTED LOAD ROWS
# ============================================================

valid_mask = (~duplicate_mask) & (~invalid_mask)

expected_load_rows = int(valid_mask.sum())

print(f"Expected Load Rows: {expected_load_rows}")


# ============================================================
# 7. GET VALID CUSTOMER IDs FROM SOURCE
# ============================================================

valid_source_ids = (
    df.loc[valid_mask, "customer_id"]
    .astype(int)
    .tolist()
)


# ============================================================
# 8. CONNECT TO POSTGRESQL
# ============================================================

connection = None
cursor = None

try:

    connection = psycopg.connect(
        host=db_host,
        port=db_port,
        dbname=db_name,
        user=db_user,
        password=db_password,
        connect_timeout=5
    )

    cursor = connection.cursor()

    print("\nDatabase connection successful.")


    # ========================================================
    # 9. CHECK SOURCE CUSTOMER IDs IN TARGET TABLE
    # ========================================================

    if valid_source_ids:

        cursor.execute(
            """
            SELECT customer_id
            FROM customers
            WHERE customer_id = ANY(%s)
            """,
            (valid_source_ids,)
        )

        database_rows = cursor.fetchall()

        database_customer_ids = {
            row[0] for row in database_rows
        }

            # ====================================================
        # DAY 11 PRACTICE ONLY
        # Simulate one missing database record
        # ====================================================

        if database_customer_ids:
            simulated_missing_id = min(database_customer_ids)

            database_customer_ids.remove(
                simulated_missing_id
            )

            print(
                f"\nSIMULATION: Customer ID "
                f"{simulated_missing_id} removed from "
                f"target result."
            )

    else:

        database_customer_ids = set()


    # ========================================================
    # 10. RECONCILIATION CALCULATIONS
    # ========================================================

    source_customer_ids = set(valid_source_ids)

    matched_customer_ids = (
        source_customer_ids
        & database_customer_ids
    )

    missing_customer_ids = (
        source_customer_ids
        - database_customer_ids
    )

    db_matched_rows = len(matched_customer_ids)
    missing_rows = len(missing_customer_ids)


    # ========================================================
    # 11. PRINT RECONCILIATION SUMMARY
    # ========================================================

    print("\n" + "=" * 50)
    print("RECONCILIATION SUMMARY")
    print("=" * 50)

    print(f"Source Rows        : {source_rows}")
    print(f"Duplicate Rows     : {duplicate_rows}")
    print(f"Rejected Rows      : {rejected_rows}")
    print(f"Expected Load Rows : {expected_load_rows}")
    print(f"DB Matched Rows    : {db_matched_rows}")
    print(f"Missing Rows       : {missing_rows}")


    # ========================================================
    # 12. FINAL STATUS
    # ========================================================

    if (
        expected_load_rows == db_matched_rows
        and missing_rows == 0
    ):

        print("\nRECONCILIATION STATUS: PASS")

    else:

        print("\nRECONCILIATION STATUS: FAIL")

        if missing_customer_ids:
            print(
                "Missing Customer IDs:",
                sorted(missing_customer_ids)
            )


except Exception as error:

    print("\nReconciliation failed.")
    print("Error:", error)


finally:

    if cursor is not None:
        cursor.close()

    if connection is not None:
        connection.close()

    print("\nDatabase resources closed.")