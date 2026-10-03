# QueryForge
# Day 37 - Streamlit to PostgreSQL Staging Load

import os

import pandas as pd
import psycopg
import streamlit as st
from dotenv import load_dotenv


# ============================================================
# ENVIRONMENT
# ============================================================

load_dotenv()


# ============================================================
# PAGE CONFIGURATION
# ============================================================

st.set_page_config(
    page_title="QueryForge",
    page_icon="📊",
    layout="wide"
)


# ============================================================
# REQUIRED SCHEMA
# ============================================================

REQUIRED_COLUMNS = [
    "customer_id",
    "customer_name",
    "city",
    "email",
    "credit_limit"
]


# ============================================================
# DATABASE CONNECTION
# ============================================================

def get_connection():

    return psycopg.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        connect_timeout=5
    )


# ============================================================
# LOAD DATA INTO STAGING
# ============================================================

def load_to_staging(df):

    rows_to_insert = []

    for index, row in df.iterrows():

        rows_to_insert.append(
            (
                index + 2,
                int(row["customer_id"]),
                str(row["customer_name"]).strip(),
                str(row["city"]).strip(),
                str(row["email"]).strip(),
                float(row["credit_limit"])
            )
        )

    with get_connection() as conn:

        with conn.cursor() as cur:

            # Clear previous staging batch
            cur.execute(
                "TRUNCATE TABLE staging.customer_upload;"
            )

            # Insert current validated batch
            cur.executemany(
                """
                INSERT INTO staging.customer_upload
                (
                    source_row_no,
                    customer_id,
                    customer_name,
                    city,
                    email,
                    credit_limit
                )
                VALUES
                (%s, %s, %s, %s, %s, %s);
                """,
                rows_to_insert
            )

        conn.commit()

    return len(rows_to_insert)


# ============================================================
# APPLICATION HEADER
# ============================================================

st.title("📊 QueryForge")

st.subheader(
    "DataVault 360 - Validated Staging Load"
)

st.write(
    "Upload, validate and load customer data into PostgreSQL staging."
)


# ============================================================
# FILE UPLOAD
# ============================================================

uploaded_file = st.file_uploader(
    "Upload Excel File",
    type=["xlsx", "xls"]
)


# ============================================================
# PROCESS FILE
# ============================================================

if uploaded_file is not None:

    try:

        df = pd.read_excel(uploaded_file)

        st.success(
            "Excel file uploaded successfully!"
        )

        # ====================================================
        # FILE INFORMATION
        # ====================================================

        st.write("### File Information")

        col1, col2 = st.columns(2)

        with col1:
            st.metric(
                "Total Rows",
                len(df)
            )

        with col2:
            st.metric(
                "Total Columns",
                len(df.columns)
            )


        # ====================================================
        # SCHEMA VALIDATION
        # ====================================================

        actual_columns = list(df.columns)

        missing_columns = [
            column
            for column in REQUIRED_COLUMNS
            if column not in actual_columns
        ]

        extra_columns = [
            column
            for column in actual_columns
            if column not in REQUIRED_COLUMNS
        ]

        st.write("### Schema Validation")

        if missing_columns or extra_columns:

            st.error(
                "❌ Schema validation failed."
            )

            if missing_columns:

                st.error(
                    f"Missing Columns: {missing_columns}"
                )

            if extra_columns:

                st.warning(
                    f"Unexpected Columns: {extra_columns}"
                )

        else:

            st.success(
                "✅ Schema validation passed."
            )


            # =================================================
            # ROW VALIDATION
            # =================================================

            validation_errors = []


            for index, row in df.iterrows():

                row_errors = []

                excel_row = index + 2


                # ---------------------------------------------
                # NULL / BLANK CHECK
                # ---------------------------------------------

                for column in REQUIRED_COLUMNS:

                    value = row[column]

                    if (
                        pd.isna(value)
                        or str(value).strip() == ""
                    ):

                        row_errors.append(
                            f"{column} is missing"
                        )


                # ---------------------------------------------
                # CUSTOMER ID CHECK
                # ---------------------------------------------

                customer_id = pd.to_numeric(
                    row["customer_id"],
                    errors="coerce"
                )

                if pd.isna(customer_id):

                    row_errors.append(
                        "customer_id must be numeric"
                    )


                # ---------------------------------------------
                # EMAIL CHECK
                # ---------------------------------------------

                email = str(
                    row["email"]
                ).strip()

                if (
                    email
                    and email.lower() != "nan"
                    and (
                        "@" not in email
                        or "." not in email.split("@")[-1]
                    )
                ):

                    row_errors.append(
                        "invalid email format"
                    )


                # ---------------------------------------------
                # CREDIT LIMIT CHECK
                # ---------------------------------------------

                credit_limit = pd.to_numeric(
                    row["credit_limit"],
                    errors="coerce"
                )

                if pd.isna(credit_limit):

                    row_errors.append(
                        "credit_limit must be numeric"
                    )

                elif credit_limit < 0:

                    row_errors.append(
                        "credit_limit cannot be negative"
                    )


                # ---------------------------------------------
                # SAVE ROW ERRORS
                # ---------------------------------------------

                if row_errors:

                    validation_errors.append(
                        {
                            "excel_row": excel_row,
                            "customer_id": row["customer_id"],
                            "errors": " | ".join(row_errors)
                        }
                    )


            # =================================================
            # DUPLICATE CHECK
            # =================================================

            duplicate_mask = (
                df["customer_id"]
                .duplicated(keep=False)
            )

            duplicate_rows = df[
                duplicate_mask
            ]

            for index, row in duplicate_rows.iterrows():

                validation_errors.append(
                    {
                        "excel_row": index + 2,
                        "customer_id": row["customer_id"],
                        "errors": "duplicate customer_id"
                    }
                )


            # =================================================
            # DATA VALIDATION RESULT
            # =================================================

            st.write("### Data Validation")

            if validation_errors:

                error_df = pd.DataFrame(
                    validation_errors
                )

                st.error(
                    f"❌ Data validation failed. "
                    f"{len(error_df)} issue(s) found."
                )

                st.dataframe(
                    error_df,
                    use_container_width=True
                )

                st.warning(
                    "Database load blocked because validation failed."
                )


            else:

                st.success(
                    "✅ Data validation passed."
                )

                st.write("### Data Preview")

                st.dataframe(
                    df.head(10),
                    use_container_width=True
                )


                # =============================================
                # DATABASE LOAD
                # =============================================

                st.write(
                    "### PostgreSQL Staging Load"
                )

                if st.button(
                    "Load Valid Data to Staging"
                ):

                    try:

                        loaded_rows = load_to_staging(
                            df
                        )

                        st.success(
                            f"✅ {loaded_rows} rows loaded "
                            f"into staging.customer_upload."
                        )

                    except Exception as db_error:

                        st.error(
                            "❌ Database load failed."
                        )

                        st.exception(
                            db_error
                        )


    except Exception as error:

        st.error(
            "Unable to process the Excel file."
        )

        st.exception(
            error
        )

else:

    st.info(
        "Please upload an Excel file to continue."
    )