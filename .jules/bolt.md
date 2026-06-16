## DynAbap Performance Learnings

## 2024-06-14 - Replacing SELECT...ENDSELECT with Array Fetches in ABAP
**Learning:** The ABAP `SELECT...ENDSELECT` loop construct issues a separate database trip for every matching row, causing a significant N+1-like performance bottleneck in code loops. Using `SELECT ... INTO TABLE ...` fetches all rows in a single DB round-trip and allows us to iterate over them locally in memory with `LOOP AT`.
**Action:** Always favor `SELECT ... INTO TABLE ...` combined with `LOOP AT` instead of using `SELECT...ENDSELECT` loops for database access to reduce DB latency significantly. Note that `sy-subrc` will need to be cached if its check happens *after* the `LOOP AT` block.
## 2024-06-15 - SELECT...ENDSELECT vs INTO TABLE Optimization
**Learning:** Legacy ABAP `SELECT...ENDSELECT` loops lead to significant N+1-like performance issues due to excessive database round-trips. Replacing them with bulk array fetches using `SELECT ... INTO TABLE ...` and `LOOP AT ...` minimizes DB communication overhead.
**Action:** Always refactor `SELECT...ENDSELECT` constructs to `SELECT ... INTO TABLE` combined with `LOOP AT` when performance tuning ABAP codebases, especially when iterating through results inside an application logic loop.
## 2024-06-16 - Pushing Loop Filters to the DB
**Learning:** Moving internal table loop conditions (`IF stokz = space AND stzhl = '00000000' EXIT.`) into the `WHERE` clause of a `SELECT SINGLE` query successfully avoids fetching unnecessary rows over the network.
**Action:** When identifying `SELECT ... INTO TABLE ... LOOP AT` blocks that exit after the first specific match, replace them with `SELECT SINGLE` using the exact conditions in the `WHERE` clause.

## 2024-06-16 - Anti-pattern: Multiple DB queries vs Single Array Fetch
**Learning:** Trying to preserve complex, unintended legacy loop side-effects (e.g. keeping variable states from the last row) by replacing a single `SELECT INTO TABLE` with multiple separate queries (`SELECT COUNT(*)`, `SELECT SINGLE`, `SELECT ... UP TO 1 ROWS`) is a performance anti-pattern. If the original query fetches a small dataset, the overhead of multiple network roundtrips is worse than processing a small internal table in memory.
**Action:** Do not sacrifice single array fetch efficiency for multiple DB queries just to emulate rare legacy fallbacks. Either find a single-query solution or leave the `SELECT INTO TABLE` alone if it's already fast enough.
