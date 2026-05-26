# Implementation Plan — Borrow Legacy Print Logic & Parameters

This plan outlines the enhancements to the dynamic printing pipeline in **DynAbap** by borrowing robust, production-proven print initialization logic and parameter overrides from the legacy program **`/CELLAG/ALCAREP02`**.

## User Review Required

Please review the following enhancements that will be ported from the legacy program into the modern dynamic architecture:

> [!IMPORTANT]
> 1. **Removal of Direct `USR01` Queries**: We will replace direct database reads of the `USR01` table with the standard SAP API **`SUSR_USER_DEFAULTS_GET`**. This complies with Clean ABAP principles and guarantees cloud-compatibility and safety.
> 2. **Spool Parameter override via SET/GET Parameter**: We will add support for the user profile parameter **`/CELLAG/PAFR`** (defined as constant `co_pafr_para` in the old app) to allow users to override default printers on their SAP profile parameters.
> 3. **Dynamic Printer Device Type Resolution**: We will borrow the call to **`SSF_GET_DEVICE_TYPE`** to dynamically set the correct printer layout device type based on the user's language before calling a Smart Form.
> 4. **SM30 Customizing Table Validation (Obligatory Interface)**:
>    * When saving or editing a customizing record in table `/CTDI/REP_FORMS` via Transaction `SM30`, the customizing engine **must validate** that any existing class name implements the mandatory interface `/CTDI/IF_REPAIR_PRINT_PROVIDER` (by querying the relation table `seometarel`). Any class without this interface will be **strictly rejected**.
> 5. **Default Class and Unconditional Method Enforcement**:
>    * On creating a new entry in SM30 (`on_new_entry`), the class name is automatically defaulted to the standard base class **`/CTDI/CL_REPAIR_PRINT_BASE`** and the method name is defaulted to **`EXECUTE`**.
>    * During the save event (`ON_BEFORE_SAVE`), the engine **unconditionally overrides** the method name to **`EXECUTE`** for all entries, enforcing obligatory interface standards and allowing developers to hide the method name field from the SM30 customizing screen safely.
> 6. **Package and Transport Prompting on Class Auto-Generation**:
>    * If the class does not exist, the engine will still prompt to generate it. 
>    * To prevent orphaned local objects, the engine will present a popup dialog (`POPUP_TO_GET_VALUES`) requesting the **Development Package**, defaulting to the application package **`/CTDI/WORKSHOP`**. If a transportable package is selected, standard SAP transport routines inside `SEO_CLASS_COPY` will automatically prompt the user to assign the class to an active **Transport Request**, guaranteeing safe deployment across QA/PRD environments.

---

## Proposed Changes

We will modify two key files in the repository:
1. The base print class **`#ctdi#cl_repair_print_base.clas.abap`** to implement the improved print parameters initialization.
2. The wrapper program **`#ctdi#sd_repair_print_program.prog.abap`** to support consistent parameters and standalone/fallback options.

---

### Dynamic Engine Base Class

#### [MODIFY] [cl_repair_print_base.clas.abap](file:///D:/_Repos/DynAbap/src/%23ctdi%23cl_repair_print_base.clas.abap)

* **Refactor User Defaults Retrieval**:
  Replace the direct database query of `usr01` on line 75 with the standard SAP function module **`SUSR_USER_DEFAULTS_GET`**.
* **Integrate User Parameter Override**:
  Call `GET PARAMETER ID '/CELLAG/PAFR'` and let it take precedence over standard user defaults.
* **Integrate Smart Form Device Type Auto-Detection**:
  Call `SSF_GET_DEVICE_TYPE` and set `ls_output_options-tdprinter` when preparing Smart Forms.
* **Batch Mode (`sy-batch`) Safety Check**:
  Add checks in `download_pdf` to guard against execution in background batch mode.
  * If `sy-batch` is active, bypass GUI file dialogs (`cl_gui_frontend_services`) and write a standard warning log to `/CTDI/CL_REPAIR_LOG` instead of attempting frontend downloads, which prevent short dumps in automated background processes.

##### Code Diff draft for `sy-batch` guard:
```abap
  METHOD download_pdf.
    ...
    " Guard against execution in background processing (Batch mode)
    IF sy-batch IS NOT INITIAL.
      /ctdi/cl_repair_log=>log_warning( |Presentation layer download bypassed for Repair { iv_repair_id } in batch mode.| ).
      RETURN.
    ENDIF.
    ...
```

##### Code Diff draft:
```diff
-    " Fetch User Print Defaults from USR01
-    SELECT SINGLE * FROM usr01 INTO @ls_usr01 WHERE bname = @sy-uname.
+    " 1. Retrieve User Defaults using standard SAP API
+    DATA: ls_user_defaults TYPE usdefaults.
+    CALL FUNCTION 'SUSR_USER_DEFAULTS_GET'
+      EXPORTING
+        user_name     = sy-uname
+      IMPORTING
+        user_defaults = ls_user_defaults
+      EXCEPTIONS
+        OTHERS        = 1.
+
+    " 2. Check for user-specific SET/GET parameter override (/CELLAG/PAFR)
+    DATA: lv_user_printer TYPE paramval.
+    GET PARAMETER ID '/CELLAG/PAFR' FIELD lv_user_printer.
+
+    " 3. Determine the output printer destination
+    DATA(lv_printer_dest) = COND #( WHEN lv_user_printer IS NOT INITIAL
+                                    THEN lv_user_printer
+                                    ELSE ls_user_defaults-spld ).
```

For **Smart Forms (Type `S`)**:
```diff
-      " Apply user printing defaults if configured
-      IF ls_usr01-spld IS NOT INITIAL.
-        ls_output_options-tddest   = ls_usr01-spld.
-        ls_output_options-tdimmed  = ls_usr01-splg.
-*        ls_output_options-tddel    = ls_usr01-spda.
-      ENDIF.
+      " Apply printer and format options
+      ls_output_options-tddest   = lv_printer_dest.
+      ls_output_options-tdcopies = 1.
+      ls_output_options-tdimmed  = COND #( WHEN ls_user_defaults-splg IS NOT INITIAL THEN ls_user_defaults-splg ELSE abap_true ).
+      ls_output_options-tddelete = COND #( WHEN ls_user_defaults-spda IS NOT INITIAL THEN ls_user_defaults-spda ELSE abap_true ).
+      ls_output_options-tdnewid  = abap_true.
+
+      " Dynamic Device Type detection based on language
+      DATA: lv_devtype TYPE rspoptype.
+      CALL FUNCTION 'SSF_GET_DEVICE_TYPE'
+        EXPORTING
+          i_language    = sy-langu
+          i_application = 'SAPDEFAULT'
+        IMPORTING
+          e_devtype     = lv_devtype.
+      ls_output_options-tdprinter = lv_devtype.
```

For **Adobe Forms (Type `A`)**:
```diff
-      " Apply user printing defaults if configured
-      IF ls_usr01-spld IS NOT INITIAL.
-        ls_outputparams-dest   = ls_usr01-spld.
-        ls_outputparams-reqimm = ls_usr01-splg.
-        ls_outputparams-reqdel = ls_usr01-spda.
-      ENDIF.
+      " Apply printer and format options
+      ls_outputparams-dest   = lv_printer_dest.
+      ls_outputparams-reqimm = COND #( WHEN ls_user_defaults-splg IS NOT INITIAL THEN ls_user_defaults-splg ELSE abap_true ).
+      ls_outputparams-reqdel = COND #( WHEN ls_user_defaults-spda IS NOT INITIAL THEN ls_user_defaults-spda ELSE abap_true ).
```

---

### Dynamic Engine Core

#### [MODIFY] [cl_repair_print_engine.clas.abap](file:///D:/_Repos/DynAbap/src/%23ctdi%23cl_repair_print_engine.clas.abap)

* **Enforce Strict Interface Usage**:
  Remove the legacy dynamic method fallback (`CALL METHOD lr_instance->(lv_method_name)`) inside `execute_provider`.
  * If the dynamic casting `lr_provider ?= lr_instance.` fails with `cx_sy_move_cast_error`, the engine will now raise a strict exception `/ctdi/cx_print_error` indicating that the class does not implement the standard print provider interface `/CTDI/IF_REPAIR_PRINT_PROVIDER`.

##### Code Diff draft:
```diff
    " Dynamic Casting to Interface (Strict Interface Enforcement)
    TRY.
        " Try to dynamically cast the instance to the standard print provider interface
        lr_provider ?= lr_instance.

        " Execute the provider in one step via the interface
        lr_provider->execute(
          EXPORTING iv_repair_id     = iv_repair_id
                    iv_form_name     = is_config-form_name
                    iv_save_as_pdf   = iv_save_as_pdf
          CHANGING  cs_repair        = cs_repair
                    ct_repair_error  = ct_repair_error
                    ct_comment_lines = ct_comment_lines ).

      CATCH cx_sy_move_cast_error INTO DATA(lx_cast_error).
        " Raise strict exception if the class lacks the interface
        DATA(lv_cast_err_msg) = |{ 'Class &1 does not implement interface /CTDI/IF_REPAIR_PRINT_PROVIDER'(005) }|.
        REPLACE '&1' IN lv_cast_err_msg WITH lv_class_name.
        RAISE EXCEPTION TYPE /ctdi/cx_print_error
          EXPORTING
            repair_id = iv_repair_id
            message   = lv_cast_err_msg
            previous  = lx_cast_error.
    ENDTRY.
```

---

### Customizing Engine Class

#### [MODIFY] [cl_repair_cust_engine.clas.abap](file:///D:/_Repos/DynAbap/src/%23ctdi%23cl_repair_cust_engine.clas.abap)

* **Interface Validation on Existing Classes**:
  Add validation in `validate_entry` to verify that any existing class implements `/CTDI/IF_REPAIR_PRINT_PROVIDER` (checking relation table `seometarel`).
* **Copy Base Class as Template on Auto-Generation**:
  * Replace the blank class creation with a programmatic copy of the base template class **`/CTDI/CL_REPAIR_PRINT_BASE`** (using standard FM **`SEO_CLASS_COPY`**).
  * Prompt the user for the **Development Package** via **`POPUP_TO_GET_VALUES`**.
  * If a transportable package is specified, SAP will automatically prompt for standard **Transport Request (TR)** selection during class copy execution.

##### Code Diff draft for Interface Validation:
```abap
    " Validate Interface Implementation on Existing Classes
    SELECT SINGLE clsname FROM seometarel
      INTO @DATA(lv_implements)
      WHERE clsname = @lv_class_name
        AND refclsname = '/CTDI/IF_REPAIR_PRINT_PROVIDER'
        AND reltype = '1'. " 1 = Interface Implementation
    IF sy-subrc <> 0.
      DATA(lv_interface_err) = |{ 'Class &1 does not implement interface /CTDI/IF_REPAIR_PRINT_PROVIDER'(010) }|.
      REPLACE '&1' IN lv_interface_err WITH is_entry-class_name.
      RAISE EXCEPTION TYPE /ctdi/cx_print_error
        EXPORTING
          repair_id = conv aufnr( is_entry-vbeln )
          message   = lv_interface_err.
    ENDIF.
```

##### Code Diff draft for Package and Transport dialog:
```abap
        IF sy-subrc = 0 AND lv_answer = '1'.
          " Prompt user for the target Development Package
          DATA: lt_fields TYPE TABLE OF sval,
                ls_field  TYPE sval,
                lv_returncode TYPE c,
                lv_package TYPE devclass VALUE '/CTDI/WORKSHOP'.

          ls_field-tabname   = 'TDEVC'.
          ls_field-fieldname = 'DEVCLASS'.
          ls_field-value     = '/CTDI/WORKSHOP'.
          APPEND ls_field TO lt_fields.

          CALL FUNCTION 'POPUP_TO_GET_VALUES'
            EXPORTING
              titlebar      = 'Enter Target Development Package'(011)
            IMPORTING
              returncode    = lv_returncode
            TABLES
              fields        = lt_fields
            EXCEPTIONS
              OTHERS        = 1.

          IF lv_returncode <> 'A'.
            READ TABLE lt_fields INTO ls_field INDEX 1.
            IF sy-subrc = 0 AND ls_field-value IS NOT INITIAL.
              lv_package = ls_field-value.
            ENDIF.
          ELSE.
            " Cancelled: abort generation with error
            RAISE EXCEPTION TYPE /ctdi/cx_print_error
              EXPORTING
                repair_id = is_entry-vbeln
                message   = 'Class generation cancelled by user.'.
          ENDIF.

          " Programmatically copy base class under the chosen package
          " SEO_CLASS_COPY will automatically trigger Transport Request prompt
          CALL FUNCTION 'SEO_CLASS_COPY'
            EXPORTING
              clsname      = '/CTDI/CL_REPAIR_PRINT_BASE'
              new_clsname  = is_entry-class_name
              devclass     = lv_package
            EXCEPTIONS
              OTHERS       = 1.
```

---

### Executable Wrapper Program

#### [MODIFY] [sd_repair_print_program.prog.abap](file:///D:/_Repos/DynAbap/src/%23ctdi%23sd_repair_print_program.prog.abap)

* Add `P_sf` parameter as a hidden parameter in the selection screen to mirror the legacy screen interface exactly:
  ```abap
  PARAMETERS: p_sf as checkbox NO-DISPLAY.
  ```
* Standardize selection screen texts for SE38 execution compatibility.

---

## Verification Plan

### Automated Tests
* Run static syntax check using `abap_lint` on `/CTDI/CL_REPAIR_PRINT_BASE` and `/CTDI/CL_REPAIR_PRINT_ENGINE`.

### Manual Verification
* Test the program in standalone execution mode with a dummy order number, confirming that defaults are filled correctly from user profile/SUSR settings without database access issues.
