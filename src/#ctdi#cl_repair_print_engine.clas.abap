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
        !iv_skz TYPE bemot OPTIONAL
        !iv_akz TYPE char4 OPTIONAL
      CHANGING
        !cs_repair TYPE /ctdi/repair OPTIONAL
        !ct_repair_error TYPE any table OPTIONAL
        !ct_comment_lines TYPE any table OPTIONAL
      RAISING
        /ctdi/cx_no_config_found
        cx_static_check.



  PROTECTED SECTION.
private section.

  TYPES tt_config_buffer TYPE HASHED TABLE OF /ctdi/rep_forms WITH UNIQUE KEY vbeln skz akz.

  data MT_CONFIG_BUFFER type TT_CONFIG_BUFFER .

  methods RESOLVE_CONTRACT
    importing
      !IV_REPAIR_ID type AUFNR
    exporting
      !EV_CONTRACT_ID type VBELN_VA
      !EV_SKZ type BEMOT
      !EV_AKZ type CHAR4
    exceptions
      /CTDI/CX_REPAIR_NOT_FOUND .
  methods GET_CONFIG
    importing
      !IV_CONTRACT_ID type VBELN_VA
      !IV_SKZ type BEMOT optional
      !IV_AKZ type CHAR4 optional
    returning
      value(RS_CONFIG) type /CTDI/REP_FORMS
    raising
      /CTDI/CX_NO_CONFIG_FOUND .
  methods EXECUTE_PROVIDER
    importing
      !IV_REPAIR_ID type AUFNR
      !IS_CONFIG type /CTDI/REP_FORMS
      !IV_SAVE_AS_PDF type ABAP_BOOL default ABAP_FALSE
    changing
      !CS_REPAIR type /CTDI/REPAIR optional
      !CT_REPAIR_ERROR type ANY TABLE optional
      !CT_COMMENT_LINES type ANY TABLE optional
    raising
      CX_STATIC_CHECK .
ENDCLASS.



CLASS /CTDI/CL_REPAIR_PRINT_ENGINE IMPLEMENTATION.


  METHOD execute.
    DATA: lv_contract_id TYPE vbeln_va,
          lv_skz         TYPE bemot,
          lv_akz         TYPE char4.

    /ctdi/cl_repair_log=>log_info( |Start execution of Dynamic Print Engine for Repair ID { iv_repair_id }| ).

    lv_skz = iv_skz.
    lv_akz = iv_akz.

    TRY.
        resolve_contract( EXPORTING iv_repair_id = iv_repair_id
                          IMPORTING ev_contract_id = lv_contract_id
                                    ev_skz = lv_skz
                                    ev_akz = lv_akz ).

        /ctdi/cl_repair_log=>log_info( |Resolved contract ID: { lv_contract_id }, SKZ: { lv_skz }, AKZ: { lv_akz }| ).

        DATA(ls_config) = get_config( iv_contract_id = lv_contract_id
                                       iv_skz = lv_skz
                                       iv_akz = lv_akz ).

        /ctdi/cl_repair_log=>log_info(
          |Resolved Configuration - Class: { ls_config-class_name }, | &&
          |Method: { ls_config-method_name }, Form: { ls_config-form_name }| ).

        execute_provider( EXPORTING iv_repair_id     = iv_repair_id
                                    is_config        = ls_config
                                    iv_save_as_pdf   = iv_save_as_pdf
                          CHANGING  cs_repair        = cs_repair
                                    ct_repair_error  = ct_repair_error
                                    ct_comment_lines = ct_comment_lines ).

        /ctdi/cl_repair_log=>log_info( |Execution completed successfully for Repair ID { iv_repair_id }| ).

      CATCH /ctdi/cx_no_config_found INTO DATA(lx_no_config).
        /ctdi/cl_repair_log=>log_warning( |No active print configuration found for contract { lv_contract_id }| ).
        RAISE EXCEPTION lx_no_config.
      CATCH /ctdi/cx_repair_not_found INTO DATA(lx_no_contract).
        /ctdi/cl_repair_log=>log_exception( lx_no_contract ).
        RAISE EXCEPTION lx_no_contract.
      CATCH cx_static_check INTO DATA(lx_static).
        /ctdi/cl_repair_log=>log_exception( lx_static ).
        RAISE EXCEPTION lx_static.
    ENDTRY.
  ENDMETHOD.


  METHOD execute_provider.
    DATA: lr_instance TYPE REF TO object,
          lr_provider TYPE REF TO /ctdi/if_repair_print_provider.

    " Validate that class and method names are configured
    IF is_config-class_name IS INITIAL OR is_config-method_name IS INITIAL.
      RAISE EXCEPTION TYPE /ctdi/cx_print_error
        EXPORTING
          repair_id = iv_repair_id
          message   = |{ 'Class name or method name not configured'(001) }|.
    ENDIF.

    DATA(lv_class_name) = /ctdi/cl_repair_cust_engine=>resolve_class_name( is_config-class_name ).

    " Instantiate configured printer class
    TRY.
        " Dynamically instantiate the class
        CREATE OBJECT lr_instance TYPE (lv_class_name).

      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        " Handle instantiation errors (e.g. class doesn't exist or constructor error)
        DATA(lv_inst_err) = |{ 'Failed to instantiate class: &1'(002) }|.
        REPLACE '&1' IN lv_inst_err WITH is_config-class_name.
        RAISE EXCEPTION TYPE /ctdi/cx_print_error
          EXPORTING
            repair_id = iv_repair_id
            message   = lv_inst_err
            previous  = lx_create.
    ENDTRY.

    " Dynamic Casting to Interface or Fallback to Dynamic Method Call
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

      CATCH cx_sy_move_cast_error.
        " If class does not implement the interface, fallback to fully dynamic method execution
        TRY.
            CALL METHOD lr_instance->(is_config-method_name)
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
                CALL METHOD lr_instance->(is_config-method_name)
                  EXPORTING
                    iv_repair_id   = iv_repair_id
                    iv_form_name   = is_config-form_name
                    iv_save_as_pdf = iv_save_as_pdf.
              CATCH cx_sy_dyn_call_error INTO DATA(lx_dyn_call_inner).
                DATA(lv_method_err_inner) = |{ 'Dynamic method call failed: &1'(003) }|.
                REPLACE '&1' IN lv_method_err_inner WITH is_config-method_name.
                RAISE EXCEPTION TYPE /ctdi/cx_print_error
                  EXPORTING
                    repair_id = iv_repair_id
                    message   = lv_method_err_inner
                    previous  = lx_dyn_call_inner.
            ENDTRY.
          CATCH cx_sy_dyn_call_error INTO DATA(lx_dyn_call).
            DATA(lv_method_err) = |{ 'Dynamic method call failed: &1'(003) }|.
            REPLACE '&1' IN lv_method_err WITH is_config-method_name.
            RAISE EXCEPTION TYPE /ctdi/cx_print_error
              EXPORTING
                repair_id = iv_repair_id
                message   = lv_method_err
                previous  = lx_dyn_call.
        ENDTRY.

      CATCH cx_root INTO DATA(lx_root).
        " Catch other static or dynamic exceptions
        RAISE EXCEPTION TYPE /ctdi/cx_print_error
          EXPORTING
            repair_id = iv_repair_id
            message   = |{ 'Error occurred during print provider execution'(004) }|
            previous  = lx_root.
    ENDTRY.
  ENDMETHOD.


  METHOD get_config.
    TYPES: BEGIN OF ty_query_step,
             vbeln TYPE vbeln_va,
             skz   TYPE bemot,
             akz   TYPE char4,
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

      IF lt_steps IS NOT INITIAL.
        " Fetch all potential active customizing records in a single database select
        SELECT * FROM /ctdi/rep_forms
          INTO TABLE @DATA(lt_forms)
          FOR ALL ENTRIES IN @lt_steps
          WHERE vbeln = @lt_steps-vbeln
            AND skz   = @lt_steps-skz
            AND akz   = @lt_steps-akz.

        " Retrieve the highest priority match according to the Access Sequence
        LOOP AT lt_steps INTO DATA(ls_step).
          READ TABLE lt_forms INTO rs_config WITH KEY
            vbeln = ls_step-vbeln
            skz   = ls_step-skz
            akz   = ls_step-akz.
          IF sy-subrc = 0.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.

      IF rs_config IS INITIAL.
        RAISE EXCEPTION TYPE /ctdi/cx_no_config_found.
      ENDIF.

      INSERT rs_config INTO TABLE mt_config_buffer.
    ENDIF.
  ENDMETHOD.


  METHOD resolve_contract.
    DATA(lv_aufnr) = |{ iv_repair_id ALPHA = IN }|.

    CLEAR: ev_contract_id,
           ev_skz,
           ev_akz.

    " Try resolving Contract via Service Order (AUFK → VBAP)
    SELECT SINGLE
           v~/cellag/vbeln_vl
      INTO ev_contract_id
      FROM aufk AS a
      LEFT OUTER JOIN vbap AS v
        ON v~vbeln = a~kdauf
       AND v~posnr = a~kdpos
      WHERE a~aufnr = lv_aufnr.

    IF sy-subrc = 0.

      " Read AFRU confirmations for operation 9010
*      DATA lt_afru TYPE STANDARD TABLE OF afru.

      SELECT bemot,
             stokz,
             stzhl
        FROM afru
        INTO TABLE @DATA(lt_afru)
        WHERE aufnr = @lv_aufnr
          AND vornr = '9010'.

      LOOP AT lt_afru ASSIGNING FIELD-SYMBOL(<ls_afru>).
        IF <ls_afru>-stokz = space
           AND <ls_afru>-stzhl = '00000000'.
          ev_skz = <ls_afru>-bemot.
          EXIT.
        ENDIF.
      ENDLOOP.

      " Read AKZ from notification
      SELECT SINGLE qmcod
        INTO ev_akz
        FROM qmel
        WHERE aufnr = lv_aufnr
          AND qmart = 'Z2'.

    ELSE.
      " Not a PM/CS Service Order → treat as Sales Document
      RAISE /ctdi/cx_repair_not_found.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
