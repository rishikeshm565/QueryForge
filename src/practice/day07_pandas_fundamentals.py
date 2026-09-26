# QueryForge
# Day 7 - Pandas Fundamentals

from pathlib import Path
import pandas as pd


# ==========================================
# 1. PROJECT PATHS
# ==========================================

project_root = Path(__file__).resolve().parents[2]
data_folder = project_root / "data"
excel_file = data_folder / "day07_customers.xlsx"


# ==========================================
# 2. CREATE SAMPLE DATA
# ==========================================

customer_data = {
    "customer_id": [1001, 1002, 1003, 1004, 1005],
    "full_name": [
        "Rahul Sharma",
        "Priya Rao",
        "Arjun Kumar",
        "Neha Singh",
        "Vikram Reddy"
    ],
    "city": [
        "Hyderabad",
        "Bengaluru",
        "Pune",
        "Hyderabad",
        "Chennai"
    ],
    "credit_limit": [
        25000.00,
        15000.50,
        10000.00,
        30000.75,
        20000.00
    ],
    "is_active": [
        True,
        True,
        False,
        True,
        False
    ],
    "signup_date": pd.to_datetime([
        "2026-01-10",
        "2026-02-15",
        "2026-03-20",
        "2026-04-25",
        "2026-05-30"
    ])
}


# ==========================================
# 3. CREATE DATAFRAME
# ==========================================

source_df = pd.DataFrame(customer_data)


# ==========================================
# 4. WRITE DATAFRAME TO EXCEL
# ==========================================

source_df.to_excel(
    excel_file,
    index=False
)

print("Excel file created:")
print(excel_file)


# ==========================================
# 5. READ EXCEL WITH PANDAS
# ==========================================

df = pd.read_excel(excel_file)


# ==========================================
# 6. DATAFRAME CHECK
# ==========================================

print()
print("Object Type:")
print(type(df))


# ==========================================
# 7. HEAD
# ==========================================

print()
print("First 3 Rows:")
print(df.head(3))


# ==========================================
# 8. SHAPE
# ==========================================

print()
print("Shape:")
print(df.shape)


# ==========================================
# 9. DTYPES
# ==========================================

print()
print("Data Types:")
print(df.dtypes)


# ==========================================
# 10. INFO
# ==========================================

print()
print("DataFrame Info:")
df.info()


# ==========================================
# 11. SERIES
# ==========================================

customer_names = df["full_name"]

print()
print("Series Type:")
print(type(customer_names))

print()
print("Customer Name Series:")
print(customer_names)