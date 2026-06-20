## 2025-02-14 - Prevent Information Leakage in Exception Handling
**Vulnerability:** Raw exception text from `cx_root` and its subclasses was directly displayed in the UI via `lx_driver_err->message` and `lx_print_error->message`.
**Learning:** Exposing detailed technical errors directly to users allows for potential information leakage regarding internal system or database states.
**Prevention:** Always log exceptions securely on the backend (e.g., using `/ctdi/cl_print_driver_log=>log_exception( lx_err )`) and display a sanitized, generic error message to the user.
