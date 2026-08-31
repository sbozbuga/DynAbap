## 2024-07-10 - Consolidated JOINs eliminate ABAP N+1 patterns
**Learning:** Sequential `SELECT SINGLE` queries across linked tables (like `qmfe`, `ekkn`, `aufk`, `vbap`, `vbkd`) cause severe N+1 database roundtrip latency, a common legacy anti-pattern.
**Action:** Consolidate these into a single database hit using `LEFT OUTER JOIN`s, maintaining intermediate checks to preserve explicit fallback behaviors where downstream lookup failures don't clobber earlier values.
## 2025-01-28 - Consolidate independent sequential lookups into single DB hit
**Learning:** Legacy ABAP code often performs sequential `SELECT SINGLE` lookups based on an initial order ID (e.g. from `aufk`, then `vbak`, `afru`, `qmel` in separate queries). This triples or quadruples DB latency compared to a single roundtrip.
**Action:** Use `LEFT OUTER JOIN`s to fetch all dependent properties simultaneously in a single `SELECT SINGLE ... INTO (...)` statement, but carefully preserve the explicit backend exception behavior if intermediate logical conditions (e.g. `vbtyp NE 'G'`) fail.
## 2025-01-29 - Consolidate independent sequential lookups into single DB hit (equi/equz)
**Learning:** Sequential `SELECT SINGLE` queries on different tables (like `equi` and `equz`) that share a primary key (`equnr`) can be combined to reduce N+1-style DB roundtrips.
**Action:** Use `LEFT OUTER JOIN`s to fetch all dependent properties simultaneously in a single query when the base key is the same, reducing overhead significantly.
## 2025-01-29 - Consolidate sequential self-lookups into single DB hit (vbak)
**Learning:** Sequential `SELECT SINGLE` queries on the exact same database table (like fetching `vbak-vgbel` first, then querying `vbak` again to check `vbtyp` of the result) cause unnecessary database latency.
**Action:** Use a self `LEFT OUTER JOIN` (e.g., `vbak AS a LEFT OUTER JOIN vbak AS b ON b~vbeln = a~vgbel`) to fetch both the initial and related document fields in a single query, preserving explicit application fallback behaviors.
## 2025-01-29 - Consolidate sequential equi and mara lookups into single DB hit
**Learning:** Sequential `SELECT SINGLE` queries on `equi` and `mara` linked by `matnr` cause N+1 database roundtrip latency.
**Action:** Consolidate these into a single database hit using `LEFT OUTER JOIN`s, maintaining intermediate checks for when `matnr` is already populated.
## 2025-01-29 - Bypassing table buffers with ORDER BY degrades performance
**Learning:** Forcing a consolidated `SELECT UP TO 1 ROWS` with an `ORDER BY` clause to replace fallback `SELECT SINGLE` queries is an anti-pattern for configuration tables. `SELECT SINGLE` reads highly-optimized SAP table buffers. Adding an `ORDER BY` explicitly bypasses the buffer, causing a database roundtrip and degrading performance. Additionally, ABAP Strict Mode requires `UP TO 1 ROWS` to precede the `INTO` clause.
**Action:** Do not consolidate fallback `SELECT SINGLE` queries into a single query using `ORDER BY` for configuration tables, as it bypasses SAP table buffering. Sequential `SELECT SINGLE` queries are faster because they leverage the buffer.
## 2025-01-29 - Consolidate conditional sequential lookups into single DB hit
**Learning:** Sequential `SELECT SINGLE` queries where a subsequent query is executed based on a condition (e.g., `IF kdauf IS NOT INITIAL`) cause N+1 database roundtrips when the condition is met.
**Action:** Consolidate these into a single database hit using `LEFT OUTER JOIN`s. The database handles the conditional linking efficiently via the `ON` clause, eliminating the need for application-level conditional queries and reducing DB latency.
## 2025-01-29 - Consolidate afih and objk lookups into single DB hit
**Learning:** When resolving a Notification (qmnum) for a Maintenance Order (aufnr), sequential lookups on Order Header (afih) and Object List (objk) tables cause unnecessary database roundtrips.
**Action:** Consolidate these into a single LEFT OUTER JOIN on obknr (Object list number) to prevent N+1 database roundtrips.
## 2025-01-29 - Push CDPOS filtering to database level
**Learning:** Fetching unfiltered change document items from massive tables like `CDPOS` into ABAP internal tables and discarding irrelevant rows locally causes massive memory overhead and DB transfer latency.
**Action:** Push filter conditions (like `tabname` and `fname`) directly to the database query in the `WHERE` clause to drastically reduce DB load.
