" -----------------------------------------------------------------------
" Report  /CTDI/PRINT_REPAIR_MASS
" -----------------------------------------------------------------------
" Transaktion                                                          -
" Datum           17.08.2026                                           -
" -----------------------------------------------------------------------
" Firma          CTDI GmbH Malsch Headquarter
"
" Beschreibung:
"   Mass Print for Repair Orders.
"   Selects repair orders based on filters, displays them in an ALV
"   with checkboxes, and allows the user to print selected orders
"   using the /CTDI/CL_PRINT_DRIVER_BASE framework.
"
" -----------------------------------------------------------------------
" Anforderer: Felix
" Ticket....: 2508-077
" Konzept...: MZ
" Betreuung.: MZ
" -----------------------------------------------------------------------
" Entwickler...: NHS003381 - SBOZBUGA                                  -
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
" 17.08.2026 SBOZBUGA    Initial version — mass print with ALV
" -----------------------------------------------------------------------
REPORT /ctdi/print_repair_mass.

" -----------------------------------------------------------------------
" Global Data for SELECT-OPTIONS references
" -----------------------------------------------------------------------
TYPE-POOLS icon.
SELECTION-SCREEN FUNCTION KEY 1.
SELECTION-SCREEN FUNCTION KEY 2.
SELECTION-SCREEN FUNCTION KEY 3.
SELECTION-SCREEN FUNCTION KEY 4.

TABLES: aufk, afru, qmel, vbak, sscrfields.
DATA gv_contr TYPE jvbelncontract.

" -----------------------------------------------------------------------
" Selection Screen
" -----------------------------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
SELECT-OPTIONS: s_aufnr FOR aufk-aufnr,                 " Repair Order
                s_kdauf FOR aufk-kdauf NO-DISPLAY,                 " Sales Order
                s_contr FOR gv_contr NO-DISPLAY,                   " Contract
                s_qmnum FOR qmel-qmnum NO-DISPLAY,                " Notification
                s_auart FOR aufk-auart DEFAULT 'ZM03' NO-DISPLAY,  " Order Type
                s_werks FOR aufk-werks NO-DISPLAY,                 " Plant
                s_erdat FOR aufk-erdat NO-DISPLAY,                 " Creation Date
                s_vornr FOR afru-vornr DEFAULT '9010' NO-DISPLAY,  " Operation (WFER)
                s_qmart FOR qmel-qmart NO-DISPLAY.                 " QM Notification Type
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE TEXT-036.
PARAMETERS: p_images AS CHECKBOX.                        " Append GOS Images
SELECTION-SCREEN SKIP.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-018.
PARAMETERS: p_indiv RADIOBUTTON GROUP spl DEFAULT 'X',  " Individual Spool
            p_bundl RADIOBUTTON GROUP spl,              " Bundled Spool (per form type)
            p_merge RADIOBUTTON GROUP spl.              " Merged Spool (single PDF)
SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN BEGIN OF BLOCK b5 WITH FRAME TITLE TEXT-037.
PARAMETERS: p_rawpdf RADIOBUTTON GROUP rren, " Raw PDF (built-in renderer)
            p_adspdf RADIOBUTTON GROUP rren DEFAULT 'X'.              " ADS Form (Adobe render)
SELECTION-SCREEN END OF BLOCK b5.
SELECTION-SCREEN END OF BLOCK b4.



" -----------------------------------------------------------------------
" ALV output structure
" -----------------------------------------------------------------------
TYPES: BEGIN OF ty_alv_line,
         icon        TYPE icon_d,         " Status icon
         icon_img    TYPE icon_d,         " Image attachment icon
         aufnr       TYPE aufnr,          " Repair Order
         auart       TYPE aufart,         " Order Type
         erdat       TYPE auferfdat,      " Creation Date
         werks       TYPE werks_d,        " Plant
         ktext       TYPE auftext,        " Order short text
         kdauf       TYPE kdauf,          " Sales Order
         contract_id TYPE jvbelncontract, " Contract
         qmnum       TYPE qmnum,          " Notification (QMEL)
         qmart       TYPE qmart,          " Notification Type
         skz         TYPE bemot,          " SKZ (Confirmation reason)
         akz         TYPE qmcod,          " AKZ (QM Code)
         form_name   TYPE fpname,         " Form Name
         form_type   TYPE char1,          " Form Type (S=SmartForm, A=Adobe)
         msg         TYPE string,         " Message (success/error)
       END OF ty_alv_line.

TYPES: BEGIN OF ty_step,
         vbeln TYPE vbeln_va,
         skz   TYPE bemot,
         akz   TYPE char4,
       END OF ty_step.
TYPES ty_step_tab TYPE STANDARD TABLE OF ty_step WITH EMPTY KEY.

" -----------------------------------------------------------------------
" Main Application Class
" -----------------------------------------------------------------------
CLASS lcl_mass_print DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS run.

  PRIVATE SECTION.
    CONSTANTS c_mode_individual TYPE i VALUE 1.
    CONSTANTS c_mode_bundled    TYPE i VALUE 2.
    CONSTANTS c_mode_merged     TYPE i VALUE 3.

    CLASS-DATA gt_alv        TYPE TABLE OF ty_alv_line.
    CLASS-DATA go_salv       TYPE REF TO cl_salv_table.
    CLASS-DATA gv_spool_mode TYPE i.

    CLASS-METHODS select_orders.
    CLASS-METHODS resolve_form_types.
    CLASS-METHODS display_alv.
    CLASS-METHODS toggle_spool_mode.

    CLASS-METHODS on_user_command FOR EVENT added_function OF cl_salv_events_table
      IMPORTING e_salv_function.

    CLASS-METHODS on_double_click FOR EVENT double_click OF cl_salv_events_table
      IMPORTING !row !column.

    CLASS-METHODS on_link_click FOR EVENT link_click OF cl_salv_events_table
      IMPORTING !row !column.

    CLASS-METHODS execute_print
      IMPORTING it_rows        TYPE salv_t_row
                iv_save_as_pdf TYPE abap_bool
                iv_merge       TYPE abap_bool DEFAULT abap_false
      EXPORTING ev_ok          TYPE i
                ev_err         TYPE i.

    CLASS-METHODS execute_print_bundled
      IMPORTING it_rows  TYPE salv_t_row
                iv_merge TYPE abap_bool DEFAULT abap_false
      EXPORTING ev_ok    TYPE i
                ev_err   TYPE i.

    CLASS-METHODS execute_pdf_merge_ads
      IMPORTING it_rows TYPE salv_t_row
      EXPORTING ev_ok   TYPE i
                ev_err  TYPE i.

    CLASS-METHODS execute_preview
      IMPORTING iv_row TYPE i.

    CLASS-METHODS all_adobe
      IMPORTING it_rows          TYPE salv_t_row
      RETURNING VALUE(rv_result) TYPE abap_bool.

    CLASS-METHODS download_pdf_file
      IMPORTING iv_pdf_data  TYPE xstring
                iv_filename  TYPE string
                iv_prompt    TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    CLASS-METHODS show_summary
      IMPORTING iv_ok  TYPE i
                iv_err TYPE i.

    CLASS-METHODS build_error_msg
      IMPORTING ix_error      TYPE REF TO cx_root
      RETURNING VALUE(rv_msg) TYPE string.

    CLASS-METHODS show_progress
      IMPORTING iv_aufnr   TYPE aufnr
                iv_current TYPE i
                iv_total   TYPE i.

    CLASS-METHODS mark_rows_error
      IMPORTING it_lines TYPE ANY TABLE
                iv_msg   TYPE string
      CHANGING  cv_err   TYPE i.

    CLASS-METHODS print_single_order
      IMPORTING iv_aufnr       TYPE aufnr
                iv_external    TYPE abap_bool DEFAULT abap_true
                iv_collect_pdf TYPE abap_bool DEFAULT abap_false
                iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
      EXPORTING ev_pdf         TYPE xstring
      CHANGING  cs_alv         TYPE ty_alv_line
      RETURNING VALUE(rv_ok)   TYPE abap_bool.

    CLASS-METHODS resolve_printer
      RETURNING VALUE(rv_printer) TYPE rspopname.

    CLASS-METHODS navigate_to_transaction
      IMPORTING iv_tcode TYPE tcode
                iv_param TYPE memoryid
                iv_value TYPE clike.

    CLASS-METHODS build_job_error_msg
      IMPORTING iv_context    TYPE string
                iv_subrc      TYPE sy-subrc
      RETURNING VALUE(rv_msg) TYPE string.

    CLASS-METHODS send_pdf_to_spool
      IMPORTING iv_pdf       TYPE xstring
                iv_printer   TYPE rspopname
                iv_title     TYPE clike
      RETURNING VALUE(rv_ok) TYPE abap_bool.
ENDCLASS.


CLASS lcl_mass_print IMPLEMENTATION.
  METHOD run.
    select_orders( ).
    IF gt_alv IS INITIAL.
      MESSAGE TEXT-003 TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    display_alv( ).
  ENDMETHOD.

  METHOD select_orders.
    SELECT DISTINCT a~aufnr,
                    a~auart,
                    a~erdat,
                    a~werks,
                    a~ktext,
                    a~kdauf,
                    o~vgbel AS contract_id,
                    q~qmnum,
                    q~qmart,
                    f~bemot AS skz,
                    q~qmcod AS akz
      FROM aufk AS a
             INNER JOIN
               qmel AS q ON q~aufnr = a~aufnr
                 INNER JOIN
                   vbak AS o ON o~vbeln = a~kdauf
                     INNER JOIN
                       vbak AS c ON  c~vbeln = o~vgbel
                                 AND c~vbtyp = 'G'
                         LEFT OUTER JOIN
                           afru AS f ON  f~aufnr = a~aufnr
                                     AND f~stokz = @space
                                     AND f~stzhl = '00000000'

      WHERE a~aufnr IN @s_aufnr
        AND a~kdauf IN @s_kdauf
        AND a~auart IN @s_auart
        AND a~werks IN @s_werks
        AND a~erdat IN @s_erdat
        AND o~vgbel IN @s_contr
        AND f~vornr IN @s_vornr
        AND q~qmart IN @s_qmart
        AND q~qmnum IN @s_qmnum
      ORDER BY a~aufnr
      INTO TABLE @DATA(lt_orders) ##SUBRC_OK.

    " Sort and deduplicate to guarantee strictly 1 unique line per repair order in ALV:
    " Prioritize rows with active SKZ (AFRU) and primary notification (QMEL QMART 'Z2')
    SORT lt_orders BY aufnr
                      skz DESCENDING
                      qmart DESCENDING
                      qmnum DESCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_orders COMPARING aufnr.

    gt_alv = VALUE #( FOR <ls_order> IN lt_orders
                      ( icon        = icon_led_inactive
                        aufnr       = <ls_order>-aufnr
                        auart       = <ls_order>-auart
                        erdat       = <ls_order>-erdat
                        werks       = <ls_order>-werks
                        ktext       = <ls_order>-ktext
                        kdauf       = <ls_order>-kdauf
                        contract_id = <ls_order>-contract_id
                        qmnum       = <ls_order>-qmnum
                        qmart       = <ls_order>-qmart
                        skz         = <ls_order>-skz
                        akz         = <ls_order>-akz ) ).

    resolve_form_types( ).

    " Check which orders have image attachments (single DB call)
    DATA(lt_aufnr_range) = VALUE /ctdi/cl_print_gos_images=>ty_aufnr_range(
                                     FOR <ls_r> IN gt_alv
                                     ( sign = 'I' option = 'EQ' low = <ls_r>-aufnr ) ).

    DATA lt_with_attachments TYPE /ctdi/cl_print_gos_images=>ty_aufnr_tab.
    DATA(lt_with_images) = /ctdi/cl_print_gos_images=>get_orders_with_images(
                             EXPORTING it_aufnr_range      = lt_aufnr_range
                             IMPORTING et_with_attachments = lt_with_attachments ).

    LOOP AT gt_alv ASSIGNING FIELD-SYMBOL(<ls_img_check>).
      " Confirmed images (Content Server ZRS_JPG) → bitmap icon
      READ TABLE lt_with_images WITH KEY table_line = <ls_img_check>-aufnr TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        <ls_img_check>-icon_img = icon_bmp.
      ELSE.
        " GOS attachments (may include non-images) → attachment icon
        READ TABLE lt_with_attachments WITH KEY table_line = <ls_img_check>-aufnr TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          <ls_img_check>-icon_img = icon_attachment.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD resolve_form_types.
    " 1. Read all config entries from /CTDI/REP_FORMS (Customizing buffer with sorted key)
    DATA lt_config TYPE SORTED TABLE OF /ctdi/rep_forms WITH NON-UNIQUE KEY vbeln skz akz.

    SELECT * FROM /ctdi/rep_forms INTO TABLE @lt_config ##SUBRC_OK. "#EC CI_NOWHERE "#EC CI_ALL_FIELDS_NEEDED

    IF lt_config IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Get all distinct form names and check which are SmartForms (exist in STXFADM)
    DATA lt_form_names TYPE SORTED TABLE OF fpname WITH NON-UNIQUE KEY table_line.
    LOOP AT lt_config ASSIGNING FIELD-SYMBOL(<ls_cfg>).
      INSERT <ls_cfg>-form_name INTO TABLE lt_form_names.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_form_names.

    DATA lt_smartforms TYPE SORTED TABLE OF fpname WITH NON-UNIQUE KEY table_line.
    SELECT formname FROM stxfadm
      FOR ALL ENTRIES IN @lt_form_names
      WHERE formname = @lt_form_names-table_line
      INTO TABLE @lt_smartforms ##SUBRC_OK.

    " 3. For each ALV line: find matching config via 8-step fallback sequence
    LOOP AT gt_alv ASSIGNING FIELD-SYMBOL(<ls_alv>).
      DATA(lt_steps) = VALUE ty_step_tab( ( vbeln = <ls_alv>-contract_id skz = <ls_alv>-skz akz = <ls_alv>-akz )
                                          ( vbeln = <ls_alv>-contract_id skz = <ls_alv>-skz akz = '' )
                                          ( vbeln = <ls_alv>-contract_id skz = ''           akz = <ls_alv>-akz )
                                          ( vbeln = <ls_alv>-contract_id skz = ''           akz = '' )
                                          ( vbeln = ''                   skz = <ls_alv>-skz akz = <ls_alv>-akz )
                                          ( vbeln = ''                   skz = <ls_alv>-skz akz = '' )
                                          ( vbeln = ''                   skz = ''           akz = <ls_alv>-akz )
                                          ( vbeln = ''                   skz = ''           akz = '' ) ).

      LOOP AT lt_steps ASSIGNING FIELD-SYMBOL(<ls_step>). "#EC CI_NESTED
        ASSIGN lt_config[ vbeln = <ls_step>-vbeln
                          skz   = <ls_step>-skz
                          akz   = <ls_step>-akz ] TO FIELD-SYMBOL(<ls_match>).
        IF sy-subrc = 0.
          <ls_alv>-form_name = <ls_match>-form_name.
          <ls_alv>-form_type = COND #( WHEN line_exists( lt_smartforms[ table_line = <ls_match>-form_name ] )
                                       THEN 'S'
                                       ELSE 'A' ).
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD display_alv.
    DATA lo_columns    TYPE REF TO cl_salv_columns_table.
    DATA lo_events     TYPE REF TO cl_salv_events_table.
    DATA lo_selections TYPE REF TO cl_salv_selections.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = go_salv
                                CHANGING  t_table      = gt_alv ).
      CATCH cx_salv_msg INTO DATA(lx_msg).
        MESSAGE lx_msg->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    " Initialize spool mode from selection screen
    gv_spool_mode = COND #( WHEN p_merge = abap_true THEN c_mode_merged
                            WHEN p_bundl = abap_true THEN c_mode_bundled
                            ELSE                          c_mode_individual ).

    go_salv->set_screen_status( pfstatus      = 'MASS_ALV'
                                report        = sy-repid
                                set_functions = go_salv->c_functions_all ).

    lo_columns = go_salv->get_columns( ).
    lo_columns->set_optimize( abap_true ).

    TRY.
        DATA(lo_col_icon) = CAST cl_salv_column_table( lo_columns->get_column( 'ICON' ) ).
        lo_col_icon->set_short_text( CONV #( TEXT-030 ) ). " Status
        lo_col_icon->set_icon( abap_true ).
        lo_col_icon->set_alignment( if_salv_c_alignment=>centered ).

        DATA(lo_col_img) = CAST cl_salv_column_table( lo_columns->get_column( 'ICON_IMG' ) ).
        lo_col_img->set_short_text( 'Att.' ).
        lo_col_img->set_medium_text( 'Attachments' ).
        lo_col_img->set_icon( abap_true ).
        lo_col_img->set_alignment( if_salv_c_alignment=>centered ).
        lo_col_img->set_output_length( 4 ).

        DATA(lo_col_msg) = CAST cl_salv_column_table( lo_columns->get_column( 'MSG' ) ).
        lo_col_msg->set_short_text( CONV #( TEXT-006 ) ).
        lo_col_msg->set_medium_text( CONV #( TEXT-006 ) ).
        lo_col_msg->set_long_text( CONV #( TEXT-006 ) ).
        lo_col_msg->set_output_length( 40 ).
        lo_col_msg->set_fixed_header_text( 'S' ).

        DATA(lo_col_ftype) = CAST cl_salv_column_table( lo_columns->get_column( 'FORM_TYPE' ) ).
        lo_col_ftype->set_short_text( 'Type' ).
        lo_col_ftype->set_medium_text( 'Form Type' ).
        lo_col_ftype->set_long_text( 'Form Type' ).

        DATA(lo_col_fname) = CAST cl_salv_column_table( lo_columns->get_column( 'FORM_NAME' ) ).
        lo_col_fname->set_short_text( 'Form' ).
        lo_col_fname->set_medium_text( 'Form Name' ).
        lo_col_fname->set_long_text( 'Form Name' ).

        " Hotspot columns for navigation
        CAST cl_salv_column_table( lo_columns->get_column( 'AUFNR' ) )->set_cell_type( if_salv_c_cell_type=>hotspot ).
        CAST cl_salv_column_table( lo_columns->get_column( 'QMNUM' ) )->set_cell_type( if_salv_c_cell_type=>hotspot ).
        CAST cl_salv_column_table( lo_columns->get_column( 'CONTRACT_ID' ) )->set_cell_type(
                                                                               if_salv_c_cell_type=>hotspot ).
        CAST cl_salv_column_table( lo_columns->get_column( 'KDAUF' ) )->set_cell_type( if_salv_c_cell_type=>hotspot ).
      CATCH cx_salv_not_found.
    ENDTRY.

    lo_selections = go_salv->get_selections( ).
    lo_selections->set_selection_mode( if_salv_c_selection_mode=>row_column ).

    lo_events = go_salv->get_event( ).
    SET HANDLER on_user_command FOR lo_events.
    SET HANDLER on_double_click FOR lo_events.
    SET HANDLER on_link_click FOR lo_events.

    DATA(lo_display) = go_salv->get_display_settings( ).
    lo_display->set_list_header( CONV #( |{ sy-title } ({ lines( gt_alv ) })| ) ).

    go_salv->display( ).
  ENDMETHOD.

  METHOD on_user_command.
    " Handle spool mode toggle first (no row selection needed)
    IF e_salv_function = 'SPOOL_MODE'.
      toggle_spool_mode( ).
      RETURN.
    ENDIF.

    DATA(lt_rows) = go_salv->get_selections( )->get_selected_rows( ).

    IF e_salv_function = 'PREVIEW'.
      IF lt_rows IS NOT INITIAL.
        execute_preview( iv_row = lt_rows[ 1 ] ).
      ELSE.
        MESSAGE TEXT-008 TYPE 'S' DISPLAY LIKE 'W'.
      ENDIF.
      RETURN.
    ENDIF.

    IF lt_rows IS INITIAL.
      MESSAGE TEXT-008 TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA lv_count_ok  TYPE i.
    DATA lv_count_err TYPE i.

    CASE e_salv_function.
      WHEN 'PRINT_SEL'.
        CASE gv_spool_mode.
          WHEN c_mode_merged.
            execute_print_bundled( EXPORTING it_rows  = lt_rows
                                             iv_merge = abap_true
                                   IMPORTING ev_ok    = lv_count_ok
                                             ev_err   = lv_count_err ).
          WHEN c_mode_bundled.
            execute_print_bundled( EXPORTING it_rows  = lt_rows
                                             iv_merge = abap_false
                                   IMPORTING ev_ok    = lv_count_ok
                                             ev_err   = lv_count_err ).
          WHEN c_mode_individual.
            execute_print( EXPORTING it_rows        = lt_rows
                                     iv_save_as_pdf = abap_false
                           IMPORTING ev_ok          = lv_count_ok
                                     ev_err         = lv_count_err ).
        ENDCASE.

      WHEN 'PDF_SEL'.
        /ctdi/cl_print_driver_base=>set_download_dir( space ).
        execute_print( EXPORTING it_rows        = lt_rows
                                 iv_save_as_pdf = abap_true
                       IMPORTING ev_ok          = lv_count_ok
                                 ev_err         = lv_count_err ).

      WHEN 'PDF_MERGE'.
        " Always use CL_RSPO_PDF_MERGE path — includes GOS images per order
        execute_print( EXPORTING it_rows        = lt_rows
                                 iv_save_as_pdf = abap_true
                                 iv_merge       = abap_true
                       IMPORTING ev_ok          = lv_count_ok
                                 ev_err         = lv_count_err ).
    ENDCASE.

    go_salv->get_columns( )->set_optimize( abap_true ).
    go_salv->refresh( s_stable = VALUE #( row = abap_true
                                          col = abap_true ) ).
    show_summary( iv_ok  = lv_count_ok
                  iv_err = lv_count_err ).

    " Show application log (debug/diagnostics)
    /ctdi/cl_print_driver_log=>show_log( ).
  ENDMETHOD.

  METHOD on_double_click.
    IF row > 0.
      execute_preview( iv_row = row ).
    ENDIF.
  ENDMETHOD.

  METHOD on_link_click.
    ASSIGN gt_alv[ row ] TO FIELD-SYMBOL(<ls>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SET PARAMETER ID 'ANR' FIELD ''.
    SET PARAMETER ID 'RCK' FIELD ''.
    SET PARAMETER ID 'IQM' FIELD ''.
    SET PARAMETER ID 'KTN' FIELD ''.
    SET PARAMETER ID 'AUN' FIELD ''.
    CASE column.
      WHEN 'AUFNR'.
        navigate_to_transaction( iv_tcode = 'IW33'
                                 iv_param = 'ANR'
                                 iv_value = <ls>-aufnr ).
      WHEN 'QMNUM'.
        navigate_to_transaction( iv_tcode = 'IW53'
                                 iv_param = 'IQM'
                                 iv_value = <ls>-qmnum ).
      WHEN 'CONTRACT_ID'.
        navigate_to_transaction( iv_tcode = 'VA43'
                                 iv_param = 'KTN'
                                 iv_value = <ls>-contract_id ).
      WHEN 'KDAUF'.
        navigate_to_transaction( iv_tcode = 'VA03'
                                 iv_param = 'AUN'
                                 iv_value = <ls>-kdauf ).
    ENDCASE.
  ENDMETHOD.

  METHOD execute_preview.
    ASSIGN gt_alv[ iv_row ] TO FIELD-SYMBOL(<ls_line>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    TRY.
        DATA(lr_driver) = /ctdi/cl_print_driver_base=>factory( iv_repair_id = <ls_line>-aufnr ).
        lr_driver->set_append_images( p_images ).
        lr_driver->execute( iv_save_as_pdf = abap_false
                            iv_no_dialog   = abap_false
                            iv_preview     = abap_true ).
      CATCH cx_root INTO DATA(lx).
        MESSAGE lx->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD execute_print.
    CLEAR: ev_ok,
           ev_err.

    DATA lo_merger TYPE REF TO cl_rspo_pdf_merge.
    IF iv_save_as_pdf = abap_true AND iv_merge = abap_true.
      TRY.
          lo_merger = NEW #( ).
        CATCH cx_rspo_pdf_merge.
          MESSAGE TEXT-014 TYPE 'S' DISPLAY LIKE 'E'.
          RETURN.
      ENDTRY.
    ENDIF.

    DATA lv_pdf TYPE xstring.

    LOOP AT it_rows INTO DATA(lv_row).
      DATA(lv_idx) = sy-tabix.
      ASSIGN gt_alv[ lv_row ] TO FIELD-SYMBOL(<ls_line>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      show_progress( iv_aufnr   = <ls_line>-aufnr
                     iv_current = lv_idx
                     iv_total   = lines( it_rows ) ).

      IF print_single_order( EXPORTING iv_aufnr       = <ls_line>-aufnr
                                       iv_external    = abap_false
                                       iv_collect_pdf = iv_merge
                                       iv_save_as_pdf = iv_save_as_pdf
                             IMPORTING ev_pdf         = lv_pdf
                             CHANGING  cs_alv         = <ls_line> ) = abap_true.
        IF iv_merge = abap_true AND lv_pdf IS NOT INITIAL.
          lo_merger->add_document( lv_pdf ).
        ENDIF.
        ev_ok = ev_ok + 1.
      ELSE.
        ev_err = ev_err + 1.
      ENDIF.
    ENDLOOP.

    IF iv_merge = abap_true AND ev_ok > 0.
      DATA lv_merged TYPE xstring.
      DATA lv_rc     TYPE i.
      lo_merger->merge_documents( IMPORTING merged_document = lv_merged
                                            rc              = lv_rc ).
      IF lv_rc = 0 AND lv_merged IS NOT INITIAL.
        download_pdf_file( iv_pdf_data = lv_merged
                           iv_filename = |Repair-Merged-{ ev_ok }-{ sy-datum }-{ sy-uzeit }{ COND #(
                             WHEN p_rawpdf = abap_true THEN '_RAW' ELSE '_ADS' ) }.pdf|
                           iv_prompt   = abap_true ).
      ELSE.
        MESSAGE TEXT-015 TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD all_adobe.
    rv_result = abap_true.
    IF it_rows IS INITIAL.
      rv_result = abap_false.
      RETURN.
    ENDIF.
    LOOP AT it_rows INTO DATA(lv_row).
      ASSIGN gt_alv[ lv_row ] TO FIELD-SYMBOL(<ls>).
      IF sy-subrc = 0 AND <ls>-form_type <> 'A'.
        rv_result = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD execute_print_bundled.
    CLEAR: ev_ok,
           ev_err.

    DATA(lv_printer) = resolve_printer( ).

    IF iv_merge = abap_true.
      " =================================================================
      " Option 2: Merge ALL forms into single PDF → send to spool
      " (No Adobe/SmartForm split needed — all produce PDF via driver)
      " =================================================================
      DATA lt_pdfs   TYPE TABLE OF xstring.
      DATA lv_mg_pdf TYPE xstring.

      LOOP AT it_rows INTO DATA(lv_mg_row).
        DATA(lv_mg_idx) = sy-tabix.
        ASSIGN gt_alv[ lv_mg_row ] TO FIELD-SYMBOL(<ls_mg>).
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.

        show_progress( iv_aufnr   = <ls_mg>-aufnr
                       iv_current = lv_mg_idx
                       iv_total   = lines( it_rows ) ).

        IF print_single_order( EXPORTING iv_aufnr       = <ls_mg>-aufnr
                                         iv_external    = abap_false
                                         iv_collect_pdf = abap_true
                                         iv_save_as_pdf = abap_true
                               IMPORTING ev_pdf         = lv_mg_pdf
                               CHANGING  cs_alv         = <ls_mg> ) = abap_true.
          IF lv_mg_pdf IS NOT INITIAL.
            APPEND lv_mg_pdf TO lt_pdfs.
          ENDIF.
          ev_ok = ev_ok + 1.
        ELSE.
          ev_err = ev_err + 1.
        ENDIF.
      ENDLOOP.

      " Merge collected PDFs and send to spool
      IF lt_pdfs IS NOT INITIAL.
        DATA lo_merger TYPE REF TO cl_rspo_pdf_merge.
        TRY.
            CREATE OBJECT lo_merger.
          CATCH cx_rspo_pdf_merge.
        ENDTRY.
        IF lo_merger IS BOUND.
          LOOP AT lt_pdfs INTO DATA(lv_pdf_piece).
            lo_merger->add_document( lv_pdf_piece ).
          ENDLOOP.
          DATA lv_merged_pdf TYPE xstring.
          DATA lv_merge_rc   TYPE i.
          lo_merger->merge_documents( IMPORTING merged_document = lv_merged_pdf
                                                rc              = lv_merge_rc ).
          IF lv_merge_rc = 0 AND lv_merged_pdf IS NOT INITIAL.
            send_pdf_to_spool( iv_pdf     = lv_merged_pdf
                               iv_printer = lv_printer
                               iv_title   = |{ TEXT-033 } { sy-datum }_{ sy-uzeit }| ). " Mass Print Merged
          ENDIF.
        ENDIF.
      ENDIF.

    ELSE.
      " =================================================================
      " Option 1: Per-form bundled spool (split Adobe / SmartForm)
      " =================================================================
      DATA lt_adobe TYPE TABLE OF ty_alv_line.
      DATA lt_smart TYPE TABLE OF ty_alv_line.

      LOOP AT it_rows INTO DATA(lv_row).
        ASSIGN gt_alv[ lv_row ] TO FIELD-SYMBOL(<ls>).
        IF sy-subrc = 0.
          IF <ls>-form_type = 'S'.
            APPEND <ls> TO lt_smart.
          ELSE.
            APPEND <ls> TO lt_adobe.
          ENDIF.
        ENDIF.
      ENDLOOP.

      " --- Adobe group: single spool via FP_JOB_OPEN ---
      IF lt_adobe IS NOT INITIAL.
        DATA ls_outputparams TYPE sfpoutputparams.

        ls_outputparams-reqnew     = abap_true.
        ls_outputparams-reqfinal   = abap_true.
        ls_outputparams-dest       = lv_printer.
        ls_outputparams-reqimm     = abap_true.
        ls_outputparams-reqdel     = abap_false.
        ls_outputparams-nodialog   = abap_true.
        ls_outputparams-bumode     = 'X'.        " Simple Bundling
        ls_outputparams-adstrlevel = '02'.       " Medium ADS trace
        ls_outputparams-covtitle   = |{ TEXT-034 } { sy-datum }_{ sy-uzeit }|. " Mass Print Adobe

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
          mark_rows_error( EXPORTING it_lines = lt_adobe
                                     iv_msg   = build_job_error_msg( iv_context = 'FP_JOB_OPEN'
                                                                     iv_subrc   = sy-subrc )
                           CHANGING  cv_err   = ev_err ).
        ELSE.
          LOOP AT lt_adobe ASSIGNING FIELD-SYMBOL(<ls_a>).
            show_progress( iv_aufnr   = <ls_a>-aufnr
                           iv_current = sy-tabix
                           iv_total   = lines( lt_adobe ) ).

            ASSIGN gt_alv[ aufnr = <ls_a>-aufnr ] TO FIELD-SYMBOL(<ls_alv_a>).
            IF sy-subrc = 0.
              IF print_single_order( EXPORTING iv_aufnr       = <ls_a>-aufnr
                                               iv_external    = abap_true
                                               iv_save_as_pdf = abap_false
                                     CHANGING  cs_alv         = <ls_alv_a> ) = abap_true.
                ev_ok = ev_ok + 1.
              ELSE.
                ev_err = ev_err + 1.
              ENDIF.
            ENDIF.
          ENDLOOP.

          CALL FUNCTION 'FP_JOB_CLOSE'
            EXCEPTIONS
              OTHERS = 1.
          IF sy-subrc <> 0.
            /ctdi/cl_print_driver_log=>log_error( |FP_JOB_CLOSE failed (subrc={ sy-subrc })| ).
          ENDIF.
        ENDIF.   " IF sy-subrc (FP_JOB_OPEN)
      ENDIF.

      " --- SmartForm group: single spool via SSF_OPEN ---
      IF lt_smart IS NOT INITIAL.
        DATA ls_sf_ctrl   TYPE ssfctrlop.
        DATA ls_sf_output TYPE ssfcompop.

        ls_sf_ctrl-no_dialog    = abap_true.
        ls_sf_output-tddest     = lv_printer.
        ls_sf_output-tdnewid    = abap_true.
        ls_sf_output-tdimmed    = abap_true.
        ls_sf_output-tddelete   = abap_false.
        ls_sf_output-tdcovtitle = |{ TEXT-035 } { sy-datum }_{ sy-uzeit }|. " Mass Print SmartForms

        CALL FUNCTION 'SSF_OPEN'
          EXPORTING
            control_parameters = ls_sf_ctrl
            output_options     = ls_sf_output
            user_settings      = abap_false
          EXCEPTIONS
            OTHERS             = 1.
        IF sy-subrc <> 0.
          DATA(lv_ssf_msg) = |SSF_OPEN failed (subrc={ sy-subrc })|.
          mark_rows_error( EXPORTING it_lines = lt_smart
                                     iv_msg   = lv_ssf_msg
                           CHANGING  cv_err   = ev_err ).
        ELSE.
          LOOP AT lt_smart ASSIGNING FIELD-SYMBOL(<ls_s>).
            show_progress( iv_aufnr   = <ls_s>-aufnr
                           iv_current = sy-tabix
                           iv_total   = lines( lt_smart ) ).

            ASSIGN gt_alv[ aufnr = <ls_s>-aufnr ] TO FIELD-SYMBOL(<ls_alv_s>).
            IF sy-subrc = 0.
              IF print_single_order( EXPORTING iv_aufnr       = <ls_s>-aufnr
                                               iv_external    = abap_true
                                               iv_save_as_pdf = abap_false
                                     CHANGING  cs_alv         = <ls_alv_s> ) = abap_true.
                ev_ok = ev_ok + 1.
              ELSE.
                ev_err = ev_err + 1.
              ENDIF.
            ENDIF.
          ENDLOOP.

          CALL FUNCTION 'SSF_CLOSE'
            EXCEPTIONS
              OTHERS = 1.
          IF sy-subrc <> 0.
            /ctdi/cl_print_driver_log=>log_error( |SSF_CLOSE failed (subrc={ sy-subrc })| ).
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.   " IF iv_merge / ELSE
  ENDMETHOD.

  METHOD execute_pdf_merge_ads.
    CLEAR: ev_ok,
           ev_err.

    DATA ls_outputparams TYPE sfpoutputparams.
    ls_outputparams-nodialog = abap_true.
    ls_outputparams-getpdf   = 'M'.     " Merge mode
    ls_outputparams-assemble = abap_true.
    ls_outputparams-bumode   = 'M'.     " Bundle mode
    ls_outputparams-reqnew   = abap_true.
    ls_outputparams-reqfinal = abap_true.

    CALL FUNCTION 'FP_JOB_OPEN'
      CHANGING
        ie_outputparams = ls_outputparams
      EXCEPTIONS
        cancel          = 1
        OTHERS          = 5.
    IF sy-subrc <> 0.
      DATA(lv_merge_msg) = build_job_error_msg( iv_context = CONV #( TEXT-032 ) " PDF merge job opening
                                                iv_subrc   = sy-subrc ).
      LOOP AT it_rows INTO DATA(lv_err_row).
        ASSIGN gt_alv[ lv_err_row ] TO FIELD-SYMBOL(<ls_err>).
        IF sy-subrc = 0.
          <ls_err>-icon = icon_led_red.
          <ls_err>-msg  = lv_merge_msg.
        ENDIF.
        ev_err = ev_err + 1.
      ENDLOOP.
      RETURN.
    ENDIF.

    LOOP AT it_rows INTO DATA(lv_row).
      DATA(lv_idx) = sy-tabix.
      ASSIGN gt_alv[ lv_row ] TO FIELD-SYMBOL(<ls_line>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      show_progress( iv_aufnr   = <ls_line>-aufnr
                     iv_current = lv_idx
                     iv_total   = lines( it_rows ) ).

      IF print_single_order( EXPORTING iv_aufnr       = <ls_line>-aufnr
                                       iv_external    = abap_true
                                       iv_collect_pdf = abap_true
                                       iv_save_as_pdf = abap_true
                             CHANGING  cs_alv         = <ls_line> ) = abap_true.
        ev_ok = ev_ok + 1.
      ELSE.
        ev_err = ev_err + 1.
      ENDIF.
    ENDLOOP.

    CALL FUNCTION 'FP_JOB_CLOSE'
      EXCEPTIONS
        OTHERS = 0.

    DATA lt_pdf_table TYPE tfpcontent.
    CALL FUNCTION 'FP_GET_PDF_TABLE'
      IMPORTING
        e_pdf_table = lt_pdf_table.

    IF lt_pdf_table IS NOT INITIAL.
      download_pdf_file( iv_pdf_data = lt_pdf_table[ 1 ]
                         iv_filename = |Repair-Merged-{ ev_ok }-{ sy-datum }-{ sy-uzeit }{ COND #(
                           WHEN p_rawpdf = abap_true THEN '_RAW' ELSE '_ADS' ) }.pdf|
                         iv_prompt   = abap_true ).
    ELSE.
      MESSAGE TEXT-015 TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD download_pdf_file.
    rv_ok = abap_false.
    IF iv_pdf_data IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_data     TYPE solix_tab.
    DATA lv_filesize TYPE i.
    DATA lv_fpath    TYPE string.

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

    IF iv_prompt = abap_true OR /ctdi/cl_print_driver_base=>get_download_dir( ) IS INITIAL.
      DATA lv_action   TYPE i.
      DATA lv_filename TYPE string.
      DATA lv_path     TYPE string.
      DATA lv_fullpath TYPE string.
      DATA(lv_init_dir) = /ctdi/cl_print_driver_base=>get_download_dir( ).

      cl_gui_frontend_services=>file_save_dialog( EXPORTING  default_file_name = iv_filename
                                                             default_extension = 'pdf'
                                                             file_filter       = CONV #( TEXT-031 ) " PDF Files (*.pdf)|*.pdf
                                                             initial_directory = lv_init_dir
                                                  CHANGING   filename          = lv_filename
                                                             path              = lv_path
                                                             fullpath          = lv_fullpath
                                                             user_action       = lv_action
                                                  EXCEPTIONS OTHERS            = 1 ).

      IF lv_action <> cl_gui_frontend_services=>action_ok OR lv_fullpath IS INITIAL.
        RETURN.
      ENDIF.
      /ctdi/cl_print_driver_base=>set_download_dir( lv_path ).
      lv_fpath = lv_fullpath.
    ELSE.
      lv_fpath = /ctdi/cl_print_driver_base=>get_download_dir( ) && iv_filename.
    ENDIF.

    lv_filesize = xstrlen( iv_pdf_data ).
    cl_gui_frontend_services=>gui_download( EXPORTING  filename     = lv_fpath
                                                       filetype     = 'BIN'
                                                       bin_filesize = lv_filesize
                                            CHANGING   data_tab     = lt_data
                                            EXCEPTIONS OTHERS       = 19 ).

    rv_ok = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD show_summary.
    MESSAGE |{ TEXT-012 }: { iv_ok } OK, { iv_err } { TEXT-013 }.| TYPE 'S'.
  ENDMETHOD.

  METHOD toggle_spool_mode.
    DATA lv_button TYPE c LENGTH 1.

    DATA(lv_ind) = COND string( WHEN gv_spool_mode = c_mode_individual THEN ' <<' ).
    DATA(lv_bnd) = COND string( WHEN gv_spool_mode = c_mode_bundled THEN ' <<' ).
    DATA(lv_mrg) = COND string( WHEN gv_spool_mode = c_mode_merged THEN ' <<' ).

    CALL FUNCTION 'POPUP_FOR_INTERACTION'
      EXPORTING
        headline       = TEXT-019                  " Spool Mode
        text1          = TEXT-020                  " Select spool mode for printing:
        text2          = ' '
        text3          = |{ TEXT-021 }{ lv_ind }|  " Individual: 1 spool per order
        text4          = |{ TEXT-022 }{ lv_bnd }|  " Bundled: grouped by form type
        text5          = |{ TEXT-023 }{ lv_mrg }|  " Merged: single PDF spool
        ticon          = 'Q'
        button_1       = TEXT-024                  " Individual
        button_2       = TEXT-025                  " Bundled
        button_3       = TEXT-026                  " Merged
      IMPORTING
        button_pressed = lv_button.

    IF lv_button IS NOT INITIAL AND lv_button <> 'A'.
      gv_spool_mode = SWITCH #( lv_button
                                WHEN '1' THEN c_mode_individual
                                WHEN '2' THEN c_mode_bundled
                                WHEN '3' THEN c_mode_merged ).

      DATA(lv_mode_text) = SWITCH string( gv_spool_mode
                                          WHEN c_mode_individual THEN TEXT-027 " Individual Spool
                                          WHEN c_mode_bundled    THEN TEXT-028 " Bundled Spool
                                          WHEN c_mode_merged     THEN TEXT-029 ). " Merged Spool
      MESSAGE |{ TEXT-019 }: { lv_mode_text }| TYPE 'S'.
    ENDIF.
  ENDMETHOD.

  METHOD build_error_msg.
    DATA lv_ads_trace TYPE string.

    CALL FUNCTION 'FP_GET_LAST_ADS_TRACE'
      IMPORTING
        e_adstrace = lv_ads_trace.

    DATA(lv_base) = COND string( WHEN ix_error->previous IS BOUND
                                 THEN ix_error->previous->get_text( )
                                 ELSE ix_error->get_text( ) ).

    rv_msg = COND #( WHEN lv_ads_trace IS NOT INITIAL
                     THEN |{ lv_base } [ADS: { lv_ads_trace }]|
                     ELSE lv_base ).
  ENDMETHOD.

  METHOD show_progress.
    cl_progress_indicator=>progress_indicate(
        i_text               = |{ TEXT-007 } { iv_aufnr } ({ iv_current }/{ iv_total })...|
        i_processed          = iv_current
        i_total              = iv_total
        i_output_immediately = abap_true ).
  ENDMETHOD.

  METHOD mark_rows_error.
    FIELD-SYMBOLS <ls_line> TYPE ty_alv_line.

    LOOP AT it_lines ASSIGNING <ls_line>.
      ASSIGN gt_alv[ aufnr = <ls_line>-aufnr ] TO FIELD-SYMBOL(<ls_alv>).
      IF sy-subrc = 0.
        <ls_alv>-icon = icon_led_red.
        <ls_alv>-msg  = iv_msg.
      ENDIF.
      cv_err = cv_err + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD print_single_order.
    rv_ok = abap_false.
    CLEAR ev_pdf.

    TRY.
        DATA(lr_driver) = /ctdi/cl_print_driver_base=>factory( iv_repair_id = iv_aufnr ).

        lr_driver->set_append_images( p_images ).

        " Set image render mode from selection screen
        lr_driver->set_img_render_mode( COND #(
          WHEN p_adspdf = abap_true
          THEN /ctdi/cl_print_gos_images=>gc_render_ads
          ELSE /ctdi/cl_print_gos_images=>gc_render_raw ) ).

        IF iv_external = abap_true.
          lr_driver->set_external_job( abap_true ).
        ENDIF.
        IF iv_collect_pdf = abap_true.
          lr_driver->set_collect_pdf( abap_true ).
        ENDIF.

        lr_driver->execute( iv_save_as_pdf = iv_save_as_pdf
                            iv_no_dialog   = abap_true
                            iv_preview     = abap_false ).

        IF iv_collect_pdf = abap_true.
          ev_pdf = lr_driver->get_last_pdf( ).
        ENDIF.

        cs_alv-icon = icon_led_green.
        cs_alv-msg  = COND #( WHEN iv_save_as_pdf = abap_true
                              THEN TEXT-011
                              ELSE TEXT-010 ).
        rv_ok = abap_true.

      CATCH /ctdi/cx_no_config_found INTO DATA(lx_noconf).
        cs_alv-icon = icon_led_yellow.
        cs_alv-msg  = COND #( WHEN lx_noconf->previous IS BOUND
                              THEN lx_noconf->previous->get_text( )
                              ELSE lx_noconf->get_text( ) ).

      CATCH cx_root INTO DATA(lx).
        cs_alv-icon = icon_led_red.
        cs_alv-msg  = build_error_msg( lx ).
    ENDTRY.
  ENDMETHOD.

  METHOD resolve_printer.
    DATA ls_user_defaults TYPE usdefaults.

    CALL FUNCTION 'SUSR_USER_DEFAULTS_GET'
      EXPORTING
        user_name     = sy-uname
      IMPORTING
        user_defaults = ls_user_defaults
      EXCEPTIONS
        OTHERS        = 0.

    GET PARAMETER ID '/CELLAG/PAFR' FIELD rv_printer.
    IF rv_printer IS INITIAL.
      rv_printer = ls_user_defaults-spld.
    ENDIF.
  ENDMETHOD.

  METHOD navigate_to_transaction.
    IF iv_value IS NOT INITIAL.
      SET PARAMETER ID iv_param FIELD iv_value.
      CALL TRANSACTION iv_tcode AND SKIP FIRST SCREEN.
    ENDIF.
  ENDMETHOD.

  METHOD build_job_error_msg.
    DATA lv_ads_trace TYPE string.

    CALL FUNCTION 'FP_GET_LAST_ADS_TRACE'
      IMPORTING
        e_adstrace = lv_ads_trace.

    rv_msg = COND #( WHEN lv_ads_trace IS NOT INITIAL
                     THEN |{ iv_context } failed (subrc={ iv_subrc }) [ADS: { lv_ads_trace }]|
                     ELSE |{ iv_context } failed (subrc={ iv_subrc })| ).
  ENDMETHOD.

  METHOD send_pdf_to_spool.
    rv_ok = abap_false.

    IF iv_pdf IS INITIAL OR iv_printer IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_title) = CONV tsp01-rqtitle( iv_title ).

    CALL FUNCTION 'ADS_CREATE_PDF_SPOOLJOB'
      EXPORTING
        dest            = iv_printer
        pages           = 0
        pdf_data        = iv_pdf
        immediate_print = 'X'
        auto_delete     = ' '
        titleline       = lv_title
      EXCEPTIONS
        OTHERS          = 1.

    rv_ok = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.
ENDCLASS.

" -----------------------------------------------------------------------

INITIALIZATION.
  " Default qmart pattern: Z*
  s_qmart[]  = VALUE #( ( sign = 'I' option = 'CP' low = 'Z*' ) ).
  sscrfields = /ctdi/cl_print_cust_engine=>init_toolbar( ).

AT SELECTION-SCREEN.
  /ctdi/cl_print_cust_engine=>handle_selection_screen_fcode( sscrfields-ucomm ).

START-OF-SELECTION.
  lcl_mass_print=>run( ).
