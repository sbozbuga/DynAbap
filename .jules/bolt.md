## DynAbap Performance Learnings

## 2024-06-14 - Replacing SELECT...ENDSELECT with Array Fetches in ABAP
**Learning:** The ABAP `SELECT...ENDSELECT` loop construct issues a separate database trip for every matching row, causing a significant N+1-like performance bottleneck in code loops. Using `SELECT ... INTO TABLE ...` fetches all rows in a single DB round-trip and allows us to iterate over them locally in memory with `LOOP AT`.
**Action:** Always favor `SELECT ... INTO TABLE ...` combined with `LOOP AT` instead of using `SELECT...ENDSELECT` loops for database access to reduce DB latency significantly. Note that `sy-subrc` will need to be cached if its check happens *after* the `LOOP AT` block.
## 2024-06-15 - SELECT...ENDSELECT vs INTO TABLE Optimization
**Learning:** Legacy ABAP `SELECT...ENDSELECT` loops lead to significant N+1-like performance issues due to excessive database round-trips. Replacing them with bulk array fetches using `SELECT ... INTO TABLE ...` and `LOOP AT ...` minimizes DB communication overhead.
**Action:** Always refactor `SELECT...ENDSELECT` constructs to `SELECT ... INTO TABLE` combined with `LOOP AT` when performance tuning ABAP codebases, especially when iterating through results inside an application logic loop.
## 2024-06-16 - Resolving N+1 issues in loops via Bulk Loading and Hashed Tables
**Learning:** Legacy ABAP `LOOP` iterations fetching secondary text descriptors sequentially via `SELECT SINGLE` trigger an N+1 problem resulting in significant database round trips when the number of items is high.
**Action:** Extract database accesses out of the loop logic. Fetch the required data points en-masse via `SELECT ... INTO TABLE ... FOR ALL ENTRIES IN ...` queries prior to the loop. Structure the internal target tables as `HASHED TABLE` with specific `UNIQUE KEY` to achieve O(1) performance during lookups. Replace the inner `SELECT SINGLE` queries with `READ TABLE ... WITH TABLE KEY ...`.
