CLASS /ctdi/cl_repair_print_base DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  "* Naming convention: 
  "*   ms_ = structure (single record)
  "*   mt_ = internal table (multiple records)

  PUBLIC SECTION.
    INTERFACES /ctdi/if_repair_print_provider.

    ALIASES print
      FOR /ctdi/if_repair_print_provider~print.
    ALIASES read_data
      FOR /ctdi/if_repair_print_provider~read_data.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_project_info,
             vbeln       TYPE vbeln_va,
             project_id  TYPE ps_posid,
             description TYPE ps_post1,
             cust_ref    TYPE bstnk,
           END OF ty_project_info.

    METHODS download_pdf
      IMPORTING
        !iv_repair_id TYPE aufnr
        !iv_pdf_data    TYPE xstring
      RAISING
        cx_static_check.
ENDCLASS.



CLASS /CTDI/CL_REPAIR_PRINT_BASE IMPLEMENTATION.


  METHOD /ctdi/if_repair_print_provider~execute.
    me->/ctdi/if_repair_print_provider~read_data(
      EXPORTING iv_repair_id     = iv_repair_id
      CHANGING  cs_repair        = cs_repair
                ct_device_defects  = ct_device_defects
                ct_comment_lines = ct_comment_lines ).
    me->/ctdi/if_repair_print_provider~print(
      EXPORTING iv_repair_id     = iv_repair_id
                iv_form_name     = iv_form_name
                iv_save_as_pdf   = iv_save_as_pdf
      CHANGING  cs_repair        = cs_repair
                ct_device_defects  = ct_device_defects
                ct_comment_lines = ct_comment_lines ).
  ENDMETHOD.


  METHOD /ctdi/if_repair_print_provider~print.
    DATA: lv_fm_name      TYPE rs38l_fnam,
          ls_outputparams TYPE sfpoutputparams,
          ls_docparams    TYPE sfpdocparams,
          lv_form_type    TYPE char1.

    DATA: ls_user_defaults TYPE usdefaults,
          lv_user_printer  TYPE paramval,
          lv_printer_dest  TYPE rspopname.

    /ctdi/cl_repair_log=>log_info( |Print Provider execution started for Form: { iv_form_name }| ).

    " Ensure passed repair header is valid
    IF cs_repair IS INITIAL.
      /ctdi/cl_repair_log=>log_warning(
        |Passed repair header data is empty - | &&
        |Print execution bypassed for Repair ID { iv_repair_id }| ).
      RETURN.
    ENDIF.

    " 1. Retrieve User Defaults using standard SAP API
    CALL FUNCTION 'SUSR_USER_DEFAULTS_GET'
      EXPORTING
        user_name     = sy-uname
      IMPORTING
        user_defaults = ls_user_defaults
      EXCEPTIONS
        OTHERS        = 1.

    " 2. Check for user-specific SET/GET parameter override (/CELLAG/PAFR)
    GET PARAMETER ID '/CELLAG/PAFR' FIELD lv_user_printer.

    " 3. Determine the output printer destination
    lv_printer_dest = COND #( WHEN lv_user_printer IS NOT INITIAL
                              THEN lv_user_printer
                              ELSE ls_user_defaults-spld ).

    " Dynamically detect the form type (Smart Form vs Adobe PDF Form)
    SELECT SINGLE formname FROM stxfadm
      INTO @DATA(lv_ssf_name)
      WHERE formname = @iv_form_name.
    IF sy-subrc = 0.
      lv_form_type = 'S'. " Smart Form
    ELSE.
      lv_form_type = 'A'. " Adobe Form (Default)
    ENDIF.

    /ctdi/cl_repair_log=>log_info(
      |Form technology resolved: { COND #( WHEN lv_form_type = 'S'
                                           THEN 'Smart Form'
                                           ELSE 'Adobe Form' ) }| ).

    IF lv_form_type = 'S'. " Smart Forms
      DATA: lv_ssf_fm_name        TYPE rs38l_fnam,
            ls_control_parameters TYPE ssfctrlop,
            ls_output_options     TYPE ssfcompop,
            ls_output_data        TYPE ssfcrescl,
            lt_otf                TYPE TABLE OF itcoo,
            lv_pdf_xstring        TYPE xstring,
            lt_pdf_lines          TYPE TABLE OF tline.

      " Retrieve the dynamically generated function module name for the Smart Form
      CALL FUNCTION 'SSF_FUNCTION_MODULE_NAME'
        EXPORTING
          formname           = iv_form_name
        IMPORTING
          fm_name            = lv_ssf_fm_name
        EXCEPTIONS
          no_form            = 1
          no_function_module = 2
          OTHERS             = 3.
      IF sy-subrc <> 0.
        DATA(lv_err_msg) = |{ 'Smart Form function module name resolution failed for: &1, subrc = &2'(001) }|.
        REPLACE '&1' IN lv_err_msg WITH iv_form_name.
        REPLACE '&2' IN lv_err_msg WITH |{ sy-subrc }|.
        /ctdi/cl_repair_log=>log_error( lv_err_msg ).
        RAISE EXCEPTION TYPE /ctdi/cx_form_error
          EXPORTING
            repair_id = iv_repair_id
            message   = lv_err_msg
            subrc     = sy-subrc.
      ENDIF.

      " Apply printer and format options from defaults
      ls_output_options-tddest   = lv_printer_dest.
      ls_output_options-tdcopies = 1.
      ls_output_options-tdimmed  = COND #( WHEN ls_user_defaults-splg IS NOT INITIAL THEN ls_user_defaults-splg ELSE abap_true ).
      ls_output_options-tddelete = COND #( WHEN ls_user_defaults-spda IS NOT INITIAL THEN ls_user_defaults-spda ELSE abap_true ).
      ls_output_options-tdnewid  = abap_true.

      " Dynamic Device Type detection based on language
      DATA: lv_devtype TYPE rspoptype.
      CALL FUNCTION 'SSF_GET_DEVICE_TYPE'
        EXPORTING
          i_language    = sy-langu
          i_application = 'SAPDEFAULT'
        IMPORTING
          e_devtype     = lv_devtype.
      ls_output_options-tdprinter = lv_devtype.

      " If Save as PDF is selected, retrieve OTF data instead of sending directly to spool
      IF iv_save_as_pdf = abap_true.
        ls_control_parameters-getotf    = abap_true.
        ls_control_parameters-no_dialog = abap_true.
      ENDIF.

      /ctdi/cl_repair_log=>log_info( |Calling Smart Form function module: { lv_ssf_fm_name }| ).

      " Call the Smart Form FM dynamically
      " Check if the generated Smart Form function module signature accepts error tables
      SELECT SINGLE paramname FROM fupararef
        INTO @DATA(lv_ssf_has_errors)
        WHERE funcname = @lv_ssf_fm_name
          AND paramname = 'IT_REPAIR_ERROR'.

      IF sy-subrc = 0.
        CALL FUNCTION lv_ssf_fm_name
          EXPORTING
            control_parameters = ls_control_parameters
            output_options     = ls_output_options
            is_repair          = cs_repair
          IMPORTING
            job_output_info    = ls_output_data
          TABLES
            it_repair_error    = ct_device_defects
            it_comment_lines   = ct_comment_lines
          EXCEPTIONS
            formatting_error   = 1
            internal_error     = 2
            send_error         = 3
            user_canceled      = 4
            OTHERS             = 5.
      ELSE.
        CALL FUNCTION lv_ssf_fm_name
          EXPORTING
            control_parameters = ls_control_parameters
            output_options     = ls_output_options
            is_repair          = cs_repair
          IMPORTING
            job_output_info    = ls_output_data
          EXCEPTIONS
            formatting_error   = 1
            internal_error     = 2
            send_error         = 3
            user_canceled      = 4
            OTHERS             = 5.
      ENDIF.
      IF sy-subrc <> 0.
        lv_err_msg = |{ 'Smart Form dynamic execution failed for function module: &1, subrc = &2'(002) }|.
        REPLACE '&1' IN lv_err_msg WITH lv_ssf_fm_name.
        REPLACE '&2' IN lv_err_msg WITH |{ sy-subrc }|.
        /ctdi/cl_repair_log=>log_error( lv_err_msg ).
        RAISE EXCEPTION TYPE /ctdi/cx_form_error
          EXPORTING
            repair_id = iv_repair_id
            message   = lv_err_msg
            subrc     = sy-subrc.
      ENDIF.

      /ctdi/cl_repair_log=>log_info( |Smart Form executed successfully.| ).

      " If Save as PDF, convert OTF to PDF and trigger local download
      IF iv_save_as_pdf = abap_true.
        lt_otf = ls_output_data-otfdata.

        /ctdi/cl_repair_log=>log_info( 'Converting Smart Form OTF to PDF stream...' ).

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
      IF sy-subrc = 0.
        /ctdi/cl_repair_log=>log_info(
          |OTF-to-PDF Conversion successful. | &&
          |Binary size: { xstrlen( lv_pdf_xstring ) } bytes.| ).
        TRY.
            download_pdf(
              iv_repair_id = iv_repair_id
              iv_pdf_data  = lv_pdf_xstring ).
          CATCH cx_static_check INTO DATA(lx_error).
            /ctdi/cl_repair_log=>log_exception( lx_error ).
            RAISE EXCEPTION TYPE /ctdi/cx_form_error
              EXPORTING
                repair_id = iv_repair_id
                message   = lx_error->get_text( ).
        ENDTRY.
      ELSE.
        lv_err_msg = |{ 'CONVERT_OTF failed to convert OTF stream to PDF, subrc = &1'(003) }|.
        REPLACE '&1' IN lv_err_msg WITH |{ sy-subrc }|.
        /ctdi/cl_repair_log=>log_error( lv_err_msg ).
        RAISE EXCEPTION TYPE /ctdi/cx_form_error
          EXPORTING
            repair_id = iv_repair_id
            message   = lv_err_msg
            subrc     = sy-subrc.
      ENDIF.
    ENDIF.

    ELSE. " Adobe Forms (default)
      DATA: ls_formoutput TYPE fpformoutput.

      " 2. Initialize Output Parameters (Standard SAP Interactive/Adobe Forms logic)
      ls_outputparams-connection = 'ADS'.       " Adobe Document Services default connection
      ls_outputparams-nodialog   = abap_true.   " Suppress print dialog for automated printing
      ls_outputparams-preview    = abap_true.    " Enable print preview

      " Apply printer and format options from defaults
      ls_outputparams-dest   = lv_printer_dest.
      ls_outputparams-reqimm = COND #( WHEN ls_user_defaults-splg IS NOT INITIAL THEN ls_user_defaults-splg ELSE abap_true ).
      ls_outputparams-reqdel = COND #( WHEN ls_user_defaults-spda IS NOT INITIAL THEN ls_user_defaults-spda ELSE abap_true ).

      " If Save as PDF is selected, instruct ADS to return PDF data
      IF iv_save_as_pdf = abap_true.
        ls_outputparams-getpdf   = abap_true.
      ENDIF.

      /ctdi/cl_repair_log=>log_info( 'Opening Adobe Forms connection (FP_JOB_OPEN)...' ).

      " Open the printing job
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
        lv_err_msg = |{ 'FP_JOB_OPEN failed to open Adobe Forms job, subrc = &1'(004) }|.
        REPLACE '&1' IN lv_err_msg WITH |{ sy-subrc }|.
        /ctdi/cl_repair_log=>log_error( lv_err_msg ).
        RAISE EXCEPTION TYPE /ctdi/cx_form_error
          EXPORTING
            repair_id = iv_repair_id
            message   = lv_err_msg
            subrc     = sy-subrc.
      ENDIF.

      " 3. Retrieve the dynamic PDF/Adobe function module name generated for the form
      TRY.
          CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
            EXPORTING
              i_name     = iv_form_name
            IMPORTING
              e_funcname = lv_fm_name.
        CATCH cx_root INTO DATA(lx_fm_err).
          /ctdi/cl_repair_log=>log_exception( lx_fm_err ).
          " Ensure job is closed in case of error
          CALL FUNCTION 'FP_JOB_CLOSE'.
          RETURN.
      ENDTRY.

      /ctdi/cl_repair_log=>log_info( |Resolved Adobe Form Function Module: { lv_fm_name }. Calling form now...| ).

      " 4. Call the Adobe Form generated function module dynamically
      " Docparams controls language and country configurations
      ls_docparams-langu   = sy-langu.
      ls_docparams-country = 'US'.

      " Check if the generated Adobe Form function module signature accepts error tables
      SELECT SINGLE paramname FROM fupararef
        INTO @DATA(lv_fp_has_errors)
        WHERE funcname = @lv_fm_name
          AND paramname = 'IT_REPAIR_ERROR'.

      IF sy-subrc = 0.
        CALL FUNCTION lv_fm_name
          EXPORTING
            /1bcdwb/docparams     = ls_docparams
            is_repair             = cs_repair
            it_repair_error       = ct_device_defects
            it_comment_lines      = ct_comment_lines
          IMPORTING
            /1bcdwb/formoutput    = ls_formoutput
          EXCEPTIONS
            usage_error           = 1
            system_error          = 2
            internal_error        = 3
            OTHERS                = 4.
      ELSE.
        CALL FUNCTION lv_fm_name
          EXPORTING
            /1bcdwb/docparams = ls_docparams
            is_repair         = cs_repair
          IMPORTING
            /1bcdwb/formoutput    = ls_formoutput
          EXCEPTIONS
            usage_error       = 1
            system_error      = 2
            internal_error    = 3
            OTHERS            = 4.
      ENDIF.

      DATA(lv_subrc) = sy-subrc.

      /ctdi/cl_repair_log=>log_info( |Adobe Form function call finished. Closing printing job (FP_JOB_CLOSE)...| ).

      " 5. Close the printing job
      DATA: ls_joboutput TYPE sfpjoboutput.

      CALL FUNCTION 'FP_JOB_CLOSE'
        IMPORTING
          e_joboutput    = ls_joboutput
        EXCEPTIONS
          usage_error    = 1
          system_error   = 2
          internal_error = 3
          OTHERS         = 4.

      IF lv_subrc <> 0.
        lv_err_msg = |{ 'Adobe Form dynamic generated function module failed, subrc = &1'(005) }|.
        REPLACE '&1' IN lv_err_msg WITH |{ lv_subrc }|.
        /ctdi/cl_repair_log=>log_error( lv_err_msg ).
        RAISE EXCEPTION TYPE /ctdi/cx_form_error
          EXPORTING
            repair_id = iv_repair_id
            message   = lv_err_msg
            subrc     = lv_subrc.
      ElseIF sy-subrc <> 0.
        lv_err_msg = |{ 'FP_JOB_CLOSE failed to close Adobe Forms job, subrc = &1'(006) }|.
        REPLACE '&1' IN lv_err_msg WITH |{ sy-subrc }|.
        /ctdi/cl_repair_log=>log_error( lv_err_msg ).
        RAISE EXCEPTION TYPE /ctdi/cx_form_error
          EXPORTING
            repair_id = iv_repair_id
            message   = lv_err_msg
            subrc     = sy-subrc.
      ENDIF.

      /ctdi/cl_repair_log=>log_info( |Adobe Form execution completed successfully.| ).

      " If Save as PDF, trigger local download of the retrieved PDF xstring
      IF iv_save_as_pdf = abap_true AND ls_formoutput-pdf IS NOT INITIAL.
        /ctdi/cl_repair_log=>log_info(
          |Downloading resolved PDF stream. | &&
          |Size: { xstrlen( ls_formoutput-pdf ) } bytes.| ).
        TRY.
            download_pdf( iv_repair_id = iv_repair_id
                          iv_pdf_data  = ls_formoutput-pdf ).
          CATCH cx_static_check INTO DATA(lx_pdf_err).
            /ctdi/cl_repair_log=>log_exception( lx_pdf_err ).
            RAISE EXCEPTION TYPE /ctdi/cx_form_error
              EXPORTING
                repair_id = iv_repair_id
                message   = lx_pdf_err->get_text( ).
        ENDTRY.
      ENDIF.

    ENDIF.

  ENDMETHOD.


  METHOD /ctdi/if_repair_print_provider~read_data.
    " Stateless implementation: data is retrieved directly during print execution
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

    " Guard against execution in background processing (Batch mode)
    IF sy-batch IS NOT INITIAL.
      /ctdi/cl_repair_log=>log_warning( |Presentation layer download bypassed for Repair { iv_repair_id } in batch mode.| ).
      RETURN.
    ENDIF.

    " Convert xstring to binary table
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
*          dp_error                  = 11
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
ENDCLASS.
