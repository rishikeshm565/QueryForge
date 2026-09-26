# QueryForge
# Day 11 - Field-Level Reconciliation
# Excel Source vs PostgreSQL Target

from pathlib import Path
import os

import pandas as pd
import psycopg
from dotenv import load_dotenv


# ============================================================
# 1. PROJECT PATHS
# ============================================================

project_root = Path(__file__).resolve().parents[2]

source_file = (
    project_root
    / "data"
    / "day10_customer_source.xlsx"
)

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
# 3. READ SOURCE EXCEL
# ============================================================

source_df = pd.read_excel(source_file)

print("\nDay 11 - Field-Level Reconciliation")
print("=" * 60)

print(f"Raw Source Rows: {len(source_df)}")


# ============================================================
# 4. REMOVE DUPLICATES / INVALID ROWS
# ============================================================

duplicate_mask = source_df.duplicated(
    subset=["customer_id"],
    keep="first"
)

required_columns = [
    "customer_id",
    "full_name",
    "email"
]

invalid_mask = (
    source_df[required_columns]
    .isna()
    .any(axis=1)
)

valid_mask = (
    (~duplicate_mask)
    & (~invalid_mask)
)

valid_source_df = source_df.loc[
    valid_mask,
    [
        "customer_id",
        "full_name",
        "email",
        "city",
        "credit_limit",
        "is_active"
    ]
].copy()


valid_source_df["customer_id"] = (
    valid_source_df["customer_id"]
    .astype(int)
)

source_ids = (
    valid_source_df["customer_id"]
    .tolist()
)

print(
    f"Valid Source Rows: "
    f"{len(valid_source_df)}"
)


# ============================================================
# 5. HELPER FUNCTIONS
# ============================================================
def normalize_text(value):

    if pd.isna(value):
        return ""

    return str(value).strip().casefold()



def normalize_number(value):

    if pd.isna(value):
        return None

    return round(float(value), 2)


def normalize_boolean(value):

    if pd.isna(value):
        return None

    text = str(value).strip().lower()

    if text in {
        "true",
        "1",
        "yes"
    }:
        return True

    if text in {
        "false",
        "0",
        "no"
    }:
        return False

    return text


def values_match(
    field_name,
    source_value,
    target_value
):

    if field_name == "credit_limit":

        return (
            normalize_number(source_value)
            ==
            normalize_number(target_value)
        )

    if field_name == "is_active":

        return (
            normalize_boolean(source_value)
            ==
            normalize_boolean(target_value)
        )

    return (
        normalize_text(source_value)
        ==
        normalize_text(target_value)
    )


# ============================================================
# 6. CONNECT TO POSTGRESQL
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
    # 7. READ TARGET RECORDS
    # ========================================================

    cursor.execute(
        """
        SELECT
            customer_id,
            full_name,
            email,
            city,
            credit_limit,
            is_active
        FROM customers
        WHERE customer_id = ANY(%s)
        ORDER BY customer_id
        """,
        (source_ids,)
    )

    database_rows = cursor.fetchall()


    target_df = pd.DataFrame(
        database_rows,
        columns=[
            "customer_id",
            "full_name",
            "email",
            "city",
            "credit_limit",
            "is_active"
        ]
    )

    print(
        f"Target Rows Found: "
        f"{len(target_df)}"
    )


    # ========================================================
    # 8. MERGE SOURCE AND TARGET
    # ========================================================

    comparison_df = valid_source_df.merge(
        target_df,
        on="customer_id",
        how="left",
        suffixes=(
            "_source",
            "_target"
        ),
        indicator=True
    )


    # ========================================================
    # 9. CHECK MISSING TARGET RECORDS
    # ========================================================

    missing_target_df = comparison_df[
        comparison_df["_merge"]
        != "both"
    ]

    missing_target_rows = len(
        missing_target_df
    )


    # ========================================================
    # 10. FIELD-BY-FIELD COMPARISON
    # ========================================================

    compare_fields = [
        "full_name",
        "email",
        "city",
        "credit_limit",
        "is_active"
    ]

    mismatch_details = []

    matched_records_df = comparison_df[
        comparison_df["_merge"]
        == "both"
    ]

    for _, row in matched_records_df.iterrows():

        customer_id = int(
            row["customer_id"]
        )

        for field_name in compare_fields:

            source_value = row[
                f"{field_name}_source"
            ]

            target_value = row[
                f"{field_name}_target"
            ]

            if not values_match(
                field_name,
                source_value,
                target_value
            ):

                mismatch_details.append(
                    {
                        "customer_id":
                            customer_id,

                        "field":
                            field_name,

                        "source_value":
                            source_value,

                        "target_value":
                            target_value
                    }
                )


    # ========================================================
    # 11. SUMMARY
    # ========================================================

    field_mismatch_count = len(
        mismatch_details
    )

    print("\n" + "=" * 60)

    print(
        "FIELD-LEVEL RECONCILIATION "
        "SUMMARY"
    )

    print("=" * 60)

    print(
        f"Expected Source Rows  : "
        f"{len(valid_source_df)}"
    )

    print(
        f"Target Rows Found     : "
        f"{len(target_df)}"
    )

    print(
        f"Missing Target Rows   : "
        f"{missing_target_rows}"
    )

    print(
        f"Field Mismatches      : "
        f"{field_mismatch_count}"
    )


    # ========================================================
    # 12. DISPLAY MISMATCH DETAILS
    # ========================================================

    if missing_target_rows > 0:

        print(
            "\nMissing Customer IDs:"
        )

        print(
            missing_target_df[
                "customer_id"
            ].tolist()
        )


    if mismatch_details:

        print(
            "\nFIELD MISMATCH DETAILS"
        )

        print("-" * 60)

        for mismatch in mismatch_details:

            print(
                f"Customer ID : "
                f"{mismatch['customer_id']}"
            )

            print(
                f"Field       : "
                f"{mismatch['field']}"
            )

            print(
                f"Source      : "
                f"{mismatch['source_value']}"
            )

            print(
                f"Target      : "
                f"{mismatch['target_value']}"
            )

            print("-" * 60)


    # ========================================================
    # 13. FINAL STATUS
    # ========================================================

    if (
        missing_target_rows == 0
        and field_mismatch_count == 0
    ):

        print(
            "\nFIELD RECONCILIATION "
            "STATUS: PASS"
        )

    else:

        print(
            "\nFIELD RECONCILIATION "
            "STATUS: FAIL"
        )


except Exception as error:

    print(
        "\nField reconciliation failed."
    )

    print(
        "Error:",
        error
    )


finally:

    if cursor is not None:
        cursor.close()

    if connection is not None:
        connection.close()

    print(
        "\nDatabase resources closed."
    )