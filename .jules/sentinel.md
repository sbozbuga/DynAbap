## 2025-02-14 - Prevent Information Leakage in Exception Handling
**Vulnerability:** Raw exception text from `cx_root` and its subclasses was directly displayed in the UI via `lx_driver_err->message` and `lx_print_error->message`.
**Learning:** Exposing detailed technical errors directly to users allows for potential information leakage regarding internal system or database states.
**Prevention:** Always log exceptions securely on the backend (e.g., using `/ctdi/cl_print_driver_log=>log_exception( lx_err )`) and display a sanitized, generic error message to the user.
## 2025-02-13 - [Error Message Info Leakage]
**Vulnerability:** The unhandled exception catch block (`CATCH cx_root`) in `src/#ctdi#print_driver_program.prog.abap` was directly outputting the raw exception text (`lx_root->get_text( )`) to the user interface via a standard ABAP `MESSAGE` statement.
**Learning:** This could leak internal system details, table names, or code paths to end users, aiding potential attackers. ABAP developers frequently pass exception texts to the UI, which is a bad practice for unexpected system errors.
**Prevention:** Always log the detailed exception text securely to a backend log (like `BAL_LOG_MSG_ADD`), and present a sanitized, generic error message to the user.

## 2025-02-14 - [Information Exposure through Exception Text via String Templates]
**Vulnerability:** In `src/#ctdi#cl_print_driver_base.clas.abap`, technical exception details (`lx_fp->get_text( )` and `lx_dyn_call->get_text( )`) were being concatenated into error message strings (`lv_err`) via string templates and subsequently propagated up and displayed to the user UI, exposing internal stack and technical specifics.
**Learning:** This highlights a common pattern in ABAP string templating where `|... { lx_ex->get_text( ) } ...|` is used to build error messages. It exposes inner workings to the user which is a security risk.
**Prevention:** Avoid embedding `get_text( )` output in string templates intended for UI presentation. Instead, write generic UI error strings to the user, log the detailed `get_text( )` directly to backend logging mechanisms, and use the `previous` parameter of custom exceptions to preserve the error chain for backend debugging without exposing it on the frontend.

## 2025-02-14 - [Information Exposure through Custom Exception Attributes]
**Vulnerability:** In `src/#ctdi#print_repair.prog.abap`, when catching `/ctdi/cx_print_driver_error`, the custom error text (`lx_driver_err->message`) was directly assigned to the UI message variable `lv_emsg` and displayed. This exposed internal technical details such as table names, system variables, and class names (e.g., "Cannot instantiate class X", "No configuration found in /CTDI/REP_FORMS").
**Learning:** It's not just standard `cx_root->get_text()` that leaks information. Custom exception objects with a `message` attribute can contain highly technical error messages meant for backend logging, which should not be exposed directly to end-users on the frontend.
**Prevention:** Always log technical exception attributes using `/ctdi/cl_print_driver_log=>log_exception()` or `log_error()` and provide a sanitized, generic error message string (e.g., `TEXT-007`) to the user UI.
## 2025-02-14 - Information Leakage through Exception Attribute
**Vulnerability:** In `src/templates/sm30_event_class_generator.abap`, the custom exception text `lx_err->message` was directly assigned to a `MESSAGE ... TYPE 'W'` statement, exposing potentially sensitive backend information directly to the UI.
**Learning:** Even within generated standard SAP templates (like SM30 table maintenance events), custom exceptions may still contain technical messages intended for backend tracing rather than UI exposure. Passing exception texts, custom attributes, or output directly into ABAP UI messages compromises security and can leak database table, configuration, or structural names.
**Prevention:** Always sanitize UI error messages in ABAP dialogs. Instead of embedding custom exception attributes, utilize a standardized logging layer (e.g., `/ctdi/cl_print_driver_log=>log_exception`) to store technical details securely, and issue a generic, safe `MESSAGE` string to the frontend user.
## 2025-02-14 - Information Leakage through Raw Exception Text in TRY-CATCH block
**Vulnerability:** In `src/#ctdi#print_repair.prog.abap`, the raw text representation of multiple exceptions (`lx_noconf->get_text( )`, `lx_driver_err->get_text( )`, and `lx_root->get_text( )`) was directly captured into `lv_emsg` and displayed on the UI.
**Learning:** Returning `get_text( )` outputs directly to the UI compromises application security by exposing internal workings (like missing class instantiations, configuration paths, database fields).
**Prevention:** Instead of exposing `get_text( )`, always log the exception instance using a standard backend mechanism (e.g. `/ctdi/cl_print_driver_log=>log_exception( lx_err )`) and output a sanitized generic text symbol (e.g. `TEXT-007`) to the user interface.
