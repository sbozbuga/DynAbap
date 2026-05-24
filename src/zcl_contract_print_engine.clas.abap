CLASS zcl_contract_print_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS print
      IMPORTING
        !iv_contract_id TYPE vbeln_va
        !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
      RAISING
        zcx_no_config_found
        cx_static_check.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_contract_print_engine IMPLEMENTATION.

  METHOD print.
    DATA: lv_auart    TYPE auart,
          lo_instance TYPE REF TO object.

    " 1. Retrieve contract type from standard Sales Document Header (VBAK)
    SELECT SINGLE auart FROM vbak INTO @lv_auart WHERE vbeln = @iv_contract_id.
    IF sy-subrc <> 0.
      " Raise a generic error if contract doesn't exist
      RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
    ENDIF.

    " 2. Fetch Customizing configuration for the contract type
    SELECT SINGLE form_name, form_type, class_name, method_name
      FROM zsd_contr_form
      INTO @DATA(ls_config)
      WHERE auart = @lv_auart.

    IF sy-subrc <> 0.
      " No customizing found for this Sales Contract Type - Fallback to print_old exception
      RAISE EXCEPTION TYPE zcx_no_config_found.
    ENDIF.

    " Validate that class and method names are configured
    IF ls_config-class_name IS INITIAL OR ls_config-method_name IS INITIAL.
      RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
    ENDIF.

    " 3. Instantiate configured printer class and call the method dynamically
    TRY.
        " Dynamically instantiate the class
        CREATE OBJECT lo_instance TYPE (ls_config-class_name).

        " Dynamically call the method with contract id, form name, form type, and save-as-pdf parameters
        CALL METHOD lo_instance->(ls_config-method_name)
          EXPORTING
            iv_contract_id = iv_contract_id
            iv_form_name   = ls_config-form_name
            iv_form_type   = ls_config-form_type
            iv_save_as_pdf = iv_save_as_pdf.

      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        " Handle instantiation errors (e.g. class doesn't exist or constructor error)
        RAISE EXCEPTION lx_create.

      CATCH cx_sy_dyn_call_error INTO DATA(lx_dyn_call).
        " Handle dynamic call errors (e.g. method doesn't exist or parameters mismatch)
        RAISE EXCEPTION lx_dyn_call.

      CATCH cx_root INTO DATA(lx_root).
        " Catch any other static or dynamic exceptions
        RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
