## 2025-02-13 - [Error Message Info Leakage]
**Vulnerability:** The unhandled exception catch block (`CATCH cx_root`) in `src/#ctdi#print_driver_program.prog.abap` was directly outputting the raw exception text (`lx_root->get_text( )`) to the user interface via a standard ABAP `MESSAGE` statement.
**Learning:** This could leak internal system details, table names, or code paths to end users, aiding potential attackers. ABAP developers frequently pass exception texts to the UI, which is a bad practice for unexpected system errors.
**Prevention:** Always log the detailed exception text securely to a backend log (like `BAL_LOG_MSG_ADD`), and present a sanitized, generic error message to the user.

## 2025-02-14 - [Information Exposure through Exception Text via String Templates]
**Vulnerability:** In `src/#ctdi#cl_print_driver_base.clas.abap`, technical exception details (`lx_fp->get_text( )` and `lx_dyn_call->get_text( )`) were being concatenated into error message strings (`lv_err`) via string templates and subsequently propagated up and displayed to the user UI, exposing internal stack and technical specifics.
**Learning:** This highlights a common pattern in ABAP string templating where `|... { lx_ex->get_text( ) } ...|` is used to build error messages. It exposes inner workings to the user which is a security risk.
**Prevention:** Avoid embedding `get_text( )` output in string templates intended for UI presentation. Instead, write generic UI error strings to the user, log the detailed `get_text( )` directly to backend logging mechanisms, and use the `previous` parameter of custom exceptions to preserve the error chain for backend debugging without exposing it on the frontend.
