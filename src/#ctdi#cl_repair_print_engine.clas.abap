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
    TYPES: tt_config_buffer TYPE HASHED TABLE OF /ctdi/sd_repair_form WITH UNIQUE KEY auart.

    DATA: mt_config_buffer TYPE tt_config_buffer.
ENDCLASS.



CLASS /ctdi/cl_repair_print_engine IMPLEMENTATION.

  METHOD print.
    DATA: lv_auart       TYPE auart,
          ls_config      TYPE /ctdi/sd_repair_form,
          lo_instance    TYPE REF TO object,
          lo_provider    TYPE REF TO /ctdi/if_repair_print_provider,
          lv_aufnr       TYPE aufnr,
          lv_contract_id TYPE vbeln_va,
          lv_kdauf       TYPE kdauf.

    " 1. Format input ID and check if it exists in PM/CS Service Orders (AUFK)
    lv_aufnr = |{ iv_repair_id ALPHA = IN }|.
    SELECT SINGLE auart FROM aufk INTO @DATA(lv_order_type) WHERE aufnr = @lv_aufnr.
    IF sy-subrc = 0.
      " It is a PM/CS Service Order from IW42:
      " Try resolving direct Contract Number from AFIH
      SELECT SINGLE kunum FROM afih INTO @lv_contract_id WHERE aufnr = @lv_aufnr.
      
      IF lv_contract_id IS INITIAL.
        " Try resolving indirect Contract Number via Sales Order reference in AUFK
        SELECT SINGLE kdauf FROM aufk INTO @lv_kdauf WHERE aufnr = @lv_aufnr.
        IF sy-subrc = 0 AND lv_kdauf IS NOT INITIAL.
          SELECT SINGLE vgbel FROM vbap INTO @lv_contract_id 
            WHERE vbeln = @lv_kdauf 
              AND vgbel IS NOT INITIAL.
          IF lv_contract_id IS INITIAL.
            lv_contract_id = lv_kdauf.
          ENDIF.
        ENDIF.
      ENDIF.

      " Query custom customizing mapping via the resolved Contract ID
      IF lv_contract_id IS NOT INITIAL.
        SELECT SINGLE auart FROM vbak INTO @lv_auart WHERE vbeln = @lv_contract_id.
      ENDIF.
    ELSE.
      " It is a standard Sales Document (VBELN):
      SELECT SINGLE auart FROM vbak INTO @lv_auart WHERE vbeln = @iv_repair_id.
    ENDIF.

    IF lv_auart IS INITIAL.
      " Raise a generic error if the Sales Document / Contract doesn't exist
      RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
    ENDIF.

    " 2. Fetch Customizing configuration for the repair type (Check buffer first)
    READ TABLE mt_config_buffer INTO ls_config WITH KEY auart = lv_auart.
    IF sy-subrc <> 0.
      SELECT SINGLE *
        FROM /ctdi/sd_repair_form
        INTO CORRESPONDING FIELDS OF @ls_config
        WHERE auart = @lv_auart.

      IF sy-subrc <> 0.
        " No customizing found for this Sales Repair Type - Fallback to print_old exception
        RAISE EXCEPTION TYPE /ctdi/cx_no_config_found.
      ENDIF.

      " Insert into hashed buffer
      INSERT ls_config INTO TABLE mt_config_buffer.
    ENDIF.

    " Validate that class and method names are configured
    IF ls_config-class_name IS INITIAL OR ls_config-method_name IS INITIAL.
      RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
    ENDIF.

    " 3. Instantiate configured printer class
    TRY.
        " Dynamically instantiate the class
        CREATE OBJECT lo_instance TYPE (ls_config-class_name).

      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        " Handle instantiation errors (e.g. class doesn't exist or constructor error)
        RAISE EXCEPTION lx_create.
    ENDTRY.

    " 4. Dynamic Casting to Interface or Fallback to Dynamic Method Call
    TRY.
        " Try to dynamically cast the instance to the standard print provider interface
        lo_provider ?= lo_instance.

        " Execute method type-safely via the interface
        lo_provider->read_data( iv_repair_id = iv_repair_id ).

        lo_provider->print(
          iv_repair_id = iv_repair_id
          iv_form_name   = ls_config-form_name
          iv_save_as_pdf = iv_save_as_pdf ).

      CATCH cx_sy_move_cast_error.
        " If class does not implement the interface, fallback to fully dynamic method execution
        " NOTE: For legacy classes, we assume the single method defined in customizing handles both
        TRY.
            CALL METHOD lo_instance->(ls_config-method_name)
              EXPORTING
                iv_repair_id = iv_repair_id
                iv_form_name   = ls_config-form_name
                iv_save_as_pdf = iv_save_as_pdf.
          CATCH cx_sy_dyn_call_error INTO DATA(lx_dyn_call).
            RAISE EXCEPTION lx_dyn_call.
        ENDTRY.

      CATCH cx_root INTO DATA(lx_root).
        " Catch other static or dynamic exceptions
        RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
