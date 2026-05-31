CLASS /ctdi/cl_print_driver_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Main entry: executes the full print pipeline for a given repair ID.
    "!
    "! @parameter iv_repair_id   | Repair / Service Order ID
    "! @parameter iv_form_name   | Optional explicit form name (bypasses customizing)
    "! @parameter iv_class_name  | Optional explicit class name (bypasses customizing)
    "! @parameter iv_save_as_pdf | If TRUE, saves output as PDF
    "! @parameter cs_repair      | Repair data structure (in/out)
    "! @parameter ct_errors      | Device defect lines
    "! @parameter ct_comments    | Comment lines
    "! @raising   /ctdi/cx_print_driver_error | Engine or provider failure
    METHODS execute
      IMPORTING
        !iv_repair_id   TYPE aufnr
        !iv_form_name   TYPE fpname OPTIONAL
        !iv_class_name  TYPE seoclsname OPTIONAL
        !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
      CHANGING
        !cs_repair      TYPE any
        !ct_errors      TYPE ANY TABLE
        !ct_comments    TYPE ANY TABLE
      RAISING
        /ctdi/cx_print_driver_error.

  PROTECTED SECTION.
  PRIVATE SECTION.
    "! Looks up the print configuration from customizing table /CTDI/REP_FORMS.
    METHODS get_config_from_db
      IMPORTING
        !iv_repair_id   TYPE aufnr
      EXPORTING
        !ev_form_name   TYPE fpname
        !ev_class_name  TYPE seoclsname
      RAISING
        /ctdi/cx_print_driver_error.

    "! Dynamically instantiates the configured provider class.
    METHODS create_provider
      IMPORTING
        !iv_class_name  TYPE seoclsname
        !iv_repair_id   TYPE aufnr
      RETURNING
        VALUE(rr_provider) TYPE REF TO /ctdi/if_print_driver
      RAISING
        /ctdi/cx_print_driver_error.

    "! Resolves a class name, normalizing Z-prefix names to /CTDI/ namespace.
    METHODS normalize_class_name
      IMPORTING
        !iv_class_name  TYPE seoclsname
      RETURNING
        VALUE(rv_class_name) TYPE seoclsname.
ENDCLASS.



CLASS /ctdi/cl_print_driver_engine IMPLEMENTATION.

  METHOD execute.
    DATA: lv_form_name  TYPE fpname,
          lv_class_name TYPE seoclsname.

    /ctdi/cl_print_driver_log=>log_info(
      |Print driver engine invoked for Repair { iv_repair_id }| ).

    " Resolve configuration
    IF iv_form_name IS NOT INITIAL AND iv_class_name IS NOT INITIAL.
      " Fully explicit — no customizing lookup needed
      lv_form_name  = iv_form_name.
      lv_class_name = iv_class_name.
      /ctdi/cl_print_driver_log=>log_info(
        |Using explicit config — Form: { lv_form_name }, Class: { lv_class_name }| ).
    ELSE.
      " Look up from customizing table
      get_config_from_db(
        EXPORTING iv_repair_id  = iv_repair_id
        IMPORTING ev_form_name  = lv_form_name
                  ev_class_name = lv_class_name ).
    ENDIF.

    " Fallback to base class if nothing configured
    IF lv_class_name IS INITIAL.
      lv_class_name = '/CTDI/CL_PRINT_DRIVER_BASE'.
      /ctdi/cl_print_driver_log=>log_info(
        |No class configured — falling back to { lv_class_name }| ).
    ENDIF.

    " Instantiate and execute the provider
    DATA(lr_provider) = create_provider(
      iv_class_name = lv_class_name
      iv_repair_id  = iv_repair_id ).

    lr_provider->execute(
      EXPORTING iv_repair_id   = iv_repair_id
                iv_form_name   = lv_form_name
                iv_save_as_pdf = iv_save_as_pdf
      CHANGING  cs_repair      = cs_repair
                ct_errors      = ct_errors
                ct_comments    = ct_comments ).

    /ctdi/cl_print_driver_log=>log_info(
      |Print driver engine completed successfully for Repair { iv_repair_id }| ).
  ENDMETHOD.


  METHOD get_config_from_db.
    " Query the customizing table for an active record matching the repair ID.
    " Uses the same /CTDI/REP_FORMS table as the legacy DynAbap framework.
    SELECT SINGLE form_name, class_name
      FROM /ctdi/rep_forms
      INTO @DATA(ls_config)
      WHERE vbeln = @iv_repair_id.

    IF sy-subrc <> 0.
      " Try without leading zeros
      DATA(lv_raw) = |{ iv_repair_id ALPHA = OUT }|.
      SELECT SINGLE form_name, class_name
        FROM /ctdi/rep_forms
        INTO @ls_config
        WHERE vbeln = @lv_raw.
    ENDIF.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
        EXPORTING
          repair_id = iv_repair_id
          message   = |No print configuration found for Repair { iv_repair_id }|.
    ENDIF.

    ev_form_name  = ls_config-form_name.
    ev_class_name = normalize_class_name( ls_config-class_name ).

    /ctdi/cl_print_driver_log=>log_info(
      |Config resolved — Form: { ev_form_name }, Class: { ev_class_name }| ).
  ENDMETHOD.


  METHOD create_provider.
    DATA: lr_instance TYPE REF TO object.

    " Normalize class name
    DATA(lv_class) = normalize_class_name( iv_class_name ).

    " Instantiate the configured class
    TRY.
        CREATE OBJECT lr_instance TYPE (lv_class).
      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING
            repair_id = iv_repair_id
            message   = |Cannot instantiate class { lv_class }|
            previous  = lx_create.
    ENDTRY.

    " Cast to the print driver interface
    TRY.
        rr_provider ?= lr_instance.
      CATCH cx_sy_move_cast_error INTO DATA(lx_cast).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING
            repair_id = iv_repair_id
            message   = |Class { lv_class } does not implement /CTDI/IF_PRINT_DRIVER|
            previous  = lx_cast.
    ENDTRY.
  ENDMETHOD.


  METHOD normalize_class_name.
    rv_class_name = iv_class_name.
    IF rv_class_name IS INITIAL.
      RETURN.
    ENDIF.

    " If name starts with 'Z' or 'Y', convert to /CTDI/ namespace
    IF rv_class_name(1) = 'Z' OR rv_class_name(1) = 'Y'.
      rv_class_name = |/CTDI/{ rv_class_name+1 }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
