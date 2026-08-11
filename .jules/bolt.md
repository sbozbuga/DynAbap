## 2024-07-10 - Consolidated JOINs eliminate ABAP N+1 patterns
**Learning:** Sequential `SELECT SINGLE` queries across linked tables (like `qmfe`, `ekkn`, `aufk`, `vbap`, `vbkd`) cause severe N+1 database roundtrip latency, a common legacy anti-pattern.
**Action:** Consolidate these into a single database hit using `LEFT OUTER JOIN`s, maintaining intermediate checks to preserve explicit fallback behaviors where downstream lookup failures don't clobber earlier values.
## 2025-01-28 - Consolidate independent sequential lookups into single DB hit
**Learning:** Legacy ABAP code often performs sequential `SELECT SINGLE` lookups based on an initial order ID (e.g. from `aufk`, then `vbak`, `afru`, `qmel` in separate queries). This triples or quadruples DB latency compared to a single roundtrip.
**Action:** Use `LEFT OUTER JOIN`s to fetch all dependent properties simultaneously in a single `SELECT SINGLE ... INTO (...)` statement, but carefully preserve the explicit backend exception behavior if intermediate logical conditions (e.g. `vbtyp NE 'G'`) fail.
## 2025-01-29 - Consolidate independent sequential lookups into single DB hit (equi/equz)
**Learning:** Sequential `SELECT SINGLE` queries on different tables (like `equi` and `equz`) that share a primary key (`equnr`) can be combined to reduce N+1-style DB roundtrips.
**Action:** Use `LEFT OUTER JOIN`s to fetch all dependent properties simultaneously in a single query when the base key is the same, reducing overhead significantly.
## 2025-01-29 - Consolidate sequential lookups into single DB hit (vbak)
**Learning:** Legacy ABAP code often performs sequential `SELECT SINGLE` lookups based on an initial order ID or similar (e.g., getting a field from a row, then checking another field of that row, or joining to a related table). Here, `SELECT SINGLE vgbel FROM vbak` then `SELECT SINGLE vbtyp FROM vbak` on the same document are two trips to the DB, causing N+1-style overhead.
**Action:** Consolidate these into a single database hit using a single query fetching all required fields (e.g., `vgbel, vbtyp`), avoiding redundant DB roundtrips.
