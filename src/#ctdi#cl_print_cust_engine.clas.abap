CLASS /ctdi/cl_print_cust_engine DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS gc_base_class TYPE seoclsname VALUE '/CTDI/CL_PRINT_DRIVER_BASE'.

    "! Initializes selection screen toolbar pushbuttons for Customizing navigation
    "! @parameter rs_sscrfields | Selection screen fields structure with populated toolbar texts
    CLASS-METHODS init_toolbar
      RETURNING VALUE(rs_sscrfields) TYPE sscrfields.

    "! Dispatches selection screen function codes (FC02: Projects, FC03: Forms, FC04: Results)
    "! @parameter iv_ucomm | Function code triggered by user action
    CLASS-METHODS handle_selection_screen_fcode
      IMPORTING iv_ucomm TYPE sy-ucomm.

    "! Calls SM30 view maintenance for the given table or view
    "! @parameter iv_tabname | Table or View name to maintain
    CLASS-METHODS call_view_maintenance
      IMPORTING iv_tabname TYPE dd02v-tabname.

    "! Hook for SM30 table maintenance event (Event 05: on new entry creation)
    "! @parameter cs_entry | Table entry being created
    CLASS-METHODS on_new_entry
      CHANGING cs_entry TYPE /ctdi/rep_forms.

    "! Validates a Customizing record before saving in SM30 (Event 01)
    "! Checks Form existence in STXFADM/FPCONTEXT, verifies driver class inheritance,
    "! and verifies Form mandatory interface parameter compatibility.
    "! @parameter is_entry | Customizing entry to validate
    "! @raising /ctdi/cx_cust_error | Validation error with diagnostic details
    CLASS-METHODS validate_entry
      IMPORTING is_entry TYPE /ctdi/rep_forms
      RAISING   /ctdi/cx_cust_error.

    "! Checks whether dynamic print provider class generation is permitted
    "! Validates user S_DEVELOP authority and repository client modifiability.
    "! @parameter rv_allowed | True if class generation is permitted, false otherwise
    CLASS-METHODS check_generation_allowed
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Normalizes a short class name to the full provider class name
    "! @parameter iv_class_name | Short or full class name
    "! @parameter rv_class_name | Full normalized class name
    CLASS-METHODS normalize_class_name
      IMPORTING iv_class_name        TYPE seoclsname
      RETURNING VALUE(rv_class_name) TYPE seoclsname.

  PRIVATE SECTION.
    CONSTANTS gc_form_alcatel TYPE fpname VALUE '/CELLAG/ALCAREP' ##NO_TEXT.

    CLASS-METHODS is_subclass_of
      IMPORTING iv_class_name    TYPE seoclsname
                iv_base_class    TYPE seoclsname
      RETURNING VALUE(rv_result) TYPE abap_bool.

    CLASS-METHODS prompt_user_for_generation
      IMPORTING iv_class_name     TYPE seoclsname
                iv_vbeln          TYPE vbeln_va
      RETURNING VALUE(rv_package) TYPE devclass
      RAISING   /ctdi/cx_cust_error.

    CLASS-METHODS copy_and_activate_class
      IMPORTING iv_class_name TYPE seoclsname
                iv_package    TYPE devclass
                iv_vbeln      TYPE vbeln_va
      RAISING   /ctdi/cx_cust_error.

    CLASS-METHODS validate_form_interface
      IMPORTING iv_form_name  TYPE fpname
                iv_class_name TYPE seoclsname
                iv_vbeln      TYPE vbeln_va
      RAISING   /ctdi/cx_cust_error.

    CLASS-METHODS generate_provider_class
      IMPORTING iv_class_name TYPE seoclsname
                iv_vbeln      TYPE vbeln_va
      RAISING   /ctdi/cx_cust_error.

ENDCLASS.



CLASS /CTDI/CL_PRINT_CUST_ENGINE IMPLEMENTATION.


  METHOD call_view_maintenance.
    DATA lv_action TYPE c LENGTH 1 VALUE 'U'. " 'U' for Update / Maintain, 'S' for Display / Show

    CALL FUNCTION 'VIEW_MAINTENANCE_CALL'
      EXPORTING
        action                       = lv_action
        view_name                    = iv_tabname
      EXCEPTIONS
        client_reference             = 1
        foreign_lock                 = 2
        invalid_action               = 3
        no_clientindependent_auth    = 4
        no_database_function         = 5
        no_editor_function           = 6
        no_show_auth                 = 7
        no_tvdir_entry               = 8
        no_upd_auth                  = 9
        only_show_allowed            = 10
        system_failure               = 11
        unknown_field_in_dba_sellist = 12
        view_not_found               = 13
        maintenance_prohibited       = 14
        OTHERS                       = 15.

    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
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
    DATA lv_system_edit TYPE tadir-edtflag.

    CALL FUNCTION 'TR_SYS_PARAMS'
      IMPORTING
        systemedit    = lv_system_edit  " 'W' = Modifiable, 'R' = Read-only
      EXCEPTIONS
        no_systemname = 1
        no_systemtype = 2
        OTHERS        = 3.
    DATA(lv_subrc_sys) = sy-subrc.

    IF lv_subrc_sys = 0 AND lv_system_edit <> 'N'.
      rv_allowed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD copy_and_activate_class.
    DATA ls_clskey     TYPE seoclskey.
    DATA ls_new_clskey TYPE seoclskey.
    DATA lv_package    TYPE devclass.

    ls_clskey-clsname     = '/CTDI/CL_PRINT_DRIVER_TEMPLATE'.
    ls_new_clskey-clsname = iv_class_name.
    lv_package            = iv_package.

    CALL FUNCTION 'SEO_CLASS_COPY'
      EXPORTING
        clskey       = ls_clskey
        new_clskey   = ls_new_clskey
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

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE /ctdi/cx_cust_error
        EXPORTING
          contract_id = iv_vbeln
          message     = |Failed to generate class (SUBRC: { sy-subrc }).|.
    ENDIF.

    MESSAGE |Class { iv_class_name } generated successfully.| TYPE 'S'.

    " Activate the newly generated class
    DATA lt_objects TYPE STANDARD TABLE OF dwinactiv WITH EMPTY KEY.
    DATA ls_object  TYPE dwinactiv.

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
    IF sy-subrc = 0.
      MESSAGE |Class { iv_class_name } activated successfully.| TYPE 'S'.
    ENDIF.
  ENDMETHOD.


  METHOD generate_provider_class.
    DATA(lv_package) = prompt_user_for_generation( iv_class_name = iv_class_name
                                                   iv_vbeln      = iv_vbeln ).

    copy_and_activate_class( iv_class_name = iv_class_name
                             iv_package    = lv_package
                             iv_vbeln      = iv_vbeln ).
  ENDMETHOD.


  METHOD handle_selection_screen_fcode.
    CASE iv_ucomm.
      WHEN 'FC02'.
        call_view_maintenance( '/CTDI/REP_PROJEC' ).
      WHEN 'FC03'.
        call_view_maintenance( '/CTDI/REP_FORMS' ).
      WHEN 'FC04'.
        call_view_maintenance( '/CTDI/REP_RESULT' ).
      WHEN 'FC05'.
        SUBMIT /ctdi/print_repair_mass VIA SELECTION-SCREEN AND RETURN.
    ENDCASE.
  ENDMETHOD.


  METHOD init_toolbar.
    rs_sscrfields-functxt_01 = ' | '. " separator
    rs_sscrfields-functxt_02 = |@PR@ { 'Project'(038) }|.
    rs_sscrfields-functxt_03 = |@0R@ { 'Forms'(039) }|.
    rs_sscrfields-functxt_04 = |@0Q@ { 'Results'(040) }|.
    IF sy-cprog = '/CTDI/PRINT_REPAIR'.
      rs_sscrfields-functxt_05 = |@HB@ { 'Mass Print'(041) }|.
    ENDIF.
  ENDMETHOD.


  METHOD is_subclass_of.
    rv_result = abap_false.
    IF iv_class_name IS INITIAL OR iv_base_class IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_descr) = CAST cl_abap_classdescr(
          cl_abap_typedescr=>describe_by_name( iv_class_name ) ).

        WHILE lo_descr IS BOUND.
          IF lo_descr->absolute_name CS iv_base_class.
            rv_result = abap_true.
            RETURN.
          ENDIF.
          lo_descr = lo_descr->get_super_class_type( ).
        ENDWHILE.
      CATCH cx_root.
        rv_result = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD normalize_class_name.
    rv_class_name = to_upper( iv_class_name ).

    IF rv_class_name IS INITIAL.
      RETURN.
    ENDIF.

    " If it already contains a namespace or standard prefix, do nothing
    IF rv_class_name CS '/'.
      RETURN.
    ENDIF.

    " Normalize short names like 'CTDI', 'BASE' into full class names
    IF rv_class_name CS 'CL_PRINT_DRIVER_'.
      rv_class_name = |/CTDI/{ rv_class_name }|.
    ELSE.
      rv_class_name = |/CTDI/CL_PRINT_DRIVER_{ rv_class_name }|.
    ENDIF.
  ENDMETHOD.


  METHOD on_new_entry.
    " Hook for SM30 table maintenance event (Event 05: on new entry creation).
    " Customizing defaulting or validation logic can be placed here.
*    CLEAR cs_entry-akz.
  ENDMETHOD.


  METHOD prompt_user_for_generation.
    DATA lv_answer TYPE c LENGTH 1.

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

    IF sy-subrc <> 0 OR lv_answer <> '1'.
      DATA(lv_cancel_msg) = |Class { iv_class_name } does not exist and generation was declined.|.
      RAISE EXCEPTION TYPE /ctdi/cx_cust_error
        EXPORTING
          contract_id = iv_vbeln
          message     = lv_cancel_msg.
    ENDIF.

    " Prompt user for the target Development Package
    DATA lt_fields     TYPE STANDARD TABLE OF sval WITH EMPTY KEY.
    DATA ls_field      TYPE sval.
    DATA lv_returncode TYPE c LENGTH 1.

    rv_package = '/CTDI/WORKSHOP'.

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

    IF lv_returncode = 'A'.
      RAISE EXCEPTION TYPE /ctdi/cx_cust_error
        EXPORTING
          contract_id = iv_vbeln
          message     = 'Class generation cancelled by user.'.
    ENDIF.

    READ TABLE lt_fields INTO ls_field INDEX 1.
    IF sy-subrc = 0 AND ls_field-value IS NOT INITIAL.
      rv_package = ls_field-value.
    ENDIF.
  ENDMETHOD.


  METHOD validate_entry.
    " 1. Validate Form Name existence in Smart Forms (STXFADM) or Adobe Forms (FPCONTEXT)
    IF is_entry-form_name IS NOT INITIAL.
      SELECT SINGLE formname FROM stxfadm
        WHERE formname = @is_entry-form_name
        INTO @DATA(lv_ssf_exists) ##NEEDED.
      IF sy-subrc <> 0.
        SELECT SINGLE name FROM fpcontext
          WHERE name = @is_entry-form_name
          INTO @DATA(lv_fp_exists) ##NEEDED.
        IF sy-subrc <> 0.
          DATA(lv_form_err) = |Form { is_entry-form_name } does not exist as a Smart Form or Adobe Form.|.
          RAISE EXCEPTION TYPE /ctdi/cx_cust_error
            EXPORTING
              contract_id = is_entry-vbeln
              message     = lv_form_err.
        ENDIF.
      ENDIF.

      " Eagerly validate form parameter compatibility
      validate_form_interface( iv_form_name  = is_entry-form_name
                               iv_class_name = is_entry-class_name
                               iv_vbeln      = is_entry-vbeln ).
    ENDIF.

    IF is_entry-form_name = gc_form_alcatel.
      RETURN.
    ENDIF. " NE gc_form_alcatel.

    " 2. Class name is required for new Forms
    IF is_entry-class_name IS INITIAL.
      DATA(lv_msg) = |Class name is required for Contract { is_entry-vbeln }|.
      RAISE EXCEPTION TYPE /ctdi/cx_cust_error
        EXPORTING
          contract_id = is_entry-vbeln
          message     = lv_msg.
    ENDIF.

    " 3. Validate Class existence in Repository (SEOCLASS)
    DATA(lv_class_name) = is_entry-class_name.

    SELECT SINGLE clsname FROM seoclass
      WHERE clsname = @lv_class_name
      INTO @DATA(lv_class_exists) ##NEEDED.
    IF sy-subrc <> 0.
      " Class does not exist! Offer to generate it on-the-fly if system modifiability and authorizations permit
      IF check_generation_allowed( ) = abap_true.
        generate_provider_class( iv_class_name = is_entry-class_name
                                 iv_vbeln      = is_entry-vbeln ).
        RETURN. " Class now successfully generated, bypass error check
      ENDIF.

      " Raise validation error if generation is skipped or not permitted (e.g. locked client)
      DATA(lv_class_err) = |Class { is_entry-class_name } does not exist in the repository|.
      RAISE EXCEPTION TYPE /ctdi/cx_cust_error
        EXPORTING
          contract_id = is_entry-vbeln
          message     = lv_class_err.
    ELSEIF is_subclass_of( iv_class_name = lv_class_name
                           iv_base_class = gc_base_class ) = abap_false.
      " Validate inheritance from base class /CTDI/CL_PRINT_DRIVER_BASE
      DATA(lv_interface_err) = |Class { is_entry-class_name } does not inherit from /CTDI/CL_PRINT_DRIVER_BASE|.
      RAISE EXCEPTION TYPE /ctdi/cx_cust_error
        EXPORTING
          contract_id = is_entry-vbeln
          message     = lv_interface_err.
    ENDIF.
  ENDMETHOD.


  METHOD validate_form_interface.
    DATA lv_fm_name   TYPE rs38l_fnam.
    DATA lv_form_type TYPE char1.

    " 1. Determine form type and generated FM name
    SELECT SINGLE formname FROM stxfadm
      WHERE formname = @iv_form_name
      INTO @DATA(lv_ssf_name) ##NEEDED.
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
    SELECT parameter FROM fupararef
      WHERE funcname    = @lv_fm_name
        AND paramtype  IN ( 'I', 'T', 'C' )
        AND optional    = @space
        AND defaultval  = @space
      ORDER BY parameter
      INTO TABLE @DATA(lt_mandatory_params).

    IF sy-subrc <> 0.
      RETURN. " No mandatory parameters found
    ENDIF.

    " 3. Filter out standard/framework parameters
    DATA lt_framework_sf TYPE SORTED TABLE OF fupararef-parameter WITH UNIQUE KEY table_line.
    DATA lt_framework_af TYPE SORTED TABLE OF fupararef-parameter WITH UNIQUE KEY table_line.

    lt_framework_sf = VALUE #( ( CONV #( /ctdi/cl_print_driver_base=>gc_param_control_param ) )
                               ( CONV #( /ctdi/cl_print_driver_base=>gc_param_output_opt ) )
                               ( CONV #( 'USER_SETTINGS' ) )
                               ( CONV #( 'ARCHIVE_INDEX' ) )
                               ( CONV #( 'ARCHIVE_INDEX_TAB' ) )
                               ( CONV #( 'ARCHIVE_PARAMETERS' ) )
                               ( CONV #( 'MAIL_APPL_OBJ' ) )
                               ( CONV #( 'MAIL_RECIPIENT' ) )
                               ( CONV #( 'MAIL_SENDER' ) ) ).

    lt_framework_af = VALUE #( ( CONV #( /ctdi/cl_print_driver_base=>gc_param_docparams ) ) ).

    LOOP AT lt_mandatory_params ASSIGNING FIELD-SYMBOL(<ls_param>).
      DATA(lv_param) = to_upper( <ls_param>-parameter ).

      IF ( lv_form_type = 'S' AND line_exists( lt_framework_sf[ table_line = lv_param ] ) )
      OR ( lv_form_type = 'A' AND line_exists( lt_framework_af[ table_line = lv_param ] ) ).
        CONTINUE.
      ENDIF.

      " If we reach here, we found a custom mandatory parameter!
      " If the base class is configured, it will dump because it cannot supply this parameter.
      IF iv_class_name = gc_base_class.
        DATA(lv_err_msg) = |Form { iv_form_name } requires custom mandatory parameter { <ls_param>-parameter } which standard base class does not support.|.
        RAISE EXCEPTION TYPE /ctdi/cx_cust_error
          EXPORTING
            contract_id = iv_vbeln
            message     = lv_err_msg.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
