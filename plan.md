1. **Add `SORT` before `DELETE ADJACENT DUPLICATES` in `src/#ctdi#cl_print_data_legacy.clas.abap`.**
   - Use `replace_with_git_merge_diff` to modify `src/#ctdi#cl_print_data_legacy.clas.abap`. Replace the existing `DELETE ADJACENT DUPLICATES` lines with:
     ```abap
     <<<<<<< SEARCH
         DELETE ADJACENT DUPLICATES FROM lt_qpgt COMPARING katalogart codegruppe.

         DELETE ADJACENT DUPLICATES FROM lt_qpct COMPARING katalogart codegruppe code.
     =======
         " ⚡ Bolt Optimization: Ensure tables are sorted before deduplication and binary search
         SORT lt_qpgt BY katalogart codegruppe.
         DELETE ADJACENT DUPLICATES FROM lt_qpgt COMPARING katalogart codegruppe.

         SORT lt_qpct BY katalogart codegruppe code.
         DELETE ADJACENT DUPLICATES FROM lt_qpct COMPARING katalogart codegruppe code.
     >>>>>>> REPLACE
     ```
2. **Review the fix by reading the file**
   - Use `sed -n '508,520p' src/#ctdi#cl_print_data_legacy.clas.abap` to check that the `SORT` statements were placed correctly.
3. **Run Lint Checks**
   - Run `pnpm dlx @abaplint/cli -c abaplint.json` to verify that there are no regressions.
4. **Complete Pre-Commit Steps**
   - Ensure proper testing, verification, review, and reflection are done.
5. **Submit the PR**
   - Call `submit` tool with branch name `bolt-sort-opt` and title `⚡ Bolt: Add missing SORT for binary search tables`.
   - The description must exactly match:
     ```
     💡 What: Added `SORT` statements before `DELETE ADJACENT DUPLICATES` for `lt_qpgt` and `lt_qpct` in `src/#ctdi#cl_print_data_legacy.clas.abap`.
     🎯 Why: The internal tables were being deduplicated and later read using `BINARY SEARCH` without being explicitly sorted first. This guarantees accurate deduplication and optimal O(log N) binary search performance.
     📊 Impact: Prevents `BINARY SEARCH` from failing or falling back to O(N) sequential scans, improving performance during nested lookups.
     🔬 Measurement: Verify that memory allocation and table reads perform consistently faster when deduplication is strictly enforced by prior sorting.
     ```
