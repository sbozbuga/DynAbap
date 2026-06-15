CLASS /ctdi/cl_print_driver_base DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      tt_config_buffer TYPE HASHED TABLE OF /ctdi/rep_forms WITH UNIQUE KEY vbeln skz akz.
      
    CLASS-DATA mt_config_buffer TYPE tt_config_buffer.
    CLASS-DATA mt_project_buffer TYPE HASHED TABLE OF /ctdi/rep_projec WITH UNIQUE KEY vbeln.

    "! Static factory to determine and instantiate the correct driver
    CLASS-METHODS factory
      IMPORTING
        !iv_repair_id TYPE aufnr
        !iv_sernr     TYPE equi-sernr OPTIONAL
      RETURNING
        VALUE(ro_driver) TYPE REF TO /ctdi/cl_print_driver_base
      RAISING
        /ctdi/cx_print_driver_error
        /ctdi/cx_no_config_found.

    "! Executes the full print pipeline (read data + render form).
    METHODS execute
      IMPORTING
        !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
        !io_data        TYPE REF TO object OPTIONAL
      RAISING
        /ctdi/cx_print_driver_error.

  PROTECTED SECTION.
    DATA: mv_repair_order TYPE aufnr,
          mv_sernr        TYPE equi-sernr,
          mv_form_name TYPE fpname,
          ms_repair    TYPE /ctdi/repair,
          ms_project  TYPE /ctdi/rep_projec,
          mt_errors   TYPE /ctdi/repair_error_tt,
          mt_comments TYPE STANDARD TABLE OF tline,
          mt_custom_form_params TYPE abap_func_parmbind_tab.

    "! Registers a custom parameter to be passed dynamically to the form
    METHODS register_custom_parameter
      IMPORTING
        !iv_name TYPE string
        !ir_data TYPE REF TO data
        !iv_kind TYPE abap_func_parmbind-kind DEFAULT abap_func_exporting.

    "! Reads repair data from the database into memory.
    "! Subclasses should redefine this method to supply custom data.
    METHODS read_data
      IMPORTING
        !io_data        TYPE REF TO object OPTIONAL
      RAISING
        /ctdi/cx_print_driver_error.

    "! Renders the form (SmartForm or Adobe) and optionally saves as PDF.
    METHODS render_form
      IMPORTING
        !iv_save_as_pdf TYPE abap_bool
      RAISING
        /ctdi/cx_print_driver_error.

    "! Detects form technology: 'S' = Smart Form, 'A' = Adobe Form.
    METHODS detect_form_type
      RETURNING
        VALUE(rv_type)  TYPE char1.

    "! Executes a Smart Form and optionally converts OTF output to PDF.
    METHODS execute_smartform
      IMPORTING
        !iv_save_as_pdf TYPE abap_bool
      RAISING
        /ctdi/cx_print_driver_error.

    "! Executes an Adobe Form and optionally retrieves the PDF stream.
    METHODS execute_adobeform
      IMPORTING
        !iv_save_as_pdf TYPE abap_bool
      RAISING
        /ctdi/cx_print_driver_error.

    "! Downloads an XSTRING as a PDF file via the presentation layer.
    METHODS download_pdf
      IMPORTING
        !iv_pdf_data  TYPE xstring
      RAISING
        /ctdi/cx_print_driver_error.

    "! Retrieves user print defaults via standard SAP APIs.
    METHODS get_user_print_defaults
      EXPORTING
        !ev_printer TYPE rspopname
        !ev_immed   TYPE c
        !ev_delete  TYPE c.

  PRIVATE SECTION.
    CLASS-METHODS resolve_contract
      IMPORTING
        !iv_repair_id TYPE aufnr
      EXPORTING
        !ev_contract_id TYPE vbeln_va
        !ev_skz TYPE bemot
        !ev_akz TYPE char4
      RAISING
        /ctdi/cx_print_driver_error.
        
    CLASS-METHODS get_config_from_db
      IMPORTING
        !iv_repair_id TYPE aufnr
      EXPORTING
        !ev_form_name TYPE fpname
        !ev_class_name TYPE seoclsname
        !es_project TYPE /ctdi/rep_projec
      RAISING
        /ctdi/cx_print_driver_error
        /ctdi/cx_no_config_found.
        
ENDCLASS.

CLASS /ctdi/cl_print_driver_base IMPLEMENTATION.

  METHOD execute.
    /ctdi/cl_print_driver_log=>log_info(
      |Print driver started | &&
      |Repair: { mv_repair_order }, Form: { mv_form_name }, Save PDF: { iv_save_as_pdf }| ).

    " Step 1: Read business data
    read_data( io_data = io_data ).

    " Step 2: Render the form (SmartForm or Adobe)
    render_form( iv_save_as_pdf = iv_save_as_pdf ).

    /ctdi/cl_print_driver_log=>log_info(
      |Print driver completed successfully for Repair { mv_repair_order }| ).
  ENDMETHOD.

  METHOD factory.
    DATA: lv_form_name  TYPE fpname,
          lv_class_name TYPE seoclsname,
          ls_project_db TYPE /ctdi/rep_projec.

    /ctdi/cl_print_driver_log=>log_info(
      |Print driver factory invoked for Repair { iv_repair_id }, Sernr { iv_sernr }| ).

    get_config_from_db(
      EXPORTING iv_repair_id  = iv_repair_id
      IMPORTING ev_form_name  = lv_form_name
                ev_class_name = lv_class_name
                es_project    = ls_project_db ).

    IF lv_form_name = '/CELLAG/ALCAREP'.
      RAISE EXCEPTION TYPE /ctdi/cx_no_config_found.
    ENDIF.

    TRY.
        CREATE OBJECT ro_driver TYPE (lv_class_name).
        ro_driver->mv_repair_order = iv_repair_id.
        ro_driver->mv_sernr        = iv_sernr.
        ro_driver->mv_form_name = lv_form_name.
        ro_driver->ms_project   = ls_project_db.
      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING
            repair_id = iv_repair_id
            message   = |Cannot instantiate class { lv_class_name }|
            previous  = lx_create.
    ENDTRY.
  ENDMETHOD.

  METHOD resolve_contract.
    DATA(lv_aufnr) = |{ iv_repair_id ALPHA = IN }|.
    CLEAR: ev_contract_id, ev_skz, ev_akz.

    SELECT SINGLE kdauf
      FROM aufk AS a
      WHERE a~aufnr = @lv_aufnr
      INTO @DATA(lv_order_id).

    IF sy-subrc = 0 AND lv_order_id IS NOT INITIAL.
      SELECT SINGLE vgbel
       FROM vbak
      WHERE vbeln = @lv_order_id
        AND vbtyp = 'G'
        INTO @ev_contract_id.
        
      IF sy-subrc NE 0.
        DATA(lv_err1) = |Could not find a Contract for Order { lv_order_id }|.
        /ctdi/cl_print_driver_log=>log_error( lv_err1 ).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING
            repair_id = iv_repair_id
            message   = lv_err1.
      ENDIF.

      SELECT bemot, stokz, stzhl
        FROM afru
        WHERE aufnr = @lv_aufnr
          AND vornr = '9010'
        INTO TABLE @DATA(lt_afru).

      IF sy-subrc = 0.
        LOOP AT lt_afru ASSIGNING FIELD-SYMBOL(<ls_afru>).
          IF <ls_afru>-stokz = space AND <ls_afru>-stzhl = '00000000'.
            ev_skz = <ls_afru>-bemot.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.

      SELECT SINGLE qmcod
        FROM qmel
        WHERE aufnr = @lv_aufnr
          AND qmart = 'Z2'
        INTO @ev_akz.
      IF sy-subrc <> 0.
        " Ignore
      ENDIF.

      /ctdi/cl_print_driver_log=>log_info(
        |Resolved Order { iv_repair_id } -> Contract { ev_contract_id }, SKZ { ev_skz }, AKZ { ev_akz }| ).

    ELSE.
      DATA(lv_err2) = |Could not resolve Contract for Repair Order { iv_repair_id }|.
      /ctdi/cl_print_driver_log=>log_error( lv_err2 ).
      RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
        EXPORTING
          repair_id = iv_repair_id
          message   = lv_err2.
    ENDIF.
  ENDMETHOD.

  METHOD get_config_from_db.
    DATA: lv_contract TYPE vbeln_va,
          lv_skz      TYPE bemot,
          lv_akz      TYPE char4,
          ls_config   TYPE /ctdi/rep_forms.

    TYPES: BEGIN OF ty_query_step,
             vbeln TYPE vbeln_va,
             skz   TYPE bemot,
             akz   TYPE char4,
           END OF ty_query_step.
    DATA: lt_steps TYPE TABLE OF ty_query_step.

    IF ev_form_name IS SUPPLIED OR ev_class_name IS SUPPLIED.

      resolve_contract( EXPORTING iv_repair_id    = iv_repair_id
                        IMPORTING ev_contract_id  = lv_contract
                                  ev_skz          = lv_skz
                                  ev_akz          = lv_akz ).

      READ TABLE mt_config_buffer WITH TABLE KEY
        vbeln = lv_contract
        skz   = lv_skz
        akz   = lv_akz
        INTO ls_config.

      IF sy-subrc = 0.
        ev_form_name  = ls_config-form_name.
        ev_class_name = /ctdi/cl_print_cust_engine=>normalize_class_name( ls_config-class_name ).
      ELSE.
        IF lv_contract IS NOT INITIAL.
          IF lv_skz IS NOT INITIAL AND lv_akz IS NOT INITIAL.
            APPEND VALUE #( vbeln = lv_contract skz = lv_skz akz = lv_akz ) TO lt_steps.
          ENDIF.
          IF lv_skz IS NOT INITIAL.
            APPEND VALUE #( vbeln = lv_contract skz = lv_skz akz = '' ) TO lt_steps.
          ENDIF.
          IF lv_akz IS NOT INITIAL.
            APPEND VALUE #( vbeln = lv_contract skz = '' akz = lv_akz ) TO lt_steps.
          ENDIF.
          APPEND VALUE #( vbeln = lv_contract skz = '' akz = '' ) TO lt_steps.
        ENDIF.

        IF lv_skz IS NOT INITIAL AND lv_akz IS NOT INITIAL.
          APPEND VALUE #( vbeln = '' skz = lv_skz akz = lv_akz ) TO lt_steps.
        ENDIF.
        IF lv_skz IS NOT INITIAL.
          APPEND VALUE #( vbeln = '' skz = lv_skz akz = '' ) TO lt_steps.
        ENDIF.
        IF lv_akz IS NOT INITIAL.
          APPEND VALUE #( vbeln = '' skz = '' akz = lv_akz ) TO lt_steps.
        ENDIF.
        
        " Global fallback (Empty Keys)
        APPEND VALUE #( vbeln = '' skz = '' akz = '' ) TO lt_steps.

        IF lt_steps IS NOT INITIAL.

          SELECT * FROM /ctdi/rep_forms "#EC CI_ALL_FIELDS_NEEDED
            WHERE vbeln = @lv_contract OR vbeln =  ''
            ORDER BY PRIMARY KEY ##SUBRC_OK
            INTO TABLE @DATA(lt_forms).

          LOOP AT lt_steps ASSIGNING FIELD-SYMBOL(<ls_step>).
            READ TABLE lt_forms INTO ls_config WITH KEY
              vbeln = <ls_step>-vbeln
              skz   = <ls_step>-skz
              akz   = <ls_step>-akz.
            IF sy-subrc = 0.
              EXIT.
            ENDIF.
          ENDLOOP.
        ENDIF.

        IF ls_config IS NOT INITIAL.
          INSERT ls_config INTO TABLE mt_config_buffer.
          ev_form_name  = ls_config-form_name.
          ev_class_name = /ctdi/cl_print_cust_engine=>normalize_class_name( ls_config-class_name ).
        ELSE.
          RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
            EXPORTING
              repair_id = iv_repair_id
              message   = |No configuration found in /CTDI/REP_FORMS (including default fallback).|.
        ENDIF.
      ENDIF.
      /ctdi/cl_print_driver_log=>log_info(
        |Config resolved and cached — Contract: { lv_contract }, | &&
        |SKZ: { lv_skz }, AKZ: { lv_akz }, Form: { ev_form_name }, Class: { ev_class_name }| ).
    ENDIF.

    READ TABLE mt_project_buffer INTO es_project WITH TABLE KEY vbeln = lv_contract.

    IF sy-subrc <> 0.
      SELECT SINGLE *
        FROM /ctdi/rep_projec "#EC CI_ALL_FIELDS_NEEDED
        WHERE vbeln = @lv_contract ##SUBRC_OK
        INTO @es_project.

      IF es_project IS NOT INITIAL.
        INSERT es_project INTO TABLE mt_project_buffer.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD read_data.
    " Default: no-op. Subclasses override this to populate ms_repair
    " from database tables based on mv_repair_order.
    /ctdi/cl_print_driver_log=>log_info(
      |Default read_data invoked for Repair { mv_repair_order } — no data loaded| ).
  ENDMETHOD.

  METHOD render_form.
    " Ensure passed repair header is valid
    IF ms_repair IS INITIAL.
      /ctdi/cl_print_driver_log=>log_warning(
        |Repair data reference is empty - | &&
        |Print execution bypassed for Repair ID { mv_repair_order }| ).
      RETURN.
    ENDIF.

    DATA(lv_form_type) = detect_form_type( ).

    IF lv_form_type = 'S'.
      /ctdi/cl_print_driver_log=>log_info(
        |Form { mv_form_name } detected as Smart Form| ).
      execute_smartform( iv_save_as_pdf = iv_save_as_pdf ).
    ELSE.
      /ctdi/cl_print_driver_log=>log_info(
        |Form { mv_form_name } detected as Adobe Form| ).
      execute_adobeform( iv_save_as_pdf = iv_save_as_pdf ).
    ENDIF.
  ENDMETHOD.

  METHOD detect_form_type.
    SELECT SINGLE formname FROM stxfadm
      WHERE formname = @mv_form_name
      INTO @DATA(lv_ssf_name).
    IF sy-subrc = 0.
      rv_type = 'S'.          " Smart Form exists in STXFADM
    ELSE.
      rv_type = 'A'.          " Default to Adobe Form
    ENDIF.
  ENDMETHOD.


  METHOD execute_smartform.
    DATA: lv_fm_name          TYPE rs38l_fnam,
          ls_control_params   TYPE ssfctrlop,
          ls_output_options   TYPE ssfcompop,
          ls_job_output       TYPE ssfcrescl,
          lt_otf              TYPE TABLE OF itcoo,
          lv_pdf_xstring      TYPE xstring,
          lt_pdf_lines        TYPE TABLE OF tline,
          lv_printer          TYPE rspopname,
          lv_immed            TYPE c,
          lv_delete           TYPE c,
          lv_err              TYPE string.

    " Resolve generated function module name
    CALL FUNCTION 'SSF_FUNCTION_MODULE_NAME'
      EXPORTING
        formname           = mv_form_name
      IMPORTING
        fm_name            = lv_fm_name
      EXCEPTIONS
        no_form            = 1
        no_function_module = 2
        OTHERS             = 3.
    IF sy-subrc <> 0.
      lv_err = |Smart Form FM resolution failed for { mv_form_name } (subrc={ sy-subrc })|.
      /ctdi/cl_print_driver_log=>log_error( lv_err ).
      RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
        EXPORTING repair_id = mv_repair_order
                  message   = lv_err.
    ENDIF.

    " Apply user print defaults
    get_user_print_defaults(
      IMPORTING ev_printer = lv_printer
                ev_immed   = lv_immed
                ev_delete  = lv_delete ).

    ls_output_options-tddest   = lv_printer.
    ls_output_options-tdcopies = 1.
    ls_output_options-tdimmed  = lv_immed.
    ls_output_options-tddelete = lv_delete.
    ls_output_options-tdnewid  = abap_true.

    " Dynamic device type based on logon language
    DATA: lv_devtype TYPE rspoptype.
    CALL FUNCTION 'SSF_GET_DEVICE_TYPE'
      EXPORTING
        i_language    = sy-langu
      IMPORTING
        e_devtype     = lv_devtype
      EXCEPTIONS
        OTHERS        = 1.
    IF sy-subrc <> 0.
      lv_devtype = 'YPDF'.
    ENDIF.
    ls_output_options-tdprinter = lv_devtype.

    " PDF mode: intercept OTF data
    IF iv_save_as_pdf = abap_true.
      ls_control_params-getotf    = abap_true.
      ls_control_params-no_dialog = abap_true.
    ENDIF.

    DATA: lv_subrc_fm TYPE sysubrc.

    DATA: lt_ptab TYPE abap_func_parmbind_tab,
          ls_ptab TYPE abap_func_parmbind,
          lt_etab TYPE abap_func_excpbind_tab,
          ls_etab TYPE abap_func_excpbind.

    ls_ptab-name = 'CONTROL_PARAMETERS'.
    ls_ptab-kind = abap_func_exporting.
    GET REFERENCE OF ls_control_params INTO ls_ptab-value.
    INSERT ls_ptab INTO TABLE lt_ptab.

    ls_ptab-name = 'OUTPUT_OPTIONS'.
    ls_ptab-kind = abap_func_exporting.
    GET REFERENCE OF ls_output_options INTO ls_ptab-value.
    INSERT ls_ptab INTO TABLE lt_ptab.


    " Fetch all valid parameters for the generated function module to prevent dumps
    SELECT parameter FROM fupararef
      WHERE funcname = @lv_fm_name
      INTO TABLE @DATA(lt_valid_params_sf).

    " Inject any dynamically registered custom parameters if they exist in the form
    LOOP AT mt_custom_form_params INTO DATA(ls_custom_param_sf).
      READ TABLE lt_valid_params_sf WITH KEY parameter = ls_custom_param_sf-name TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        INSERT ls_custom_param_sf INTO TABLE lt_ptab.
      ENDIF.
    ENDLOOP.

    ls_ptab-name = 'JOB_OUTPUT_INFO'.
    ls_ptab-kind = abap_func_importing.
    GET REFERENCE OF ls_job_output INTO ls_ptab-value.
    INSERT ls_ptab INTO TABLE lt_ptab.

    ls_etab-name = 'FORMATTING_ERROR'. ls_etab-value = 1. INSERT ls_etab INTO TABLE lt_etab.
    ls_etab-name = 'INTERNAL_ERROR'.   ls_etab-value = 2. INSERT ls_etab INTO TABLE lt_etab.
    ls_etab-name = 'SEND_ERROR'.       ls_etab-value = 3. INSERT ls_etab INTO TABLE lt_etab.
    ls_etab-name = 'USER_CANCELED'.    ls_etab-value = 4. INSERT ls_etab INTO TABLE lt_etab.
    ls_etab-name = 'OTHERS'.           ls_etab-value = 5. INSERT ls_etab INTO TABLE lt_etab.

    TRY.
        CALL FUNCTION lv_fm_name
          PARAMETER-TABLE lt_ptab
          EXCEPTION-TABLE lt_etab.
        lv_subrc_fm = sy-subrc.
      CATCH cx_sy_dyn_call_error INTO DATA(lx_dyn_call).
        lv_err = |Dynamic call error for { mv_form_name }: { lx_dyn_call->get_text( ) }|.
        /ctdi/cl_print_driver_log=>log_error( lv_err ).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING repair_id = mv_repair_order
                    message   = lv_err.
    ENDTRY.

    IF lv_subrc_fm <> 0.
      lv_err = |Smart Form { mv_form_name } execution failed (subrc={ lv_subrc_fm })|.
      /ctdi/cl_print_driver_log=>log_error( lv_err ).
      RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
        EXPORTING repair_id = mv_repair_order
                  message   = lv_err.
    ENDIF.

    /ctdi/cl_print_driver_log=>log_info(
      |Smart Form { mv_form_name } executed successfully| ).

    " PDF conversion if requested
    IF iv_save_as_pdf = abap_true.
      lt_otf = ls_job_output-otfdata.
      CALL FUNCTION 'CONVERT_OTF'
        EXPORTING
          format                = 'PDF'
        IMPORTING
          bin_file              = lv_pdf_xstring
        TABLES
          otf                   = lt_otf
          lines                 = lt_pdf_lines
        EXCEPTIONS
          err_max_linewidth     = 1
          err_format            = 2
          err_conv_not_possible = 3
          err_bad_otf           = 4
          OTHERS                = 5.
      IF sy-subrc <> 0.
        lv_err = |CONVERT_OTF failed for { mv_form_name } (subrc={ sy-subrc })|.
        /ctdi/cl_print_driver_log=>log_error( lv_err ).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING repair_id = mv_repair_order
                    message   = lv_err.
      ENDIF.

      download_pdf( iv_pdf_data = lv_pdf_xstring ).
    ENDIF.
  ENDMETHOD.


  METHOD execute_adobeform.
    DATA: lv_fm_name        TYPE rs38l_fnam,
          ls_outputparams   TYPE sfpoutputparams,
          ls_docparams      TYPE sfpdocparams,
          ls_formoutput     TYPE fpformoutput,
          ls_joboutput      TYPE sfpjoboutput,
          lv_subrc          TYPE sysubrc,
          lv_printer        TYPE rspopname,
          lv_immed          TYPE c,
          lv_delete          TYPE c,
          lv_err            TYPE string.

    " Apply user print defaults
    get_user_print_defaults(
      IMPORTING ev_printer = lv_printer
                ev_immed   = lv_immed
                ev_delete  = lv_delete ).

    " Configure output parameters
*    ls_outputparams-connection = 'ADS'.
    ls_outputparams-reqnew = abap_true.
    ls_outputparams-reqimm = abap_true.
    ls_outputparams-reqfinal = abap_true.
    ls_outputparams-dest       = lv_printer.
    ls_outputparams-reqimm     = lv_immed.
    ls_outputparams-reqdel     = lv_delete.
    IF iv_save_as_pdf = abap_true.
      ls_outputparams-nodialog   = abap_true.
      ls_outputparams-getpdf   = abap_true.
    ELSE.
      ls_outputparams-preview    = abap_true.
    ENDIF.

    " Open Adobe print job
    CALL FUNCTION 'FP_JOB_OPEN'
      CHANGING
        ie_outputparams = ls_outputparams
      EXCEPTIONS
        cancel          = 1
        usage_error     = 2
        system_error    = 3
        internal_error  = 4
        OTHERS          = 5.
    IF sy-subrc <> 0.
      lv_err = |FP_JOB_OPEN failed (subrc={ sy-subrc })|.
      /ctdi/cl_print_driver_log=>log_error( lv_err ).
      RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
        EXPORTING repair_id = mv_repair_order
                  message   = lv_err.
    ENDIF.

    " Resolve generated function module name
    TRY.
        CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
          EXPORTING
            i_name     = mv_form_name
          IMPORTING
            e_funcname = lv_fm_name.
      CATCH cx_fp_api INTO DATA(lx_fp).
        CALL FUNCTION 'FP_JOB_CLOSE'
          EXCEPTIONS
            OTHERS = 1.
        IF sy-subrc <> 0.
          DATA(lv_subrc_close_err) = sy-subrc.
        ENDIF.
        lv_err = |Adobe Form FM resolution failed for { mv_form_name }: { lx_fp->get_text( ) }|.
        /ctdi/cl_print_driver_log=>log_error( lv_err ).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING repair_id = mv_repair_order
                    message   = lv_err
                    previous  = lx_fp.
    ENDTRY.

    " Document parameters
    ls_docparams-langu   = sy-langu.
    ls_docparams-country = 'US'.

    DATA: lt_ptab TYPE abap_func_parmbind_tab,
          ls_ptab TYPE abap_func_parmbind,
          lt_etab TYPE abap_func_excpbind_tab,
          ls_etab TYPE abap_func_excpbind.

    ls_ptab-name = '/1BCDWB/DOCPARAMS'.
    ls_ptab-kind = abap_func_exporting.
    GET REFERENCE OF ls_docparams INTO ls_ptab-value.
    INSERT ls_ptab INTO TABLE lt_ptab.



    " Fetch all valid parameters for the generated function module to prevent dumps
    SELECT parameter FROM fupararef
      WHERE funcname = @lv_fm_name
      INTO TABLE @DATA(lt_valid_params_af).

    " Inject any dynamically registered custom parameters if they exist in the form
    LOOP AT mt_custom_form_params INTO DATA(ls_custom_param_af).
      READ TABLE lt_valid_params_af WITH KEY parameter = ls_custom_param_af-name TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        INSERT ls_custom_param_af INTO TABLE lt_ptab.
      ENDIF.
    ENDLOOP.

    ls_ptab-name = '/1BCDWB/FORMOUTPUT'.
    ls_ptab-kind = abap_func_importing.
    GET REFERENCE OF ls_formoutput INTO ls_ptab-value.
    INSERT ls_ptab INTO TABLE lt_ptab.

    ls_etab-name = 'USAGE_ERROR'.    ls_etab-value = 1. INSERT ls_etab INTO TABLE lt_etab.
    ls_etab-name = 'SYSTEM_ERROR'.   ls_etab-value = 2. INSERT ls_etab INTO TABLE lt_etab.
    ls_etab-name = 'INTERNAL_ERROR'. ls_etab-value = 3. INSERT ls_etab INTO TABLE lt_etab.
    ls_etab-name = 'OTHERS'.         ls_etab-value = 4. INSERT ls_etab INTO TABLE lt_etab.

    TRY.
        CALL FUNCTION lv_fm_name
          PARAMETER-TABLE lt_ptab
          EXCEPTION-TABLE lt_etab.
        lv_subrc = sy-subrc.
      CATCH cx_sy_dyn_call_error INTO DATA(lx_dyn_call).
        lv_err = |Dynamic call error for { mv_form_name }: { lx_dyn_call->get_text( ) }|.
        /ctdi/cl_print_driver_log=>log_error( lv_err ).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING repair_id = mv_repair_order
                    message   = lv_err.
    ENDTRY.

    " Close the print job
    CALL FUNCTION 'FP_JOB_CLOSE'
      IMPORTING
        e_result       = ls_joboutput
      EXCEPTIONS
        usage_error    = 1
        system_error   = 2
        internal_error = 3
        OTHERS         = 4.
    IF sy-subrc <> 0.
      DATA(lv_subrc_close) = sy-subrc.
    ENDIF.

    IF lv_subrc <> 0.
      lv_err = |Adobe Form { mv_form_name } execution failed (subrc={ lv_subrc })|.
      /ctdi/cl_print_driver_log=>log_error( lv_err ).
      RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
        EXPORTING repair_id = mv_repair_order
                  message   = lv_err.
    ENDIF.

    /ctdi/cl_print_driver_log=>log_info(
      |Adobe Form { mv_form_name } executed successfully| ).

    " Download PDF if requested
    IF iv_save_as_pdf = abap_true AND ls_formoutput-pdf IS NOT INITIAL.
      download_pdf( iv_pdf_data = ls_formoutput-pdf ).
    ENDIF.
  ENDMETHOD.


  METHOD download_pdf.
    DATA: lt_filetab TYPE filetable,
          lv_rc      TYPE i,
          lv_action  TYPE i,
          lv_path    TYPE string,
          lv_filename TYPE string,
          lt_data    TYPE solix_tab.

    IF iv_pdf_data IS INITIAL.
      RETURN.
    ENDIF.

    " Guard: batch mode — frontend services are unavailable
    IF sy-batch IS NOT INITIAL.
      /ctdi/cl_print_driver_log=>log_warning(
        |PDF download skipped for Repair { mv_repair_order } in batch mode| ).
      RETURN.
    ENDIF.

    " Convert XSTRING to binary table
    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
      EXPORTING
        buffer     = iv_pdf_data
      TABLES
        binary_tab = lt_data
      EXCEPTIONS
        OTHERS     = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Show file-save dialog
    cl_gui_frontend_services=>file_save_dialog(
      EXPORTING
        default_file_name    = |Repair_{ mv_repair_order }.pdf|
        default_extension    = 'pdf'
        file_filter          = 'PDF Files (*.pdf)|*.pdf'
      CHANGING
        filename             = lv_filename
        path                 = lv_path
        fullpath             = lv_path
        user_action          = lv_action
      EXCEPTIONS
        OTHERS               = 1 ).
    IF sy-subrc <> 0.
      DATA(lv_subrc_dialog) = sy-subrc.
    ENDIF.

    IF lv_action = cl_gui_frontend_services=>action_ok AND lv_path IS NOT INITIAL.
      cl_gui_frontend_services=>gui_download(
        EXPORTING
          filename                  = lv_path
          filetype                  = 'BIN'
          bin_filesize              = xstrlen( iv_pdf_data )
        CHANGING
          data_tab                  = lt_data
        EXCEPTIONS
          file_write_error          = 1
          no_batch                  = 2
          gui_refuse_filetransfer   = 3
          invalid_type              = 4
          no_authority              = 5
          unknown_error             = 6
          header_not_allowed        = 7
          separator_not_allowed     = 8
          filesize_not_allowed      = 9
          header_too_long           = 10
          access_denied             = 12
          dp_out_of_memory          = 13
          disk_full                 = 14
          dp_timeout                = 15
          file_not_found            = 16
          dataprovider_exception    = 17
          control_flush_error       = 18
          OTHERS                    = 19 ).
      IF sy-subrc <> 0.
        DATA(lv_subrc_download) = sy-subrc.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD get_user_print_defaults.
    DATA: ls_user_defaults TYPE usdefaults,
          lv_user_printer  TYPE char40.

    " 1. Fetch user defaults via standard API
    CALL FUNCTION 'SUSR_USER_DEFAULTS_GET'
      EXPORTING
        user_name     = sy-uname
      IMPORTING
        user_defaults = ls_user_defaults
      EXCEPTIONS
        OTHERS        = 1.
    IF sy-subrc <> 0.
      DATA(lv_subrc_user) = sy-subrc.
    ENDIF.

    " 2. Check SET/GET parameter override (/CELLAG/PAFR)
    GET PARAMETER ID '/CELLAG/PAFR' FIELD lv_user_printer.

    " 3. Printer: parameter takes precedence over user default
    ev_printer = COND #( WHEN lv_user_printer IS NOT INITIAL
                         THEN lv_user_printer
                         ELSE ls_user_defaults-spld ).

    " 4. Legacy override: Druckersteuerung durch ycl_printer
    ev_printer = ycl_printer=>select_printer(
                     iv_uname   = sy-uname
                     iv_medium  = ycl_printer=>co_paperprinter_dina4
                     iv_printer = ev_printer ).

    " 5. Hardcoded values from legacy print_sf subroutine
    ev_immed  = abap_true.
    ev_delete = abap_true.
  ENDMETHOD.



  METHOD register_custom_parameter.
    DATA: ls_param TYPE abap_func_parmbind.
    ls_param-name  = iv_name.
    ls_param-kind  = iv_kind.
    ls_param-value = ir_data.
    INSERT ls_param INTO TABLE mt_custom_form_params.
  ENDMETHOD.

ENDCLASS.
