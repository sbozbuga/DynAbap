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
private section.

  constants GC_FORM_ALCATEL type FPNAME value '/CELLAG/ALCAREP' ##NO_TEXT.

  class-methods VALIDATE_FORM_INTERFACE
    importing
      !IV_FORM_NAME type FPNAME
      !IV_CLASS_NAME type SEOCLSNAME
      !IV_VBELN type VBELN_VA
    RAISING
      /CTDI/CX_PRINT_ERROR .

  CLASS-METHODS generate_provider_class
    IMPORTING
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
*    " Default class name and method name to standard base provider class
*    IF cs_entry-class_name IS INITIAL.
*      cs_entry-class_name = /ctdi/cl_print_driver_base=>gc_base_class.
*    ENDIF.
*    cs_entry-method_name = 'EXECUTE'.
  ENDMETHOD.


  METHOD resolve_class_name.
    rv_class_name = iv_class_name.

    IF rv_class_name IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE clsname FROM seoclass
      WHERE clsname = @rv_class_name
      INTO @DATA(lv_exists).
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    DATA(lv_normalized) = normalize_class_name( iv_class_name ).
    IF lv_normalized = rv_class_name.
      RETURN.
    ENDIF.

    SELECT SINGLE clsname FROM seoclass
      WHERE clsname = @lv_normalized
      INTO @lv_exists.
    IF sy-subrc = 0.
      rv_class_name = lv_normalized.
    ENDIF.
  ENDMETHOD.


  METHOD validate_entry.

    " 1. Validate Form Name existence in Smart Forms (STXFADM) or Adobe Forms (FPCONTEXT)
    IF is_entry-form_name IS NOT INITIAL.
      SELECT SINGLE formname FROM stxfadm
        WHERE formname = @is_entry-form_name
        INTO @DATA(lv_ssf_exists).
      IF sy-subrc <> 0.
        SELECT SINGLE name FROM fpcontext
          WHERE name = @is_entry-form_name
          INTO @DATA(lv_fp_exists).
        IF sy-subrc <> 0.
          DATA(lv_form_err) = |Form { is_entry-form_name } does not exist as a Smart Form or Adobe Form.|.
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

    IF is_entry-form_name NE gc_form_alcatel.

      " 2. Class name is required for new Forms
      IF is_entry-class_name IS INITIAL.
        DATA(lv_msg) = |Class name is required for Contract { is_entry-vbeln }|.
        RAISE EXCEPTION TYPE /ctdi/cx_print_error
          EXPORTING
            repair_id = CONV aufnr( is_entry-vbeln )
            message   = lv_msg.
      ENDIF.

      " 3. Validate Class existence in Repository (SEOCLASS)
      DATA(lv_class_name) = resolve_class_name( is_entry-class_name ).

      SELECT SINGLE clsname FROM seoclass
        WHERE clsname = @lv_class_name
        INTO @DATA(lv_class_exists).
      IF sy-subrc <> 0.
        " Class does not exist! Offer to generate it on-the-fly if system modifiability and authorizations permit
        IF check_generation_allowed( ) = abap_true.
          generate_provider_class( iv_class_name = is_entry-class_name
                                   iv_vbeln      = is_entry-vbeln ).
          RETURN. " Class now successfully generated, bypass error check
        ENDIF.

        " Raise validation error if generation is skipped or not permitted (e.g. locked client)
        DATA(lv_class_err) = |Class { is_entry-class_name } does not exist in the repository|.
        RAISE EXCEPTION TYPE /ctdi/cx_print_error
          EXPORTING
            repair_id = CONV aufnr( is_entry-vbeln )
            message   = lv_class_err.
      ELSE.
        " Validate inheritance from base class /CTDI/CL_PRINT_DRIVER_BASE
        " Check the class and all its superclasses
        DATA: lv_implemented   TYPE abap_bool.

        IF lv_class_name = /ctdi/cl_print_driver_base=>gc_base_class.
          lv_implemented = abap_true.
        ELSE.
          CALL FUNCTION 'SEO_CLASS_GET_SUPERCLASSES'
            EXPORTING
              clsname      = lv_class_name
            IMPORTING
              superclasses = DATA(lt_superclasses)
            EXCEPTIONS
              OTHERS       = 1.
          IF sy-subrc = 0.
            LOOP AT lt_superclasses INTO DATA(ls_super).
              IF ls_super-refclsname = /ctdi/cl_print_driver_base=>gc_base_class.
                lv_implemented = abap_true.
                EXIT.
              ENDIF.
            ENDLOOP.
          ENDIF.
        ENDIF.

        IF lv_implemented = abap_false.
          DATA(lv_interface_err) = |Class { is_entry-class_name } does not inherit from /CTDI/CL_PRINT_DRIVER_BASE|.
          RAISE EXCEPTION TYPE /ctdi/cx_print_error
            EXPORTING
              repair_id = CONV aufnr( is_entry-vbeln )
              message   = lv_interface_err.
        ENDIF.

        " 4. Validate Method existence in Class Components (SEOCOMPO)
        IF is_entry-method_name IS NOT INITIAL.
          SELECT SINGLE cmpname FROM seocompo
            WHERE clsname = @lv_class_name
              AND cmpname = @is_entry-method_name
            INTO @DATA(lv_method_exists).
          IF sy-subrc <> 0.
            " If not found, check in base class /CTDI/CL_PRINT_DRIVER_BASE
            SELECT SINGLE cmpname FROM seocompo
              WHERE clsname = @/ctdi/cl_print_driver_base=>gc_base_class
                AND cmpname = @is_entry-method_name
              INTO @lv_method_exists.
            IF sy-subrc <> 0.
              DATA(lv_method_err) = |Method { is_entry-method_name } does not exist in class { is_entry-class_name } or its base class|.
              RAISE EXCEPTION TYPE /ctdi/cx_print_error
                EXPORTING
                  repair_id = CONV aufnr( is_entry-vbeln )
                  message   = lv_method_err.
            ENDIF.
          ENDIF.
        ENDIF.

      ENDIF." select seoclass
    ENDIF. "NE gc_form_alcatel.

  ENDMETHOD.


  METHOD generate_provider_class.
    DATA: lv_answer TYPE c.

    DATA(lv_question) = |Class { iv_class_name } does not exist. Do you want to generate it now?|.

    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Generate Missing Print Provider Class?'
        text_question         = lv_question
        text_button_1         = 'Yes'
        text_button_2         = 'No'
        display_cancel_button = abap_false
      IMPORTING
        answer                = lv_answer
      EXCEPTIONS
        text_not_found        = 1
        OTHERS                = 2.

    IF sy-subrc = 0 AND lv_answer = '1'.
      " Prompt user for the target Development Package
      DATA: lt_fields     TYPE TABLE OF sval,
            ls_field      TYPE sval,
            lv_returncode TYPE c,
            lv_package    TYPE devclass VALUE '/CTDI/WORKSHOP'.

      ls_field-tabname   = 'TDEVC'.
      ls_field-fieldname = 'DEVCLASS'.
      ls_field-value     = '/CTDI/WORKSHOP'.
      APPEND ls_field TO lt_fields.

      CALL FUNCTION 'POPUP_GET_VALUES'
        EXPORTING
          popup_title = 'Enter Target Development Package'
        IMPORTING
          returncode  = lv_returncode
        TABLES
          fields      = lt_fields
        EXCEPTIONS
          OTHERS      = 1.
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
            repair_id = CONV aufnr( iv_vbeln )
            message   = 'Class generation cancelled by user.'.
      ENDIF.

      " Copy standard base class /CTDI/CL_PRINT_DRIVER_TEMPLATE to the new class name
      DATA: ls_clskey     TYPE seoclskey,
            ls_new_clskey TYPE seoclskey,
            ls_new_class  TYPE vseoclass.

      ls_clskey-clsname     = '/CTDI/CL_PRINT_DRIVER_TEMPLATE'.
      ls_new_clskey-clsname = iv_class_name.

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
        DATA(lv_success) = |Class { iv_class_name } generated successfully.|.
        MESSAGE lv_success TYPE 'S'.

        " Activate the newly generated class
        DATA: lt_objects TYPE STANDARD TABLE OF dwinactiv,
              ls_object  TYPE dwinactiv.

        ls_object-object   = 'CLAS'.
        ls_object-obj_name = iv_class_name.
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
          lv_success = |Class { iv_class_name } activated successfully.|.
          MESSAGE lv_success TYPE 'S'.
        ENDIF.
      ELSE.
        DATA(lv_subrc) = sy-subrc.
        RAISE EXCEPTION TYPE /ctdi/cx_print_error
          EXPORTING
            repair_id = CONV aufnr( iv_vbeln )
            message   = |Failed to generate class (SUBRC: { lv_subrc }).|.
      ENDIF.
    ELSE.
      DATA(lv_cancel_msg) = |Class { iv_class_name } does not exist and generation was declined.|.
      RAISE EXCEPTION TYPE /ctdi/cx_print_error
        EXPORTING
          repair_id = CONV aufnr( iv_vbeln )
          message   = lv_cancel_msg.
    ENDIF.
  ENDMETHOD.


  METHOD validate_form_interface.
    DATA: lv_fm_name   TYPE rs38l_fnam,
          lv_form_type TYPE char1.

    " 1. Determine form type and generated FM name
    SELECT SINGLE formname FROM stxfadm
      WHERE formname = @iv_form_name
      INTO @DATA(lv_ssf_name).
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
      WHERE funcname = @lv_fm_name
        AND paramtype IN ('I', 'T', 'C')
        AND optional = @space
        AND defaultval = @space
      ORDER BY parameter
      INTO TABLE @DATA(lt_mandatory_params).

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
           lv_param = 'REPAIR' OR
           lv_param = 'PROJECT' OR
           lv_param = 'COMMENT_LINES' OR
           lv_param = 'REPAIR_ERRORS'.
          CONTINUE.
        ENDIF.
      ENDIF.

      " If we reach here, we found a custom mandatory parameter!
      " If the base class is configured, it will dump because it cannot supply this parameter.
      IF iv_class_name = /ctdi/cl_print_driver_base=>gc_base_class.
        DATA(lv_err_msg) = |Form { iv_form_name } requires custom mandatory parameter { ls_param-parameter } which standard base class does not support.|.
        RAISE EXCEPTION TYPE /ctdi/cx_print_error
          EXPORTING
            repair_id = CONV aufnr( iv_vbeln )
            message   = lv_err_msg.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
