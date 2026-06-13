*&---------------------------------------------------------------------*
*& Report /CTDI/PRINT_DRIVER_PROGRAM
*&---------------------------------------------------------------------*
*& Print Driver — NAST Output Determination Wrapper + Standalone Mode
*&
*& Integrates with standard SAP print workbench (NACE / TNAPR) and
*& supports standalone execution via SE38 / SA38.
*&
*& Supports both Smart Forms and Adobe Forms via the dynamic OO
*& print driver framework (/CTDI/CL_PRINT_DRIVER_ENGINE).
*&---------------------------------------------------------------------*
REPORT /ctdi/print_driver_program.

" Global NAST/TNAPR structures — populated by SAP output determination
TABLES: nast, tnapr.

*&---------------------------------------------------------------------*
*& Selection Screen (Standalone Mode)
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_aufnr TYPE aufk-aufnr OBLIGATORY,      " Repair / Order ID
            p_sernr TYPE equi-sernr,                   " Serial number (optional)

            p_pdf   AS CHECKBOX DEFAULT ' '.           " Save as PDF
PARAMETERS: p_sf    type abap_bool NO-DISPLAY.            " Legacy compat flag
SELECTION-SCREEN END OF BLOCK b1.

*&---------------------------------------------------------------------*
*& START-OF-SELECTION (Standalone Execution)
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM run_standalone.

*&---------------------------------------------------------------------*
*& Form ENTRY — NACE Output Determination Callback
*&---------------------------------------------------------------------*
* Called by standard SAP message control (NACE) via TNAPR configuration.
* NAST-OBJKY contains the source document / repair number.
*----------------------------------------------------------------------*
FORM entry USING ent_retco TYPE sysubrc
                 ent_screen TYPE c.

  DATA: lv_repair_id TYPE aufnr.

  " Clear return code
  ent_retco = 0.

  " Guard: NAST must be populated
  IF nast-objky IS INITIAL.
    ent_retco = 4.
    RETURN.
  ENDIF.

  " Normalize the repair ID
  lv_repair_id = |{ nast-objky ALPHA = IN }|.

  /ctdi/cl_print_driver_log=>log_info(
    |NAST entry triggered for Repair { lv_repair_id }| ).

  TRY.
      DATA(lr_driver) = /ctdi/cl_print_driver_base=>factory( lv_repair_id ).
      lr_driver->execute(
        EXPORTING
          iv_save_as_pdf = abap_false ).       " NACE always prints to spool

      " Mark NAST as successfully processed (vstat = '2')
      nast-vstat   = '2'.
      /ctdi/cl_print_driver_log=>log_info(
        |NAST protocol: Output { lv_repair_id } marked as successful| ).

    CATCH /ctdi/cx_no_config_found.
      " Fall back to legacy printing logic
      PERFORM print_old USING lv_repair_id abap_false.

    CATCH /ctdi/cx_print_driver_error INTO DATA(lx_driver_err).
      /ctdi/cl_print_driver_log=>log_exception( lx_driver_err ).

      " Store the error via MESSAGE for the NACE output protocol
      MESSAGE ID '/CTDI/PRINT' TYPE 'E' NUMBER '001'
        WITH lx_driver_err->get_text( )
        INTO sy-msgli.
      CALL FUNCTION 'MESSAGE_STORE'
        EXPORTING
          arbgb  = '/CTDI/PRINT'
          msgnr  = '001'
          msgty  = 'E'
          msgv1  = sy-msgv1
          msgv2  = sy-msgv2
          msgv3  = sy-msgv3
          msgv4  = sy-msgv4
          txtnr  = '001'
        EXCEPTIONS
          OTHERS = 1.
      IF sy-subrc <> 0.
        " Muted
      ENDIF.

      " Reset NAST to 'New' (vstat = '0') so the output is retried
      " on the next NACE scheduling run instead of remaining stuck
      " in error status.
      nast-vstat         = '0'.
      nast-anzal         = 0.
      /ctdi/cl_print_driver_log=>log_warning(
        |NAST protocol: Output { lv_repair_id } reset to New for retry| ).
      ent_retco = 4.

    CATCH cx_root INTO DATA(lx_root).
      /ctdi/cl_print_driver_log=>log_exception( lx_root ).
      ent_retco = 4.
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form RUN_STANDALONE
*&---------------------------------------------------------------------*
FORM run_standalone.


  TRY.
      " Read data using the specific data provider extension (allows passing manual parameters like p_sernr)
      DATA(lr_data) = NEW /ctdi/cl_print_data_legacy_ext( ).
      lr_data->read_data( iv_aufnr = p_aufnr
                          iv_sernr = p_sernr ).

      DATA(lr_driver) = /ctdi/cl_print_driver_base=>factory( p_aufnr ).
      lr_driver->execute(
        EXPORTING
          iv_save_as_pdf = p_pdf
          io_data        = lr_data ).

      MESSAGE |Print completed successfully for { p_aufnr }| TYPE 'S'.

    CATCH /ctdi/cx_no_config_found.
      " Fall back to legacy printing logic
      PERFORM print_old USING p_aufnr p_pdf.

    CATCH /ctdi/cx_print_driver_error INTO DATA(lx_driver_err).
      DATA(lv_msg) = |{ 'Print failed: &1'(003) }|.
      REPLACE '&1' IN lv_msg WITH lx_driver_err->message.
      /ctdi/cl_print_driver_log=>log_exception( lx_driver_err ).
      MESSAGE lv_msg TYPE 'E'.

    CATCH cx_root INTO DATA(lx_root).
      lv_msg = |{ 'Unexpected error: &1'(004) }|.
      REPLACE '&1' IN lv_msg WITH lx_root->get_text( ).
      /ctdi/cl_print_driver_log=>log_exception( lx_root ).
      MESSAGE lv_msg TYPE 'E'.
  ENDTRY.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form PRINT_OLD
*&---------------------------------------------------------------------*
*& Fallback legacy printing routine
*&---------------------------------------------------------------------*
FORM print_old USING iv_repair_id TYPE aufnr
                     iv_save_as_pdf TYPE abap_bool.

  DATA(lv_legacy_msg) = |{ 'Executing legacy printing routine (print_old) for repair &1'(006) }|.
  REPLACE '&1' IN lv_legacy_msg WITH iv_repair_id.
  MESSAGE lv_legacy_msg TYPE 'I'.

ENDFORM.
