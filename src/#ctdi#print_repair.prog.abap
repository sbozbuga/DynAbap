" & ----------------------------------------------------------------------
" -----------------------------------------------------------------------
" Report  /CTDI/PRINT_REPAIR
" -----------------------------------------------------------------------
" Transaktion                                                          -
" Datum           16.06.2026                                           -
" -----------------------------------------------------------------------
" Firma          CTDI GmbH Malsch Headquarter
"
" Beschreibung:
"   Dynamic Routing and Execution Orchestrator for Repair Printouts.
"   Built upon the logic of /CELLAG/ALCAREP02, extending it with
"   flexible routing capabilities.
"
"   Routing & Determination Flow:
"   - Reads customizing configurations from /CTDI/REP_FORMS.
"   - Resolves the form layout and print driver class using a fallback
"     access sequence.
"
"   How to Extend Data Logic:
"   1. Create a new subclass inheriting from /CTDI/CL_PRINT_DRIVER_BASE.
"   2. Redefine protected action hook methods:
"      - unpack_io_data: Extract and unpack parameters.
"      - fetch_data_from_db: Retrieve required database data.
"      - map_and_register_data: Map fields & register parameters.
"   3. Register custom parameters in map_and_register_data via
"      register_custom_parameter.
"
"   How to Extend Process Logic:
"   1. Maintain configurations in /CTDI/REP_FORMS via SM30.
"   2. Define form layout name and assign your new class.
" -----------------------------------------------------------------------
" Anforderer: Felix
" Ticket....: 2508-077
" Konzept...: MZ
" Betreuung.: MZ
" -----------------------------------------------------------------------
" Entwickler...: NHS003381 - SBOZBUGA                                  -
"                                                                      -
" -----------------------------------------------------------------------

" -----------------------------------------------------------------------
" !!!ACHTUNG BITTE BEACHTEN!!! ----------------------
" -----------------------------------------------------------------------
" !!!      Keine Korrekturen oder Erweiterungen ohne Absprache     !!! -
" !!!      mit der Anwendungsentwicklung                           !!! -
" -----------------------------------------------------------------------
" !!! Keine Korrekturen/Erweiterung ohne Dokumentation in Historie !!! -
" -----------------------------------------------------------------------
" Änderungshistorie                                                    -
"                                                                      -
" Datum      Entwickler  Bemerkung                                     -
" xx.xx.xxxx ???         ???
" -----------------------------------------------------------------------
REPORT /ctdi/print_repair.

TABLES sscrfields.

SELECTION-SCREEN FUNCTION KEY 1.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_aufnr TYPE aufk-aufnr OBLIGATORY, " Repair / Order ID
            p_sernr TYPE equi-sernr.           " Serial number (optional)

SELECTION-SCREEN BEGIN OF BLOCK b_img WITH FRAME TITLE TEXT-020.
PARAMETERS: p_imgdef RADIOBUTTON GROUP r_img DEFAULT 'X', " Default (Project Customizing)
            p_imgyes RADIOBUTTON GROUP r_img,              " Force Append Images
            p_imgno  RADIOBUTTON GROUP r_img.              " Force Suppress Images
SELECTION-SCREEN END OF BLOCK b_img.

SELECTION-SCREEN BEGIN OF BLOCK b1a WITH FRAME.
PARAMETERS: p_shwlog TYPE sap_bool AS CHECKBOX, " Show logs
            p_sf     TYPE sap_bool NO-DISPLAY.  " Save as PDF
SELECTION-SCREEN END OF BLOCK b1a.
SELECTION-SCREEN END OF BLOCK b1.
" ---------------------------------------------------------------------
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS run.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.
  METHOD run.
    DATA lv_emsg TYPE string.

    TRY.
        DATA(lv_append_override) = COND char1(
          WHEN p_imgyes = abap_true THEN /ctdi/cl_print_driver_base=>gc_img_override_yes
          WHEN p_imgno  = abap_true THEN /ctdi/cl_print_driver_base=>gc_img_override_no
          ELSE /ctdi/cl_print_driver_base=>gc_img_override_default ).

        DATA(lr_driver) = /ctdi/cl_print_driver_base=>factory(
          iv_repair_id     = p_aufnr
          iv_sernr         = p_sernr
          iv_append_images = lv_append_override ).

        " In legacy ALCAREP02, p_sf = 'X' means "Spool mode" (do NOT download PDF).
        " Also, if called from transaction IW42, it defaults to Spool mode.
        " Therefore, save_as_pdf is TRUE only if p_sf is empty AND tcode is not IW42.
        DATA(lv_save_as_pdf) = xsdbool( p_sf = abap_false AND sy-tcode <> 'IW42' ).

        lr_driver->execute( iv_save_as_pdf = lv_save_as_pdf ).

      CATCH /ctdi/cx_no_config_found INTO DATA(lx_noconf).
        lv_emsg = lx_noconf->get_text( ).

      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_driver_err).
        lv_emsg = lx_driver_err->get_text( ).

      CATCH cx_root INTO DATA(lx_root).
        /ctdi/cl_print_driver_log=>log_exception( lx_root ).
        lv_emsg = lx_root->get_text( ).
    ENDTRY.

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

INITIALIZATION.
  sscrfields-functxt_01 = |@HB@ { TEXT-009 }|. " Mass Print

AT SELECTION-SCREEN.
  IF sscrfields-ucomm = 'FC01'.
    SUBMIT /ctdi/print_repair_mass VIA SELECTION-SCREEN AND RETURN.
  ENDIF.

START-OF-SELECTION.
  lcl_app=>run( ).
