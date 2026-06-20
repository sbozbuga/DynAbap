## DynAbap Performance Learnings

## 2024-06-14 - Replacing SELECT...ENDSELECT with Array Fetches in ABAP
**Learning:** The ABAP `SELECT...ENDSELECT` loop construct issues a separate database trip for every matching row, causing a significant N+1-like performance bottleneck in code loops. Using `SELECT ... INTO TABLE ...` fetches all rows in a single DB round-trip and allows us to iterate over them locally in memory with `LOOP AT`.
**Action:** Always favor `SELECT ... INTO TABLE ...` combined with `LOOP AT` instead of using `SELECT...ENDSELECT` loops for database access to reduce DB latency significantly. Note that `sy-subrc` will need to be cached if its check happens *after* the `LOOP AT` block.
## 2024-06-15 - SELECT...ENDSELECT vs INTO TABLE Optimization
**Learning:** Legacy ABAP `SELECT...ENDSELECT` loops lead to significant N+1-like performance issues due to excessive database round-trips. Replacing them with bulk array fetches using `SELECT ... INTO TABLE ...` and `LOOP AT ...` minimizes DB communication overhead.
**Action:** Always refactor `SELECT...ENDSELECT` constructs to `SELECT ... INTO TABLE` combined with `LOOP AT` when performance tuning ABAP codebases, especially when iterating through results inside an application logic loop.
## 2024-06-25 - Bulk fetching inside ABAP loop
**Learning:** Using `RANGE` variables built from an internal table is safe for small lists but can trigger short dumps (`CX_SY_OPEN_SQL_DB`) when the internal table grows large. Furthermore, relying on statically typed bounds (e.g. `katalogart IN ('E', 'Z')`) can cause data loss if dynamic business logic modifies variables (like `mv_katalogart` varying).
**Action:** Always prefer using `FOR ALL ENTRIES IN @itab` over building huge dynamic `RANGE` tables for bulk DB queries in ABAP. Ensure that the WHERE clause covers all possible dynamic variations (e.g., matching the fields instead of hardcoding what you think the variable might evaluate to).
