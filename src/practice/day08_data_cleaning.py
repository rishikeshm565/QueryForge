# QueryForge
# Day 8 - Data Cleaning

from pathlib import Path
import pandas as pd


# ==========================================
# 1. PROJECT PATHS
# ==========================================

project_root = Path(__file__).resolve().parents[2]
data_folder = project_root / "data"

dirty_file = data_folder / "day08_dirty_customers.xlsx"
clean_file = data_folder / "day08_cleaned_customers.xlsx"


# ==========================================
# 2. CREATE DIRTY SAMPLE DATA
# ==========================================

dirty_data = {
    "customer_id": [
        1001,
        1002,
        1002,
        1003,
        1004,
        1005
    ],

    "full_name": [
        " Rahul Sharma ",
        "Priya Rao",
        "Priya Rao",
        " Arjun Kumar",
        "Neha Singh ",
        "Vikram Reddy"
    ],

    "email": [
        "RAHUL@EXAMPLE.COM ",
        "priya@example.com",
        "priya@example.com",
        " arjun@example.com ",
        "NEHA@EXAMPLE.COM",
        "vikram@example.com "
    ],

    "city": [
        " hyderabad ",
        "BENGALURU",
        "BENGALURU",
        "pune",
        None,
        " Chennai "
    ],

    "credit_limit": [
        "25000",
        "15000.50",
        "15000.50",
        "ten thousand",
        None,
        "20000"
    ],

    "is_active": [
        "Yes",
        "TRUE",
        "TRUE",
        "No",
        "1",
        "false"
    ],

    "signup_date": [
        "2026-01-10",
        "15/02/2026",
        "15/02/2026",
        "2026/03/20",
        "bad-date",
        "2026-05-30"
    ]
}


dirty_df = pd.DataFrame(dirty_data)


# ==========================================
# 3. SAVE DIRTY EXCEL
# ==========================================

dirty_df.to_excel(
    dirty_file,
    index=False
)

print("Dirty Excel created:")
print(dirty_file)


# ==========================================
# 4. READ DIRTY EXCEL
# ==========================================

df = pd.read_excel(dirty_file)


# ==========================================
# 5. BEFORE CLEANING
# ==========================================

print()
print("===== BEFORE CLEANING =====")

print()
print("Shape:")
print(df.shape)

print()
print("Data Types:")
print(df.dtypes)

print()
print("Missing Values:")
print(df.isna().sum())

print()
print("Duplicate Rows:")
print(df.duplicated().sum())

print()
print("Dirty Data:")
print(df)


# ==========================================
# 6. REMOVE DUPLICATES
# ==========================================

df = df.drop_duplicates()


# ==========================================
# 7. CLEAN TEXT COLUMNS
# ==========================================

df["full_name"] = (
    df["full_name"]
    .str.strip()
)

df["email"] = (
    df["email"]
    .str.strip()
    .str.lower()
)

df["city"] = (
    df["city"]
    .str.strip()
    .str.title()
)


# ==========================================
# 8. HANDLE NULL CITY
# ==========================================

df["city"] = df["city"].fillna("Unknown")


# ==========================================
# 9. CLEAN NUMERIC COLUMN
# ==========================================

df["credit_limit"] = pd.to_numeric(
    df["credit_limit"],
    errors="coerce"
)

df["credit_limit"] = df["credit_limit"].fillna(0.0)


# ==========================================
# 10. CLEAN BOOLEAN COLUMN
# ==========================================

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


# ==========================================
# 11. CLEAN DATE COLUMN
# ==========================================

df["signup_date"] = pd.to_datetime(
    df["signup_date"],
    errors="coerce",
    dayfirst=True
)


# ==========================================
# 12. FINAL SORT + RESET INDEX
# ==========================================

df = df.sort_values("customer_id")

df = df.reset_index(drop=True)


# ==========================================
# 13. AFTER CLEANING
# ==========================================

print()
print("===== AFTER CLEANING =====")

print()
print("Shape:")
print(df.shape)

print()
print("Data Types:")
print(df.dtypes)

print()
print("Missing Values:")
print(df.isna().sum())

print()
print("Duplicate Rows:")
print(df.duplicated().sum())

print()
print("Cleaned Data:")
print(df)


# ==========================================
# 14. SAVE CLEANED EXCEL
# ==========================================

df.to_excel(
    clean_file,
    index=False
)

print()
print("Cleaned Excel created:")
print(clean_file)