## 2026-06-16 - Add success toast messages for report executions
**Learning:** Background processes or reports that execute silently on success leave the user guessing if their action worked. Adding a simple status message (e.g. `MESSAGE '...' TYPE 'S'`) provides immediate, clear confirmation.
**Action:** Always include a success message for UI actions that do not otherwise provide clear visual feedback or state changes upon successful completion.

## 2026-06-20 - Use non-blocking error messages on selection screens
**Learning:** Hard-abort `TYPE 'E'` messages at the end of report execution can disrupt the user flow by locking the screen or requiring extra interaction. Using `TYPE 'S' DISPLAY LIKE 'E'` provides clear, red visual feedback while keeping the interface responsive and smooth.
**Action:** Replace `TYPE 'E'` messages with `TYPE 'S' DISPLAY LIKE 'E'` for report execution errors on selection screens to improve UX.

## 2026-07-04 - Avoid hard aborts in legacy class wrappers
**Learning:** When wrapping legacy data classes (like `cl_print_data_legacy`) in a modern framework, using hard-abort `TYPE 'E'` messages deeply nested in the backend logic disrupts the user flow by locking the UI or terminating the application unexpectedly.
**Action:** Replace `TYPE 'E'` with non-blocking errors (`TYPE 'S' DISPLAY LIKE 'E'`) even inside legacy classes to maintain a responsive and smooth user experience without crashing the wrapper.

## 2026-07-28 - Maintain persistent status bar feedback alongside popup logs
**Learning:** When displaying a popup log in ABAP, the background selection screen's status bar should still be updated with a non-blocking success or error message. Otherwise, users who close the log immediately are left without persistent visual feedback of the execution outcome.
**Action:** Always ensure status bar messages are displayed independently of popup log displays to maintain consistent UI feedback.

## 2026-08-01 - Add missing selection screen text labels
**Learning:** Screen readers and everyday users rely on text symbols in selection screens for proper context. Without corresponding `.prog.xml` text symbols, ABAP falls back to generic frame numbers or empty strings, reducing screen accessibility and intuitive navigation.
**Action:** Always verify that block titles (e.g. `WITH FRAME TITLE TEXT-XYZ`) and input labels have corresponding valid entries in the program's `<TPOOL>` texts, ensuring proper accessibility and UI labeling.
