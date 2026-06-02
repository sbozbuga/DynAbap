CLASS /ctdi/cl_print_driver_template DEFINITION
  PUBLIC
  INHERITING FROM /ctdi/cl_print_driver_base
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
    "! Redefines base method to load custom business data for a new process.
    METHODS read_data REDEFINITION.

  PRIVATE SECTION.
ENDCLASS.



CLASS /ctdi/cl_print_driver_template IMPLEMENTATION.

  METHOD read_data.
    " =========================================================================
    " TEMPLATE METHOD: read_data
    " =========================================================================
    " Subclasses should redefine this method to supply custom business data
    " for a new process. The business data is loaded into cs_repair, ct_errors,
    " and ct_comments.
    " =========================================================================

    DATA(lv_repair_id) = |{ iv_repair_id ALPHA = IN }|.

    /ctdi/cl_print_driver_log=>log_info(
      |Template read_data started for Repair ID: { iv_repair_id } (internal format: { lv_repair_id })| ).

    " Example 1: Select header data into cs_repair structure.
    " In a real custom process, cs_repair should be typed as the appropriate structure
    " (e.g. /CTDI/REPAIR) and filled accordingly.
    SELECT SINGLE *
      FROM /ctdi/repair
      INTO @cs_repair
      WHERE aufnr = @lv_repair_id.

    IF sy-subrc <> 0.
      /ctdi/cl_print_driver_log=>log_warning(
        |Repair record { iv_repair_id } not found in /CTDI/REPAIR. Using fallback mock header.| ).

      " Example of handling missing data (either fail with exception or supply default)
      " If this is a critical error for the process:
      " RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
      "   EXPORTING
      "     repair_id = iv_repair_id
      "     message   = |Process data could not be retrieved for { iv_repair_id }|.
    ENDIF.

    " Example 2: Select error/defect records.
    " ct_errors should be filled from your process-specific defect/log table.
    SELECT *
      FROM /ctdi/repair_error
      INTO TABLE @ct_errors
      WHERE aufnr = @lv_repair_id.

    /ctdi/cl_print_driver_log=>log_info(
      |Loaded { lines( ct_errors ) } error/defect lines for Repair { iv_repair_id }| ).

    " Example 3: Enriching comments or custom long texts.
    " Developers can append custom info or read standard SAP texts (READ_TEXT) here.
    " APPEND INITIAL LINE TO ct_comments ASSIGNING FIELD-SYMBOL(<ls_comment>).
    " ...

  ENDMETHOD.

ENDCLASS.
