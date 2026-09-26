# QueryForge
# Day 6 - Python Refresher

from datetime import datetime


# ==========================================
# 1. VARIABLES
# ==========================================

project_name = "QueryForge"
version = "V0.5"
customer_count = 3
database_ready = True


# ==========================================
# 2. LIST
# ==========================================

customers = [
    "Rahul Sharma",
    "Priya Rao",
    "Arjun Kumar"
]


# ==========================================
# 3. DICTIONARY
# ==========================================

customer = {
    "customer_id": 3001,
    "name": "Rahul Sharma",
    "city": "Hyderabad",
    "is_active": True
}


# ==========================================
# 4. CONDITION
# ==========================================

if database_ready:
    database_status = "Database is ready"
else:
    database_status = "Database is not ready"


# ==========================================
# 5. LOOP
# ==========================================

print("Customers:")

for name in customers:
    print("-", name)


# ==========================================
# 6. FUNCTION
# ==========================================

def calculate_order_total(unit_price, quantity):
    total = unit_price * quantity
    return total


order_total = calculate_order_total(500, 3)


# ==========================================
# 7. EXCEPTION HANDLING
# ==========================================

try:
    user_input = "100"
    converted_value = int(user_input)

except ValueError:
    converted_value = 0


# ==========================================
# 8. MODULE
# ==========================================

current_time = datetime.now()


# ==========================================
# FINAL OUTPUT
# ==========================================

print()
print("Project:", project_name)
print("Version:", version)
print("Customer Count:", customer_count)
print("Database Ready:", database_ready)
print("Database Status:", database_status)

print()
print("Customer Dictionary:")
print(customer)

print()
print("Calculated Order Total:", order_total)
print("Converted Value:", converted_value)
print("Current Time:", current_time)