## 2024-07-10 - Consolidated JOINs eliminate ABAP N+1 patterns
**Learning:** Sequential `SELECT SINGLE` queries across linked tables (like `qmfe`, `ekkn`, `aufk`, `vbap`, `vbkd`) cause severe N+1 database roundtrip latency, a common legacy anti-pattern.
**Action:** Consolidate these into a single database hit using `LEFT OUTER JOIN`s, maintaining intermediate checks to preserve explicit fallback behaviors where downstream lookup failures don't clobber earlier values.

## 2025-01-28 - Consolidate independent sequential lookups into single DB hit
**Learning:** Legacy ABAP code often performs sequential `SELECT SINGLE` lookups based on an initial order ID (e.g. from `aufk`, then `vbak`, `afru`, `qmel` in separate queries). This triples or quadruples DB latency compared to a single roundtrip.
**Action:** Use `LEFT OUTER JOIN`s to fetch all dependent properties simultaneously in a single `SELECT SINGLE ... INTO (...)` statement, but carefully preserve the explicit backend exception behavior if intermediate logical conditions (e.g. `vbtyp NE 'G'`) fail.

## 2025-01-29 - Consolidate independent sequential lookups into single DB hit (equi/equz)
**Learning:** Sequential `SELECT SINGLE` queries on different tables (like `equi` and `equz`) that share a primary key (`equnr`) can be combined to reduce N+1-style DB roundtrips.
**Action:** Use `LEFT OUTER JOIN`s to fetch all dependent properties simultaneously in a single query when the base key is the same, reducing overhead significantly.

## 2025-05-18 - Avoid Sequential SELECT SINGLE Queries
**Learning:** Sequential SELECT SINGLE queries across linked tables (like VBAK, VBAP, VBKD) cause significant N+1 performance bottlenecks.
**Action:** Consolidate multiple sequential SELECT SINGLE queries into a single database hit using JOINs. Ensure conditional logic (e.g. IF lv_vbeln IS NOT INITIAL) is preserved.

## 2025-05-18 - Optimizing `SELECT ... UP TO 1 ROWS`
**Learning:** `SELECT * FROM table INTO @data UP TO 1 ROWS.` without an `ORDER BY` is non-deterministic and can perform poorly. It's often better to use `ORDER BY` or explicitly select exactly what is needed. Also `SELECT ... UP TO 1 ROWS` into a flat structure opens a loop implicitly and needs `ENDSELECT`.
**Action:** Use `SELECT SINGLE` when reading by full primary key, or use `UP TO 1 ROWS` combined with `ORDER BY` and `ENDSELECT` (or into a table) when fetching the "latest" record.
