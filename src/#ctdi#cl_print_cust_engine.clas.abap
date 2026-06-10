CLASS /CTDI/CL_PRINT_CUST_ENGINE DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

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
        !iv_class_name TYPE seoclsname
      RETURNING
        VALUE(rv_class_name) TYPE seoclsname.

    CLASS-METHODS resolve_class_name
      IMPORTING
        !iv_class_name TYPE seoclsname
      RETURNING
        VALUE(rv_class_name) TYPE seoclsname.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS validate_form_interface
      IMPORTING
        !iv_form_name  TYPE fpname
        !iv_class_name TYPE seoclsname
        !iv_vbeln      TYPE vbeln_va
      RAISING
        /ctdi/cx_print_error.
ENDCLASS.



CLASS /CTDI/CL_PRINT_CUST_ENGINE IMPLEMENTATION.


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
    DATA: lv_system_edit TYPE tadir-edtflag,
          lv_system_name TYPE sysysid,
          lv_system_type TYPE sysysid.

    CALL FUNCTION 'TR_SYS_PARAMS'
      IMPORTING
        systemname    = lv_system_name
        systemtype    = lv_system_type
        systemedit    = lv_system_edit  " 'W' = Modifiable, 'R' = Read-only
      EXCEPTIONS
        no_systemname = 1
        no_systemtype = 2
        OTHERS        = 3.
    DATA(lv_subrc_sys) = sy-subrc.

    IF lv_subrc_sys = 0 AND lv_system_edit NE 'N'.
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
    " Default class name and method name to standard base provider class
    IF cs_entry-class_name IS INITIAL.
      cs_entry-class_name = '/CTDI/CL_PRINT_DRIVER_BASE'.
    ENDIF.
    cs_entry-method_name = 'EXECUTE'.
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
          repair_id =  CONV aufnr( is_entry-vbeln )
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
              repair_id = CONV aufnr( is_entry-vbeln )
              message   = lv_form_err.
        ENDIF.
      ENDIF.

      " Eagerly validate form parameter compatibility
      validate_form_interface( iv_form_name  = is_entry-form_name
                               iv_class_name = is_entry-class_name
                               iv_vbeln      = is_entry-vbeln ).
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
          " Prompt user for the target Development Package
          DATA: lt_fields TYPE TABLE OF sval,
                ls_field  TYPE sval,
                lv_returncode TYPE c,
                lv_package TYPE devclass VALUE '/CTDI/WORKSHOP'.

          ls_field-tabname   = 'TDEVC'.
          ls_field-fieldname = 'DEVCLASS'.
          ls_field-value     = '/CTDI/WORKSHOP'.
          APPEND ls_field TO lt_fields.

          CALL FUNCTION 'POPUP_GET_VALUES'
            EXPORTING
              popup_title   = 'Enter Target Development Package'(011)
            IMPORTING
              returncode    = lv_returncode
            TABLES
              fields        = lt_fields
            EXCEPTIONS
              OTHERS        = 1.
          IF sy-subrc <> 0.
            lv_returncode = 'A'.
          ENDIF.

          IF lv_returncode <> 'A'.
            READ TABLE lt_fields INTO ls_field INDEX 1.
            IF sy-subrc = 0 AND ls_field-value IS NOT INITIAL.
              lv_package = ls_field-value.
            ENDIF.
          ELSE.
            " Cancelled: abort generation with error
            RAISE EXCEPTION TYPE /ctdi/cx_print_error
              EXPORTING
                repair_id = CONV aufnr( is_entry-vbeln )
                message   = 'Class generation cancelled by user.'.
          ENDIF.

          " Copy standard base class /CTDI/CL_PRINT_DRIVER_TEMPLATE to the new class name
          DATA: ls_clskey     TYPE seoclskey,
                ls_new_clskey TYPE seoclskey,
                ls_new_class  TYPE vseoclass.

          ls_clskey-clsname     = '/CTDI/CL_PRINT_DRIVER_TEMPLATE'.
          ls_new_clskey-clsname = is_entry-class_name.

          CALL FUNCTION 'SEO_CLASS_COPY'
            EXPORTING
              clskey       = ls_clskey
              new_clskey   = ls_new_clskey
            IMPORTING
              new_class    = ls_new_class
            CHANGING
              devclass     = lv_package
            EXCEPTIONS
              not_existing = 1
              deleted      = 2
              is_interface = 3
              not_copied   = 4
              db_error     = 5
              no_access    = 6
              OTHERS       = 7.

          IF sy-subrc = 0.
            DATA: lv_success TYPE char200.
            lv_success = |{ 'Class &1 generated successfully.'(005) }|.
            REPLACE '&1' IN lv_success WITH is_entry-class_name.
            MESSAGE lv_success TYPE 'S'.

            " Activate the newly generated class
            DATA: lt_objects TYPE STANDARD TABLE OF dwinactiv,
                  ls_object  TYPE dwinactiv.

            ls_object-object   = 'CLAS'.
            ls_object-obj_name = is_entry-class_name.
            APPEND ls_object TO lt_objects.

            CALL FUNCTION 'RS_WORKING_OBJECTS_ACTIVATE'
              EXPORTING
                activate_ddic_objects  = abap_true
                with_popup             = abap_false
              TABLES
                objects                = lt_objects
              EXCEPTIONS
                excecution_error       = 1
                cancelled              = 2
                insert_into_corr_error = 3
                OTHERS                 = 4.
            IF sy-subrc EQ 0.
              lv_success = |{ 'Class &1 activated successfully.' }|.
              REPLACE '&1' IN lv_success WITH is_entry-class_name.
              MESSAGE lv_success TYPE 'S'.
            ENDIF.

            RETURN. " Class now successfully generated, bypass error check
          ELSE.
            DATA(lv_subrc) = sy-subrc.
            RAISE EXCEPTION TYPE /ctdi/cx_print_error
              EXPORTING
                repair_id = CONV aufnr( is_entry-vbeln )
                message   = |Failed to generate class (SUBRC: { lv_subrc }).|.
          ENDIF.
        ENDIF.
      ENDIF.

      " Raise validation error if generation is skipped or not permitted (e.g. locked client)
      DATA(lv_class_err) = |{ 'Class &1 does not exist in the repository'(008) }|.
      REPLACE '&1' IN lv_class_err WITH is_entry-class_name.
      RAISE EXCEPTION TYPE /ctdi/cx_print_error
        EXPORTING
          repair_id = CONV aufnr( is_entry-vbeln )
          message   = lv_class_err.
    ELSE.
      " Validate Interface Implementation on Existing Classes (Strictly enforces /CTDI/IF_PRINT_DRIVER)
      " Check the class and all its superclasses
      DATA: lv_current_class TYPE seoclsname,
            lv_implemented   TYPE abap_bool.

      lv_current_class = lv_class_name.
      lv_implemented   = abap_false.

      WHILE lv_current_class IS NOT INITIAL AND lv_implemented = abap_false.
        SELECT SINGLE clsname FROM seometarel
          INTO @DATA(lv_implements)
          WHERE clsname = @lv_current_class
            AND refclsname = '/CTDI/IF_PRINT_DRIVER'
            AND reltype = '1'. " 1 = Interface Implementation
        IF sy-subrc = 0.
          lv_implemented = abap_true.
        ELSE.
          " Try to get the superclass
          SELECT SINGLE refclsname FROM seometarel
            INTO @lv_current_class
            WHERE clsname = @lv_current_class
              AND reltype = '2'. " 2 = Inheritance
          IF sy-subrc <> 0.
            CLEAR lv_current_class. " Reached the top of the hierarchy
          ENDIF.
        ENDIF.
      ENDWHILE.

      IF lv_implemented = abap_false.
        DATA(lv_interface_err) = |{ 'Class &1 does not implement interface /CTDI/IF_PRINT_DRIVER'(010) }|.
        REPLACE '&1' IN lv_interface_err WITH is_entry-class_name.
        RAISE EXCEPTION TYPE /ctdi/cx_print_error
          EXPORTING
            repair_id = CONV aufnr( is_entry-vbeln )
            message   = lv_interface_err.
      ENDIF.

      " 4. Validate Method existence in Class Components (SEOCOMPO)
      IF is_entry-method_name IS NOT INITIAL.
        SELECT SINGLE cmpname FROM seocompo
          INTO @DATA(lv_method_exists)
          WHERE clsname = @lv_class_name
            AND cmpname = @is_entry-method_name.
        IF sy-subrc <> 0.
          " Also check if it implements interface method (e.g. /CTDI/IF_PRINT_DRIVER~EXECUTE)
          DATA(lv_interface_method) = |/CTDI/IF_PRINT_DRIVER~{ is_entry-method_name }|.
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
                repair_id = CONV aufnr( is_entry-vbeln )
                message   = lv_method_err.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD validate_form_interface.
    DATA: lv_fm_name   TYPE rs38l_fnam,
          lv_form_type TYPE char1.

    " 1. Determine form type and generated FM name
    SELECT SINGLE formname FROM stxfadm
      INTO @DATA(lv_ssf_name)
      WHERE formname = @iv_form_name.
    IF sy-subrc = 0.
      lv_form_type = 'S'. " Smart Form
      CALL FUNCTION 'SSF_FUNCTION_MODULE_NAME'
        EXPORTING
          formname           = iv_form_name
        IMPORTING
          fm_name            = lv_fm_name
        EXCEPTIONS
          no_form            = 1
          no_function_module = 2
          OTHERS             = 3.
      IF sy-subrc <> 0.
        RETURN. " Muted: will be handled at runtime print execution
      ENDIF.
    ELSE.
      lv_form_type = 'A'. " Adobe Form
      TRY.
          CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
            EXPORTING
              i_name     = iv_form_name
            IMPORTING
              e_funcname = lv_fm_name.
        CATCH cx_fp_api.
          RETURN. " Muted: will be handled at runtime print execution
      ENDTRY.
    ENDIF.

    " 2. Fetch all mandatory parameters (OPTIONAL = space, DEFAULTVAL = space)
    SELECT parameter
      FROM fupararef
      INTO TABLE @DATA(lt_mandatory_params)
      WHERE funcname = @lv_fm_name
        AND paramtype IN ('I', 'T', 'C')
        AND optional = @space
        AND defaultval = @space.

    IF sy-subrc <> 0.
      RETURN. " No mandatory parameters found
    ENDIF.

    " 3. Filter out standard/framework parameters
    LOOP AT lt_mandatory_params INTO DATA(ls_param).
      DATA(lv_param) = to_upper( ls_param-parameter ).

      IF lv_form_type = 'S'. " Smart Form
        IF lv_param = 'CONTROL_PARAMETERS' OR
           lv_param = 'OUTPUT_OPTIONS'     OR
           lv_param = 'USER_SETTINGS'      OR
           lv_param = 'ARCHIVE_INDEX'      OR
           lv_param = 'ARCHIVE_INDEX_TAB'  OR
           lv_param = 'ARCHIVE_PARAMETERS' OR
           lv_param = 'MAIL_APPL_OBJ'      OR
           lv_param = 'MAIL_RECIPIENT'     OR
           lv_param = 'MAIL_SENDER'        OR
           lv_param = 'REPAIR'.
          CONTINUE.
        ENDIF.
      ELSE. " Adobe Form
        IF lv_param = '/1BCDWB/DOCPARAMS' OR
           lv_param = 'REPAIR'.
          CONTINUE.
        ENDIF.
      ENDIF.

      " If we reach here, we found a custom mandatory parameter!
      " If the base class is configured, it will dump because it cannot supply this parameter.
      IF iv_class_name = '/CTDI/CL_PRINT_DRIVER_BASE'.
        DATA(lv_err_msg) =
          |{ 'Form &1 requires custom mandatory parameter &2 which standard base class does not support.'(012) }|.
        REPLACE '&1' IN lv_err_msg WITH iv_form_name.
        REPLACE '&2' IN lv_err_msg WITH ls_param-parameter.
        RAISE EXCEPTION TYPE /ctdi/cx_print_error
          EXPORTING
            repair_id = CONV aufnr( iv_vbeln )
            message   = lv_err_msg.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
