## 2024-06-15 - SELECT...ENDSELECT vs INTO TABLE Optimization
**Learning:** Legacy ABAP `SELECT...ENDSELECT` loops lead to significant N+1-like performance issues due to excessive database round-trips. Replacing them with bulk array fetches using `SELECT ... INTO TABLE ...` and `LOOP AT ...` minimizes DB communication overhead.
**Action:** Always refactor `SELECT...ENDSELECT` constructs to `SELECT ... INTO TABLE` combined with `LOOP AT` when performance tuning ABAP codebases, especially when iterating through results inside an application logic loop.
