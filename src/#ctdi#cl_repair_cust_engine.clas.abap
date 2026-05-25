CLASS /ctdi/cl_repair_cust_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
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

    CLASS-METHODS normalize_class_name
      IMPORTING
        !iv_class_name TYPE string
      RETURNING
        VALUE(rv_class_name) TYPE string.

    CLASS-METHODS resolve_class_name
      IMPORTING
        !iv_class_name TYPE string
      RETURNING
        VALUE(rv_class_name) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /ctdi/cl_repair_cust_engine IMPLEMENTATION.

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
