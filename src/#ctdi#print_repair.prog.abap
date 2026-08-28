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
TYPE-POOLS icon.
TABLES sscrfields.

SELECTION-SCREEN FUNCTION KEY 1.
SELECTION-SCREEN FUNCTION KEY 2.
SELECTION-SCREEN FUNCTION KEY 3.
SELECTION-SCREEN FUNCTION KEY 4.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_aufnr TYPE aufk-aufnr OBLIGATORY, " Repair / Order ID
            p_sernr TYPE equi-sernr.           " Serial number (optional)

SELECTION-SCREEN SKIP.

SELECTION-SCREEN END OF BLOCK b1.
SELECTION-SCREEN BEGIN OF BLOCK b_img WITH FRAME TITLE TEXT-020.
PARAMETERS: p_imgdef RADIOBUTTON GROUP rimg DEFAULT 'X', " Default (Project Customizing)
            p_imgyes RADIOBUTTON GROUP rimg,              " Force Append Images
            p_imgno  RADIOBUTTON GROUP rimg.              " Force Suppress Images
SELECTION-SCREEN END OF BLOCK b_img.

SELECTION-SCREEN BEGIN OF BLOCK b_ren WITH FRAME TITLE TEXT-021.
PARAMETERS: p_rawpdf RADIOBUTTON GROUP rren DEFAULT 'X', " Raw PDF (built-in renderer)
            p_adspdf RADIOBUTTON GROUP rren.              " ADS Form (Adobe render)
SELECTION-SCREEN END OF BLOCK b_ren.

SELECTION-SCREEN BEGIN OF BLOCK b1a WITH FRAME.
PARAMETERS: p_shwlog TYPE sap_bool AS CHECKBOX, " Show logs
            p_sf     TYPE sap_bool NO-DISPLAY.  "Spool
SELECTION-SCREEN END OF BLOCK b1a.
" ---------------------------------------------------------------------
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS run.
    CLASS-METHODS fcodes.
  PRIVATE SECTION.
    CLASS-METHODS view_maintenance_call
      IMPORTING iv_tabname TYPE dd02v-tabname.
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

        " Set image render mode from selection screen
        lr_driver->set_img_render_mode( COND #(
          WHEN p_adspdf = abap_true THEN /ctdi/cl_print_gos_images=>gc_render_ads
          ELSE /ctdi/cl_print_gos_images=>gc_render_raw ) ).

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
  METHOD fcodes.
    CASE sscrfields-ucomm.
      WHEN 'FC02'.
        view_maintenance_call( '/CTDI/REP_PROJEC' ).
      WHEN 'FC03'.
        view_maintenance_call( '/CTDI/REP_FORMS' ).
      WHEN 'FC04'.
        view_maintenance_call( '/CTDI/REP_RESULT' ).
      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.
  METHOD view_maintenance_call.
    DATA: lv_action TYPE c LENGTH 1 VALUE 'U'. " 'U' for Update / Maintain, 'S' for Display / Show

    CALL FUNCTION 'VIEW_MAINTENANCE_CALL'
      EXPORTING
        action                       = lv_action
        view_name                    = iv_tabname
      EXCEPTIONS
        client_reference             = 1
        foreign_lock                 = 2
        invalid_action               = 3
        no_clientindependent_auth    = 4
        no_database_function         = 5
        no_editor_function           = 6
        no_show_auth                 = 7
        no_tvdir_entry               = 8
        no_upd_auth                  = 9
        only_show_allowed            = 10
        system_failure               = 11
        unknown_field_in_dba_sellist = 12
        view_not_found               = 13
        maintenance_prohibited       = 14
        OTHERS                       = 15.

    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

INITIALIZATION.
  sscrfields-functxt_01 = ' | '. "seperator
  sscrfields-functxt_02 = |@PR@ { TEXT-038 }|. " Project
  sscrfields-functxt_03 = |@0R@ { TEXT-039 }|. " Forms
  sscrfields-functxt_04 = |@0Q@ { TEXT-040 }|. " Results

AT SELECTION-SCREEN.
  lcl_app=>fcodes( ).

START-OF-SELECTION.
  lcl_app=>run( ).
