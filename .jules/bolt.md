## 2024-07-10 - Consolidated JOINs eliminate ABAP N+1 patterns
**Learning:** Sequential `SELECT SINGLE` queries across linked tables (like `qmfe`, `ekkn`, `aufk`, `vbap`, `vbkd`) cause severe N+1 database roundtrip latency, a common legacy anti-pattern.
**Action:** Consolidate these into a single database hit using `LEFT OUTER JOIN`s, maintaining intermediate checks to preserve explicit fallback behaviors where downstream lookup failures don't clobber earlier values.
## 2025-01-28 - Consolidate independent sequential lookups into single DB hit
**Learning:** Legacy ABAP code often performs sequential `SELECT SINGLE` lookups based on an initial order ID (e.g. from `aufk`, then `vbak`, `afru`, `qmel` in separate queries). This triples or quadruples DB latency compared to a single roundtrip.
**Action:** Use `LEFT OUTER JOIN`s to fetch all dependent properties simultaneously in a single `SELECT SINGLE ... INTO (...)` statement, but carefully preserve the explicit backend exception behavior if intermediate logical conditions (e.g. `vbtyp NE 'G'`) fail.
## 2025-01-29 - Consolidate independent sequential lookups into single DB hit (equi/equz)
**Learning:** Sequential `SELECT SINGLE` queries on different tables (like `equi` and `equz`) that share a primary key (`equnr`) can be combined to reduce N+1-style DB roundtrips.
**Action:** Use `LEFT OUTER JOIN`s to fetch all dependent properties simultaneously in a single query when the base key is the same, reducing overhead significantly.
## 2026-07-15 - Consolidate sequential dependent lookups into single DB hit (equi/mara)
**Learning:** Sequential `SELECT SINGLE` queries where the result of the first query (e.g. `matnr` from `equi`) is used in the `WHERE` clause of the second (e.g. `mfrpn` from `mara`) artificially double the database latency.
**Action:** Use `LEFT OUTER JOIN`s (e.g. `equi AS e LEFT OUTER JOIN mara AS m ON m~matnr = e~matnr`) to fetch both the base record and its foreign-key dependent properties in a single database roundtrip.
