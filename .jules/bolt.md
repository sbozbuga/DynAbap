## 2024-07-10 - Consolidated JOINs eliminate ABAP N+1 patterns
**Learning:** Sequential `SELECT SINGLE` queries across linked tables (like `qmfe`, `ekkn`, `aufk`, `vbap`, `vbkd`) cause severe N+1 database roundtrip latency, a common legacy anti-pattern.
**Action:** Consolidate these into a single database hit using `LEFT OUTER JOIN`s, maintaining intermediate checks to preserve explicit fallback behaviors where downstream lookup failures don't clobber earlier values.
## 2025-01-28 - Consolidate independent sequential lookups into single DB hit
**Learning:** Legacy ABAP code often performs sequential `SELECT SINGLE` lookups based on an initial order ID (e.g. from `aufk`, then `vbak`, `afru`, `qmel` in separate queries). This triples or quadruples DB latency compared to a single roundtrip.
**Action:** Use `LEFT OUTER JOIN`s to fetch all dependent properties simultaneously in a single `SELECT SINGLE ... INTO (...)` statement, but carefully preserve the explicit backend exception behavior if intermediate logical conditions (e.g. `vbtyp NE 'G'`) fail.
## 2025-01-29 - Consolidate independent sequential lookups into single DB hit (equi/equz)
**Learning:** Sequential `SELECT SINGLE` queries on different tables (like `equi` and `equz`) that share a primary key (`equnr`) can be combined to reduce N+1-style DB roundtrips.
**Action:** Use `LEFT OUTER JOIN`s to fetch all dependent properties simultaneously in a single query when the base key is the same, reducing overhead significantly.
## 2024-07-25 - Consolidate equi and mara lookups
**Learning:** Sequential `SELECT SINGLE` lookups on `equi` and `mara` within the same logical path cause unnecessary database round-trips.
**Action:** Use a `LEFT OUTER JOIN` between `equi` and `mara` based on `matnr` to fetch equipment and material data in a single query when the equipment number is known, significantly reducing DB latency.
