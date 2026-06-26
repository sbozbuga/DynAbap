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

## $(date +%Y-%m-%d) - Prevent O(N*M) nested loop lookups with BINARY SEARCH
**Learning:** Found multiple instances where `READ TABLE` was executed inside a `LOOP AT` without utilizing `BINARY SEARCH`. In ABAP, internal table lookups without `BINARY SEARCH` result in a sequential O(N) scan. When nested inside an O(M) loop, this balloons into a major O(N*M) performance bottleneck, especially as result sets scale up.
**Action:** Always ensure the target internal table is sorted correctly by the lookup keys and append the `BINARY SEARCH` addition to `READ TABLE` statements occurring inside loops to reduce the lookup time to O(log N).

## 2024-05-15 - Prefer field symbols over work areas in loops
**Learning:** Found instances where large loops were copying entire table structures into variables (`INTO DATA(...)`) instead of simply pointing to memory. In ABAP, assigning a field symbol is functionally passing by reference, preventing a heavy memory copy operation on each loop iteration.
**Action:** When iterating over or reading internal tables in ABAP, always prefer using inline declarations with field symbols (`ASSIGNING FIELD-SYMBOL(<ls_row>)`) to minimize overhead.
## 2026-06-22 - Safe FIELD-SYMBOL substitution inside loops
**Learning:** When using `ASSIGNING FIELD-SYMBOL(<...>)` in ABAP `LOOP AT` statements to prevent expensive memory copying, any modifications made to the field symbol will mutate the original internal table. If the logic requires changing values (e.g., updating a parameter `kind` attribute before passing to another function) but the original source table must remain unaltered, modifying the field symbol directly is dangerous and causes side effects.
**Action:** When replacing `INTO DATA()` with `ASSIGNING FIELD-SYMBOL()` in loops where data modification is necessary, introduce a local copy (e.g., `DATA(ls_insert) = <fs>`) *inside* the loop, ideally only after validation conditions (like a successful `READ TABLE`) are met. This maximizes performance by avoiding copies for rejected rows while preserving the safety of the source data.

## 2026-06-23 - Optimize LOOP AT memory allocation overhead
**Learning:** Found multiple instances where large internal tables were iterated over using `LOOP AT ... INTO DATA(...)`, which unnecessarily copies the data of each row into a new work area on every iteration, leading to increased memory allocation and CPU overhead.
**Action:** When iterating over internal tables in ABAP without the need to modify a separate copy of the data, always prefer using `LOOP AT ... ASSIGNING FIELD-SYMBOL(<...>)` to iterate via references, completely eliminating the copying overhead.

## 2026-06-23 - Push SORT and LIMIT down to DB for change tracking tables
**Learning:** Legacy code often fetches an entire history of changes (e.g. from `jcds` or `cdpos`) into an internal table, then sorts it and reads `INDEX 1` to find the latest record. This causes excessive data transfer and high memory usage.
**Action:** Always shift this logic to the database level using `ORDER BY ... DESCENDING` combined with `UP TO 1 ROWS` (into a table, then read index 1) to significantly reduce DB communication overhead and application server memory consumption.
