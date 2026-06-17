## DynAbap Performance Learnings

## 2024-06-14 - Replacing SELECT...ENDSELECT with Array Fetches in ABAP
**Learning:** The ABAP `SELECT...ENDSELECT` loop construct issues a separate database trip for every matching row, causing a significant N+1-like performance bottleneck in code loops. Using `SELECT ... INTO TABLE ...` fetches all rows in a single DB round-trip and allows us to iterate over them locally in memory with `LOOP AT`.
**Action:** Always favor `SELECT ... INTO TABLE ...` combined with `LOOP AT` instead of using `SELECT...ENDSELECT` loops for database access to reduce DB latency significantly. Note that `sy-subrc` will need to be cached if its check happens *after* the `LOOP AT` block.
## 2024-06-15 - SELECT...ENDSELECT vs INTO TABLE Optimization
**Learning:** Legacy ABAP `SELECT...ENDSELECT` loops lead to significant N+1-like performance issues due to excessive database round-trips. Replacing them with bulk array fetches using `SELECT ... INTO TABLE ...` and `LOOP AT ...` minimizes DB communication overhead.
**Action:** Always refactor `SELECT...ENDSELECT` constructs to `SELECT ... INTO TABLE` combined with `LOOP AT` when performance tuning ABAP codebases, especially when iterating through results inside an application logic loop.
## 2024-06-16 - Replacing SELECT SINGLE inside loops with bulk fetching
**Learning:** Performing `SELECT SINGLE` queries inside an ABAP `LOOP AT` block for things like fetching texts (`qpgt`, `qpct`) leads to N+1 query performance issues, especially when iterating through items like repair results/errors.
**Action:** Extract loop variables into range tables (`RANGE OF`), perform a single `SELECT ... INTO TABLE ...` before the loop, and use `READ TABLE` inside the loop to fetch data from memory. Sort and remove duplicates from range tables for optimal DB fetching.
