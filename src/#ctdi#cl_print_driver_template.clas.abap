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

    DATA(lv_repair_id) = |{ mv_repair_order ALPHA = IN }|.

    /ctdi/cl_print_driver_log=>log_info(
      |Template read_data started for Repair ID: { mv_repair_order } (internal format: { lv_repair_id })| ).

    " Example 1: Select header data into ms_repair structure.
    " SELECT SINGLE *
    "   FROM /ctdi/repair
    "   INTO @ms_repair
    "   WHERE aufnr = @lv_repair_id.
    "
    " IF sy-subrc <> 0.
    "   /ctdi/cl_print_driver_log=>log_warning(
    "     |Repair record { mv_repair_order } not found in /CTDI/REPAIR. Using fallback mock header.| ).
    "
    "   " Example of handling missing data (either fail with exception or supply default)
    "   " If this is a critical error for the process.
    "   " RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
    "   "   EXPORTING
    "   "     repair_id = mv_repair_order
    "   "     message   = |Process data could not be retrieved for { mv_repair_order }|.
    " ENDIF.

    " Example 2: Select error/defect records.
    " SELECT *
    "   FROM /ctdi/repair_error
    "   INTO TABLE @mt_errors
    "   WHERE aufnr = @lv_repair_id.
    "
    " /ctdi/cl_print_driver_log=>log_info(
    "   |Loaded { lines( mt_errors ) } error/defect lines for Repair { mv_repair_order }| ).

    " Example 3: Enriching comments or custom long texts.
    " APPEND INITIAL LINE TO mt_comments ASSIGNING FIELD-SYMBOL(<ls_comment>).
    " ...

    " Example 4: Injecting completely custom data structures for specific forms.
    " If your form expects a parameter NOT in the base class (e.g., 'CUST_DATA'),
    " you can register it dynamically here. The Base class will inject it for you.
    " DATA ls_cust_data TYPE zcust_data.
    " SELECT SINGLE * FROM zcust_table INTO ls_cust_data WHERE aufnr = lv_repair_id.
    " register_custom_parameter( iv_name = 'CUST_DATA' ir_data = REF #( ls_cust_data ) ).

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
      |Template render_form invoked for Repair { mv_repair_order }, Form { mv_form_name }| ).

    " --- Example: Pre-processing ---
    " Update a custom status before printing
    " UPDATE /ctdi/repair SET print_status = 'IN_PROGRESS' WHERE aufnr = @mv_repair_order.
    " COMMIT WORK.

    " --- Standard base pipeline ---
    super->render_form(
      EXPORTING iv_save_as_pdf = iv_save_as_pdf ).

    " --- Example: Post-processing ---
    " Log or trigger a follow-up action after successful printing
    " /ctdi/cl_print_driver_log=>log_info(
    "   |Print completed — triggering follow-up for { mv_repair_order }| ).
    " UPDATE /ctdi/repair SET print_status = 'PRINTED' WHERE aufnr = @mv_repair_order.
    " COMMIT WORK.

  ENDMETHOD.

ENDCLASS.
