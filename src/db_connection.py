# QueryForge
# Day 9 - Python to PostgreSQL Connection

from pathlib import Path
import os

import psycopg
from dotenv import load_dotenv


# ==========================================
# 1. LOAD ENVIRONMENT VARIABLES
# ==========================================

project_root = Path(__file__).resolve().parents[1]

env_file = project_root / ".env"

load_dotenv(env_file)


# ==========================================
# 2. DATABASE CONFIGURATION
# ==========================================

db_host = os.getenv("DB_HOST")
db_port = os.getenv("DB_PORT")
db_name = os.getenv("DB_NAME")
db_user = os.getenv("DB_USER")
db_password = os.getenv("DB_PASSWORD")


# ==========================================
# 3. CONNECT TO POSTGRESQL
# ==========================================

try:

    connection = psycopg.connect(
        host=db_host,
        port=db_port,
        dbname=db_name,
        user=db_user,
        password=db_password,
        connect_timeout=5
    )

    print("PostgreSQL connection successful.")


    # ======================================
    # 4. CREATE CURSOR
    # ======================================

    cursor = connection.cursor()


    # ======================================
    # 5. TEST DATABASE CONNECTION
    # ======================================

    cursor.execute(
        """
        SELECT
            current_database(),
            current_user,
            version();
        """
    )

    result = cursor.fetchone()


    # ======================================
    # 6. DISPLAY DATABASE INFORMATION
    # ======================================

    print()
    print("Database:", result[0])
    print("User:", result[1])
    print("PostgreSQL Version:")
    print(result[2])


    # ======================================
    # 7. COUNT PUBLIC TABLES
    # ======================================

    cursor.execute(
        """
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = 'public';
        """
    )

    table_count = cursor.fetchone()[0]

    print()
    print("Public Table Count:", table_count)


    # ======================================
    # 8. CLOSE RESOURCES
    # ======================================

    cursor.close()
    connection.close()

    print()
    print("Database connection closed.")


# ==========================================
# 9. HANDLE DATABASE ERRORS
# ==========================================

except psycopg.Error as error:

    print()
    print("PostgreSQL connection failed.")
    print("Error:")
    print(error)