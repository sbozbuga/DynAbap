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
* Beschreibung:  Dynamic Routing and Execution Orchestrator for Repair
*                Printouts.
*                NOTE: This report is built upon the logic of the legacy
*                report /CELLAG/ALCAREP02, extending it with flexible
*                routing capabilities. Once the testing phase is
*                successfully completed, this framework is intended to
*                replace /CELLAG/ALCAREP02 entirely.
*
*                Routing & Determination Flow:
*                - Reads customizing configurations from /CTDI/REP_FORMS.
*                - Resolves the form layout and print driver class using
*                  a fallback access sequence.
*
*                How to Extend Data Logic:
*                1. Create a new subclass inheriting from base class
*                   /CTDI/CL_PRINT_DRIVER_BASE.
*                2. Redefine and implement protected action hook methods:
*                   - unpack_io_data: Extract and unpack parameters.
*                   - fetch_data_from_db: Retrieve required database data.
*                   - map_and_register_data: Map fields & register
*                     parameters.
*                3. Register custom parameters in map_and_register_data
*                   via register_custom_parameter, passing the explicit
*                   parameter kind to avoid slow runtime DB lookups.
*
*                How to Extend Process Logic:
*                1. Maintain configurations in /CTDI/REP_FORMS via SM30.
*                2. Define form layout name and assign your new class.
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
PARAMETERS: p_aufnr  TYPE aufk-aufnr OBLIGATORY, " Repair / Order ID
            p_sernr  TYPE equi-sernr,           " Serial number (optional)
            p_shwlog TYPE sap_bool AS CHECKBOX, " Show logs
            p_sf     TYPE sap_bool NO-DISPLAY.  " Save as PDF
SELECTION-SCREEN END OF BLOCK b1.

*--------------------------------------------------------------------*
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS run.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.
  METHOD run.
    DATA lv_emsg TYPE string.

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
        " Missing configuration — this is now a real error, not a fallback
        /ctdi/cl_print_driver_log=>log_exception( lx_noconf ).
        IF lx_noconf->message IS NOT INITIAL.
          lv_emsg = lx_noconf->message.
        ELSE.
          MESSAGE e001(00) WITH TEXT-005 p_aufnr INTO lv_emsg.
        ENDIF.

      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_driver_err).
        " Business error — log full chain, show driver's message if available
        /ctdi/cl_print_driver_log=>log_exception( lx_driver_err ).
        IF lx_driver_err->message IS NOT INITIAL.
          lv_emsg = lx_driver_err->message.
        ELSE.
          MESSAGE e001(00) WITH TEXT-007 INTO lv_emsg.
        ENDIF.

      CATCH cx_root INTO DATA(lx_root).
        " Safety net for unexpected errors — keep for production stability
        /ctdi/cl_print_driver_log=>log_exception( lx_root ).
        MESSAGE e001(00) WITH TEXT-007 INTO lv_emsg.
    ENDTRY.

    IF lv_emsg IS NOT INITIAL.
      /ctdi/cl_print_driver_log=>log_error( lv_emsg ).
    ENDIF.

    IF p_shwlog = abap_true.
      /ctdi/cl_print_driver_log=>show_log( ).
    ENDIF.

    IF lv_emsg IS NOT INITIAL.
      MESSAGE lv_emsg TYPE 'S' DISPLAY LIKE 'E'.
    ELSE.
      MESSAGE TEXT-008 TYPE 'S'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  lcl_app=>run( ).
