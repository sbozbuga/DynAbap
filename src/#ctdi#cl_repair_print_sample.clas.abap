CLASS /ctdi/cl_repair_print_sample DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

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

    DATA: ms_header   TYPE vbak,
          mt_items    TYPE TABLE OF vbap,
          ms_customer TYPE kna1,
          ms_shipto   TYPE kna1,
          ms_project  TYPE ty_project_info,
          ms_usr01    TYPE usr01.

    METHODS download_pdf
      IMPORTING
        !iv_repair_id TYPE vbeln_va
        !iv_pdf_data    TYPE xstring
      RAISING
        cx_static_check.
ENDCLASS.



CLASS /ctdi/cl_repair_print_sample IMPLEMENTATION.

  METHOD /ctdi/if_repair_print_provider~read_data.
    DATA: lv_kunnr_we TYPE kunnr.

    " 1. Fetch Repair Header and Item Data from VBAK and VBAP
    SELECT SINGLE * FROM vbak INTO @ms_header WHERE vbeln = @iv_repair_id.
    IF sy-subrc <> 0.
      " Exit if repair not found
      RETURN.
    ENDIF.

    SELECT * FROM vbap INTO TABLE @mt_items WHERE vbeln = @iv_repair_id.

    " 1.1 Fetch Sold-to Customer master data (KNA1) using VBAK-KUNNR
    IF ms_header-kunnr IS NOT INITIAL.
      SELECT SINGLE * FROM kna1 INTO @ms_customer WHERE kunnr = @ms_header-kunnr.
    ENDIF.

    " 1.2 Fetch Ship-to Customer from Partner table (VBPA) where Role = 'WE' (Ship-to)
    SELECT SINGLE kunnr FROM vbpa INTO @lv_kunnr_we
      WHERE vbeln = @iv_repair_id
        AND parvw = 'WE'.
    IF sy-subrc = 0 AND lv_kunnr_we IS NOT INITIAL.
      SELECT SINGLE * FROM kna1 INTO @ms_shipto WHERE kunnr = @lv_kunnr_we.
    ENDIF.

    " 1.3 Fetch Customer Project / WBS Element details linked to the repair items
    ms_project-vbeln    = iv_repair_id.
    ms_project-cust_ref = ms_header-bstnk. " Customer Purchase Order / Reference (often contains project/repair name)

    LOOP AT mt_items INTO DATA(ls_item) WHERE ps_psp_eln IS NOT INITIAL.
      SELECT SINGLE posid, post1 FROM prps INTO ( @ms_project-project_id, @ms_project-description )
        WHERE pspnr = @ls_item-ps_psp_eln.
      IF sy-subrc = 0.
        EXIT. " Use the first WBS element found for sample description
      ENDIF.
    ENDLOOP.

    " Fallback: If no WBS project is explicitly linked to the items, check standard VBAK fields
    IF ms_project-project_id IS INITIAL.
      " If VBAK-BSTNK has a project name (like 'Deutsche Telekom 5G Base Station Repair')
      " we can treat that as the project description fallback
      ms_project-description = ms_header-bstnk.
    ENDIF.

    " 1.4 Fetch User Print Defaults from USR01
    SELECT SINGLE * FROM usr01 INTO @ms_usr01 WHERE bname = @sy-uname.
  ENDMETHOD.

  METHOD /ctdi/if_repair_print_provider~print.
    DATA: lv_fm_name      TYPE rs38l_fnam,
          ls_outputparams TYPE sfpoutputparams,
          ls_docparams    TYPE sfpdocparams.

    " Ensure header data is read
    IF ms_header IS INITIAL.
      RETURN.
    ENDIF.

    IF iv_form_type = 'S'. " Smart Forms
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
          others             = 3.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
      ENDIF.

      " Apply user printing defaults if configured
      IF ms_usr01-spld IS NOT INITIAL.
        ls_output_options-tddest   = ms_usr01-spld.
        ls_output_options-tdimmed  = ms_usr01-splg.
        ls_output_options-tddel    = ms_usr01-spda.
      ENDIF.

      " If Save as PDF is selected, retrieve OTF data instead of sending directly to spool
      IF iv_save_as_pdf = abap_true.
        ls_control_parameters-getotf    = abap_true.
        ls_control_parameters-no_dialog = abap_true.
      ENDIF.

      " Call the Smart Form FM dynamically
      CALL FUNCTION lv_ssf_fm_name
        EXPORTING
          control_parameters = ls_control_parameters
          output_options     = ls_output_options
          is_header          = ms_header
          is_customer        = ms_customer
          is_shipto          = ms_shipto
          is_project         = ms_project
        IMPORTING
          job_output_info    = ls_output_data
        TABLES
          it_items           = mt_items
        EXCEPTIONS
          formatting_error   = 1
          internal_error     = 2
          send_error         = 3
          user_canceled      = 4
          others             = 5.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
      ENDIF.

      " If Save as PDF, convert OTF to PDF and trigger local download
      IF iv_save_as_pdf = abap_true.
        lt_otf[] = ls_output_data-otfdata[].

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
            others                = 4.
        IF sy-subrc = 0.
          download_pdf( iv_repair_id = iv_repair_id
                        iv_pdf_data    = lv_pdf_xstring ).
        ELSE.
          RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
        ENDIF.
      ENDIF.

    ELSE. " Adobe Forms (iv_form_type = 'A' or default)

      " 2. Initialize Output Parameters (Standard SAP Interactive/Adobe Forms logic)
      ls_outputparams-connection = 'ADS'.       " Adobe Document Services default connection
      ls_outputparams-nodialog   = abap_true.   " Suppress print dialog for automated printing
      ls_outputparams-preview    = abap_true.    " Enable print preview

      " Apply user printing defaults if configured
      IF ms_usr01-spld IS NOT INITIAL.
        ls_outputparams-dest   = ms_usr01-spld.
        ls_outputparams-reqimm = ms_usr01-splg.
        ls_outputparams-reqdel = ms_usr01-spda.
      ENDIF.

      " If Save as PDF is selected, instruct ADS to return PDF data
      IF iv_save_as_pdf = abap_true.
        ls_outputparams-getpdf   = abap_true.
      ENDIF.

      " Open the printing job
      CALL FUNCTION 'FP_JOB_OPEN'
        CHANGING
          ie_outputparams = ls_outputparams
        EXCEPTIONS
          cancel          = 1
          usage_error     = 2
          system_error    = 3
          internal_error  = 4
          others          = 5.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
      ENDIF.

      " 3. Retrieve the dynamic PDF/Adobe function module name generated for the form
      TRY.
          CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
            EXPORTING
              i_name     = iv_form_name
            IMPORTING
              e_funcname = lv_fm_name.
        CATCH cx_root.
          " Ensure job is closed in case of error
          CALL FUNCTION 'FP_JOB_CLOSE'.
          RETURN.
      ENDTRY.

      " 4. Call the Adobe Form generated function module dynamically
      " Docparams controls language and country configurations
      ls_docparams-langu   = sy-langu.
      ls_docparams-country = 'US'.

      CALL FUNCTION lv_fm_name
        EXPORTING
          /1bcdwb/docparams = ls_docparams
          " Pass header, items, customer, ship-to partner, and project details to the form
          is_header         = ms_header
          it_items          = mt_items
          is_customer       = ms_customer
          is_shipto         = ms_shipto
          is_project        = ms_project
        EXCEPTIONS
          usage_error       = 1
          system_error      = 2
          internal_error    = 3
          others            = 4.

      DATA(lv_subrc) = sy-subrc.

      " 5. Close the printing job
      DATA: ls_joboutput TYPE sfpjoboutput.

      CALL FUNCTION 'FP_JOB_CLOSE'
        IMPORTING
          e_joboutput    = ls_joboutput
        EXCEPTIONS
          usage_error    = 1
          system_error   = 2
          internal_error = 3
          others         = 4.

      IF lv_subrc <> 0 OR sy-subrc <> 0.
        RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
      ENDIF.

      " If Save as PDF, trigger local download of the retrieved PDF xstring
      IF iv_save_as_pdf = abap_true AND ls_joboutput-pdf IS NOT INITIAL.
        download_pdf( iv_repair_id = iv_repair_id
                      iv_pdf_data    = ls_joboutput-pdf ).
      ENDIF.

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
        others               = 1 ).

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
          dp_error                  = 11
          access_denied             = 12
          dp_out_of_memory          = 13
          disk_full                 = 14
          dp_timeout                = 15
          file_not_found            = 16
          dataprovider_exception    = 17
          control_flush_error       = 18
          others                    = 19 ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
