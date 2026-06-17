*&---------------------------------------------------------------------*
*----------------------------------------------------------------------*
* Report  /CTDI/PRINT_REPAIR
*
*----------------------------------------------------------------------*
* Transaktion                                                          *
* Datum           16.06.2026                                           *
*----------------------------------------------------------------------*
* Firma               CTDI GmbH Malsch Headquarter
*
* Beschreibung:  1.) Repair Printouts
*                2.)
*                3.)
*----------------------------------------------------------------------*
* Anforderer: Felix
* Ticket....: 2508-077
* Konzept...: MZ
* Betreuung.: MZ
*----------------------------------------------------------------------*
* Entwickler...: nhs003381 - sbozbuga                                  *
*                                                                      *
*----------------------------------------------------------------------*

************************************************************************
******************** !!!ACHTUNG BITTE BEACHTEN!!! **********************
************************************************************************
* !!!      Keine Korrekturen oder Erweiterungen ohne Absprache     !!! *
* !!!      mit der Anwendungsentwicklung                           !!! *
*----------------------------------------------------------------------*
* !!! Keine Korrekturen/Erweiterung ohne Dokumentation in Historie !!! *
************************************************************************
* Änderungshistorie                                                    *
*                                                                      *
* Datum      Entwickler  Bemerkung                                     *
* xx.xx.xxxx ???         ???
*----------------------------------------------------------------------*
REPORT /ctdi/print_repair.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_aufnr TYPE aufk-aufnr OBLIGATORY, " Repair / Order ID
            p_sernr TYPE equi-sernr,           " Serial number (optional)
            p_sf    TYPE sap_bool NO-DISPLAY.  " Save as PDF
SELECTION-SCREEN END OF BLOCK b1.

START-OF-SELECTION.
  PERFORM entry.

*--------------------------------------------------------------------*
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

    CATCH /ctdi/cx_no_config_found INTO DATA(lx_noconf).
      MESSAGE e001(00) WITH 'No configuration found in /CTDI/REP_FORMS for Order' p_aufnr
                       INTO DATA(lv_emsg) .
    CATCH /ctdi/cx_print_driver_error INTO DATA(lx_driver_err).
      lv_emsg = lx_driver_err->message.
    CATCH cx_root INTO DATA(lx_root).
      MESSAGE e001(00) WITH 'An unexpected system error occurred'
                       INTO lv_emsg.
  ENDTRY.

  /ctdi/cl_print_driver_log=>log_error( lv_emsg ).
  /ctdi/cl_print_driver_log=>save_log( ).

  IF lv_emsg IS NOT INITIAL.
    MESSAGE lv_emsg TYPE 'E'.
  ELSE.
    MESSAGE 'Printout generated successfully' TYPE 'S'.
  ENDIF.
ENDFORM.
