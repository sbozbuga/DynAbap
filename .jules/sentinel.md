## 2025-02-13 - [Error Message Info Leakage]
**Vulnerability:** The unhandled exception catch block (`CATCH cx_root`) in `src/#ctdi#print_driver_program.prog.abap` was directly outputting the raw exception text (`lx_root->get_text( )`) to the user interface via a standard ABAP `MESSAGE` statement.
**Learning:** This could leak internal system details, table names, or code paths to end users, aiding potential attackers. ABAP developers frequently pass exception texts to the UI, which is a bad practice for unexpected system errors.
**Prevention:** Always log the detailed exception text securely to a backend log (like `BAL_LOG_MSG_ADD`), and present a sanitized, generic error message to the user.
