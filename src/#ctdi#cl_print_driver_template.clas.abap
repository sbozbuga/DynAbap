CLASS /ctdi/cl_print_driver_template DEFINITION
  PUBLIC
  INHERITING FROM /ctdi/cl_print_driver_base
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
    "! Redefines base method to load custom business data for a new process.
    METHODS read_data REDEFINITION.

    "! Redefines base method to customize form routing, add pre/post
    "! processing around form execution, or bypass form rendering entirely.
    METHODS render_form REDEFINITION.

  PRIVATE SECTION.
ENDCLASS.



CLASS /ctdi/cl_print_driver_template IMPLEMENTATION.

  METHOD read_data.
    " =========================================================================
    " TEMPLATE METHOD: read_data
    " =========================================================================
    " Subclasses should redefine this method to supply custom business data
    " for a new process. The business data should be allocated and loaded into
    " mr_repair, mr_errors, and mr_comments.
    " =========================================================================

    DATA(lv_repair_id) = |{ iv_repair_id ALPHA = IN }|.

    /ctdi/cl_print_driver_log=>log_info(
      |Template read_data started for Repair ID: { iv_repair_id } (internal format: { lv_repair_id })| ).

    " Example 1: Select header data into mr_repair structure.
    " CREATE DATA mr_repair TYPE /ctdi/repair.
    " ASSIGN mr_repair->* TO FIELD-SYMBOL(<ls_repair>).
    " SELECT SINGLE *
    "   FROM /ctdi/repair
    "   INTO @<ls_repair>
    "   WHERE aufnr = @lv_repair_id.
    "
    " IF sy-subrc <> 0.
    "   /ctdi/cl_print_driver_log=>log_warning(
    "     |Repair record { iv_repair_id } not found in /CTDI/REPAIR. Using fallback mock header.| ).
    "
    "   " Example of handling missing data (either fail with exception or supply default)
    "   " If this is a critical error for the process.
    "   " RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
    "   "   EXPORTING
    "   "     repair_id = iv_repair_id
    "   "     message   = |Process data could not be retrieved for { iv_repair_id }|.
    " ENDIF.

    " Example 2: Select error/defect records.
    " CREATE DATA mr_errors TYPE STANDARD TABLE OF /ctdi/repair_error.
    " ASSIGN mr_errors->* TO FIELD-SYMBOL(<lt_errors>).
    " SELECT *
    "   FROM /ctdi/repair_error
    "   INTO TABLE @<lt_errors>
    "   WHERE aufnr = @lv_repair_id.
    "
    " /ctdi/cl_print_driver_log=>log_info(
    "   |Loaded { lines( ct_errors ) } error/defect lines for Repair { iv_repair_id }| ).

    " Example 3: Enriching comments or custom long texts.
    " CREATE DATA mr_comments TYPE STANDARD TABLE OF tline.
    " ASSIGN mr_comments->* TO FIELD-SYMBOL(<lt_comments>).
    " APPEND INITIAL LINE TO <lt_comments> ASSIGNING FIELD-SYMBOL(<ls_comment>).
    " ...

  ENDMETHOD.


  METHOD render_form.
    " =========================================================================
    " TEMPLATE METHOD: render_form
    " =========================================================================
    " Override this method to perform the following.
    "   - Add custom pre-processing  before form execution (e.g., update
    "     status tables, lock/unlock documents)
    "   - Add custom post-processing after form execution (e.g., send
    "     notification, trigger follow-up workflow)
    "   - Bypass form rendering entirely for certain conditions
    "   - Route to a completely custom output channel
    "
    " Call super->render_form( ... ) to invoke the standard base pipeline
    " (detect_form_type -> execute_smartform / execute_adobeform).
    " =========================================================================

    /ctdi/cl_print_driver_log=>log_info(
      |Template render_form invoked for Repair { iv_repair_id }, Form { iv_form_name }| ).

    " --- Example: Pre-processing ---
    " Update a custom status before printing
    " UPDATE /ctdi/repair SET print_status = 'IN_PROGRESS' WHERE aufnr = @iv_repair_id.
    " COMMIT WORK.

    " --- Standard base pipeline ---
    super->render_form(
      EXPORTING iv_repair_id   = iv_repair_id
                iv_form_name   = iv_form_name
                iv_save_as_pdf = iv_save_as_pdf ).

    " --- Example: Post-processing ---
    " Log or trigger a follow-up action after successful printing
    " /ctdi/cl_print_driver_log=>log_info(
    "   |Print completed — triggering follow-up for { iv_repair_id }| ).
    " UPDATE /ctdi/repair SET print_status = 'PRINTED' WHERE aufnr = @iv_repair_id.
    " COMMIT WORK.

  ENDMETHOD.

ENDCLASS.
