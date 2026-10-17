# QueryForge — Day 63 Performance Report

- Generated (UTC): 2026-10-17T13:28:20+00:00
- Database: `queryforge_dev`
- Audit: PostgreSQL read-only transaction.
- No source rows changed.
- Timings are observations, not fixed thresholds.

## Data counts

| Object | Rows |
|---|---:|
| `customers_big` | 100,000 |
| `orders_partitioned` | 300,000 |
| `monthly_summary_rows` | 144 |
| `registered_uploads` | 0 |
| `uploaded_customer_rows` | 0 |

## Query plans and timings

| Benchmark | Execution (ms) | Planning (ms) | Shared hits | Shared reads |
|---|---:|---:|---:|---:|
| 1. Primary-key lookup | 0.068 | 0.066 | 6 | 0 |
| 2. CAST on primary key | 10.307 | 0.088 | 1291 | 0 |
| 3. Composite index | 0.091 | 0.110 | 7 | 0 |
| 4. Partial index | 0.063 | 0.289 | 5 | 0 |
| 5. Covering index | 0.092 | 0.054 | 5 | 0 |
| 6. ORDER BY expression | 8.515 | 0.061 | 1335 | 0 |
| 7. Partition pruning | 7.613 | 0.123 | 786 | 0 |
| 8. Materialized view | 0.019 | 0.049 | 2 | 0 |

## Plan details

### 1. Primary-key lookup

- Nodes: `Index Scan`
- Indexes: `customers_big_pkey`
- Order partitions scanned: `-`

### 2. CAST on primary key

- Nodes: `Seq Scan`
- Indexes: `-`
- Order partitions scanned: `-`

### 3. Composite index

- Nodes: `Limit, Index Scan`
- Indexes: `idx_customers_big_city_credit`
- Order partitions scanned: `-`

### 4. Partial index

- Nodes: `Limit, Index Scan`
- Indexes: `idx_customers_big_inactive_customer`
- Order partitions scanned: `-`

### 5. Covering index

- Nodes: `Limit, Index Only Scan`
- Indexes: `idx_customers_big_city_cover`
- Order partitions scanned: `-`

### 6. ORDER BY expression

- Nodes: `Limit, Sort, Bitmap Heap Scan, Bitmap Index Scan`
- Indexes: `idx_customers_big_city_credit`
- Order partitions scanned: `-`

### 7. Partition pruning

- Nodes: `Aggregate, Seq Scan`
- Indexes: `-`
- Order partitions scanned: `orders_2026`

### 8. Materialized view

- Nodes: `Seq Scan`
- Indexes: `-`
- Order partitions scanned: `-`

## Verification

- Required objects: PASS
- Required indexes valid and ready: PASS
- Materialized view populated: PASS
- 2026-Q1 partition pruning: PASS

Note: A timing difference alone does not prove a regression. Compare execution plans and multiple runs.
