# QueryForge Day 74 - Crash Recovery & Concurrency

Generated: 2026-10-17 16:31 UTC

- Day 72 upload ID: 1
- Status: COMPLETED
- Source snapshot rows: 4
- Processed rows: 4
- Stored rows: 4
- Committed batches: 2
- Last source row: 7

- Crash injection: deliberately raised before commit; verified separately by the PowerShell runner.
- Two worker processes: verified separately by the PowerShell runner.
- qf_day72 and qf_day73 were not modified by this demo.
- Production crash and multi-host guarantees remain untested.
