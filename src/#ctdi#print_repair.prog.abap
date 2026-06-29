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

"! <h1>Repair Printout Orchestrator</h1>
"! <p>This report serves as the entry point and routing manager for repair reports.</p>
"!
"! <h2>Routing &amp; Determination Flow</h2>
"! <ul>
"!   <li>Reads customizing from <code>/CTDI/REP_FORMS</code>.</li>
"!   <li>Determines the form layout and dynamic print driver class using a fallback sequence.</li>
"!   <li>Instantiates the resolved class and executes its print routine.</li>
"!   <li>If no configuration is found, falls back to legacy printing (<code>print_old</code> in <code>/CELLAG/ALCAREP02</code>).</li>
"! </ul>
"!
"! <h2>How to Extend Data Logic</h2>
"! <ol>
"!   <li>Create a new print driver class inheriting from <code>/CTDI/CL_PRINT_DRIVER_BASE</code>.</li>
"!   <li>Implement/redefine action hook methods:
"!     <ul>
"!       <li><code>unpack_io_data</code>: Unpack input parameters.</li>
"!       <li><code>fetch_data_from_db</code>: Retrieve data from tables.</li>
"!       <li><code>map_and_register_data</code>: Map data and register form parameters.</li>
"!     </ul>
"!   </li>
"!   <li>Register form parameters using <code>register_custom_parameter</code>, specifying the parameter kind (e.g. <code>abap_func_exporting</code>).</li>
"! </ol>
"!
"! <h2>How to Extend Process Logic</h2>
"! <ol>
"!   <li>Add/modify customizing entries in <code>/CTDI/REP_FORMS</code> via <code>SM30</code>.</li>
"!   <li>Define layout name (Smart Form / Adobe Form) and assign your driver class.</li>
"! </ol>

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
        MESSAGE e001(00) WITH TEXT-005 p_aufnr
                         INTO lv_emsg.
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_driver_err).
        " SECURITY: Do not expose raw exception text to the UI to prevent info leakage
        /ctdi/cl_print_driver_log=>log_exception( lx_driver_err ).
        MESSAGE e001(00) WITH TEXT-007
                         INTO lv_emsg.
      CATCH cx_root INTO DATA(lx_root).
        " SECURITY: Do not expose raw exception text to the UI to prevent info leakage
        /ctdi/cl_print_driver_log=>log_exception( lx_root ).
        MESSAGE e001(00) WITH TEXT-007
                         INTO lv_emsg.
    ENDTRY.

    IF lv_emsg IS NOT INITIAL.
      /ctdi/cl_print_driver_log=>log_error( lv_emsg ).
    ENDIF.

    IF p_shwlog = abap_true.
      /ctdi/cl_print_driver_log=>show_log( ).
      IF lv_emsg IS INITIAL.
        MESSAGE TEXT-008 TYPE 'S'.
      ENDIF.
    ELSE.
      IF lv_emsg IS NOT INITIAL.
        MESSAGE lv_emsg TYPE 'S' DISPLAY LIKE 'E'.
      ELSE.
        MESSAGE TEXT-008 TYPE 'S'.
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  lcl_app=>run( ).
