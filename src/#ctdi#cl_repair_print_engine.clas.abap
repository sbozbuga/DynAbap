CLASS /ctdi/cl_repair_print_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " Executes the print engine for a given repair/contract.
    " IMPORTING iv_repair_id    = Repair or Sales document number (VBELN)
    "           iv_save_as_pdf  = Flag to save output as PDF
    "           iv_skz          = Optional SKZ selector
    "           iv_akz          = Optional AKZ selector
    METHODS execute
      IMPORTING
        !iv_repair_id TYPE aufnr
        !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
        !iv_skz TYPE char10 OPTIONAL
        !iv_akz TYPE char10 OPTIONAL
      CHANGING
        !cs_repair TYPE /ctdi/repair OPTIONAL
        !ct_repair_error TYPE any table OPTIONAL
        !ct_comment_lines TYPE any table OPTIONAL
      RAISING
        /ctdi/cx_no_config_found
        cx_static_check.



  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES: tt_config_buffer TYPE HASHED TABLE OF /ctdi/rep_forms WITH UNIQUE KEY vbeln skz akz.

    DATA: mt_config_buffer TYPE tt_config_buffer.

    METHODS resolve_contract
      IMPORTING
        !iv_repair_id TYPE vbeln_va
      EXPORTING
        !ev_contract_id TYPE vbeln_va
        !ev_skz TYPE char10
        !ev_akz TYPE char10.

    METHODS get_config
      IMPORTING
        !iv_contract_id TYPE vbeln_va
        !iv_skz TYPE char10 OPTIONAL
        !iv_akz TYPE char10 OPTIONAL
      RETURNING
        VALUE(rs_config) TYPE /ctdi/rep_forms
      RAISING
        /ctdi/cx_no_config_found.

    METHODS execute_provider
      IMPORTING
        !iv_repair_id TYPE aufnr
        !is_config TYPE /ctdi/rep_forms
        !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
      CHANGING
        !cs_repair TYPE /ctdi/repair OPTIONAL
        !ct_repair_error TYPE any table OPTIONAL
        !ct_comment_lines TYPE any table OPTIONAL
      RAISING
        cx_static_check.


ENDCLASS.



CLASS /ctdi/cl_repair_print_engine IMPLEMENTATION.

  METHOD execute.
    DATA: lv_contract_id TYPE vbeln_va,
          lv_skz TYPE char10,
          lv_akz TYPE char10.

    lv_skz = iv_skz.
    lv_akz = iv_akz.

    resolve_contract( EXPORTING iv_repair_id = iv_repair_id
                      IMPORTING ev_contract_id = lv_contract_id
                                ev_skz = lv_skz
                                ev_akz = lv_akz ).

    DATA(ls_config) = get_config( iv_contract_id = lv_contract_id
                                   iv_skz = lv_skz
                                   iv_akz = lv_akz ).
    execute_provider( EXPORTING iv_repair_id     = iv_repair_id
                                is_config        = ls_config
                                iv_save_as_pdf   = iv_save_as_pdf
                      CHANGING  cs_repair        = cs_repair
                                ct_repair_error  = ct_repair_error
                                ct_comment_lines = ct_comment_lines ).
  ENDMETHOD.

  METHOD resolve_contract.
    DATA: lv_aufnr TYPE aufnr,
          lv_kdauf TYPE kdauf,
          lv_stokz TYPE afru-stokz,
          lv_stzhl TYPE afru-stzhl,
          ls_afru TYPE afru,
          lt_afru TYPE TABLE OF afru.

    CLEAR: ev_contract_id, ev_skz, ev_akz.

    " Format input ID and check if it exists in PM/CS Service Orders (AUFK)
    lv_aufnr = |{ iv_repair_id ALPHA = IN }|.
    SELECT SINGLE aufnr FROM aufk INTO @DATA(lv_dummy) WHERE aufnr = @lv_aufnr.
    IF sy-subrc = 0.
      SELECT bemot stokz stzhl FROM afru
        INTO TABLE @lt_afru
        WHERE aufnr = @lv_aufnr
          AND vornr = '9010'.

      LOOP AT lt_afru INTO ls_afru.
        IF ls_afru-stokz = ' ' AND ls_afru-stzhl = '00000000'.
          ev_skz = ls_afru-bemot.
          EXIT.
        ENDIF.
      ENDLOOP.

      SELECT SINGLE qmcod FROM qmel
        INTO @ev_akz
        WHERE aufnr = @lv_aufnr
          AND qmart = 'Z2'.

      " It is a PM/CS Service Order from IW42:
      " Try resolving direct Contract Number from AFIH
      SELECT SINGLE kunum FROM afih INTO @ev_contract_id WHERE aufnr = @lv_aufnr.

      IF ev_contract_id IS INITIAL.
        " Try resolving indirect Contract Number via Sales Order reference in AUFK
        SELECT SINGLE kdauf FROM aufk INTO @lv_kdauf WHERE aufnr = @lv_aufnr.
        IF sy-subrc = 0 AND lv_kdauf IS NOT INITIAL.
          SELECT SINGLE vgbel FROM vbap INTO @ev_contract_id
            WHERE vbeln = @lv_kdauf
              AND vgbel IS NOT INITIAL.
          IF ev_contract_id IS INITIAL.
            ev_contract_id = lv_kdauf.
          ENDIF.
        ENDIF.
      ENDIF.
    ELSE.
      " It is a standard Sales Document (VBELN):
      ev_contract_id = iv_repair_id.
    ENDIF.
  ENDMETHOD.

  METHOD get_config.
    TYPES: BEGIN OF ty_query_step,
             vbeln TYPE vbeln_va,
             skz   TYPE char10,
             akz   TYPE char10,
           END OF ty_query_step.
    DATA: lt_steps TYPE TABLE OF ty_query_step.

    CLEAR rs_config.

    " Fetch Customizing configuration for the repair contract / optional selectors
    READ TABLE mt_config_buffer WITH TABLE KEY
      vbeln = iv_contract_id
      skz = iv_skz
      akz = iv_akz
      INTO rs_config.

    IF sy-subrc <> 0.
      " Populate candidates based on the 7 Access Sequences
      IF iv_contract_id IS NOT INITIAL.
        IF iv_skz IS NOT INITIAL AND iv_akz IS NOT INITIAL.
          APPEND VALUE #( vbeln = iv_contract_id skz = iv_skz akz = iv_akz ) TO lt_steps.
        ENDIF.
        IF iv_skz IS NOT INITIAL.
          APPEND VALUE #( vbeln = iv_contract_id skz = iv_skz akz = '' ) TO lt_steps.
        ENDIF.
        IF iv_akz IS NOT INITIAL.
          APPEND VALUE #( vbeln = iv_contract_id skz = '' akz = iv_akz ) TO lt_steps.
        ENDIF.
        APPEND VALUE #( vbeln = iv_contract_id skz = '' akz = '' ) TO lt_steps.
      ENDIF.

      IF iv_skz IS NOT INITIAL AND iv_akz IS NOT INITIAL.
        APPEND VALUE #( vbeln = '' skz = iv_skz akz = iv_akz ) TO lt_steps.
      ENDIF.
      IF iv_skz IS NOT INITIAL.
        APPEND VALUE #( vbeln = '' skz = iv_skz akz = '' ) TO lt_steps.
      ENDIF.
      IF iv_akz IS NOT INITIAL.
        APPEND VALUE #( vbeln = '' skz = '' akz = iv_akz ) TO lt_steps.
      ENDIF.

      " Query sequentially
      LOOP AT lt_steps INTO DATA(ls_step).
        SELECT SINGLE * FROM /ctdi/rep_forms INTO CORRESPONDING FIELDS OF @rs_config
          WHERE vbeln = @ls_step-vbeln
            AND skz   = @ls_step-skz
            AND akz   = @ls_step-akz.
        IF sy-subrc = 0.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF rs_config IS INITIAL.
        RAISE EXCEPTION TYPE /ctdi/cx_no_config_found.
      ENDIF.

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

    DATA(lv_class_name) = /ctdi/cl_repair_cust_engine=>resolve_class_name( is_config-class_name ).

    " Instantiate configured printer class
    TRY.
        " Dynamically instantiate the class
        CREATE OBJECT lo_instance TYPE (lv_class_name).

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

        " Execute the provider in one step via the interface
        lo_provider->execute(
          EXPORTING iv_repair_id     = iv_repair_id
                    iv_form_name     = is_config-form_name
                    iv_save_as_pdf   = iv_save_as_pdf
          CHANGING  cs_repair        = cs_repair
                    ct_repair_error  = ct_repair_error
                    ct_comment_lines = ct_comment_lines ).

      CATCH cx_sy_move_cast_error.
        " If class does not implement the interface, fallback to fully dynamic method execution
        TRY.
            CALL METHOD lo_instance->(is_config-method_name)
              EXPORTING
                iv_repair_id     = iv_repair_id
                iv_form_name     = is_config-form_name
                iv_save_as_pdf   = iv_save_as_pdf
              CHANGING
                cs_repair        = cs_repair
                ct_repair_error  = ct_repair_error
                ct_comment_lines = ct_comment_lines.
          CATCH cx_sy_dyn_call_parameter_error.
            TRY.
                CALL METHOD lo_instance->(is_config-method_name)
                  EXPORTING
                    iv_repair_id   = iv_repair_id
                    iv_form_name   = is_config-form_name
                    iv_save_as_pdf = iv_save_as_pdf.
              CATCH cx_sy_dyn_call_error INTO DATA(lx_dyn_call_inner).
                RAISE EXCEPTION TYPE /ctdi/cx_print_error
                  EXPORTING
                    repair_id = iv_repair_id
                    message   = |Dynamic method call failed: { is_config-method_name }|
                    previous  = lx_dyn_call_inner.
            ENDTRY.
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
