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
REPORT /ctdi/print_repair_mass_prll.

" -----------------------------------------------------------------------
" Global Data for SELECT-OPTIONS references
" -----------------------------------------------------------------------
TABLES: aufk, afru, qmel, vbak.
DATA gv_contr TYPE jvbelncontract.

" -----------------------------------------------------------------------
" Selection Screen
" -----------------------------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
SELECT-OPTIONS: s_aufnr FOR aufk-aufnr,                 " Repair Order
                s_kdauf FOR aufk-kdauf,                 " Sales Order
                s_contr FOR gv_contr,                   " Contract
                s_qmnum FOR qmel-qmnum,                " Notification
                s_auart FOR aufk-auart DEFAULT 'ZM03',  " Order Type
                s_werks FOR aufk-werks,                 " Plant
                s_erdat FOR aufk-erdat,                 " Creation Date
                s_vornr FOR afru-vornr DEFAULT '9010',  " Operation (WFER)
                s_qmart FOR qmel-qmart.                 " QM Notification Type
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_pdf TYPE sap_bool AS CHECKBOX USER-COMMAND pdf_toggle, " Save as PDF
            p_dir TYPE string LOWER CASE MODIF ID pdf.               " Target Directory
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-018.
PARAMETERS p_spool TYPE sap_bool AS CHECKBOX.                         " Single Spool (bundle)
SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE TEXT-036.
PARAMETERS: p_images AS CHECKBOX.                        " Append GOS Images
SELECTION-SCREEN END OF BLOCK b4.

" -----------------------------------------------------------------------
" ALV output structure
" -----------------------------------------------------------------------
TYPES: BEGIN OF ty_alv_line,
         icon        TYPE icon_d,         " Status icon
         aufnr       TYPE aufnr,          " Repair Order
         auart       TYPE aufart,         " Order Type
         erdat       TYPE auferfdat,      " Creation Date
         werks       TYPE werks_d,        " Plant
         ktext       TYPE auftext,        " Order short text
         kdauf       TYPE kdauf,          " Sales Order
         contract_id TYPE jvbelncontract, " Contract
         qmnum       TYPE qmnum,          " Notification (QMEL)
         qmart       TYPE qmart,          " Notification Type
         vbap_qmnum  TYPE qmnum,          " Notification (VBAP)
         feession    TYPE fenum,          " Item/Position (VBAP)
         skz         TYPE bemot,          " SKZ (Confirmation reason)
         akz         TYPE qmcod,          " AKZ (QM Code)
         form_name   TYPE fpname,         " Form Name
         form_type   TYPE char1,          " Form Type (S=SmartForm, A=Adobe)
         msg         TYPE string,         " Message (success/error)
       END OF ty_alv_line.

" Result structure shared between parallel tasks and main program
TYPES: BEGIN OF ty_result,
         aufnr    TYPE aufnr,
         filename TYPE string,
         icon     TYPE icon_d,
         msg      TYPE string,
         pdf_data TYPE xstring,
       END OF ty_result.

TYPES: BEGIN OF ty_step,
         vbeln TYPE vbeln_va,
         skz   TYPE bemot,
         akz   TYPE char4,
       END OF ty_step.
TYPES ty_step_tab TYPE STANDARD TABLE OF ty_step WITH EMPTY KEY.

" -----------------------------------------------------------------------
" Parallel Processing Class (for 50+ orders)
" -----------------------------------------------------------------------
CLASS lcl_parallel_print DEFINITION
  INHERITING FROM cl_abap_parallel FINAL.

  PUBLIC SECTION.
    METHODS do REDEFINITION.
ENDCLASS.


CLASS lcl_parallel_print IMPLEMENTATION.
  METHOD do.
    DATA lv_aufnr    TYPE aufnr.
    DATA lv_pdf_mode TYPE abap_bool.

    IMPORT aufnr    = lv_aufnr
           pdf_mode = lv_pdf_mode FROM DATA BUFFER p_in.

    DATA ls_result TYPE ty_result.
    ls_result-aufnr = lv_aufnr.

    TRY.
        DATA(lr_driver) = /ctdi/cl_print_driver_base=>factory( iv_repair_id = lv_aufnr ).
        lr_driver->set_append_images( p_images ).

        IF lv_pdf_mode = abap_true.
          lr_driver->set_collect_pdf( abap_true ).
        ENDIF.

        lr_driver->execute( iv_save_as_pdf = lv_pdf_mode
                            iv_no_dialog   = abap_true
                            iv_preview     = abap_false ).

        ls_result-icon = icon_led_green.
        ls_result-msg  = 'OK'.

        IF lv_pdf_mode = abap_true.
          ls_result-pdf_data = lr_driver->get_last_pdf( ).
          ls_result-filename = lr_driver->build_pdf_filename( ).
        ENDIF.

      CATCH /ctdi/cx_no_config_found INTO DATA(lx_noconf).
        ls_result-icon = icon_led_yellow.
        ls_result-msg  = COND #( WHEN lx_noconf->previous IS BOUND
                                 THEN lx_noconf->previous->get_text( )
                                 ELSE lx_noconf->get_text( ) ).

      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_driver).
        ls_result-icon = icon_led_red.
        ls_result-msg  = COND #( WHEN lx_driver->previous IS BOUND
                                 THEN lx_driver->previous->get_text( )
                                 ELSE lx_driver->get_text( ) ).

      CATCH cx_root INTO DATA(lx_root).
        ls_result-icon = icon_led_red.
        ls_result-msg  = COND #( WHEN lx_root->previous IS BOUND
                                 THEN lx_root->previous->get_text( )
                                 ELSE lx_root->get_text( ) ).
    ENDTRY.

    EXPORT result = ls_result TO DATA BUFFER p_out.
  ENDMETHOD.
ENDCLASS.


" -----------------------------------------------------------------------
" Main Application Class
" -----------------------------------------------------------------------
CLASS lcl_mass_print DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS run.

  PRIVATE SECTION.
    CLASS-DATA gt_alv  TYPE TABLE OF ty_alv_line.
    CLASS-DATA go_salv TYPE REF TO cl_salv_table.

    CLASS-METHODS select_orders.
    CLASS-METHODS resolve_form_types.
    CLASS-METHODS display_alv.

    CLASS-METHODS on_user_command FOR EVENT added_function OF cl_salv_events_table
      IMPORTING e_salv_function.

    CLASS-METHODS on_double_click FOR EVENT double_click OF cl_salv_events_table
      IMPORTING !row !column.

    CLASS-METHODS execute_print
      IMPORTING it_rows        TYPE salv_t_row
                iv_save_as_pdf TYPE abap_bool
                iv_merge       TYPE abap_bool DEFAULT abap_false
      EXPORTING ev_ok          TYPE i
                ev_err         TYPE i.

    CLASS-METHODS execute_parallel
      IMPORTING it_rows TYPE salv_t_row
                iv_mode TYPE char10
      EXPORTING ev_ok   TYPE i
                ev_err  TYPE i.

    CLASS-METHODS execute_print_bundled
      IMPORTING it_rows TYPE salv_t_row
      EXPORTING ev_ok   TYPE i
                ev_err  TYPE i.

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
                    o~vgbel         AS contract_id,
                    q~qmnum,
                    q~qmart,
                    p~/cellag/qmnum AS vbap_qmnum,
                    p~/cellag/fenum AS feession,
                    f~bemot         AS skz,
                    q~qmcod         AS akz
      FROM aufk AS a
             INNER JOIN
               qmel AS q ON q~aufnr = a~aufnr
                 INNER JOIN
                   vbak AS o ON o~vbeln = a~kdauf
                     INNER JOIN
                       vbak AS c ON  c~vbeln = o~vgbel
                                 AND c~vbtyp = 'G'
                         LEFT OUTER JOIN
                           vbap AS p ON  p~vbeln = a~kdauf
                                     AND p~posnr = a~kdpos
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

    CLEAR gt_alv.
    LOOP AT lt_orders ASSIGNING FIELD-SYMBOL(<ls_order>).
      APPEND VALUE ty_alv_line( icon        = icon_led_inactive
                                aufnr       = <ls_order>-aufnr
                                auart       = <ls_order>-auart
                                erdat       = <ls_order>-erdat
                                werks       = <ls_order>-werks
                                ktext       = <ls_order>-ktext
                                kdauf       = <ls_order>-kdauf
                                contract_id = <ls_order>-contract_id
                                qmnum       = <ls_order>-qmnum
                                qmart       = <ls_order>-qmart
                                vbap_qmnum  = <ls_order>-vbap_qmnum
                                feession    = <ls_order>-feession
                                skz         = <ls_order>-skz
                                akz         = <ls_order>-akz ) TO gt_alv.
    ENDLOOP.

    resolve_form_types( ).
  ENDMETHOD.

  METHOD resolve_form_types.
    " 1. Read all config entries from /CTDI/REP_FORMS (Customizing buffer)
    SELECT * FROM /ctdi/rep_forms INTO TABLE @DATA(lt_config) ##SUBRC_OK. "#EC CI_NOWHERE "#EC CI_ALL_FIELDS_NEEDED

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
        /ctdi/cl_print_driver_log=>log_exception( lx_msg ).
        MESSAGE TEXT-015 TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    go_salv->set_screen_status( pfstatus      = 'MASS_ALV'
                                report        = sy-repid
                                set_functions = go_salv->c_functions_all ).

    lo_columns = go_salv->get_columns( ).
    lo_columns->set_optimize( abap_true ).

    TRY.
        DATA(lo_col_icon) = CAST cl_salv_column_table( lo_columns->get_column( 'ICON' ) ).
        lo_col_icon->set_short_text( 'Status' ).
        lo_col_icon->set_icon( abap_true ).
        lo_col_icon->set_alignment( if_salv_c_alignment=>centered ).

        DATA(lo_col_msg) = CAST cl_salv_column_table( lo_columns->get_column( 'MSG' ) ).
        lo_col_msg->set_short_text( CONV #( TEXT-006 ) ).
        lo_col_msg->set_medium_text( CONV #( TEXT-006 ) ).
        lo_col_msg->set_long_text( CONV #( TEXT-006 ) ).
        lo_col_msg->set_output_length( 40 ).
        lo_col_msg->set_fixed_header_text( 's' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    lo_selections = go_salv->get_selections( ).
    lo_selections->set_selection_mode( if_salv_c_selection_mode=>row_column ).

    lo_events = go_salv->get_event( ).
    SET HANDLER on_user_command FOR lo_events.
    SET HANDLER on_double_click FOR lo_events.

    DATA(lo_display) = go_salv->get_display_settings( ).
    lo_display->set_list_header( CONV #( |{ sy-title } ({ lines( gt_alv ) })| ) ).

    go_salv->display( ).
  ENDMETHOD.

  METHOD on_user_command.
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
        IF p_spool = abap_true.
          execute_print_bundled( EXPORTING it_rows = lt_rows
                                 IMPORTING ev_ok   = lv_count_ok
                                           ev_err  = lv_count_err ).
        ELSEIF lines( lt_rows ) > 50.
          execute_parallel( EXPORTING it_rows = lt_rows
                                      iv_mode = 'PRINT'
                            IMPORTING ev_ok   = lv_count_ok
                                      ev_err  = lv_count_err ).
        ELSE.
          execute_print( EXPORTING it_rows        = lt_rows
                                   iv_save_as_pdf = abap_false
                         IMPORTING ev_ok          = lv_count_ok
                                   ev_err         = lv_count_err ).
        ENDIF.

      WHEN 'PDF_SEL'.
        IF lines( lt_rows ) > 50.
          execute_parallel( EXPORTING it_rows = lt_rows
                                      iv_mode = 'PDF_SEL'
                            IMPORTING ev_ok   = lv_count_ok
                                      ev_err  = lv_count_err ).
        ELSE.
          execute_print( EXPORTING it_rows        = lt_rows
                                   iv_save_as_pdf = abap_true
                         IMPORTING ev_ok          = lv_count_ok
                                   ev_err         = lv_count_err ).
        ENDIF.

      WHEN 'PDF_MERGE'.
        IF all_adobe( lt_rows ).
          execute_pdf_merge_ads( EXPORTING it_rows = lt_rows
                                 IMPORTING ev_ok   = lv_count_ok
                                           ev_err  = lv_count_err ).
        ELSEIF lines( lt_rows ) > 50.
          execute_parallel( EXPORTING it_rows = lt_rows
                                      iv_mode = 'PDF_MERGE'
                            IMPORTING ev_ok   = lv_count_ok
                                      ev_err  = lv_count_err ).
        ELSE.
          execute_print( EXPORTING it_rows        = lt_rows
                                   iv_save_as_pdf = abap_true
                                   iv_merge       = abap_true
                         IMPORTING ev_ok          = lv_count_ok
                                   ev_err         = lv_count_err ).
        ENDIF.
    ENDCASE.

    go_salv->get_columns( )->set_optimize( abap_true ).
    go_salv->refresh( s_stable = VALUE #( row = abap_true
                                          col = abap_true ) ).
    show_summary( iv_ok  = lv_count_ok
                  iv_err = lv_count_err ).
  ENDMETHOD.

  METHOD on_double_click.
    IF row > 0.
      execute_preview( iv_row = row ).
    ENDIF.
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
        /ctdi/cl_print_driver_log=>log_exception( lx ).
        MESSAGE TEXT-015 TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD execute_parallel.
    CLEAR: ev_ok,
           ev_err.
    DATA lt_in TYPE cl_abap_parallel=>t_in_tab.
    DATA lv_in TYPE xstring.
    DATA(lv_pdf_mode) = xsdbool( iv_mode = 'PDF_SEL' OR iv_mode = 'PDF_MERGE' ).

    LOOP AT it_rows INTO DATA(lv_row).
      ASSIGN gt_alv[ lv_row ] TO FIELD-SYMBOL(<ls_line>).
      IF sy-subrc = 0.
        CLEAR lv_in.
        EXPORT aufnr    = <ls_line>-aufnr
               pdf_mode = lv_pdf_mode TO DATA BUFFER lv_in.
        APPEND lv_in TO lt_in.
      ENDIF.
    ENDLOOP.

    DATA(lo_parallel) = NEW lcl_parallel_print( p_num_tasks  = 10
                                                p_percentage = 50 ).
    DATA lt_out TYPE cl_abap_parallel=>t_out_tab.

    cl_progress_indicator=>progress_indicate( i_text               = |Parallel processing { lines( lt_in ) } orders...|
                                              i_output_immediately = abap_true ).

    lo_parallel->run( EXPORTING p_in_tab  = lt_in
                      IMPORTING p_out_tab = lt_out ).

    DATA lo_merger TYPE REF TO cl_rspo_pdf_merge.
    IF iv_mode = 'PDF_MERGE'.
      TRY.
          lo_merger = NEW #( ).
        CATCH cx_rspo_pdf_merge.
          MESSAGE TEXT-014 TYPE 'S' DISPLAY LIKE 'E'.
          RETURN.
      ENDTRY.
    ENDIF.

    IF iv_mode = 'PDF_SEL' AND p_pdf = abap_true AND p_dir IS NOT INITIAL.
      /ctdi/cl_print_driver_base=>set_download_dir( p_dir ).
    ENDIF.

    LOOP AT lt_out INTO DATA(ls_out).
      DATA ls_result TYPE ty_result.
      CLEAR ls_result.

      IF ls_out-result IS NOT INITIAL.
        IMPORT result = ls_result FROM DATA BUFFER ls_out-result.
      ELSE.
        ls_result-icon = icon_led_red.
        ls_result-msg  = COND #( WHEN ls_out-message IS NOT INITIAL
                                 THEN ls_out-message
                                 ELSE |Parallel task failed| ).
        IF ls_out-index > 0.
          DATA lv_aufnr TYPE aufnr.
          DATA(lv_in_buf) = lt_in[ ls_out-index ].
          IMPORT aufnr = lv_aufnr FROM DATA BUFFER lv_in_buf.
          ls_result-aufnr = lv_aufnr.
        ENDIF.
      ENDIF.

      IF iv_mode = 'PDF_MERGE' AND ls_result-pdf_data IS NOT INITIAL.
        lo_merger->add_document( ls_result-pdf_data ).
      ELSEIF iv_mode = 'PDF_SEL' AND ls_result-pdf_data IS NOT INITIAL.
        DATA(lv_fname) = COND string( WHEN ls_result-filename IS NOT INITIAL
                                      THEN |{ ls_result-filename }.pdf|
                                      ELSE |{ condense( CONV string( ls_result-aufnr ) ) }.pdf| ).
        download_pdf_file( iv_pdf_data = ls_result-pdf_data
                           iv_filename = lv_fname ).
      ENDIF.

      ASSIGN gt_alv[ aufnr = ls_result-aufnr ] TO FIELD-SYMBOL(<ls_alv>).
      IF sy-subrc = 0.
        <ls_alv>-icon = ls_result-icon.
        <ls_alv>-msg  = COND #( WHEN ls_result-icon = icon_led_green
                                THEN COND #( WHEN lv_pdf_mode = abap_true THEN TEXT-011 ELSE TEXT-010 )
                                ELSE ls_result-msg ).
        IF ls_result-icon = icon_led_green.
          ev_ok = ev_ok + 1.
        ELSE.
          ev_err = ev_err + 1.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF iv_mode = 'PDF_MERGE' AND ev_ok > 0.
      DATA lv_merged TYPE xstring.
      DATA lv_rc     TYPE i.
      lo_merger->merge_documents( IMPORTING merged_document = lv_merged
                                            rc              = lv_rc ).
      IF lv_rc = 0 AND lv_merged IS NOT INITIAL.
        download_pdf_file( iv_pdf_data = lv_merged
                           iv_filename = |Repair_Merged_{ sy-datum }.pdf|
                           iv_prompt   = abap_true ).
      ELSE.
        MESSAGE TEXT-015 TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD execute_print.
    CLEAR: ev_ok,
           ev_err.

    IF iv_save_as_pdf = abap_true AND p_pdf = abap_true AND p_dir IS NOT INITIAL AND iv_merge = abap_false.
      /ctdi/cl_print_driver_base=>set_download_dir( p_dir ).
    ENDIF.

    DATA lo_merger TYPE REF TO cl_rspo_pdf_merge.
    IF iv_save_as_pdf = abap_true AND iv_merge = abap_true.
      TRY.
          lo_merger = NEW #( ).
        CATCH cx_rspo_pdf_merge.
          MESSAGE TEXT-014 TYPE 'S' DISPLAY LIKE 'E'.
          RETURN.
      ENDTRY.
    ENDIF.

    LOOP AT it_rows INTO DATA(lv_row).
      ASSIGN gt_alv[ lv_row ] TO FIELD-SYMBOL(<ls_line>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      cl_progress_indicator=>progress_indicate(
          i_text               = |{ TEXT-007 } { <ls_line>-aufnr } ({ sy-tabix }/{ lines( it_rows ) })...|
          i_processed          = sy-tabix
          i_total              = lines( it_rows )
          i_output_immediately = abap_true ).

      TRY.
          DATA(lr_driver) = /ctdi/cl_print_driver_base=>factory( iv_repair_id = <ls_line>-aufnr ).
          lr_driver->set_append_images( p_images ).

          IF iv_merge = abap_true.
            lr_driver->set_collect_pdf( abap_true ).
          ENDIF.

          lr_driver->execute( iv_save_as_pdf = iv_save_as_pdf
                              iv_no_dialog   = abap_true
                              iv_preview     = abap_false ).

          IF iv_merge = abap_true.
            DATA(lv_pdf) = lr_driver->get_last_pdf( ).
            IF lv_pdf IS NOT INITIAL.
              lo_merger->add_document( lv_pdf ).
            ENDIF.
          ENDIF.

          <ls_line>-icon = icon_led_green.
          <ls_line>-msg  = COND #( WHEN iv_save_as_pdf = abap_true
                                   THEN TEXT-011
                                   ELSE TEXT-010 ).
          ev_ok = ev_ok + 1.

        CATCH /ctdi/cx_no_config_found INTO DATA(lx_noconf).
          <ls_line>-icon = icon_led_yellow.
          <ls_line>-msg  = COND #( WHEN lx_noconf->previous IS BOUND
                                   THEN lx_noconf->previous->get_text( )
                                   ELSE lx_noconf->get_text( ) ).
          ev_err = ev_err + 1.

        CATCH /ctdi/cx_print_driver_error INTO DATA(lx_driver).
          <ls_line>-icon = icon_led_red.
          <ls_line>-msg  = COND #( WHEN lx_driver->previous IS BOUND
                                   THEN lx_driver->previous->get_text( )
                                   ELSE lx_driver->get_text( ) ).
          ev_err = ev_err + 1.

        CATCH cx_root INTO DATA(lx_root).
          <ls_line>-icon = icon_led_red.
          <ls_line>-msg  = COND #( WHEN lx_root->previous IS BOUND
                                   THEN lx_root->previous->get_text( )
                                   ELSE lx_root->get_text( ) ).
          ev_err = ev_err + 1.
      ENDTRY.
    ENDLOOP.

    IF iv_merge = abap_true AND ev_ok > 0.
      DATA lv_merged TYPE xstring.
      DATA lv_rc     TYPE i.
      lo_merger->merge_documents( IMPORTING merged_document = lv_merged
                                            rc              = lv_rc ).
      IF lv_rc = 0 AND lv_merged IS NOT INITIAL.
        download_pdf_file( iv_pdf_data = lv_merged
                           iv_filename = |Repair_Merged_{ sy-datum }.pdf|
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
      DATA ls_outputparams  TYPE sfpoutputparams.
      DATA lv_printer       TYPE rspopname.
      DATA ls_user_defaults TYPE usdefaults.

      CALL FUNCTION 'SUSR_USER_DEFAULTS_GET'
        EXPORTING
          user_name     = sy-uname
        IMPORTING
          user_defaults = ls_user_defaults
        EXCEPTIONS
          OTHERS        = 0.
      GET PARAMETER ID '/CELLAG/PAFR' FIELD lv_printer.
      IF lv_printer IS INITIAL.
        lv_printer = ls_user_defaults-spld.
      ENDIF.

      ls_outputparams-reqnew   = abap_true.
      ls_outputparams-reqfinal = abap_true.
      ls_outputparams-dest     = lv_printer.
      ls_outputparams-reqimm   = abap_true.
      ls_outputparams-reqdel   = abap_false.
      ls_outputparams-nodialog = abap_true.
      ls_outputparams-covtitle = |Mass Print { sy-datum }|.

      CALL FUNCTION 'FP_JOB_OPEN'
        CHANGING
          ie_outputparams = ls_outputparams
        EXCEPTIONS
          OTHERS          = 5.
      IF sy-subrc <> 0.
        MESSAGE |FP_JOB_OPEN failed (subrc={ sy-subrc })| TYPE 'S' DISPLAY LIKE 'E'.
      ELSE.
        LOOP AT lt_adobe ASSIGNING FIELD-SYMBOL(<ls_a>).
          cl_progress_indicator=>progress_indicate(
              i_text               = |{ TEXT-007 } { <ls_a>-aufnr } ({ sy-tabix }/{ lines( lt_adobe ) })...|
              i_processed          = sy-tabix
              i_total              = lines( lt_adobe )
              i_output_immediately = abap_true ).
          TRY.
              DATA(lr_drv_a) = /ctdi/cl_print_driver_base=>factory( iv_repair_id = <ls_a>-aufnr ).
              lr_drv_a->set_external_job( abap_true ).
              lr_drv_a->execute( iv_save_as_pdf = abap_false
                                 iv_no_dialog   = abap_true
                                 iv_preview     = abap_false ).
              ASSIGN gt_alv[ aufnr = <ls_a>-aufnr ] TO FIELD-SYMBOL(<ls_alv_a>).
              IF sy-subrc = 0.
                <ls_alv_a>-icon = icon_led_green.
                <ls_alv_a>-msg  = TEXT-010.
              ENDIF.
              ev_ok = ev_ok + 1.
            CATCH cx_root INTO DATA(lx_a).
              ASSIGN gt_alv[ aufnr = <ls_a>-aufnr ] TO <ls_alv_a>.
              IF sy-subrc = 0.
                <ls_alv_a>-icon = icon_led_red.
                <ls_alv_a>-msg  = lx_a->get_text( ).
              ENDIF.
              ev_err = ev_err + 1.
          ENDTRY.
        ENDLOOP.

        CALL FUNCTION 'FP_JOB_CLOSE'
          EXCEPTIONS
            OTHERS = 1.
        IF sy-subrc <> 0.
          /ctdi/cl_print_driver_log=>log_error( |FP_JOB_CLOSE failed (subrc={ sy-subrc })| ).
        ENDIF.
      ENDIF.
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
      ls_sf_output-tdcovtitle = |Mass Print SmartForms { sy-datum }|.

      CALL FUNCTION 'SSF_OPEN'
        EXPORTING
          control_parameters = ls_sf_ctrl
          output_options     = ls_sf_output
          user_settings      = abap_false
        EXCEPTIONS
          OTHERS             = 1.
      IF sy-subrc <> 0.
        MESSAGE |SSF_OPEN failed (subrc={ sy-subrc })| TYPE 'S' DISPLAY LIKE 'E'.
      ELSE.
        LOOP AT lt_smart ASSIGNING FIELD-SYMBOL(<ls_s>).
          cl_progress_indicator=>progress_indicate(
              i_text               = |{ TEXT-007 } { <ls_s>-aufnr } ({ sy-tabix }/{ lines( lt_smart ) })...|
              i_processed          = sy-tabix
              i_total              = lines( lt_smart )
              i_output_immediately = abap_true ).
          TRY.
              DATA(lr_drv_s) = /ctdi/cl_print_driver_base=>factory( iv_repair_id = <ls_s>-aufnr ).
              lr_drv_s->set_external_job( abap_true ).
              lr_drv_s->execute( iv_save_as_pdf = abap_false
                                 iv_no_dialog   = abap_true
                                 iv_preview     = abap_false ).
              ASSIGN gt_alv[ aufnr = <ls_s>-aufnr ] TO FIELD-SYMBOL(<ls_alv_s>).
              IF sy-subrc = 0.
                <ls_alv_s>-icon = icon_led_green.
                <ls_alv_s>-msg  = TEXT-010.
              ENDIF.
              ev_ok = ev_ok + 1.
            CATCH cx_root INTO DATA(lx_s).
              ASSIGN gt_alv[ aufnr = <ls_s>-aufnr ] TO <ls_alv_s>.
              IF sy-subrc = 0.
                <ls_alv_s>-icon = icon_led_red.
                <ls_alv_s>-msg  = lx_s->get_text( ).
              ENDIF.
              ev_err = ev_err + 1.
          ENDTRY.
        ENDLOOP.

        CALL FUNCTION 'SSF_CLOSE'
          EXCEPTIONS
            OTHERS = 1.
        IF sy-subrc <> 0.
          /ctdi/cl_print_driver_log=>log_error( |SSF_CLOSE failed (subrc={ sy-subrc })| ).
        ENDIF.
      ENDIF.
    ENDIF.
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
      MESSAGE TEXT-014 TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    LOOP AT it_rows INTO DATA(lv_row).
      ASSIGN gt_alv[ lv_row ] TO FIELD-SYMBOL(<ls_line>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      cl_progress_indicator=>progress_indicate(
          i_text               = |{ TEXT-007 } { <ls_line>-aufnr } ({ sy-tabix }/{ lines( it_rows ) })...|
          i_processed          = sy-tabix
          i_total              = lines( it_rows )
          i_output_immediately = abap_true ).
      TRY.
          DATA(lr_driver) = /ctdi/cl_print_driver_base=>factory( iv_repair_id = <ls_line>-aufnr ).
          lr_driver->set_append_images( p_images ).
          lr_driver->set_external_job( abap_true ).
          lr_driver->set_collect_pdf( abap_true ).
          lr_driver->execute( iv_save_as_pdf = abap_true
                              iv_no_dialog   = abap_true
                              iv_preview     = abap_false ).
          <ls_line>-icon = icon_led_green.
          <ls_line>-msg  = TEXT-011.
          ev_ok = ev_ok + 1.

        CATCH cx_root INTO DATA(lx).
          <ls_line>-icon = icon_led_red.
          <ls_line>-msg  = lx->get_text( ).
          ev_err = ev_err + 1.
      ENDTRY.
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
                         iv_filename = |Repair_Merged_{ sy-datum }.pdf|
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

      cl_gui_frontend_services=>file_save_dialog( EXPORTING  default_file_name = iv_filename
                                                             default_extension = 'pdf'
                                                             file_filter       = 'PDF Files (*.pdf)|*.pdf'
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
ENDCLASS.


" -----------------------------------------------------------------------

INITIALIZATION.
  " Default qmart pattern: Z*
  s_qmart[] = VALUE #( ( sign = 'I' option = 'CP' low = 'Z*' ) ).
  p_dir     = 'C:\temp\'.

  IF sy-batch IS INITIAL.
    DATA lv_desktop_dir TYPE string.
    cl_gui_frontend_services=>get_desktop_directory( CHANGING   desktop_directory = lv_desktop_dir
                                                     EXCEPTIONS OTHERS            = 1 ).
    IF sy-subrc = 0 AND lv_desktop_dir IS NOT INITIAL.
      cl_gui_cfw=>flush( ).
      p_dir = lv_desktop_dir.
    ENDIF.
  ENDIF.

AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    IF screen-group1 = 'PDF'.
      IF p_pdf = abap_true.
        screen-active    = '1'.
        screen-invisible = '0'.
      ELSE.
        screen-active    = '0'.
        screen-invisible = '1'.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_dir.
  DATA lv_browse_folder TYPE string.

  cl_gui_frontend_services=>directory_browse( EXPORTING  initial_folder  = p_dir
                                              CHANGING   selected_folder = lv_browse_folder
                                              EXCEPTIONS OTHERS          = 1 ).
  IF sy-subrc = 0 AND lv_browse_folder IS NOT INITIAL.
    p_dir = lv_browse_folder.
  ENDIF.

START-OF-SELECTION.
  lcl_mass_print=>run( ).
