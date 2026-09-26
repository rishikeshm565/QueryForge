\# QueryForge — Day 10 ETL Fundamentals



\## Pipeline



Excel Source

→ Pandas Extract

→ Data Transformation

→ PostgreSQL Load



\## Source



day10\_customer\_source.xlsx



\## Target



PostgreSQL table: customers



\## ETL Result



Extracted Rows: 5

Loaded Rows: 5



\## Transformations



\- Trimmed whitespace

\- Standardized customer names

\- Lowercased email addresses

\- Standardized city names

\- Converted credit limit to numeric

\- Standardized Boolean values

\- Converted date of birth to datetime

