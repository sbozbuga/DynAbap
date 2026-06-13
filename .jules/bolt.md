## 2026-06-13 - Replace SELECT...ENDSELECT with Array Fetches
**Learning:** In ABAP, the `SELECT...ENDSELECT` construct executes a database fetch inside a loop, which can cause excessive network round-trips and degrade performance when processing many rows.
**Action:** Replace `SELECT...ENDSELECT` loops with bulk array fetches using `SELECT ... INTO TABLE ... LOOP AT` to minimize database interactions and improve performance.
