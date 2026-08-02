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
## 2026-07-29 - Label text missing for selection screen frames
**Learning:** When building selection screens, developers often use `SELECTION-SCREEN BEGIN OF BLOCK ... WITH FRAME TITLE TEXT-xxx` but forget to add the actual text symbol in the program`s XML text pool. This results in empty frame titles, which is confusing visually and breaks accessibility for screen readers.
**Action:** Always verify that referenced `TEXT-xxx` symbols exist in the `.prog.xml` text pool (both `<TPOOL>` and `<I18N_TPOOL>`). If missing, add them to improve the UX and resolve abaplint warnings.

## 2024-05-24 - Missing Selection Screen Text for NO-DISPLAY Parameters
**Learning:** In ABAP, background selection screen parameters defined with NO-DISPLAY still require text descriptions in the text pool. Without them, they lack proper labeling in background job scheduling screens and dynamic UIs, which negatively impacts UX and accessibility for administrators.
**Action:** Always ensure background parameters (NO-DISPLAY) have corresponding text entries in default text pools (e.g., <TPOOL>).
