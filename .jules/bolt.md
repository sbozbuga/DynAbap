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
