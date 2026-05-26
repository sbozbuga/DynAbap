class /CTDI/CL_REPAIR_CUST_ENGINE definition
  public
  final
  create public .

public section.

  class-methods ON_NEW_ENTRY
    changing
      !CS_ENTRY type /CTDI/REP_FORMS .
  class-methods VALIDATE_ENTRY
    importing
      !IS_ENTRY type /CTDI/REP_FORMS
    raising
      /CTDI/CX_PRINT_ERROR .
  class-methods CHECK_GENERATION_ALLOWED
    returning
      value(RV_ALLOWED) type ABAP_BOOL .
  class-methods NORMALIZE_CLASS_NAME
    importing
      !IV_CLASS_NAME type SEOCLSNAME
    returning
      value(RV_CLASS_NAME) type SEOCLSNAME .
  class-methods RESOLVE_CLASS_NAME
    importing
      !IV_CLASS_NAME type SEOCLSNAME
    returning
      value(RV_CLASS_NAME) type SEOCLSNAME .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /CTDI/CL_REPAIR_CUST_ENGINE IMPLEMENTATION.


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
      WHERE clsname = cs_entry-class_name.
    IF sy-subrc = 0.
      cs_entry-method_name = 'EXECUTE'.
      RETURN.
    ENDIF.

    " 5. Generate the SE24 class with interface /CTDI/IF_REPAIR_PRINT_PROVIDER
    DATA: ls_class      TYPE vseoclass,
          lt_intfs      TYPE seo_implementings.

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

    CALL FUNCTION 'SEO_CLASS_CREATE_COMPLETE'
      EXPORTING
        devclass      = '$TMP'
        overwrite     = abap_true
        version       = '1' " Active
      CHANGING
        class         = ls_class
        implementings = lt_intfs
      EXCEPTIONS
        OTHERS        = 1.
    IF sy-subrc = 0.
      cs_entry-method_name = 'EXECUTE'.
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


  METHOD validate_entry.
    " 1. Class name is required
    IF is_entry-class_name IS INITIAL.
      DATA(lv_msg) = |{ 'Class name is required for Contract &1'(006) }|.
      REPLACE '&1' IN lv_msg WITH is_entry-vbeln.
      RAISE EXCEPTION TYPE /ctdi/cx_print_error
        EXPORTING
          repair_id =  conv aufnr( is_entry-vbeln )
          message   = lv_msg.
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
          DATA(lv_form_err) = |{ 'Form &1 does not exist as a Smart Form or Adobe Form'(007) }|.
          REPLACE '&1' IN lv_form_err WITH is_entry-form_name.
          RAISE EXCEPTION TYPE /ctdi/cx_print_error
            EXPORTING
              repair_id = conv aufnr( is_entry-vbeln )
              message   = lv_form_err.
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

        DATA(lv_question) = |{ 'Class &1 does not exist. Do you want to generate it now?'(002) }|.
        REPLACE '&1' IN lv_question WITH is_entry-class_name.

        CALL FUNCTION 'POPUP_TO_CONFIRM'
          EXPORTING
            titlebar              = 'Generate Missing Print Provider Class?'(001)
            text_question         = lv_question
            text_button_1         = 'Yes'(003)
            text_button_2         = 'No'(004)
            display_cancel_button = abap_false
          IMPORTING
            answer                = lv_answer
          EXCEPTIONS
            text_not_found        = 1
            OTHERS                = 2.

        IF sy-subrc = 0 AND lv_answer = '1'.
          " User clicked Yes: Programmatically generate class
          DATA: ls_class      TYPE vseoclass,
                lt_intfs      TYPE seo_implementings.

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

          CALL FUNCTION 'SEO_CLASS_CREATE_COMPLETE'
            EXPORTING
              devclass        = '$TMP'
              overwrite       = abap_true
              version         = '1' " Active
            CHANGING
              class           = ls_class
              implementings   = lt_intfs
            EXCEPTIONS
              existing        = 1
              is_interface    = 2
              not_created     = 3
              db_error        = 4
              component_error = 5
              OTHERS          = 6.

          IF sy-subrc = 0.
            DATA(lv_success) = |{ 'Class &1 generated successfully.'(005) }|.
            REPLACE '&1' IN lv_success WITH is_entry-class_name.
            MESSAGE lv_success TYPE 'S'.
            RETURN. " Class now successfully generated, bypass error check
          ELSE.
            DATA(lv_subrc) = sy-subrc.
            RAISE EXCEPTION TYPE /ctdi/cx_print_error
              EXPORTING
                repair_id = is_entry-vbeln
                message   = |Failed to generate class (SUBRC: { lv_subrc }).|.
          ENDIF.
        ENDIF.
      ENDIF.

      " Raise validation error if generation is skipped or not permitted (e.g. locked client)
      DATA(lv_class_err) = |{ 'Class &1 does not exist in the repository'(008) }|.
      REPLACE '&1' IN lv_class_err WITH is_entry-class_name.
      RAISE EXCEPTION TYPE /ctdi/cx_print_error
        EXPORTING
          repair_id = conv aufnr( is_entry-vbeln )
          message   = lv_class_err.
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
            DATA(lv_method_err) = |{ 'Method &1 does not exist in class &2'(009) }|.
            REPLACE '&1' IN lv_method_err WITH is_entry-method_name.
            REPLACE '&2' IN lv_method_err WITH is_entry-class_name.
            RAISE EXCEPTION TYPE /ctdi/cx_print_error
              EXPORTING
                repair_id = conv aufnr( is_entry-vbeln )
                message   = lv_method_err.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
