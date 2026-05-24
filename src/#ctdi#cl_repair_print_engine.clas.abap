CLASS /ctdi/cl_repair_print_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS print
      IMPORTING
        !iv_repair_id TYPE vbeln_va
        !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
      RAISING
        /ctdi/cx_no_config_found
        cx_static_check.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES: tt_config_buffer TYPE HASHED TABLE OF /ctdi/sd_repair_form WITH UNIQUE KEY vbeln.

    DATA: mt_config_buffer TYPE tt_config_buffer.

    METHODS resolve_contract
      IMPORTING
        !iv_repair_id TYPE vbeln_va
      RETURNING
        VALUE(rv_contract_id) TYPE vbeln_va.

    METHODS get_config
      IMPORTING
        !iv_contract_id TYPE vbeln_va
      RETURNING
        VALUE(rs_config) TYPE /ctdi/sd_repair_form
      RAISING
        /ctdi/cx_no_config_found.

    METHODS execute_provider
      IMPORTING
        !iv_repair_id TYPE vbeln_va
        !is_config TYPE /ctdi/sd_repair_form
        !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
      RAISING
        cx_static_check.
ENDCLASS.



CLASS /ctdi/cl_repair_print_engine IMPLEMENTATION.

  METHOD print.
    DATA(lv_contract_id) = resolve_contract( iv_repair_id ).
    DATA(ls_config) = get_config( lv_contract_id ).
    execute_provider( iv_repair_id   = iv_repair_id
                      is_config      = ls_config
                      iv_save_as_pdf = iv_save_as_pdf ).
  ENDMETHOD.

  METHOD resolve_contract.
    DATA: lv_aufnr TYPE aufnr,
          lv_kdauf TYPE kdauf.

    " Format input ID and check if it exists in PM/CS Service Orders (AUFK)
    lv_aufnr = |{ iv_repair_id ALPHA = IN }|.
    SELECT SINGLE aufnr FROM aufk INTO @DATA(lv_dummy) WHERE aufnr = @lv_aufnr.
    IF sy-subrc = 0.
      " It is a PM/CS Service Order from IW42:
      " Try resolving direct Contract Number from AFIH
      SELECT SINGLE kunum FROM afih INTO @rv_contract_id WHERE aufnr = @lv_aufnr.
      
      IF rv_contract_id IS INITIAL.
        " Try resolving indirect Contract Number via Sales Order reference in AUFK
        SELECT SINGLE kdauf FROM aufk INTO @lv_kdauf WHERE aufnr = @lv_aufnr.
        IF sy-subrc = 0 AND lv_kdauf IS NOT INITIAL.
          SELECT SINGLE vgbel FROM vbap INTO @rv_contract_id 
            WHERE vbeln = @lv_kdauf 
              AND vgbel IS NOT INITIAL.
          IF rv_contract_id IS INITIAL.
            rv_contract_id = lv_kdauf.
          ENDIF.
        ENDIF.
      ENDIF.
    ELSE.
      " It is a standard Sales Document (VBELN):
      rv_contract_id = iv_repair_id.
    ENDIF.
  ENDMETHOD.

  METHOD get_config.
    " Fetch Customizing configuration for the repair contract (Check buffer first)
    rs_config = VALUE #( mt_config_buffer[ vbeln = iv_contract_id ] OPTIONAL ).
    IF rs_config IS INITIAL.
      SELECT SINGLE *
        FROM /ctdi/sd_repair_form
        INTO CORRESPONDING FIELDS OF @rs_config
        WHERE vbeln = @iv_contract_id.

      IF sy-subrc <> 0.
        " No customizing found for this Sales Repair Contract - Fallback to print_old exception
        RAISE EXCEPTION TYPE /ctdi/cx_no_config_found.
      ENDIF.

      " Insert into hashed buffer
      INSERT rs_config INTO TABLE mt_config_buffer.
    ENDIF.
  ENDMETHOD.

  METHOD execute_provider.
    DATA: lo_instance TYPE REF TO object,
          lo_provider TYPE REF TO /ctdi/if_repair_print_provider.

    " Validate that class and method names are configured
    IF is_config-class_name IS INITIAL OR is_config-method_name IS INITIAL.
      RAISE EXCEPTION TYPE /ctdi/cx_print_error
        EXPORTING
          repair_id = iv_repair_id
          message   = 'Class name or method name not configured'.
    ENDIF.

    " Instantiate configured printer class
    TRY.
        " Dynamically instantiate the class
        CREATE OBJECT lo_instance TYPE (is_config-class_name).

      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        " Handle instantiation errors (e.g. class doesn't exist or constructor error)
        RAISE EXCEPTION TYPE /ctdi/cx_print_error
          EXPORTING
            repair_id = iv_repair_id
            message   = |Failed to instantiate class: { is_config-class_name }|
            previous  = lx_create.
    ENDTRY.

    " Dynamic Casting to Interface or Fallback to Dynamic Method Call
    TRY.
        " Try to dynamically cast the instance to the standard print provider interface
        lo_provider ?= lo_instance.

        " Execute method type-safely via the interface
        lo_provider->read_data( iv_repair_id = iv_repair_id ).

        lo_provider->print(
          iv_repair_id = iv_repair_id
          iv_form_name   = is_config-form_name
          iv_save_as_pdf = iv_save_as_pdf ).

      CATCH cx_sy_move_cast_error.
        " If class does not implement the interface, fallback to fully dynamic method execution
        TRY.
            CALL METHOD lo_instance->(is_config-method_name)
              EXPORTING
                iv_repair_id = iv_repair_id
                iv_form_name   = is_config-form_name
                iv_save_as_pdf = iv_save_as_pdf.
          CATCH cx_sy_dyn_call_error INTO DATA(lx_dyn_call).
            RAISE EXCEPTION TYPE /ctdi/cx_print_error
              EXPORTING
                repair_id = iv_repair_id
                message   = |Dynamic method call failed: { is_config-method_name }|
                previous  = lx_dyn_call.
        ENDTRY.

      CATCH cx_root INTO DATA(lx_root).
        " Catch other static or dynamic exceptions
        RAISE EXCEPTION TYPE /ctdi/cx_print_error
          EXPORTING
            repair_id = iv_repair_id
            message   = 'Error occurred during print provider execution'
            previous  = lx_root.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
