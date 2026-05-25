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
        !iv_repair_id TYPE vbeln_va
        !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
        !iv_skz TYPE char10 OPTIONAL
        !iv_akz TYPE char10 OPTIONAL
      RAISING
        /ctdi/cx_no_config_found
        cx_static_check.

    CLASS-METHODS on_new_entry
      CHANGING
        !cs_entry TYPE /ctdi/rep_forms.

    CLASS-METHODS validate_entry
      IMPORTING
        !is_entry TYPE /ctdi/rep_forms
      RAISING
        /ctdi/cx_print_error.

    CLASS-METHODS check_generation_allowed
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES: tt_config_buffer TYPE HASHED TABLE OF /ctdi/rep_forms WITH UNIQUE KEY vbeln skz akz.

    DATA: mt_config_buffer TYPE tt_config_buffer.

    METHODS resolve_contract
      IMPORTING
        !iv_repair_id TYPE vbeln_va
      RETURNING
        VALUE(rv_contract_id) TYPE vbeln_va.

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
        !iv_repair_id TYPE vbeln_va
        !is_config TYPE /ctdi/rep_forms
        !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
      RAISING
        cx_static_check.

    METHODS normalize_class_name
      IMPORTING
        !iv_class_name TYPE string
      RETURNING
        VALUE(rv_class_name) TYPE string.

    METHODS resolve_class_name
      IMPORTING
        !iv_class_name TYPE string
      RETURNING
        VALUE(rv_class_name) TYPE string.
ENDCLASS.



CLASS /ctdi/cl_repair_print_engine IMPLEMENTATION.

  METHOD execute.
    DATA(lv_contract_id) = resolve_contract( iv_repair_id ).
    DATA(ls_config) = get_config( iv_contract_id = lv_contract_id
                                   iv_skz = iv_skz
                                   iv_akz = iv_akz ).
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
    DATA ls_candidate TYPE /ctdi/rep_forms.

    CLEAR rs_config.

    " Fetch Customizing configuration for the repair contract / optional selectors
    READ TABLE mt_config_buffer WITH TABLE KEY
      vbeln = iv_contract_id
      skz = iv_skz
      akz = iv_akz
      INTO rs_config.

    IF sy-subrc <> 0.
      IF iv_contract_id IS NOT INITIAL.
        IF iv_skz IS NOT INITIAL AND iv_akz IS NOT INITIAL.
          CLEAR ls_candidate.
          SELECT SINGLE *
            FROM /ctdi/rep_forms
            INTO CORRESPONDING FIELDS OF @ls_candidate
            WHERE vbeln = @iv_contract_id
              AND skz = @iv_skz
              AND akz = @iv_akz.
          IF sy-subrc = 0.
            rs_config = ls_candidate.
          ENDIF.
        ENDIF.

        IF rs_config IS INITIAL AND iv_skz IS NOT INITIAL.
          CLEAR ls_candidate.
          SELECT SINGLE *
            FROM /ctdi/rep_forms
            INTO CORRESPONDING FIELDS OF @ls_candidate
            WHERE vbeln = @iv_contract_id
              AND skz = @iv_skz
              AND akz = ''.
          IF sy-subrc = 0.
            rs_config = ls_candidate.
          ENDIF.
        ENDIF.

        IF rs_config IS INITIAL AND iv_akz IS NOT INITIAL.
          CLEAR ls_candidate.
          SELECT SINGLE *
            FROM /ctdi/rep_forms
            INTO CORRESPONDING FIELDS OF @ls_candidate
            WHERE vbeln = @iv_contract_id
              AND skz = ''
              AND akz = @iv_akz.
          IF sy-subrc = 0.
            rs_config = ls_candidate.
          ENDIF.
        ENDIF.

        IF rs_config IS INITIAL.
          CLEAR ls_candidate.
          SELECT SINGLE *
            FROM /ctdi/rep_forms
            INTO CORRESPONDING FIELDS OF @ls_candidate
            WHERE vbeln = @iv_contract_id
              AND skz = ''
              AND akz = ''.
          IF sy-subrc = 0.
            rs_config = ls_candidate.
          ENDIF.
        ENDIF.
      ELSE.
        IF iv_skz IS NOT INITIAL AND iv_akz IS NOT INITIAL.
          CLEAR ls_candidate.
          SELECT SINGLE *
            FROM /ctdi/rep_forms
            INTO CORRESPONDING FIELDS OF @ls_candidate
            WHERE vbeln = ''
              AND skz = @iv_skz
              AND akz = @iv_akz.
          IF sy-subrc = 0.
            rs_config = ls_candidate.
          ENDIF.
        ENDIF.

        IF rs_config IS INITIAL AND iv_skz IS NOT INITIAL.
          CLEAR ls_candidate.
          SELECT SINGLE *
            FROM /ctdi/rep_forms
            INTO CORRESPONDING FIELDS OF @ls_candidate
            WHERE vbeln = ''
              AND skz = @iv_skz
              AND akz = ''.
          IF sy-subrc = 0.
            rs_config = ls_candidate.
          ENDIF.
        ENDIF.

        IF rs_config IS INITIAL AND iv_akz IS NOT INITIAL.
          CLEAR ls_candidate.
          SELECT SINGLE *
            FROM /ctdi/rep_forms
            INTO CORRESPONDING FIELDS OF @ls_candidate
            WHERE vbeln = ''
              AND skz = ''
              AND akz = @iv_akz.
          IF sy-subrc = 0.
            rs_config = ls_candidate.
          ENDIF.
        ENDIF.
      ENDIF.

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

    DATA(lv_class_name) = resolve_class_name( is_config-class_name ).

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
          iv_repair_id   = iv_repair_id
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

  METHOD check_generation_allowed.
    rv_allowed = abap_false.

    " 1. Check user development authorization (CLAS / Create)
    AUTHORITY-CHECK OBJECT 'S_DEVELOP'
      ID 'DEVCLASS' FIELD '*'
      ID 'OBJTYPE'  FIELD 'CLAS'
      ID 'OBJNAME'  FIELD '*'
      ID 'P_GROUP'  FIELD '*'
      ID 'ACTVT'    FIELD '01'. " Create
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " 2. Check if the current system repository is modifiable
    DATA: lv_system_edit TYPE c.

    CALL FUNCTION 'TR_SYS_PARAMS'
      IMPORTING
        sys_edit      = lv_system_edit  " 'W' = Modifiable, 'R' = Read-only
      EXCEPTIONS
        no_systemname = 1
        no_systemtype = 2
        OTHERS        = 3.

    IF sy-subrc = 0 AND lv_system_edit = 'W'.
      rv_allowed = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD normalize_class_name.
    rv_class_name = iv_class_name.

    IF rv_class_name IS INITIAL.
      RETURN.
    ENDIF.

    IF rv_class_name(1) = 'Z' AND rv_class_name CP 'Z*'.
      rv_class_name = |/CTDI/{ rv_class_name+1 }|.
    ENDIF.
  ENDMETHOD.

  METHOD resolve_class_name.
    rv_class_name = iv_class_name.

    IF rv_class_name IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE clsname FROM seoclass
      INTO @DATA(lv_exists)
      WHERE clsname = @rv_class_name.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    DATA(lv_normalized) = normalize_class_name( iv_class_name ).
    IF lv_normalized = rv_class_name.
      RETURN.
    ENDIF.

    SELECT SINGLE clsname FROM seoclass
      INTO @lv_exists
      WHERE clsname = @lv_normalized.
    IF sy-subrc = 0.
      rv_class_name = lv_normalized.
    ENDIF.
  ENDMETHOD.

  METHOD on_new_entry.
    " 1. Bypass generation if system is QA/PRD or user lacks S_DEVELOP
    IF check_generation_allowed( ) = abap_false.
      RETURN.
    ENDIF.

    " 2. Skip if class name is already provided and exists
    IF cs_entry-class_name IS NOT INITIAL.
      SELECT SINGLE clsname FROM seoclass
        INTO @DATA(lv_exists)
        WHERE clsname = @cs_entry-class_name.
      IF sy-subrc = 0.
        RETURN.
      ENDIF.
    ENDIF.

    " 3. Auto-generate a class name from the Contract VBELN if not provided
    IF cs_entry-class_name IS INITIAL.
      cs_entry-class_name = |/CTDI/CL_REPAIR_PRINT_{ cs_entry-vbeln }|.
    ENDIF.

    " 4. Verify the class does not already exist
    SELECT SINGLE clsname FROM seoclass
      INTO lv_exists
      WHERE clsname = @cs_entry-class_name.
    IF sy-subrc = 0.
      cs_entry-method_name = 'EXECUTE'.
      RETURN.
    ENDIF.

    " 5. Generate the SE24 class with interface /CTDI/IF_REPAIR_PRINT_PROVIDER
    DATA: ls_class TYPE vseoclass,
          lt_intfs TYPE seor_implementing_keys.

    ls_class-clsname    = cs_entry-class_name.
    ls_class-langu      = sy-langu.
    ls_class-descript   = |Print Provider for Contract { cs_entry-vbeln }|.
    ls_class-state      = '1'. " Active
    ls_class-clsccincl  = 'X'.
    ls_class-fixpt      = 'X'.
    ls_class-unicode    = 'X'.
    ls_class-exposure   = '2'. " Public

    " Add interface implementation
    APPEND VALUE #( clsname    = cs_entry-class_name
                    refclsname = '/CTDI/IF_REPAIR_PRINT_PROVIDER' )
      TO lt_intfs.

    TRY.
        cl_oo_class=>create_class(
          EXPORTING
            vseoclass = ls_class
            devclass  = '$TMP'
          CHANGING
            intkey    = lt_intfs ).
        cs_entry-method_name = 'EXECUTE'.
      CATCH cx_oo_class_creation_failed.
        " Generation failed silently, will be warned during save validation
      CATCH cx_root.
        " Catch any other static or dynamic generation exceptions
    ENDTRY.
  ENDMETHOD.

  METHOD validate_entry.
    " 1. Class name is required
    IF is_entry-class_name IS INITIAL.
      RAISE EXCEPTION TYPE /ctdi/cx_print_error
        EXPORTING
          repair_id = is_entry-vbeln
          message   = |Class name is required for Contract { is_entry-vbeln }|.
    ENDIF.

    " 2. Validate Form Name existence in Smart Forms (STXFADM) or Adobe Forms (FPCONTEXT)
    IF is_entry-form_name IS NOT INITIAL.
      SELECT SINGLE formname FROM stxfadm
        INTO @DATA(lv_ssf_exists)
        WHERE formname = @is_entry-form_name.
      IF sy-subrc <> 0.
        SELECT SINGLE name FROM fpcontext
          INTO @DATA(lv_fp_exists)
          WHERE name = @is_entry-form_name.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE /ctdi/cx_print_error
            EXPORTING
              repair_id = is_entry-vbeln
              message   = |Form { is_entry-form_name } does not exist as a Smart Form or Adobe Form|.
        ENDIF.
      ENDIF.
    ENDIF.

    " 3. Validate Class existence in Repository (SEOCLASS)
    DATA(lv_class_name) = resolve_class_name( is_entry-class_name ).

    SELECT SINGLE clsname FROM seoclass
      INTO @DATA(lv_class_exists)
      WHERE clsname = @lv_class_name.
    IF sy-subrc <> 0.
      " Class does not exist! Offer to generate it on-the-fly if system modifiability and authorizations permit
      IF check_generation_allowed( ) = abap_true.
        DATA: lv_answer TYPE c.

        CALL FUNCTION 'POPUP_TO_CONFIRM'
          EXPORTING
            titlebar              = 'Generate Missing Print Provider Class?'
            text_question         = |Class { is_entry-class_name } does not exist. Do you want to generate it now?|
            text_button_1         = 'Yes'
            text_button_2         = 'No'
            display_cancel_button = abap_false
          IMPORTING
            answer                = lv_answer
          EXCEPTIONS
            text_not_found        = 1
            OTHERS                = 2.

        IF sy-subrc = 0 AND lv_answer = '1'.
          " User clicked Yes: Programmatically generate class
          DATA: ls_class TYPE vseoclass,
                lt_intfs TYPE seor_implementing_keys.

          ls_class-clsname    = is_entry-class_name.
          ls_class-langu      = sy-langu.
          ls_class-descript   = |Print Provider for Contract { is_entry-vbeln }|.
          ls_class-state      = '1'. " Active
          ls_class-clsccincl  = 'X'.
          ls_class-fixpt      = 'X'.
          ls_class-unicode    = 'X'.
          ls_class-exposure   = '2'. " Public

          APPEND VALUE #( clsname    = is_entry-class_name
                          refclsname = '/CTDI/IF_REPAIR_PRINT_PROVIDER' )
            TO lt_intfs.

          TRY.
              cl_oo_class=>create_class(
                EXPORTING
                  vseoclass = ls_class
                  devclass  = '$TMP'
                CHANGING
                  intkey    = lt_intfs ).
              MESSAGE |Class { is_entry-class_name } generated successfully.| TYPE 'S'.
              RETURN. " Class now successfully generated, bypass error check
            CATCH cx_oo_class_creation_failed INTO DATA(lx_creation_err).
              RAISE EXCEPTION TYPE /ctdi/cx_print_error
                EXPORTING
                  repair_id = is_entry-vbeln
                  message   = |Failed to generate class: { lx_creation_err->get_text( ) }|
                  previous  = lx_creation_err.
            CATCH cx_root INTO DATA(lx_root_err).
              RAISE EXCEPTION TYPE /ctdi/cx_print_error
                EXPORTING
                  repair_id = is_entry-vbeln
                  message   = |Failed to generate missing class: { is_entry-class_name }|
                  previous  = lx_root_err.
          ENDTRY.
        ENDIF.
      ENDIF.

      " Raise validation error if generation is skipped or not permitted (e.g. locked client)
      RAISE EXCEPTION TYPE /ctdi/cx_print_error
        EXPORTING
          repair_id = is_entry-vbeln
          message   = |Class { is_entry-class_name } does not exist in the repository|.
    ELSE.
      " 4. Validate Method existence in Class Components (SEOCOMPO)
      IF is_entry-method_name IS NOT INITIAL.
        SELECT SINGLE cmpname FROM seocompo
          INTO @DATA(lv_method_exists)
          WHERE clsname = @lv_class_name
            AND cmpname = @is_entry-method_name.
        IF sy-subrc <> 0.
          " Also check if it implements interface method (e.g. /CTDI/IF_REPAIR_PRINT_PROVIDER~PRINT)
          DATA(lv_interface_method) = |/CTDI/IF_REPAIR_PRINT_PROVIDER~{ is_entry-method_name }|.
          SELECT SINGLE cmpname FROM seocompo
            INTO @lv_method_exists
            WHERE clsname = @lv_class_name
              AND cmpname = @lv_interface_method.
          IF sy-subrc <> 0.
            RAISE EXCEPTION TYPE /ctdi/cx_print_error
              EXPORTING
                repair_id = is_entry-vbeln
                message   = |Method { is_entry-method_name } does not exist in class { is_entry-class_name }|.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
