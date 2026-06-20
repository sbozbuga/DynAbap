## 2026-06-16 - Add success toast messages for report executions
**Learning:** Background processes or reports that execute silently on success leave the user guessing if their action worked. Adding a simple status message (e.g. `MESSAGE '...' TYPE 'S'`) provides immediate, clear confirmation.
**Action:** Always include a success message for UI actions that do not otherwise provide clear visual feedback or state changes upon successful completion.

## 2026-06-20 - Use non-blocking error messages on selection screens
**Learning:** Hard-abort `TYPE 'E'` messages at the end of report execution can disrupt the user flow by locking the screen or requiring extra interaction. Using `TYPE 'S' DISPLAY LIKE 'E'` provides clear, red visual feedback while keeping the interface responsive and smooth.
**Action:** Replace `TYPE 'E'` messages with `TYPE 'S' DISPLAY LIKE 'E'` for report execution errors on selection screens to improve UX.
