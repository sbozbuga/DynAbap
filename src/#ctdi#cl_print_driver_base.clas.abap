CLASS /ctdi/cl_print_driver_base DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES /ctdi/if_print_driver.

    ALIASES execute
      FOR /ctdi/if_print_driver~execute.

  PROTECTED SECTION.
    DATA: mr_repair   TYPE REF TO data,
          mr_project  TYPE REF TO data,
          mr_errors   TYPE REF TO data,
          mr_comments TYPE REF TO data.

    "! Reads repair data from the database into memory.
    "! Subclasses should redefine this method to supply custom data.
    METHODS read_data
      IMPORTING
        !iv_repair_id   TYPE aufnr
        !io_data        TYPE REF TO object OPTIONAL
      RAISING
        /ctdi/cx_print_driver_error.

    "! Renders the form (SmartForm or Adobe) and optionally saves as PDF.
    METHODS render_form
      IMPORTING
        !iv_repair_id   TYPE aufnr
        !iv_form_name   TYPE fpname
        !iv_save_as_pdf TYPE abap_bool

      RAISING
        /ctdi/cx_print_driver_error.

    "! Detects form technology: 'S' = Smart Form, 'A' = Adobe Form.
    METHODS detect_form_type
      IMPORTING
        !iv_form_name   TYPE fpname
      RETURNING
        VALUE(rv_type)  TYPE char1.

    "! Executes a Smart Form and optionally converts OTF output to PDF.
    METHODS execute_smartform
      IMPORTING
        !iv_repair_id   TYPE aufnr
        !iv_form_name   TYPE fpname
        !iv_save_as_pdf TYPE abap_bool

      RAISING
        /ctdi/cx_print_driver_error.

    "! Executes an Adobe Form and optionally retrieves the PDF stream.
    METHODS execute_adobeform
      IMPORTING
        !iv_repair_id   TYPE aufnr
        !iv_form_name   TYPE fpname
        !iv_save_as_pdf TYPE abap_bool

      RAISING
        /ctdi/cx_print_driver_error.

    "! Downloads an XSTRING as a PDF file via the presentation layer.
    METHODS download_pdf
      IMPORTING
        !iv_repair_id TYPE aufnr
        !iv_pdf_data  TYPE xstring
      RAISING
        /ctdi/cx_print_driver_error.

    "! Retrieves user print defaults via standard SAP APIs.
    METHODS get_user_print_defaults
      EXPORTING
        !ev_printer TYPE rspopname
        !ev_immed   TYPE c
        !ev_delete  TYPE c.

    "! Checks if a generated function module accepts a given parameter.
    METHODS fm_has_parameter
      IMPORTING
        !iv_funcname  TYPE rs38l_fnam
        !iv_paramname TYPE string
      RETURNING
        VALUE(rv_has) TYPE abap_bool.

  PRIVATE SECTION.
ENDCLASS.



CLASS /ctdi/cl_print_driver_base IMPLEMENTATION.

  METHOD /ctdi/if_print_driver~execute.
    /ctdi/cl_print_driver_log=>log_info(
      |Print driver started | &&
      |Repair: { iv_repair_id }, Form: { iv_form_name }, Save PDF: { iv_save_as_pdf }| ).

    IF is_project IS SUPPLIED AND is_project IS NOT INITIAL.
      CREATE DATA mr_project TYPE /ctdi/rep_projec.
      ASSIGN mr_project->* TO FIELD-SYMBOL(<ls_project>).
      <ls_project> = is_project.
    ENDIF.

    " Step 1: Read business data
    read_data(
      EXPORTING iv_repair_id = iv_repair_id
                io_data      = io_data ).

    " Step 2: Render the form (SmartForm or Adobe)
    render_form(
      EXPORTING iv_repair_id   = iv_repair_id
                iv_form_name   = iv_form_name
                iv_save_as_pdf = iv_save_as_pdf ).

    /ctdi/cl_print_driver_log=>log_info(
      |Print driver completed successfully for Repair { iv_repair_id }| ).
  ENDMETHOD.


  METHOD read_data.
    " Default: no-op. Subclasses override this to populate cs_repair
    " from database tables based on iv_repair_id.
    /ctdi/cl_print_driver_log=>log_info(
      |Default read_data invoked for Repair { iv_repair_id } — no data loaded| ).
  ENDMETHOD.


  METHOD render_form.
    " Ensure passed repair header is valid
    IF mr_repair IS INITIAL.
      /ctdi/cl_print_driver_log=>log_warning(
        |Repair data reference is empty - | &&
        |Print execution bypassed for Repair ID { iv_repair_id }| ).
      RETURN.
    ENDIF.

    DATA(lv_form_type) = detect_form_type( iv_form_name ).

    IF lv_form_type = 'S'.
      /ctdi/cl_print_driver_log=>log_info(
        |Form { iv_form_name } detected as Smart Form| ).
      execute_smartform(
        EXPORTING iv_repair_id   = iv_repair_id
                  iv_form_name   = iv_form_name
                  iv_save_as_pdf = iv_save_as_pdf ).
    ELSE.
      /ctdi/cl_print_driver_log=>log_info(
        |Form { iv_form_name } detected as Adobe Form| ).
      execute_adobeform(
        EXPORTING iv_repair_id   = iv_repair_id
                  iv_form_name   = iv_form_name
                  iv_save_as_pdf = iv_save_as_pdf ).
    ENDIF.
  ENDMETHOD.


  METHOD detect_form_type.
    SELECT SINGLE formname FROM stxfadm
      INTO @DATA(lv_ssf_name)
      WHERE formname = @iv_form_name.
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
        formname           = iv_form_name
      IMPORTING
        fm_name            = lv_fm_name
      EXCEPTIONS
        no_form            = 1
        no_function_module = 2
        OTHERS             = 3.
    IF sy-subrc <> 0.
      lv_err = |Smart Form FM resolution failed for { iv_form_name } (subrc={ sy-subrc })|.
      /ctdi/cl_print_driver_log=>log_error( lv_err ).
      RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
        EXPORTING repair_id = iv_repair_id
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
        i_application = 'SAPDEFAULT'
      IMPORTING
        e_devtype     = lv_devtype
      EXCEPTIONS
        OTHERS        = 1.
    IF sy-subrc <> 0.
      lv_devtype = 'SAPDEFAULT'.
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

    IF fm_has_parameter( iv_funcname = lv_fm_name iv_paramname = 'REPAIR' ) = abap_true.
      ls_ptab-name = 'REPAIR'.
      ls_ptab-kind = abap_func_exporting.
      ls_ptab-value = mr_repair.
      INSERT ls_ptab INTO TABLE lt_ptab.
    ENDIF.

    IF fm_has_parameter( iv_funcname = lv_fm_name iv_paramname = 'PROJECT' ) = abap_true.
      ls_ptab-name = 'PROJECT'.
      ls_ptab-kind = abap_func_exporting.
      ls_ptab-value = mr_project.
      INSERT ls_ptab INTO TABLE lt_ptab.
    ENDIF.

    IF fm_has_parameter( iv_funcname = lv_fm_name iv_paramname = 'REPAIR_ERRORS' ) = abap_true.
      ls_ptab-name = 'REPAIR_ERRORS'.
      ls_ptab-kind = abap_func_tables.
      ls_ptab-value = mr_errors.
      INSERT ls_ptab INTO TABLE lt_ptab.
    ENDIF.

    IF fm_has_parameter( iv_funcname = lv_fm_name iv_paramname = 'COMMENT_LINES' ) = abap_true.
      ls_ptab-name = 'COMMENT_LINES'.
      ls_ptab-kind = abap_func_tables.
      ls_ptab-value = mr_comments.
      INSERT ls_ptab INTO TABLE lt_ptab.
    ENDIF.



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
        lv_err = |Dynamic call error for { iv_form_name }: { lx_dyn_call->get_text( ) }|.
        /ctdi/cl_print_driver_log=>log_error( lv_err ).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING repair_id = iv_repair_id
                    message   = lv_err.
    ENDTRY.

    IF lv_subrc_fm <> 0.
      lv_err = |Smart Form { iv_form_name } execution failed (subrc={ lv_subrc_fm })|.
      /ctdi/cl_print_driver_log=>log_error( lv_err ).
      RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
        EXPORTING repair_id = iv_repair_id
                  message   = lv_err.
    ENDIF.

    /ctdi/cl_print_driver_log=>log_info(
      |Smart Form { iv_form_name } executed successfully| ).

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
        lv_err = |CONVERT_OTF failed for { iv_form_name } (subrc={ sy-subrc })|.
        /ctdi/cl_print_driver_log=>log_error( lv_err ).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING repair_id = iv_repair_id
                    message   = lv_err.
      ENDIF.

      download_pdf( iv_repair_id = iv_repair_id
                    iv_pdf_data  = lv_pdf_xstring ).
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
        EXPORTING repair_id = iv_repair_id
                  message   = lv_err.
    ENDIF.

    " Resolve generated function module name
    TRY.
        CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
          EXPORTING
            i_name     = iv_form_name
          IMPORTING
            e_funcname = lv_fm_name.
      CATCH cx_fp_api INTO DATA(lx_fp).
        CALL FUNCTION 'FP_JOB_CLOSE'
          EXCEPTIONS
            OTHERS = 1.
        IF sy-subrc <> 0.
          DATA(lv_subrc_close_err) = sy-subrc.
        ENDIF.
        lv_err = |Adobe Form FM resolution failed for { iv_form_name }: { lx_fp->get_text( ) }|.
        /ctdi/cl_print_driver_log=>log_error( lv_err ).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING repair_id = iv_repair_id
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

    IF fm_has_parameter( iv_funcname = lv_fm_name iv_paramname = 'REPAIR' ) = abap_true.
      ls_ptab-name = 'REPAIR'.
      ls_ptab-kind = abap_func_exporting.
      ls_ptab-value = mr_repair.
      INSERT ls_ptab INTO TABLE lt_ptab.
    ENDIF.

    IF fm_has_parameter( iv_funcname = lv_fm_name iv_paramname = 'PROJECT' ) = abap_true.
      ls_ptab-name = 'PROJECT'.
      ls_ptab-kind = abap_func_exporting.
      ls_ptab-value = mr_project.
      INSERT ls_ptab INTO TABLE lt_ptab.
    ENDIF.

    IF fm_has_parameter( iv_funcname = lv_fm_name iv_paramname = 'REPAIR_ERRORS' ) = abap_true.
      ls_ptab-name = 'REPAIR_ERRORS'.
      ls_ptab-kind = abap_func_exporting.
      ls_ptab-value = mr_errors.
      INSERT ls_ptab INTO TABLE lt_ptab.
    ENDIF.

    IF fm_has_parameter( iv_funcname = lv_fm_name iv_paramname = 'COMMENT_LINES' ) = abap_true.
      ls_ptab-name = 'COMMENT_LINES'.
      ls_ptab-kind = abap_func_exporting.
      ls_ptab-value = mr_comments.
      INSERT ls_ptab INTO TABLE lt_ptab.
    ENDIF.

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
        lv_err = |Dynamic call error for { iv_form_name }: { lx_dyn_call->get_text( ) }|.
        /ctdi/cl_print_driver_log=>log_error( lv_err ).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING repair_id = iv_repair_id
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
      lv_err = |Adobe Form { iv_form_name } execution failed (subrc={ lv_subrc })|.
      /ctdi/cl_print_driver_log=>log_error( lv_err ).
      RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
        EXPORTING repair_id = iv_repair_id
                  message   = lv_err.
    ENDIF.

    /ctdi/cl_print_driver_log=>log_info(
      |Adobe Form { iv_form_name } executed successfully| ).

    " Download PDF if requested
    IF iv_save_as_pdf = abap_true AND ls_formoutput-pdf IS NOT INITIAL.
      download_pdf( iv_repair_id = iv_repair_id
                    iv_pdf_data  = ls_formoutput-pdf ).
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
        |PDF download skipped for Repair { iv_repair_id } in batch mode| ).
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
        default_file_name    = |Repair_{ iv_repair_id }.pdf|
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

    " 2. Check SET/GET parameter override
    GET PARAMETER ID '/CELLAG/PAFR' FIELD lv_user_printer.

    " 3. Printer: parameter takes precedence over user default
    ev_printer = COND #( WHEN lv_user_printer IS NOT INITIAL
                         THEN lv_user_printer
                         ELSE ls_user_defaults-spld ).

    " 4. Print-immediately flag
    ev_immed = COND #( WHEN ls_user_defaults-splg IS NOT INITIAL
                       THEN ls_user_defaults-splg
                       ELSE abap_true ).

    " 5. Delete-after-print flag
    ev_delete = COND #( WHEN ls_user_defaults-spda IS NOT INITIAL
                        THEN ls_user_defaults-spda
                        ELSE abap_true ).
  ENDMETHOD.


  METHOD fm_has_parameter.
    SELECT SINGLE parameter FROM fupararef
      INTO @DATA(lv_dummy)
      WHERE funcname  = @iv_funcname
        AND parameter = @iv_paramname.
    rv_has = COND #( WHEN sy-subrc = 0 THEN abap_true ELSE abap_false ).
  ENDMETHOD.

ENDCLASS.
