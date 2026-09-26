# QueryForge
# Day 10 - ETL Fundamentals
# Extract -> Transform -> Load

from pathlib import Path
import os

import pandas as pd
import psycopg
from dotenv import load_dotenv


# =========================================================
# 1. PROJECT PATHS
# =========================================================

project_root = Path(__file__).resolve().parents[2]

data_folder = project_root / "data"

source_file = data_folder / "day10_customer_source.xlsx"

env_file = project_root / ".env"


# =========================================================
# 2. CREATE SAMPLE SOURCE DATA
# =========================================================

source_data = {

    "customer_id": [
        4101,
        4102,
        4103,
        4104,
        4105
    ],

    "full_name": [
        " Rahul Verma ",
        "Sneha Rao",
        " ARJUN SINGH ",
        "Meera Reddy ",
        "Vikram Shah"
    ],

    "email": [
        "RAHUL.VERMA@EXAMPLE.COM ",
        " sneha.rao@example.com",
        "ARJUN.SINGH@EXAMPLE.COM",
        "meera.reddy@example.com ",
        " VIKRAM.SHAH@EXAMPLE.COM "
    ],

    "phone": [
        "9876543210",
        "9988776655",
        "9123456780",
        "9012345678",
        "9090909090"
    ],

    "city": [
        " hyderabad ",
        "BENGALURU",
        "pune",
        " HYDERABAD",
        "chennai "
    ],

    "credit_limit": [
        "25000",
        "18000.50",
        "15000",
        "22000.75",
        "20000"
    ],

    "is_active": [
        "YES",
        "true",
        "1",
        "No",
        "false"
    ],

    "date_of_birth": [
        "1998-05-15",
        "2000-08-20",
        "1999-11-10",
        "2001-02-25",
        "1997-07-18"
    ],

    "notes": [
        "New customer",
        "Priority account",
        None,
        "Follow-up required",
        None
    ]
}


source_df = pd.DataFrame(source_data)

source_df.to_excel(
    source_file,
    index=False
)

print("Source Excel created:")
print(source_file)


# =========================================================
# 3. EXTRACT
# =========================================================

print()
print("===== EXTRACT =====")

df = pd.read_excel(source_file)

print("Source Rows:", len(df))
print("Source Columns:", len(df.columns))

print()
print(df)


# =========================================================
# 4. TRANSFORM
# =========================================================

print()
print("===== TRANSFORM =====")


# Clean names
df["full_name"] = (
    df["full_name"]
    .str.strip()
    .str.title()
)


# Clean emails
df["email"] = (
    df["email"]
    .str.strip()
    .str.lower()
)


# Clean city
df["city"] = (
    df["city"]
    .str.strip()
    .str.title()
)


# Convert phone to string
df["phone"] = (
    df["phone"]
    .astype(str)
    .str.strip()
)


# Convert credit limit to numeric
df["credit_limit"] = pd.to_numeric(
    df["credit_limit"],
    errors="coerce"
)


# Standardize boolean values
active_mapping = {
    "yes": True,
    "true": True,
    "1": True,
    "no": False,
    "false": False,
    "0": False
}

df["is_active"] = (
    df["is_active"]
    .astype(str)
    .str.strip()
    .str.lower()
    .map(active_mapping)
)


# Convert date
df["date_of_birth"] = pd.to_datetime(
    df["date_of_birth"],
    errors="coerce"
)


print("Transformed Rows:", len(df))

print()
print(df)


# =========================================================
# 5. LOAD DATABASE CONFIGURATION
# =========================================================

load_dotenv(env_file)

db_host = os.getenv("DB_HOST")
db_port = os.getenv("DB_PORT")
db_name = os.getenv("DB_NAME")
db_user = os.getenv("DB_USER")
db_password = os.getenv("DB_PASSWORD")


# =========================================================
# 6. LOAD INTO POSTGRESQL
# =========================================================

print()
print("===== LOAD =====")

connection = None
cursor = None

loaded_rows = 0


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


    insert_sql = """
        INSERT INTO customers (
            customer_id,
            full_name,
            email,
            phone,
            city,
            credit_limit,
            is_active,
            date_of_birth,
            notes
        )
        VALUES (
            %s,
            %s,
            %s,
            %s,
            %s,
            %s,
            %s,
            %s,
            %s
        );
    """


    for _, row in df.iterrows():

        date_of_birth = row["date_of_birth"]

        if pd.isna(date_of_birth):
            date_of_birth = None
        else:
            date_of_birth = date_of_birth.date()


        notes = row["notes"]

        if pd.isna(notes):
            notes = None


        cursor.execute(
            insert_sql,
            (
                int(row["customer_id"]),
                row["full_name"],
                row["email"],
                row["phone"],
                row["city"],
                float(row["credit_limit"]),
                bool(row["is_active"]),
                date_of_birth,
                notes
            )
        )

        loaded_rows += 1


    connection.commit()

    print("Database load successful.")
    print("Loaded Rows:", loaded_rows)


except Exception as error:

    if connection is not None:
        connection.rollback()

    print("ETL load failed.")
    print("Error:")
    print(error)


finally:

    if cursor is not None:
        cursor.close()

    if connection is not None:
        connection.close()

    print("Database resources closed.")


# =========================================================
# 7. PIPELINE SUMMARY
# =========================================================

print()
print("===== ETL SUMMARY =====")

print("Extracted Rows:", len(df))
print("Loaded Rows:", loaded_rows)

print()
print("ETL pipeline completed.")