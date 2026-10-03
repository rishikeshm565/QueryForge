# ============================================================
# QueryForge / DataVault 360
# Day 49 - Saved Search & Export
# ============================================================

from pathlib import Path
import os

import pandas as pd
import psycopg
from dotenv import load_dotenv


# ------------------------------------------------------------
# PROJECT PATHS
# ------------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parents[2]
ENV_FILE = BASE_DIR / ".env"
EXPORT_DIR = BASE_DIR / "exports" / "day49"

EXPORT_DIR.mkdir(parents=True, exist_ok=True)


# ------------------------------------------------------------
# LOAD ENVIRONMENT VARIABLES
# ------------------------------------------------------------

load_dotenv(ENV_FILE)


# ------------------------------------------------------------
# DATABASE CONNECTION
# ------------------------------------------------------------

conn = psycopg.connect(
    host=os.getenv("DB_HOST"),
    port=os.getenv("DB_PORT"),
    dbname=os.getenv("DB_NAME"),
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    connect_timeout=5,
)


# ------------------------------------------------------------
# SAVED SEARCH TO EXPORT
# ------------------------------------------------------------

search_name = "Hyderabad Active Customers"
saved_by = "qf_demo_user"


query = """
WITH selected_search AS (
    SELECT
        city_filter,
        min_credit_limit,
        active_only
    FROM public.saved_customer_searches
    WHERE saved_by = %s
      AND search_name = %s
)

SELECT
    c.customer_id,
    c.full_name,
    c.email,
    c.city,
    c.credit_limit,
    c.is_active
FROM public.customers c
CROSS JOIN selected_search s
WHERE
    (
        s.city_filter IS NULL
        OR c.city = s.city_filter
    )
    AND
    (
        s.min_credit_limit IS NULL
        OR c.credit_limit >= s.min_credit_limit
    )
    AND
    (
        s.active_only = FALSE
        OR c.is_active = TRUE
    )
ORDER BY
    c.credit_limit DESC,
    c.customer_id;
"""


# ------------------------------------------------------------
# RUN QUERY
# ------------------------------------------------------------

with conn.cursor() as cur:
    cur.execute(query, (saved_by, search_name))

    rows = cur.fetchall()

    columns = [
        desc.name
        for desc in cur.description
    ]


df = pd.DataFrame(rows, columns=columns)

conn.close()


# ------------------------------------------------------------
# EXPORT FILES
# ------------------------------------------------------------

csv_file = EXPORT_DIR / "hyderabad_active_customers.csv"
excel_file = EXPORT_DIR / "hyderabad_active_customers.xlsx"

df.to_csv(csv_file, index=False)

df.to_excel(
    excel_file,
    index=False,
    sheet_name="Saved Search"
)


# ------------------------------------------------------------
# VALIDATION OUTPUT
# ------------------------------------------------------------

print("=" * 60)
print("QUERYFORGE - DAY 49 SAVED SEARCH EXPORT")
print("=" * 60)

print(f"\nSaved Search : {search_name}")
print(f"Saved By     : {saved_by}")
print(f"Rows Exported: {len(df)}")

print("\nExported Data:")
print(df)

print("\nCSV:")
print(csv_file)

print("\nExcel:")
print(excel_file)

print("\nExport completed successfully.")