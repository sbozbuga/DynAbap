*&---------------------------------------------------------------------*
*& Report /CTDI/SD_PRINT_DRIVER_STANDALONE
*&---------------------------------------------------------------------*
*& SELF-CONTAINED Print Driver — All classes are LOCAL to this program.
*&
*& Integrates with standard SAP print workbench (NACE / TNAPR) and
*& supports standalone execution via SE38 / SA38.
*&
*& Supports both Smart Forms and Adobe Forms via the internal OO
*& print driver framework defined below.
*&
*& No external SE24 global classes required — everything is defined
*& as local classes within this report for easy transport and setup.
*&---------------------------------------------------------------------*
REPORT /ctdi/sd_print_driver_standalone.

" NAST / TNAPR structures — populated by SAP output determination
TABLES: nast, tnapr.

*&---------------------------------------------------------------------*
*&  L O C A L   C L A S S   D E F I N I T I O N S
*&---------------------------------------------------------------------*

* -------------------------------------------------------------------- *
* 1. Exception Class
* -------------------------------------------------------------------- *
CLASS lcx_print_driver_error DEFINITION INHERITING FROM cx_static_check.
  PUBLIC SECTION.
    DATA repair_id TYPE aufnr READ-ONLY.
    DATA message   TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        !textid    LIKE textid OPTIONAL
        !previous  LIKE previous OPTIONAL
        !repair_id TYPE aufnr OPTIONAL
        !message   TYPE string OPTIONAL.
ENDCLASS.

* -------------------------------------------------------------------- *
* 2. Print Provider Interface
* -------------------------------------------------------------------- *
INTERFACE lif_print_driver.
  METHODS execute
    IMPORTING
      !iv_repair_id   TYPE aufnr
      !iv_form_name   TYPE fpname
      !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
    CHANGING
      !cs_repair      TYPE any
      !ct_errors      TYPE ANY TABLE
      !ct_comments    TYPE ANY TABLE
    RAISING
      lcx_print_driver_error.
ENDINTERFACE.

* -------------------------------------------------------------------- *
* 3. Logger Class
* -------------------------------------------------------------------- *
CLASS lcl_print_driver_log DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS log_info
      IMPORTING
        !iv_text       TYPE string
        !iv_object     TYPE balobj_d DEFAULT '/CTDI/PRINT'
        !iv_subobject  TYPE balsubobj DEFAULT 'DRIVER'.

    CLASS-METHODS log_warning
      IMPORTING
        !iv_text       TYPE string
        !iv_object     TYPE balobj_d DEFAULT '/CTDI/PRINT'
        !iv_subobject  TYPE balsubobj DEFAULT 'DRIVER'.

    CLASS-METHODS log_error
      IMPORTING
        !iv_text       TYPE string
        !iv_object     TYPE balobj_d DEFAULT '/CTDI/PRINT'
        !iv_subobject  TYPE balsubobj DEFAULT 'DRIVER'.

    CLASS-METHODS log_exception
      IMPORTING
        !ix_exception  TYPE REF TO cx_root
        !iv_object     TYPE balobj_d DEFAULT '/CTDI/PRINT'
        !iv_subobject  TYPE balsubobj DEFAULT 'DRIVER'.

  PRIVATE SECTION.
    CLASS-METHODS add_to_log
      IMPORTING
        !iv_text      TYPE string
        !iv_msgty     TYPE symsgty
        !iv_object    TYPE balobj_d
        !iv_subobject TYPE balsubobj.
ENDCLASS.

* -------------------------------------------------------------------- *
* 4. Base Print Class
* -------------------------------------------------------------------- *
CLASS lcl_print_driver_base DEFINITION.
  PUBLIC SECTION.
    INTERFACES lif_print_driver.

  PRIVATE SECTION.
    METHODS read_data
      IMPORTING
        !iv_repair_id   TYPE aufnr
      CHANGING
        !cs_repair      TYPE any
        !ct_errors      TYPE ANY TABLE
        !ct_comments    TYPE ANY TABLE
      RAISING
        lcx_print_driver_error.

    METHODS render_form
      IMPORTING
        !iv_repair_id   TYPE aufnr
        !iv_form_name   TYPE fpname
        !iv_save_as_pdf TYPE abap_bool
      CHANGING
        !cs_repair      TYPE any
        !ct_errors      TYPE ANY TABLE
        !ct_comments    TYPE ANY TABLE
      RAISING
        lcx_print_driver_error.

    METHODS detect_form_type
      IMPORTING
        !iv_form_name   TYPE fpname
      RETURNING
        VALUE(rv_type)  TYPE char1.

    METHODS execute_smartform
      IMPORTING
        !iv_repair_id   TYPE aufnr
        !iv_form_name   TYPE fpname
        !iv_save_as_pdf TYPE abap_bool
      CHANGING
        !cs_repair      TYPE any
        !ct_errors      TYPE ANY TABLE
        !ct_comments    TYPE ANY TABLE
      RAISING
        lcx_print_driver_error.

    METHODS execute_adobeform
      IMPORTING
        !iv_repair_id   TYPE aufnr
        !iv_form_name   TYPE fpname
        !iv_save_as_pdf TYPE abap_bool
      CHANGING
        !cs_repair      TYPE any
        !ct_errors      TYPE ANY TABLE
        !ct_comments    TYPE ANY TABLE
      RAISING
        lcx_print_driver_error.

    METHODS download_pdf
      IMPORTING
        !iv_repair_id TYPE aufnr
        !iv_pdf_data  TYPE xstring
      RAISING
        lcx_print_driver_error.

    METHODS get_user_print_defaults
      EXPORTING
        !ev_printer TYPE rspopname
        !ev_immed   TYPE c
        !ev_delete  TYPE c.

    METHODS fm_has_parameter
      IMPORTING
        !iv_funcname  TYPE rs38l_fnam
        !iv_paramname TYPE string
      RETURNING
        VALUE(rv_has) TYPE abap_bool.
ENDCLASS.

* -------------------------------------------------------------------- *
* 5. Print Engine (Orchestrator)
* -------------------------------------------------------------------- *
CLASS lcl_print_driver_engine DEFINITION.
  PUBLIC SECTION.
    METHODS execute
      IMPORTING
        !iv_repair_id   TYPE aufnr
        !iv_form_name   TYPE fpname OPTIONAL
        !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
      CHANGING
        !cs_repair      TYPE any
        !ct_errors      TYPE ANY TABLE
        !ct_comments    TYPE ANY TABLE
      RAISING
        lcx_print_driver_error.

  PRIVATE SECTION.
    METHODS get_config_from_db
      IMPORTING
        !iv_repair_id   TYPE aufnr
      EXPORTING
        !ev_form_name   TYPE fpname
      RAISING
        lcx_print_driver_error.
ENDCLASS.


* -------------------------------------------------------------------- *
* 6. NAST Protocol Handler
* -------------------------------------------------------------------- *
CLASS lcl_nast_handler DEFINITION.
  PUBLIC SECTION.
    "! Constructor: stores the NAST key for status operations.
    METHODS constructor
      IMPORTING
        !iv_nast_key TYPE nast-objky.

    "! Marks the NAST output as successfully processed (vstat = '2').
    "! Call this after the print engine completes without errors.
    METHODS mark_success
      RAISING
        lcx_print_driver_error.

    "! Resets the NAST output status to 'New' (vstat = '0').
    "! Call this after a transient error so the output is retried
    "! on the next NACE scheduling run instead of remaining stuck in error.
    METHODS reset_for_retry
      RAISING
        lcx_print_driver_error.

    "! Marks the NAST output as error (vstat = '4').
    "! Call this for unrecoverable errors where retry is not desired.
    METHODS mark_error
      RAISING
        lcx_print_driver_error.

  PRIVATE SECTION.
    DATA mv_nast_key TYPE nast-objky.

    "! Applies a new processing status to the NAST work area.
    METHODS set_status
      IMPORTING
        !iv_vstat TYPE nast-vstat
      RAISING
        lcx_print_driver_error.
ENDCLASS.


*&---------------------------------------------------------------------*
*&  L O C A L   C L A S S   I M P L E M E N T A T I O N S
*&---------------------------------------------------------------------*

* -------------------------------------------------------------------- *
CLASS lcx_print_driver_error IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    CALL METHOD super->constructor
      EXPORTING
        textid   = textid
        previous = previous.
    me->repair_id = repair_id.
    me->message   = message.
  ENDMETHOD.
ENDCLASS.

* -------------------------------------------------------------------- *
CLASS lcl_print_driver_log IMPLEMENTATION.

  METHOD log_info.
    add_to_log( iv_text      = iv_text
                iv_msgty     = 'I'
                iv_object    = iv_object
                iv_subobject = iv_subobject ).
  ENDMETHOD.

  METHOD log_warning.
    add_to_log( iv_text      = iv_text
                iv_msgty     = 'W'
                iv_object    = iv_object
                iv_subobject = iv_subobject ).
  ENDMETHOD.

  METHOD log_error.
    add_to_log( iv_text      = iv_text
                iv_msgty     = 'E'
                iv_object    = iv_object
                iv_subobject = iv_subobject ).
  ENDMETHOD.

  METHOD log_exception.
    DATA(lv_text) = ix_exception->get_text( ).
    add_to_log( iv_text      = lv_text
                iv_msgty     = 'E'
                iv_object    = iv_object
                iv_subobject = iv_subobject ).
  ENDMETHOD.

  METHOD add_to_log.
    DATA: ls_log      TYPE bal_s_log,
          lv_handle   TYPE balloghndl,
          ls_msg      TYPE bal_s_msg,
          lv_len      TYPE i,
          lt_handles  TYPE bal_t_logh.

    ls_log-object    = iv_object.
    ls_log-subobject = iv_subobject.
    ls_log-aluser    = sy-uname.
    ls_log-alprog    = sy-repid.

    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log      = ls_log
      IMPORTING
        e_log_handle = lv_handle
      EXCEPTIONS
        OTHERS       = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ls_msg-msgty = iv_msgty.
    ls_msg-msgid = '00'.
    ls_msg-msgno = '398'.

    lv_len = strlen( iv_text ).
    IF lv_len > 0.
      ls_msg-msgv1 = substring( val = iv_text off = 0 len = nmin( val1 = 50 val2 = lv_len ) ).
    ENDIF.
    IF lv_len > 50.
      ls_msg-msgv2 = substring( val = iv_text off = 50 len = nmin( val1 = 50 val2 = lv_len - 50 ) ).
    ENDIF.
    IF lv_len > 100.
      ls_msg-msgv3 = substring( val = iv_text off = 100 len = nmin( val1 = 50 val2 = lv_len - 100 ) ).
    ENDIF.
    IF lv_len > 150.
      ls_msg-msgv4 = substring( val = iv_text off = 150 len = nmin( val1 = 50 val2 = lv_len - 150 ) ).
    ENDIF.

    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        i_log_handle = lv_handle
        i_s_msg      = ls_msg
      EXCEPTIONS
        OTHERS       = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    APPEND lv_handle TO lt_handles.
    CALL FUNCTION 'BAL_DB_SAVE'
      EXPORTING
        i_t_log_handle = lt_handles
      EXCEPTIONS
        OTHERS         = 1.
  ENDMETHOD.

ENDCLASS.

* -------------------------------------------------------------------- *
CLASS lcl_print_driver_base IMPLEMENTATION.

  METHOD lif_print_driver~execute.
    lcl_print_driver_log=>log_info(
      |Print driver started | &&
      |Repair: { iv_repair_id }, Form: { iv_form_name }, Save PDF: { iv_save_as_pdf }| ).

    read_data(
      EXPORTING iv_repair_id = iv_repair_id
      CHANGING  cs_repair    = cs_repair
                ct_errors    = ct_errors
                ct_comments  = ct_comments ).

    render_form(
      EXPORTING iv_repair_id   = iv_repair_id
                iv_form_name   = iv_form_name
                iv_save_as_pdf = iv_save_as_pdf
      CHANGING  cs_repair      = cs_repair
                ct_errors      = ct_errors
                ct_comments    = ct_comments ).

    lcl_print_driver_log=>log_info(
      |Print driver completed successfully for Repair { iv_repair_id }| ).
  ENDMETHOD.

  METHOD read_data.
    lcl_print_driver_log=>log_info(
      |Default read_data invoked for Repair { iv_repair_id } — no data loaded| ).
  ENDMETHOD.

  METHOD render_form.
    DATA(lv_form_type) = detect_form_type( iv_form_name ).

    IF lv_form_type = 'S'.
      lcl_print_driver_log=>log_info(
        |Form { iv_form_name } detected as Smart Form| ).
      execute_smartform(
        EXPORTING iv_repair_id   = iv_repair_id
                  iv_form_name   = iv_form_name
                  iv_save_as_pdf = iv_save_as_pdf
        CHANGING  cs_repair      = cs_repair
                  ct_errors      = ct_errors
                  ct_comments    = ct_comments ).
    ELSE.
      lcl_print_driver_log=>log_info(
        |Form { iv_form_name } detected as Adobe Form| ).
      execute_adobeform(
        EXPORTING iv_repair_id   = iv_repair_id
                  iv_form_name   = iv_form_name
                  iv_save_as_pdf = iv_save_as_pdf
        CHANGING  cs_repair      = cs_repair
                  ct_errors      = ct_errors
                  ct_comments    = ct_comments ).
    ENDIF.
  ENDMETHOD.

  METHOD detect_form_type.
    SELECT SINGLE formname FROM stxfadm
      INTO @DATA(lv_ssf_name)
      WHERE formname = @iv_form_name.
    IF sy-subrc = 0.
      rv_type = 'S'.
    ELSE.
      rv_type = 'A'.
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
      lcl_print_driver_log=>log_error( lv_err ).
      RAISE EXCEPTION TYPE lcx_print_driver_error
        EXPORTING repair_id = iv_repair_id
                  message   = lv_err.
    ENDIF.

    get_user_print_defaults(
      IMPORTING ev_printer = lv_printer
                ev_immed   = lv_immed
                ev_delete  = lv_delete ).

    ls_output_options-tddest   = lv_printer.
    ls_output_options-tdcopies = 1.
    ls_output_options-tdimmed  = lv_immed.
    ls_output_options-tddelete = lv_delete.
    ls_output_options-tdnewid  = abap_true.

    DATA: lv_devtype TYPE rspoptype.
    CALL FUNCTION 'SSF_GET_DEVICE_TYPE'
      EXPORTING
        i_language    = sy-langu
        i_application = 'SAPDEFAULT'
      IMPORTING
        e_devtype     = lv_devtype.
    ls_output_options-tdprinter = lv_devtype.

    IF iv_save_as_pdf = abap_true.
      ls_control_params-getotf    = abap_true.
      ls_control_params-no_dialog = abap_true.
    ENDIF.

    IF fm_has_parameter( iv_funcname  = lv_fm_name
                         iv_paramname = 'IT_REPAIR_ERROR' ) = abap_true.
      CALL FUNCTION lv_fm_name
        EXPORTING
          control_parameters = ls_control_params
          output_options     = ls_output_options
          is_repair          = cs_repair
        IMPORTING
          job_output_info    = ls_job_output
        TABLES
          it_repair_error    = ct_errors
          it_comment_lines   = ct_comments
        EXCEPTIONS
          formatting_error   = 1
          internal_error     = 2
          send_error         = 3
          user_canceled      = 4
          OTHERS             = 5.
    ELSE.
      CALL FUNCTION lv_fm_name
        EXPORTING
          control_parameters = ls_control_params
          output_options     = ls_output_options
          is_repair          = cs_repair
        IMPORTING
          job_output_info    = ls_job_output
        EXCEPTIONS
          formatting_error   = 1
          internal_error     = 2
          send_error         = 3
          user_canceled      = 4
          OTHERS             = 5.
    ENDIF.

    IF sy-subrc <> 0.
      lv_err = |Smart Form { iv_form_name } execution failed (subrc={ sy-subrc })|.
      lcl_print_driver_log=>log_error( lv_err ).
      RAISE EXCEPTION TYPE lcx_print_driver_error
        EXPORTING repair_id = iv_repair_id
                  message   = lv_err.
    ENDIF.

    lcl_print_driver_log=>log_info(
      |Smart Form { iv_form_name } executed successfully| ).

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
          err_bad_keydate       = 2
          err_empty_otf         = 3
          OTHERS                = 4.
      IF sy-subrc <> 0.
        lv_err = |CONVERT_OTF failed for { iv_form_name } (subrc={ sy-subrc })|.
        lcl_print_driver_log=>log_error( lv_err ).
        RAISE EXCEPTION TYPE lcx_print_driver_error
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

    get_user_print_defaults(
      IMPORTING ev_printer = lv_printer
                ev_immed   = lv_immed
                ev_delete  = lv_delete ).

    ls_outputparams-connection = 'ADS'.
    ls_outputparams-nodialog   = abap_true.
    ls_outputparams-preview    = abap_true.
    ls_outputparams-dest       = lv_printer.
    ls_outputparams-reqimm     = lv_immed.
    ls_outputparams-reqdel     = lv_delete.
    IF iv_save_as_pdf = abap_true.
      ls_outputparams-getpdf   = abap_true.
    ENDIF.

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
      lcl_print_driver_log=>log_error( lv_err ).
      RAISE EXCEPTION TYPE lcx_print_driver_error
        EXPORTING repair_id = iv_repair_id
                  message   = lv_err.
    ENDIF.

    CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
      EXPORTING
        i_name     = iv_form_name
      IMPORTING
        e_funcname = lv_fm_name
      EXCEPTIONS
        OTHERS     = 1.
    IF sy-subrc <> 0.
      CALL FUNCTION 'FP_JOB_CLOSE'.
      lv_err = |Adobe Form FM resolution failed for { iv_form_name }|.
      lcl_print_driver_log=>log_error( lv_err ).
      RAISE EXCEPTION TYPE lcx_print_driver_error
        EXPORTING repair_id = iv_repair_id
                  message   = lv_err.
    ENDIF.

    ls_docparams-langu   = sy-langu.
    ls_docparams-country = 'US'.

    IF fm_has_parameter( iv_funcname  = lv_fm_name
                         iv_paramname = 'IT_REPAIR_ERROR' ) = abap_true.
      CALL FUNCTION lv_fm_name
        EXPORTING
          /1bcdwb/docparams  = ls_docparams
          is_repair          = cs_repair
          it_repair_error    = ct_errors
          it_comment_lines   = ct_comments
        IMPORTING
          /1bcdwb/formoutput = ls_formoutput
        EXCEPTIONS
          usage_error        = 1
          system_error       = 2
          internal_error     = 3
          OTHERS             = 4.
    ELSE.
      CALL FUNCTION lv_fm_name
        EXPORTING
          /1bcdwb/docparams  = ls_docparams
          is_repair          = cs_repair
        IMPORTING
          /1bcdwb/formoutput = ls_formoutput
        EXCEPTIONS
          usage_error        = 1
          system_error       = 2
          internal_error     = 3
          OTHERS             = 4.
    ENDIF.
    lv_subrc = sy-subrc.

    CALL FUNCTION 'FP_JOB_CLOSE'
      IMPORTING
        e_joboutput    = ls_joboutput
      EXCEPTIONS
        usage_error    = 1
        system_error   = 2
        internal_error = 3
        OTHERS         = 4.

    IF lv_subrc <> 0.
      lv_err = |Adobe Form { iv_form_name } execution failed (subrc={ lv_subrc })|.
      lcl_print_driver_log=>log_error( lv_err ).
      RAISE EXCEPTION TYPE lcx_print_driver_error
        EXPORTING repair_id = iv_repair_id
                  message   = lv_err.
    ENDIF.

    lcl_print_driver_log=>log_info(
      |Adobe Form { iv_form_name } executed successfully| ).

    IF iv_save_as_pdf = abap_true AND ls_formoutput-pdf IS NOT INITIAL.
      download_pdf( iv_repair_id = iv_repair_id
                    iv_pdf_data  = ls_formoutput-pdf ).
    ENDIF.
  ENDMETHOD.

  METHOD download_pdf.
    DATA: lt_filetab  TYPE filetable,
          lv_rc       TYPE i,
          lv_action   TYPE i,
          lv_path     TYPE string,
          lv_filename TYPE string,
          lt_data     TYPE solix_tab.

    IF iv_pdf_data IS INITIAL.
      RETURN.
    ENDIF.

    IF sy-batch IS NOT INITIAL.
      lcl_print_driver_log=>log_warning(
        |PDF download skipped for Repair { iv_repair_id } in batch mode| ).
      RETURN.
    ENDIF.

    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
      EXPORTING
        buffer     = iv_pdf_data
      TABLES
        binary_tab = lt_data.

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
    ENDIF.
  ENDMETHOD.

  METHOD get_user_print_defaults.
    DATA: ls_user_defaults TYPE usdefaults,
          lv_user_printer  TYPE paramval.

    CALL FUNCTION 'SUSR_USER_DEFAULTS_GET'
      EXPORTING
        user_name     = sy-uname
      IMPORTING
        user_defaults = ls_user_defaults
      EXCEPTIONS
        OTHERS        = 1.

    GET PARAMETER ID '/CELLAG/PAFR' FIELD lv_user_printer.

    ev_printer = COND #( WHEN lv_user_printer IS NOT INITIAL
                         THEN lv_user_printer
                         ELSE ls_user_defaults-spld ).

    ev_immed = COND #( WHEN ls_user_defaults-splg IS NOT INITIAL
                       THEN ls_user_defaults-splg
                       ELSE abap_true ).

    ev_delete = COND #( WHEN ls_user_defaults-spda IS NOT INITIAL
                        THEN ls_user_defaults-spda
                        ELSE abap_true ).
  ENDMETHOD.

  METHOD fm_has_parameter.
    SELECT SINGLE paramname FROM fupararef
      INTO @DATA(lv_dummy)
      WHERE funcname  = @iv_funcname
        AND paramname = @iv_paramname.
    rv_has = COND #( WHEN sy-subrc = 0 THEN abap_true ELSE abap_false ).
  ENDMETHOD.

ENDCLASS.

* -------------------------------------------------------------------- *
CLASS lcl_print_driver_engine IMPLEMENTATION.

  METHOD execute.
    DATA: lv_form_name TYPE fpname.

    lcl_print_driver_log=>log_info(
      |Print driver engine invoked for Repair { iv_repair_id }| ).

    IF iv_form_name IS NOT INITIAL.
      lv_form_name = iv_form_name.
      lcl_print_driver_log=>log_info(
        |Using explicit form name: { lv_form_name }| ).
    ELSE.
      get_config_from_db(
        EXPORTING iv_repair_id  = iv_repair_id
        IMPORTING ev_form_name  = lv_form_name ).
    ENDIF.

    IF lv_form_name IS INITIAL.
      RAISE EXCEPTION TYPE lcx_print_driver_error
        EXPORTING
          repair_id = iv_repair_id
          message   = |No form name configured for Repair { iv_repair_id }|.
    ENDIF.

    DATA(lr_provider) = NEW lcl_print_driver_base( ).

    lr_provider->lif_print_driver~execute(
      EXPORTING iv_repair_id   = iv_repair_id
                iv_form_name   = lv_form_name
                iv_save_as_pdf = iv_save_as_pdf
      CHANGING  cs_repair      = cs_repair
                ct_errors      = ct_errors
                ct_comments    = ct_comments ).

    lcl_print_driver_log=>log_info(
      |Print driver engine completed successfully for Repair { iv_repair_id }| ).
  ENDMETHOD.

  METHOD get_config_from_db.
    SELECT SINGLE form_name
      FROM /ctdi/rep_forms
      INTO @DATA(lv_db_form)
      WHERE vbeln = @iv_repair_id.

    IF sy-subrc <> 0.
      DATA(lv_raw) = |{ iv_repair_id ALPHA = OUT }|.
      SELECT SINGLE form_name
        FROM /ctdi/rep_forms
        INTO @lv_db_form
        WHERE vbeln = @lv_raw.
    ENDIF.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcx_print_driver_error
        EXPORTING
          repair_id = iv_repair_id
          message   = |No print configuration found for Repair { iv_repair_id }|.
    ENDIF.

    ev_form_name = lv_db_form.
    lcl_print_driver_log=>log_info(
      |Config resolved — Form: { ev_form_name }| ).
  ENDMETHOD.

ENDCLASS.

* -------------------------------------------------------------------- *
CLASS lcl_nast_handler IMPLEMENTATION.

  METHOD constructor.
    mv_nast_key = iv_nast_key.
  ENDMETHOD.

  METHOD mark_success.
    set_status( '2' ).   " 2 = Successfully processed
    lcl_print_driver_log=>log_info(
      |NAST protocol updated: Output { mv_nast_key } marked as successful| ).
  ENDMETHOD.

  METHOD reset_for_retry.
    set_status( '0' ).   " 0 = New (will be retried)
    lcl_print_driver_log=>log_info(
      |NAST protocol updated: Output { mv_nast_key } reset to New for retry| ).
  ENDMETHOD.

  METHOD mark_error.
    set_status( '4' ).   " 4 = Error (terminated)
    lcl_print_driver_log=>log_info(
      |NAST protocol updated: Output { mv_nast_key } marked as error| ).
  ENDMETHOD.

  METHOD set_status.
    " Guard: NAST work area must match the key we were constructed with
    IF nast-objky IS INITIAL.
      RAISE EXCEPTION TYPE lcx_print_driver_error
        EXPORTING
          repair_id = CONV #( mv_nast_key )
          message   = |NAST work area is empty — cannot update protocol|.
    ENDIF.

    IF nast-objky <> mv_nast_key.
      RAISE EXCEPTION TYPE lcx_print_driver_error
        EXPORTING
          repair_id = CONV #( mv_nast_key )
          message   = |NAST key mismatch: expected { mv_nast_key }, got { nast-objky }|.
    ENDIF.

    " Set the new processing status
    nast-vstat   = iv_vstat.
    nast-veraend = abap_true.   " Mark as changed so the framework persists it

    " If resetting to New, also clear the error counter and message
    IF iv_vstat = '0'.
      nast-anzah_versuche = 0.   " Reset attempt counter
    ENDIF.
  ENDMETHOD.

ENDCLASS.


*&---------------------------------------------------------------------*
*&  S E L E C T I O N   S C R E E N
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_aufnr TYPE aufk-aufnr OBLIGATORY.   " Repair / Order ID
PARAMETERS: p_form  TYPE fpname.                    " Form name (optional)
PARAMETERS: p_pdf   AS CHECKBOX DEFAULT ' '.        " Save as PDF
PARAMETERS: p_sf    AS CHECKBOX NO-DISPLAY.         " Legacy compat
SELECTION-SCREEN END OF BLOCK b1.


*&---------------------------------------------------------------------*
*&  S T A R T - O F - S E L E C T I O N
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM run_standalone.


*&---------------------------------------------------------------------*
*&  F O R M   E N T R Y   —   N A C E   C A L L B A C K
*&---------------------------------------------------------------------*
FORM entry USING ent_retco TYPE sysubrc
                 ent_screen TYPE c.

  DATA: lv_repair_id TYPE aufnr,
        ls_repair    TYPE /ctdi/repair,
        lt_errors    TYPE TABLE OF /ctdi/repair_error,
        lt_comments  TYPE TABLE OF tline,
        lo_nast      TYPE REF TO lcl_nast_handler.

  ent_retco = 0.

  IF nast-objky IS INITIAL.
    ent_retco = 4.
    RETURN.
  ENDIF.

  lv_repair_id = |{ nast-objky ALPHA = IN }|.

  lcl_print_driver_log=>log_info(
    |NAST entry triggered for Repair { lv_repair_id }| ).

  " Instantiate NAST handler for this output record
  lo_nast = NEW lcl_nast_handler( nast-objky ).

  TRY.
      DATA(lr_engine) = NEW lcl_print_driver_engine( ).
      lr_engine->execute(
        EXPORTING
          iv_repair_id   = lv_repair_id
          iv_save_as_pdf = abap_false
        CHANGING
          cs_repair      = ls_repair
          ct_errors      = lt_errors
          ct_comments    = lt_comments ).

      " Mark NAST as successfully processed
      lo_nast->mark_success( ).

    CATCH lcx_print_driver_error INTO DATA(lx_driver_err).
      lcl_print_driver_log=>log_exception( lx_driver_err ).

      " Reset NAST to 'New' so the output is retried on the next run
      TRY.
          lo_nast->reset_for_retry( ).
        CATCH lcx_print_driver_error.
          " Muted — the original error is what matters
      ENDTRY.
      ent_retco = 4.

    CATCH cx_root INTO DATA(lx_root).
      lcl_print_driver_log=>log_exception( lx_root ).
      ent_retco = 4.
  ENDTRY.

ENDFORM.


*&---------------------------------------------------------------------*
*&  F O R M   R U N _ S T A N D A L O N E
*&---------------------------------------------------------------------*
FORM run_standalone.
  DATA: ls_repair   TYPE /ctdi/repair,
        lt_errors   TYPE TABLE OF /ctdi/repair_error,
        lt_comments TYPE TABLE OF tline.

  TRY.
      DATA(lr_engine) = NEW lcl_print_driver_engine( ).
      lr_engine->execute(
        EXPORTING
          iv_repair_id   = p_aufnr
          iv_form_name   = p_form
          iv_save_as_pdf = p_pdf
        CHANGING
          cs_repair      = ls_repair
          ct_errors      = lt_errors
          ct_comments    = lt_comments ).

      MESSAGE |Print completed successfully for { p_aufnr }| TYPE 'S'.

    CATCH lcx_print_driver_error INTO DATA(lx_driver_err).
      DATA(lv_msg) = |{ 'Print failed: &1'(003) }|.
      REPLACE '&1' IN lv_msg WITH lx_driver_err->message.
      lcl_print_driver_log=>log_exception( lx_driver_err ).
      MESSAGE lv_msg TYPE 'E'.

    CATCH cx_root INTO DATA(lx_root).
      lv_msg = |{ 'Unexpected error: &1'(004) }|.
      REPLACE '&1' IN lv_msg WITH lx_root->get_text( ).
      lcl_print_driver_log=>log_exception( lx_root ).
      MESSAGE lv_msg TYPE 'E'.
  ENDTRY.
ENDFORM.
