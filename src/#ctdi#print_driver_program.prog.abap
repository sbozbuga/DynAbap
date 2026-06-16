*&---------------------------------------------------------------------*
*& Report /CTDI/PRINT_DRIVER_PROGRAM (Template for /CELLAG/ALCAREP02)
*&---------------------------------------------------------------------*
*& Ultimate drop-in replacement for the legacy print program.
*& Supports both standalone UI execution and NACE subroutine execution
*& (entry_sf and entry_pdf).
*&---------------------------------------------------------------------*
REPORT /ctdi/print_driver_program.

*&---------------------------------------------------------------------*
*& Selection Screen (Standalone Mode)
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_aufnr TYPE aufk-aufnr OBLIGATORY,      " Repair / Order ID
            p_sernr TYPE equi-sernr,                 " Serial number (optional)
            p_sf    TYPE sap_bool NO-DISPLAY.        " Save as PDF (Legacy naming for external callers)
SELECTION-SCREEN END OF BLOCK b1.

*&---------------------------------------------------------------------*
*& START-OF-SELECTION (Standalone UI Execution)
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM entry.

*&---------------------------------------------------------------------*
*& Form ENTRY
*&---------------------------------------------------------------------*
* NACE / Standalone Entry point
*----------------------------------------------------------------------*
FORM entry.
  TRY.
      DATA(lr_driver) = /ctdi/cl_print_driver_base=>factory(
                          iv_repair_id = p_aufnr
                          iv_sernr     = p_sernr ).

      " In legacy ALCAREP02, p_sf = 'X' means "Spool mode" (do NOT download PDF).
      " Also, if called from transaction IW42, it defaults to Spool mode.
      " Therefore, save_as_pdf is TRUE only if p_sf is empty AND tcode is not IW42.
      DATA(lv_save_as_pdf) = xsdbool( p_sf = abap_false AND sy-tcode <> 'IW42' ).

      lr_driver->execute( iv_save_as_pdf = lv_save_as_pdf ).

      " Normal exit: explicitly save logs
      /ctdi/cl_print_driver_log=>save_log( ).

    CATCH /ctdi/cx_no_config_found.
      /ctdi/cl_print_driver_log=>save_log( ).
      MESSAGE |No configuration found in /CTDI/REP_FORMS for Order { p_aufnr }| TYPE 'E'.

    CATCH /ctdi/cx_print_driver_error INTO DATA(lx_driver_err).
      /ctdi/cl_print_driver_log=>log_exception( lx_driver_err ).
      /ctdi/cl_print_driver_log=>save_log( ).
      MESSAGE lx_driver_err->get_text( ) TYPE 'E'.

    CATCH cx_root INTO DATA(lx_root).
      /ctdi/cl_print_driver_log=>log_exception( lx_root ).
      /ctdi/cl_print_driver_log=>save_log( ).
      MESSAGE 'An unexpected system error occurred' TYPE 'E'.
  ENDTRY.
ENDFORM.
