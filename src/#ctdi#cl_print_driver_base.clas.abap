CLASS /ctdi/cl_print_driver_base DEFINITION
  PUBLIC ABSTRACT
  CREATE PROTECTED.

  PUBLIC SECTION.
    CONSTANTS gc_operation_wfer   TYPE vornr     VALUE '9010' ##NO_TEXT.
    CONSTANTS gc_country_default  TYPE land1     VALUE 'DE' ##NO_TEXT.
    CONSTANTS gc_devtype_fallback TYPE rspoptype VALUE 'YPDF' ##NO_TEXT.
    CONSTANTS gc_qmart_repair     TYPE qmart     VALUE 'Z2' ##NO_TEXT.

    "! Static factory to determine and instantiate the correct driver
    "!
    "! @parameter iv_repair_id |
    "! @parameter iv_sernr |
    "! @parameter ro_driver |
    "! @raising /ctdi/cx_print_driver_error |
    "! @raising /ctdi/cx_no_config_found |
    CLASS-METHODS factory
      IMPORTING iv_repair_id     TYPE aufnr
                iv_sernr         TYPE equi-sernr OPTIONAL
      RETURNING VALUE(ro_driver) TYPE REF TO /ctdi/cl_print_driver_base
      RAISING   /ctdi/cx_print_driver_error
                /ctdi/cx_no_config_found.

    "! Executes the full print pipeline (read data + render form).
    "!
    "! @parameter iv_save_as_pdf |
    "! @parameter io_data |
    "! @raising /ctdi/cx_print_driver_error |
    METHODS execute
      IMPORTING iv_save_as_pdf TYPE abap_bool     DEFAULT abap_false
                io_data        TYPE REF TO object OPTIONAL
      RAISING   /ctdi/cx_print_driver_error.

  PROTECTED SECTION.
    DATA mv_repair_order       TYPE aufnr.
    DATA mv_sernr              TYPE equi-sernr.
    DATA mv_qmnum              TYPE qmnum.
    DATA mv_fenum              TYPE fenum.
    DATA mv_form_name          TYPE fpname.
    DATA ms_repair             TYPE /ctdi/repair.
    DATA ms_project            TYPE /ctdi/rep_projec.
    DATA mt_errors             TYPE /ctdi/repair_error_tt.
    DATA mt_comments           TYPE STANDARD TABLE OF tline.
    DATA mt_custom_form_params TYPE abap_func_parmbind_tab.

    "! Registers a custom parameter to be passed dynamically to the form
    "!
    "! @parameter iv_name |
    "! @parameter ir_data |
    "! @parameter iv_kind |
    METHODS register_custom_parameter
      IMPORTING iv_name TYPE string
                ir_data TYPE REF TO data
                iv_kind TYPE abap_func_parmbind-kind DEFAULT abap_func_exporting.

    "! Reads repair data from the database into memory.
    "! Subclasses should redefine this method to supply custom data.
    "!
    "! @parameter io_data |
    "! @raising /ctdi/cx_print_driver_error |
    METHODS read_data
      IMPORTING io_data TYPE REF TO object OPTIONAL
      RAISING   /ctdi/cx_print_driver_error.

    "! Hook: Unpacks a pre-loaded data object (io_data).
    "! Subclasses should CAST io_data to their specific provider type.
    "!
    "! @parameter io_data |
    "! @raising cx_sy_move_cast_error |
    "! @raising /ctdi/cx_print_driver_error |
    METHODS unpack_io_data
      IMPORTING io_data TYPE REF TO object
      RAISING   cx_sy_move_cast_error
                /ctdi/cx_print_driver_error.

    "! Hook: Fetches business data directly from the DB.
    "! Subclasses instantiate their provider and call read_data, or perform direct SELECTs.
    "!
    "! @raising cx_static_check |
    "! @raising cx_dynamic_check |
    METHODS fetch_data_from_db
      RAISING cx_static_check
              cx_dynamic_check.

    "! Hook: Maps loaded data to base attributes and registers form parameters.
    "!
    "! @raising /ctdi/cx_print_driver_error |
    METHODS map_and_register_data
      RAISING /ctdi/cx_print_driver_error.

    "! Renders the form (SmartForm or Adobe) and optionally saves as PDF.
    "!
    "! @parameter iv_save_as_pdf |
    "! @raising /ctdi/cx_print_driver_error |
    METHODS render_form
      IMPORTING iv_save_as_pdf TYPE abap_bool
      RAISING   /ctdi/cx_print_driver_error.

    "! Detects form technology: 'S' = Smart Form, 'A' = Adobe Form.
    "!
    "! @parameter rv_type |
    METHODS detect_form_type
      RETURNING VALUE(rv_type) TYPE char1.

    "! Executes a Smart Form and optionally converts OTF output to PDF.
    "!
    "! @parameter iv_save_as_pdf |
    "! @raising /ctdi/cx_print_driver_error |
    METHODS execute_smartform
      IMPORTING iv_save_as_pdf TYPE abap_bool
      RAISING   /ctdi/cx_print_driver_error.

    "! Executes an Adobe Form and optionally retrieves the PDF stream.
    "!
    "! @parameter iv_save_as_pdf |
    "! @raising /ctdi/cx_print_driver_error |
    METHODS execute_adobeform
      IMPORTING iv_save_as_pdf TYPE abap_bool
      RAISING   /ctdi/cx_print_driver_error.

    "! Downloads an XSTRING as a PDF file via the presentation layer.
    "!
    "! @parameter iv_pdf_data |
    "! @raising /ctdi/cx_print_driver_error |
    METHODS download_pdf
      IMPORTING iv_pdf_data TYPE xstring
      RAISING   /ctdi/cx_print_driver_error.

    "! Builds the parameter + exception tables for an Adobe Form dynamic call.
    "!
    "! @parameter iv_fm_name |
    "! @parameter is_docparams |
    "! @parameter et_ptab |
    "! @parameter et_etab |
    "! @parameter cs_formoutput |
    METHODS build_adobeform_params
      IMPORTING iv_fm_name    TYPE rs38l_fnam
                is_docparams  TYPE sfpdocparams
      EXPORTING et_ptab       TYPE abap_func_parmbind_tab
                et_etab       TYPE abap_func_excpbind_tab
      CHANGING  cs_formoutput TYPE fpformoutput.

    "! Builds the parameter + exception tables for a Smart Form dynamic call.
    "!
    "! @parameter iv_fm_name |
    "! @parameter is_control_params |
    "! @parameter is_output_options |
    "! @parameter et_ptab |
    "! @parameter et_etab |
    "! @parameter cs_job_output |
    METHODS build_smartform_params
      IMPORTING iv_fm_name        TYPE rs38l_fnam
                is_control_params TYPE ssfctrlop
                is_output_options TYPE ssfcompop
      EXPORTING et_ptab           TYPE abap_func_parmbind_tab
                et_etab           TYPE abap_func_excpbind_tab
      CHANGING  cs_job_output     TYPE ssfcrescl.

    "! Converts OTF data to PDF and downloads it.
    "!
    "! @parameter it_otfdata |
    "! @raising /ctdi/cx_print_driver_error |
    METHODS convert_otf_to_pdf
      IMPORTING it_otfdata TYPE ssfcrescl-otfdata
      RAISING   /ctdi/cx_print_driver_error.

    "! Logs an error (and optionally a prior exception) then raises /CTDI/CX_PRINT_DRIVER_ERROR.
    "!
    "! @parameter iv_message |
    "! @parameter ix_previous |
    "! @raising /ctdi/cx_print_driver_error |
    METHODS raise_driver_error
      IMPORTING iv_message  TYPE string
                ix_previous TYPE REF TO cx_root OPTIONAL
      RAISING   /ctdi/cx_print_driver_error.

    "! Retrieves user print defaults via standard SAP APIs.
    "!
    "! @parameter ev_printer |
    "! @parameter ev_immed |
    "! @parameter ev_delete |
    METHODS get_user_print_defaults
      EXPORTING ev_printer TYPE rspopname
                ev_immed   TYPE c
                ev_delete  TYPE c.

  PRIVATE SECTION.
    CLASS-DATA mv_download_dir TYPE string.

    CLASS-METHODS resolve_contract
      IMPORTING iv_repair_id   TYPE aufnr
      EXPORTING ev_contract_id TYPE vbeln_va
                ev_skz         TYPE bemot
                ev_akz         TYPE char4
      RAISING   /ctdi/cx_print_driver_error.

    CLASS-METHODS get_config_from_db
      IMPORTING iv_repair_id  TYPE aufnr
      EXPORTING ev_form_name  TYPE fpname
                ev_class_name TYPE seoclsname
                es_project    TYPE /ctdi/rep_projec
      RAISING   /ctdi/cx_print_driver_error
                /ctdi/cx_no_config_found.

ENDCLASS.



CLASS /CTDI/CL_PRINT_DRIVER_BASE IMPLEMENTATION.


  METHOD build_adobeform_params.
    DATA ls_ptab TYPE abap_func_parmbind.
    DATA ls_etab TYPE abap_func_excpbind.

    CLEAR: et_ptab,
           et_etab.

    ls_ptab-name = '/1BCDWB/DOCPARAMS'.
    ls_ptab-kind = abap_func_exporting.
    GET REFERENCE OF is_docparams INTO ls_ptab-value.
    INSERT ls_ptab INTO TABLE et_ptab.

    " Fetch all valid parameters for the generated function module to prevent dumps
    SELECT parameter FROM fupararef
      WHERE funcname = @iv_fm_name
      INTO TABLE @DATA(lt_valid_params).

    SORT lt_valid_params BY parameter.

    " Inject any dynamically registered custom parameters if they exist in the form
    LOOP AT mt_custom_form_params ASSIGNING FIELD-SYMBOL(<ls_custom_param>).
      READ TABLE lt_valid_params WITH KEY parameter = <ls_custom_param>-name BINARY SEARCH TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        DATA(ls_insert) = <ls_custom_param>.
        " Adobe Forms do not have a TABLES interface, they expect tables as EXPORTING
        IF ls_insert-kind = abap_func_tables.
          ls_insert-kind = abap_func_exporting.
        ENDIF.
        INSERT ls_insert INTO TABLE et_ptab.
      ENDIF.
    ENDLOOP.

    ls_ptab-name = '/1BCDWB/FORMOUTPUT'.
    ls_ptab-kind = abap_func_importing.
    GET REFERENCE OF cs_formoutput INTO ls_ptab-value.
    INSERT ls_ptab INTO TABLE et_ptab.

    ls_etab-name  = 'USAGE_ERROR'.
    ls_etab-value = 1.
    INSERT ls_etab INTO TABLE et_etab.
    ls_etab-name  = 'SYSTEM_ERROR'.
    ls_etab-value = 2.
    INSERT ls_etab INTO TABLE et_etab.
    ls_etab-name  = 'INTERNAL_ERROR'.
    ls_etab-value = 3.
    INSERT ls_etab INTO TABLE et_etab.
    ls_etab-name  = 'OTHERS'.
    ls_etab-value = 4.
    INSERT ls_etab INTO TABLE et_etab.
  ENDMETHOD.


  METHOD build_smartform_params.
    DATA ls_ptab TYPE abap_func_parmbind.
    DATA ls_etab TYPE abap_func_excpbind.

    CLEAR: et_ptab,
           et_etab.

    ls_ptab-name = 'CONTROL_PARAMETERS'.
    ls_ptab-kind = abap_func_exporting.
    GET REFERENCE OF is_control_params INTO ls_ptab-value.
    INSERT ls_ptab INTO TABLE et_ptab.

    ls_ptab-name = 'OUTPUT_OPTIONS'.
    ls_ptab-kind = abap_func_exporting.
    GET REFERENCE OF is_output_options INTO ls_ptab-value.
    INSERT ls_ptab INTO TABLE et_ptab.

*KKU 24.07.2026 Ticket 2508-077 macht Probleme....
*    " Disable user settings to prevent overriding programmatic output options (legacy compatibility)
*    DATA lv_user_settings TYPE c LENGTH 1 VALUE space.
*    ls_ptab-name = 'USER_SETTINGS'.
*    ls_ptab-kind = abap_func_exporting.
*    GET REFERENCE OF lv_user_settings INTO ls_ptab-value.
*    INSERT ls_ptab INTO TABLE et_ptab.
*KKU End

    " Fetch all valid parameters for the generated function module to prevent dumps
    SELECT parameter FROM fupararef
      WHERE funcname = @iv_fm_name
      INTO TABLE @DATA(lt_valid_params).

    SORT lt_valid_params BY parameter.

    " Inject any dynamically registered custom parameters if they exist in the form
    LOOP AT mt_custom_form_params ASSIGNING FIELD-SYMBOL(<ls_custom_param>).
      READ TABLE lt_valid_params WITH KEY parameter = <ls_custom_param>-name BINARY SEARCH TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        INSERT <ls_custom_param> INTO TABLE et_ptab.
      ENDIF.
    ENDLOOP.

    ls_ptab-name = 'JOB_OUTPUT_INFO'.
    ls_ptab-kind = abap_func_importing.
    GET REFERENCE OF cs_job_output INTO ls_ptab-value.
    INSERT ls_ptab INTO TABLE et_ptab.

    ls_etab-name  = 'FORMATTING_ERROR'.
    ls_etab-value = 1.
    INSERT ls_etab INTO TABLE et_etab.
    ls_etab-name  = 'INTERNAL_ERROR'.
    ls_etab-value = 2.
    INSERT ls_etab INTO TABLE et_etab.
    ls_etab-name  = 'SEND_ERROR'.
    ls_etab-value = 3.
    INSERT ls_etab INTO TABLE et_etab.
    ls_etab-name  = 'USER_CANCELED'.
    ls_etab-value = 4.
    INSERT ls_etab INTO TABLE et_etab.
    ls_etab-name  = 'OTHERS'.
    ls_etab-value = 5.
    INSERT ls_etab INTO TABLE et_etab.
  ENDMETHOD.


  METHOD convert_otf_to_pdf.
    DATA lt_otf         TYPE TABLE OF itcoo.
    DATA lv_pdf_xstring TYPE xstring.
    DATA lt_pdf_lines   TYPE TABLE OF tline.

    lt_otf = it_otfdata.

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
      raise_driver_error( |CONVERT_OTF failed for { mv_form_name } (subrc={ sy-subrc })| ).
    ENDIF.

    download_pdf( iv_pdf_data = lv_pdf_xstring ).
  ENDMETHOD.


  METHOD detect_form_type.
    SELECT SINGLE formname FROM stxfadm              "#EC CI_SEL_NESTED
      WHERE formname = @mv_form_name
      INTO @DATA(lv_ssf_name).
    IF sy-subrc = 0.
      rv_type = 'S'.          " Smart Form exists in STXFADM
    ELSE.
      rv_type = 'A'.          " Default to Adobe Form
    ENDIF.
  ENDMETHOD.


  METHOD download_pdf.
    DATA lv_action   TYPE i.
    DATA lv_path     TYPE string.
    DATA lv_filename TYPE string.
    DATA lv_fpath    TYPE string.
    DATA lv_filesize TYPE i.
    DATA lt_data     TYPE solix_tab.

    IF iv_pdf_data IS INITIAL.
      RETURN.
    ENDIF.

    " Guard: batch mode — frontend services are unavailable
    IF sy-batch IS NOT INITIAL.
      /ctdi/cl_print_driver_log=>log_warning( |PDF download skipped for Repair { mv_repair_order } in batch mode| ).
      RETURN.
    ENDIF.

    " Build filename: Meldungsnummer+Position_Werkstattauftrag_Herstellerserialnummer
    DATA(lv_aufnr_out) = |{ mv_repair_order ALPHA = OUT }|.
    DATA(lv_qmnum_out) = |{ mv_qmnum ALPHA = OUT }|.
    DATA(lv_sernr_out) = COND string( WHEN ms_repair-sernr IS NOT INITIAL
                                      THEN |{ ms_repair-sernr }|
                                      ELSE |{ mv_sernr }| ).
    CONDENSE: lv_aufnr_out, lv_qmnum_out, lv_sernr_out.

    DATA(lv_pdf_filename) = |{ lv_qmnum_out }+{ mv_fenum }_{ lv_aufnr_out }_{ lv_sernr_out }.pdf|.

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

    IF mv_download_dir IS INITIAL.
      " First download in this session: show file-save dialog
      cl_gui_frontend_services=>file_save_dialog( EXPORTING  default_file_name = lv_pdf_filename
                                                             default_extension = 'pdf'
                                                             file_filter       = 'PDF Files (*.pdf)|*.pdf'
                                                  CHANGING   filename          = lv_filename
                                                             path              = lv_path
                                                             fullpath          = lv_fpath
                                                             user_action       = lv_action
                                                  EXCEPTIONS OTHERS            = 1 ).

      IF lv_action <> cl_gui_frontend_services=>action_ok OR lv_fpath IS INITIAL.
        RETURN.
      ENDIF.

      " Remember directory for subsequent downloads
      mv_download_dir = lv_path.
    ELSE.
      " Subsequent downloads: reuse stored directory, auto-generate filename
      lv_fpath = mv_download_dir && lv_pdf_filename.
    ENDIF.

    lv_filesize = xstrlen( iv_pdf_data ).

    cl_gui_frontend_services=>gui_download( EXPORTING  filename                = lv_fpath
                                                       filetype                = 'BIN'
                                                       bin_filesize            = lv_filesize
                                            CHANGING   data_tab                = lt_data
                                            EXCEPTIONS file_write_error        = 1
                                                       no_batch                = 2
                                                       gui_refuse_filetransfer = 3
                                                       invalid_type            = 4
                                                       no_authority            = 5
                                                       unknown_error           = 6
                                                       header_not_allowed      = 7
                                                       separator_not_allowed   = 8
                                                       filesize_not_allowed    = 9
                                                       header_too_long         = 10
                                                       access_denied           = 12
                                                       dp_out_of_memory        = 13
                                                       disk_full               = 14
                                                       dp_timeout              = 15
                                                       file_not_found          = 16
                                                       dataprovider_exception  = 17
                                                       control_flush_error     = 18
                                                       OTHERS                  = 19 ).
    IF sy-subrc <> 0.
      /ctdi/cl_print_driver_log=>log_warning( |PDF download failed for Repair { mv_repair_order } (sy-subrc={ sy-subrc })| ).
    ENDIF.
  ENDMETHOD.


  METHOD execute.
    MESSAGE i001(/ctdi/print_repair) WITH mv_repair_order mv_form_name iv_save_as_pdf
            INTO DATA(lv_msg_started).
    /ctdi/cl_print_driver_log=>log_info( lv_msg_started ).

    " Step 1: Read business data
    read_data( io_data = io_data ).

    " Step 2: Render the form (SmartForm or Adobe)
    render_form( iv_save_as_pdf = iv_save_as_pdf ).

    MESSAGE i002(/ctdi/print_repair) WITH mv_repair_order
            INTO DATA(lv_msg_completed).
    /ctdi/cl_print_driver_log=>log_info( lv_msg_completed ).
  ENDMETHOD.


  METHOD execute_adobeform.
    DATA lv_fm_name      TYPE rs38l_fnam.
    DATA ls_outputparams TYPE sfpoutputparams.
    DATA ls_docparams    TYPE sfpdocparams.
    DATA ls_formoutput   TYPE fpformoutput.
    DATA ls_joboutput    TYPE sfpjoboutput.
    DATA lv_subrc        TYPE sysubrc.
    DATA lv_printer      TYPE rspopname.
    DATA lv_immed        TYPE c LENGTH 1.
    DATA lv_delete       TYPE c LENGTH 1.

    " Apply user print defaults
    get_user_print_defaults( IMPORTING ev_printer = lv_printer
                                       ev_immed   = lv_immed
                                       ev_delete  = lv_delete ).

    " Configure output parameters
*    ls_outputparams-connection = 'ADS'.
    ls_outputparams-reqnew   = abap_true.
    ls_outputparams-reqimm   = abap_true.
    ls_outputparams-reqfinal = abap_true.
    ls_outputparams-dest     = lv_printer.
    ls_outputparams-reqimm   = lv_immed.
    ls_outputparams-reqdel   = lv_delete.
    IF iv_save_as_pdf = abap_true.
      ls_outputparams-nodialog = abap_true.
      ls_outputparams-getpdf   = abap_true.
    ELSE.
      ls_outputparams-preview = abap_true.
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
      raise_driver_error( |FP_JOB_OPEN failed (subrc={ sy-subrc })| ).
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
            OTHERS = 0.
        raise_driver_error( iv_message  = |Adobe Form FM resolution failed for { mv_form_name }|
                            ix_previous = lx_fp ).
    ENDTRY.

    " Document parameters
    ls_docparams-langu   = sy-langu.
    ls_docparams-country = gc_country_default.

    " Build parameter and exception tables
    DATA lt_ptab TYPE abap_func_parmbind_tab.
    DATA lt_etab TYPE abap_func_excpbind_tab.

    build_adobeform_params( EXPORTING iv_fm_name    = lv_fm_name
                                      is_docparams  = ls_docparams
                            IMPORTING et_ptab       = lt_ptab
                                      et_etab       = lt_etab
                            CHANGING  cs_formoutput = ls_formoutput ).

    TRY.
        CALL FUNCTION lv_fm_name
          PARAMETER-TABLE lt_ptab
          EXCEPTION-TABLE lt_etab.
        lv_subrc = sy-subrc.
      CATCH cx_sy_dyn_call_error INTO DATA(lx_dyn_call).
        raise_driver_error( iv_message  = |Dynamic call error for { mv_form_name }|
                            ix_previous = lx_dyn_call ).
    ENDTRY.

    IF lv_subrc <> 0.
      raise_driver_error( |Adobe Form { mv_form_name } call failed (subrc={ lv_subrc })| ).
    ENDIF.

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
      raise_driver_error( |Adobe Form { mv_form_name } close failed (subrc={ sy-subrc })| ).
    ENDIF.

    /ctdi/cl_print_driver_log=>log_info( |Adobe Form { mv_form_name } executed successfully| ).

    " Download PDF if requested
    IF iv_save_as_pdf = abap_true AND ls_formoutput-pdf IS NOT INITIAL.
      download_pdf( iv_pdf_data = ls_formoutput-pdf ).
    ENDIF.
  ENDMETHOD.


  METHOD execute_smartform.
    DATA lv_fm_name        TYPE rs38l_fnam.
    DATA ls_control_params TYPE ssfctrlop.
    DATA ls_output_options TYPE ssfcompop.
    DATA ls_job_output     TYPE ssfcrescl.
    DATA lv_printer        TYPE rspopname.
    DATA lv_immed          TYPE c LENGTH 1.
    DATA lv_delete         TYPE c LENGTH 1.

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
      raise_driver_error( |Smart Form FM resolution failed for { mv_form_name } (subrc={ sy-subrc })| ).
    ENDIF.

    " Apply user print defaults
    get_user_print_defaults( IMPORTING ev_printer = lv_printer
                                       ev_immed   = lv_immed
                                       ev_delete  = lv_delete ).

    ls_output_options-tddest   = lv_printer.
    ls_output_options-tdcopies = 1.
    ls_output_options-tdimmed  = lv_immed.
    ls_output_options-tddelete = lv_delete.
    ls_output_options-tdnewid  = abap_true.

    " Dynamic device type based on logon language
    DATA lv_devtype TYPE rspoptype.
    CALL FUNCTION 'SSF_GET_DEVICE_TYPE'
      EXPORTING
        i_language = sy-langu
      IMPORTING
        e_devtype  = lv_devtype
      EXCEPTIONS
        OTHERS     = 1.
    IF sy-subrc <> 0.
      lv_devtype = gc_devtype_fallback.
    ENDIF.
    ls_output_options-tdprinter = lv_devtype.

    " Suppress print dialog unconditionally (legacy compatibility)
    ls_control_params-no_dialog = abap_true.

    " PDF mode: intercept OTF data
    IF iv_save_as_pdf = abap_true.
      ls_control_params-getotf = abap_true.
    ENDIF.

    " Build parameter and exception tables
    DATA lt_ptab TYPE abap_func_parmbind_tab.
    DATA lt_etab TYPE abap_func_excpbind_tab.

    build_smartform_params( EXPORTING iv_fm_name        = lv_fm_name
                                      is_control_params = ls_control_params
                                      is_output_options = ls_output_options
                            IMPORTING et_ptab           = lt_ptab
                                      et_etab           = lt_etab
                            CHANGING  cs_job_output     = ls_job_output ).

    DATA lv_subrc_fm TYPE sysubrc.

    TRY.
        CALL FUNCTION lv_fm_name
          PARAMETER-TABLE lt_ptab
          EXCEPTION-TABLE lt_etab.
        lv_subrc_fm = sy-subrc.
      CATCH cx_sy_dyn_call_error INTO DATA(lx_dyn_call).
        raise_driver_error( iv_message  = |Dynamic call error for { mv_form_name }|
                            ix_previous = lx_dyn_call ).
    ENDTRY.

    IF lv_subrc_fm <> 0.
      raise_driver_error( |Smart Form { mv_form_name } execution failed (subrc={ lv_subrc_fm })| ).
    ENDIF.

    /ctdi/cl_print_driver_log=>log_info( |Smart Form { mv_form_name } executed successfully| ).

    " PDF conversion if requested
    IF iv_save_as_pdf = abap_true.
      convert_otf_to_pdf( it_otfdata = ls_job_output-otfdata ).
    ENDIF.
  ENDMETHOD.


  METHOD factory.
    DATA lv_form_name  TYPE fpname.
    DATA lv_class_name TYPE seoclsname.
    DATA ls_project_db TYPE /ctdi/rep_projec.

    /ctdi/cl_print_driver_log=>log_info( |Print driver factory invoked for Repair { iv_repair_id }, Sernr { iv_sernr }| ).

    get_config_from_db( EXPORTING iv_repair_id  = iv_repair_id
                        IMPORTING ev_form_name  = lv_form_name
                                  ev_class_name = lv_class_name
                                  es_project    = ls_project_db ).

    TRY.
        CREATE OBJECT ro_driver TYPE (lv_class_name).
        ro_driver->mv_repair_order = iv_repair_id.
        ro_driver->mv_sernr        = iv_sernr.
        ro_driver->mv_form_name    = lv_form_name.
        ro_driver->ms_project      = ls_project_db.
      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING
            repair_id = iv_repair_id
            message   = |Cannot instantiate class { lv_class_name }|
            previous  = lx_create.
    ENDTRY.
  ENDMETHOD.


  METHOD fetch_data_from_db.
    " Default: no-op. Subclasses redefine this to load data from database.
  ENDMETHOD.


  METHOD get_config_from_db.
    DATA lv_contract TYPE vbeln_va.
    DATA lv_skz      TYPE bemot.
    DATA lv_akz      TYPE char4.
    DATA ls_config   TYPE /ctdi/rep_forms.

    TYPES: BEGIN OF ty_query_step,
             vbeln TYPE vbeln_va,
             skz   TYPE bemot,
             akz   TYPE char4,
           END OF ty_query_step.
    DATA lt_steps TYPE TABLE OF ty_query_step.

    resolve_contract( EXPORTING iv_repair_id   = iv_repair_id
                      IMPORTING ev_contract_id = lv_contract
                                ev_skz         = lv_skz
                                ev_akz         = lv_akz ).

    IF lv_contract IS NOT INITIAL.
      IF lv_skz IS NOT INITIAL AND lv_akz IS NOT INITIAL.
        APPEND VALUE #( vbeln = lv_contract
                        skz   = lv_skz
                        akz   = lv_akz ) TO lt_steps.
      ENDIF.
      IF lv_skz IS NOT INITIAL.
        APPEND VALUE #( vbeln = lv_contract
                        skz   = lv_skz
                        akz   = '' ) TO lt_steps.
      ENDIF.
      IF lv_akz IS NOT INITIAL.
        APPEND VALUE #( vbeln = lv_contract
                        skz   = ''
                        akz   = lv_akz ) TO lt_steps.
      ENDIF.
      APPEND VALUE #( vbeln = lv_contract
                      skz   = ''
                      akz   = '' ) TO lt_steps.
    ENDIF.

    IF lv_skz IS NOT INITIAL AND lv_akz IS NOT INITIAL.
      APPEND VALUE #( vbeln = ''
                      skz   = lv_skz
                      akz   = lv_akz ) TO lt_steps.
    ENDIF.
    IF lv_skz IS NOT INITIAL.
      APPEND VALUE #( vbeln = ''
                      skz   = lv_skz
                      akz   = '' ) TO lt_steps.
    ENDIF.
    IF lv_akz IS NOT INITIAL.
      APPEND VALUE #( vbeln = ''
                      skz   = ''
                      akz   = lv_akz ) TO lt_steps.
    ENDIF.

    " Global fallback (Empty Keys)
    APPEND VALUE #( vbeln = ''
                    skz   = ''
                    akz   = '' ) TO lt_steps.

    SELECT * FROM /ctdi/rep_forms             "#EC CI_ALL_FIELDS_NEEDED
      WHERE vbeln = @lv_contract OR vbeln = ''       "#EC CI_SEL_NESTED
      ORDER BY PRIMARY KEY ##SUBRC_OK
      INTO TABLE @DATA(lt_forms).

    SORT lt_forms BY vbeln
                     skz
                     akz.
    CLEAR ls_config.
    LOOP AT lt_steps ASSIGNING FIELD-SYMBOL(<ls_step>).
      READ TABLE lt_forms ASSIGNING FIELD-SYMBOL(<ls_form>) WITH KEY vbeln = <ls_step>-vbeln
                                                                     skz   = <ls_step>-skz
                                                                     akz   = <ls_step>-akz BINARY SEARCH.
      IF sy-subrc = 0.
        ls_config = <ls_form>.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF ls_config IS NOT INITIAL.
      ev_form_name  = ls_config-form_name.
      ev_class_name = /ctdi/cl_print_cust_engine=>normalize_class_name( ls_config-class_name ).
    ELSE.
      RAISE EXCEPTION TYPE /ctdi/cx_no_config_found
        EXPORTING
          message = |No configuration found in /CTDI/REP_FORMS for order { iv_repair_id } (including default fallback).|.
    ENDIF.

    /ctdi/cl_print_driver_log=>log_info(
        |Config resolved — Contract: { lv_contract }, | &&
        |SKZ: { lv_skz }, AKZ: { lv_akz }, Form: { ev_form_name }, Class: { ev_class_name }| ).

    SELECT SINGLE * FROM /ctdi/rep_projec     "#EC CI_ALL_FIELDS_NEEDED
      WHERE vbeln = @lv_contract ##SUBRC_OK
      INTO @es_project.                              "#EC CI_SEL_NESTED
  ENDMETHOD.


  METHOD get_user_print_defaults.
    DATA ls_user_defaults TYPE usdefaults.
    DATA lv_user_printer  TYPE char40.

    " 1. Fetch user defaults via standard API
    CALL FUNCTION 'SUSR_USER_DEFAULTS_GET'
      EXPORTING
        user_name     = sy-uname
      IMPORTING
        user_defaults = ls_user_defaults
      EXCEPTIONS
        OTHERS        = 0.

    " 2. Check SET/GET parameter override (/CELLAG/PAFR)
    GET PARAMETER ID '/CELLAG/PAFR' FIELD lv_user_printer.

    " 3. Printer: parameter takes precedence over user default
    ev_printer = COND #( WHEN lv_user_printer IS NOT INITIAL
                         THEN lv_user_printer
                         ELSE ls_user_defaults-spld ).

    " 4. Legacy override: Druckersteuerung durch ycl_printer
    ev_printer = ycl_printer=>select_printer( iv_uname   = sy-uname
                                              iv_medium  = ycl_printer=>co_paperprinter_dina4
                                              iv_printer = ev_printer ).

    " 5. Hardcoded values from legacy print_sf subroutine
    ev_immed  = abap_true.
    ev_delete = abap_true.
  ENDMETHOD.


  METHOD map_and_register_data.
    " Default: no-op. Subclasses redefine this to map data structures.
  ENDMETHOD.


  METHOD raise_driver_error.
    IF ix_previous IS BOUND.
      /ctdi/cl_print_driver_log=>log_exception( ix_previous ).
    ENDIF.
    /ctdi/cl_print_driver_log=>log_error( iv_message ).

    RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
      EXPORTING
        repair_id = mv_repair_order
        message   = iv_message
        previous  = ix_previous.
  ENDMETHOD.


  METHOD read_data.
    " 1. Initialize data state
    IF io_data IS BOUND.
      TRY.
          unpack_io_data( io_data ).
          /ctdi/cl_print_driver_log=>log_info( |Unpacked io_data for Repair { mv_repair_order }| ).
        CATCH cx_sy_move_cast_error INTO DATA(lx_cast).
          raise_driver_error( iv_message  = |Invalid data object passed to Print Driver for { mv_repair_order }|
                              ix_previous = lx_cast ).
      ENDTRY.
    ELSE.
      TRY.
          fetch_data_from_db( ).
          /ctdi/cl_print_driver_log=>log_info( |Read data from DB for Repair { mv_repair_order }| ).
        CATCH cx_root INTO DATA(lx_root).
          raise_driver_error( iv_message  = |Error reading data from DB for { mv_repair_order }|
                              ix_previous = lx_root ).
      ENDTRY.
    ENDIF.

    " 2. Map structures and register
    map_and_register_data( ).

    " 3. Resolve notification number and position for PDF filename
    IF mv_qmnum IS INITIAL.
      SELECT SINGLE q~qmnum, f~fenum
        FROM qmel AS q
               INNER JOIN qmfe AS f ON f~qmnum = q~qmnum
        WHERE q~aufnr = @mv_repair_order
          AND q~qmart = @gc_qmart_repair
        INTO ( @mv_qmnum, @mv_fenum ) ##WARN_OK.
    ENDIF.
  ENDMETHOD.


  METHOD register_custom_parameter.
    DATA ls_param TYPE abap_func_parmbind.

    ls_param-name  = iv_name.
    ls_param-kind  = iv_kind.
    ls_param-value = ir_data.
    INSERT ls_param INTO TABLE mt_custom_form_params.
  ENDMETHOD.


  METHOD render_form.
    " Ensure passed repair header is valid
    IF ms_repair IS INITIAL.
      /ctdi/cl_print_driver_log=>log_warning( |Repair data reference is empty - | &&
                                              |Print execution bypassed for Repair ID { mv_repair_order }| ).
      RETURN.
    ENDIF.

    DATA(lv_form_type) = detect_form_type( ).

    IF lv_form_type = 'S'.
      /ctdi/cl_print_driver_log=>log_info( |Form { mv_form_name } detected as Smart Form| ).
      execute_smartform( iv_save_as_pdf = iv_save_as_pdf ).
    ELSE.
      /ctdi/cl_print_driver_log=>log_info( |Form { mv_form_name } detected as Adobe Form| ).
      execute_adobeform( iv_save_as_pdf = iv_save_as_pdf ).
    ENDIF.
  ENDMETHOD.


  METHOD resolve_contract.
    DATA(lv_aufnr) = |{ iv_repair_id ALPHA = IN }|.
    CLEAR: ev_contract_id,
           ev_skz,
           ev_akz.

    SELECT SINGLE a~kdauf,                           "#EC CI_SEL_NESTED
                  o~vgbel AS contract_id,
                  c~vbtyp,
                  f~bemot,
                  q~qmcod
      FROM aufk AS a
             LEFT OUTER JOIN
               vbak AS o ON o~vbeln = a~kdauf
                 LEFT OUTER JOIN
                   vbak AS c ON c~vbeln = o~vgbel
                     LEFT OUTER JOIN
                       afru AS f ON  f~aufnr = a~aufnr
                                 AND f~vornr = @gc_operation_wfer
                                 AND f~stokz = @space
                                 AND f~stzhl = '00000000'
                         LEFT OUTER JOIN
                           qmel AS q ON  q~aufnr = a~aufnr
                                     AND q~qmart = @gc_qmart_repair
      WHERE a~aufnr = @lv_aufnr
      INTO ( @DATA(lv_order_id), @ev_contract_id, @DATA(lv_vbtyp), @ev_skz, @ev_akz ) ##WARN_OK.

    IF sy-subrc = 0 AND lv_order_id IS NOT INITIAL.

      IF ev_contract_id IS INITIAL OR lv_vbtyp <> 'G'.
        CLEAR ev_contract_id.
        /ctdi/cl_print_driver_log=>log_warning(
            |No valid contract found for Order { lv_order_id } — proceeding with global fallback| ).
      ELSE.
        /ctdi/cl_print_driver_log=>log_info(
            |Resolved Order { iv_repair_id } -> Contract { ev_contract_id }, SKZ { ev_skz }, AKZ { ev_akz }| ).
      ENDIF.

    ELSE.
      DATA(lv_err) = |Repair Order { iv_repair_id } not found in system|.
      /ctdi/cl_print_driver_log=>log_error( lv_err ).
      RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
        EXPORTING
          repair_id = iv_repair_id
          message   = lv_err.
    ENDIF.
  ENDMETHOD.


  METHOD unpack_io_data.
    " Default: no-op. Subclasses redefine this to unpack custom objects.
  ENDMETHOD.
ENDCLASS.
