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
PARAMETERS: p_spool TYPE sap_bool AS CHECKBOX.                         " Single Spool (bundle)
SELECTION-SCREEN END OF BLOCK b3.

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
         feession    TYPE fenum,           " Item/Position (VBAP)
         skz         TYPE bemot,          " SKZ (Confirmation reason)
         akz         TYPE qmcod,          " AKZ (QM Code)
         form_name   TYPE fpname,          " Form Name
         form_type   TYPE char1,           " Form Type (S=SmartForm, A=Adobe)
         msg         TYPE string,         " Message (success/error)
       END OF ty_alv_line.

" -----------------------------------------------------------------------
" Parallel Processing Class (for 50+ orders)
" -----------------------------------------------------------------------
CLASS lcl_parallel_print DEFINITION FINAL
  INHERITING FROM cl_abap_parallel.
  PUBLIC SECTION.
    METHODS do REDEFINITION.
ENDCLASS.

CLASS lcl_parallel_print IMPLEMENTATION.
  METHOD do.
    " Deserialize input
    DATA lv_aufnr      TYPE aufnr.
    DATA lv_pdf_mode   TYPE abap_bool.
    IMPORT aufnr    = lv_aufnr
           pdf_mode = lv_pdf_mode FROM DATA BUFFER p_in.

    " Result structure
    TYPES: BEGIN OF ty_result,
             aufnr    TYPE aufnr,
             icon     TYPE icon_d,
             msg      TYPE string,
             pdf_data TYPE xstring,
           END OF ty_result.
    DATA ls_result TYPE ty_result.
    ls_result-aufnr = lv_aufnr.

    TRY.
        DATA(lr_driver) = /ctdi/cl_print_driver_base=>factory( iv_repair_id = lv_aufnr ).

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

    " Serialize output
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
    CLASS-METHODS display_alv_v2.

    CLASS-METHODS on_user_command FOR EVENT added_function OF cl_salv_events_table
      IMPORTING e_salv_function.

    CLASS-METHODS on_double_click FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.

    CLASS-METHODS execute_print
      IMPORTING iv_save_as_pdf TYPE abap_bool
                iv_merge       TYPE abap_bool DEFAULT abap_false.

    CLASS-METHODS execute_print_parallel
      IMPORTING iv_pdf_merge TYPE abap_bool DEFAULT abap_false.

    CLASS-METHODS execute_print_bundled.
    CLASS-METHODS execute_pdf_sel_parallel.
    CLASS-METHODS execute_pdf_merge_ads.

    CLASS-METHODS execute_preview
      IMPORTING iv_row TYPE i.

    CLASS-METHODS all_adobe
      RETURNING VALUE(rv_result) TYPE abap_bool.
ENDCLASS.


CLASS lcl_mass_print IMPLEMENTATION.
  METHOD run.
    select_orders( ).
    IF gt_alv IS INITIAL.
      MESSAGE TEXT-003 TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    display_alv_v2( ).
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

    " Resolve form name and type for each order
    resolve_form_types( ).
  ENDMETHOD.

  METHOD resolve_form_types.
    " 1. Read all config entries from /CTDI/REP_FORMS
    SELECT * FROM /ctdi/rep_forms INTO TABLE @DATA(lt_config) ##SUBRC_OK. "#EC CI_ALL_FIELDS_NEEDED

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

    " 3. For each ALV line: find matching config via access sequence, determine form type
    SORT lt_config BY vbeln skz akz.

    LOOP AT gt_alv ASSIGNING FIELD-SYMBOL(<ls_alv>).
      " Simple fallback resolution: try contract+skz+akz, then contract, then global
      DATA lv_form TYPE fpname.
      CLEAR lv_form.

      READ TABLE lt_config ASSIGNING FIELD-SYMBOL(<ls_match>)
           WITH KEY vbeln = <ls_alv>-contract_id
                    skz   = <ls_alv>-skz
                    akz   = <ls_alv>-akz BINARY SEARCH.
      IF sy-subrc <> 0.
        READ TABLE lt_config ASSIGNING <ls_match>
             WITH KEY vbeln = <ls_alv>-contract_id
                      skz   = <ls_alv>-skz
                      akz   = '' BINARY SEARCH.
      ENDIF.
      IF sy-subrc <> 0.
        READ TABLE lt_config ASSIGNING <ls_match>
             WITH KEY vbeln = <ls_alv>-contract_id
                      skz   = ''
                      akz   = '' BINARY SEARCH.
      ENDIF.
      IF sy-subrc <> 0.
        READ TABLE lt_config ASSIGNING <ls_match>
             WITH KEY vbeln = ''
                      skz   = ''
                      akz   = '' BINARY SEARCH.
      ENDIF.

      IF sy-subrc = 0.
        <ls_alv>-form_name = <ls_match>-form_name.
        " Check if it's a SmartForm
        READ TABLE lt_smartforms TRANSPORTING NO FIELDS
             WITH KEY table_line = <ls_match>-form_name.
        <ls_alv>-form_type = COND #( WHEN sy-subrc = 0 THEN 'S' ELSE 'A' ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD display_alv.
    DATA lo_functions  TYPE REF TO cl_salv_functions_list.
    DATA lo_columns    TYPE REF TO cl_salv_columns_table.
    DATA lo_column     TYPE REF TO cl_salv_column.
    DATA lo_events     TYPE REF TO cl_salv_events_table.
    DATA lo_selections TYPE REF TO cl_salv_selections.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = go_salv
                                CHANGING  t_table      = gt_alv ).
      CATCH cx_salv_msg INTO DATA(lx_msg).
        MESSAGE lx_msg->get_text( ) TYPE 'E'.
        RETURN.
    ENDTRY.

    " Set screen status with all standard functions enabled
    go_salv->set_screen_status( pfstatus      = 'SALV_STANDARD'
                                report        = 'SALV_DEMO_TABLE_FUNCTIONS'
                                set_functions = go_salv->c_functions_all ).

    " Add custom buttons
    lo_functions = go_salv->get_functions( ).
    TRY.
        lo_functions->add_function( name     = 'PRINT_SEL'
                                    icon     = CONV #( icon_print )
                                    text     = CONV #( TEXT-004 )
                                    tooltip  = CONV #( TEXT-004 )
                                    position = if_salv_c_function_position=>right_of_salv_functions ).

        lo_functions->add_function( name     = 'PDF_SEL'
                                    icon     = CONV #( icon_pdf )
                                    text     = CONV #( TEXT-005 )
                                    tooltip  = CONV #( TEXT-005 )
                                    position = if_salv_c_function_position=>right_of_salv_functions ).

        lo_functions->add_function( name     = 'PDF_MERGE'
                                    icon     = CONV #( icon_stack )
                                    text     = CONV #( TEXT-016 )
                                    tooltip  = CONV #( TEXT-016 )
                                    position = if_salv_c_function_position=>right_of_salv_functions ).

        lo_functions->add_function( name     = 'PREVIEW'
                                    icon     = CONV #( icon_display )
                                    text     = CONV #( TEXT-017 )
                                    tooltip  = CONV #( TEXT-017 )
                                    position = if_salv_c_function_position=>right_of_salv_functions ).
      CATCH cx_salv_existing
            cx_salv_wrong_call.
    ENDTRY.

    " Configure columns
    lo_columns = go_salv->get_columns( ).
    lo_columns->set_optimize( abap_true ).

    TRY.
        lo_column = lo_columns->get_column( 'ICON' ).
        lo_column->set_short_text( 'Status' ).

        DATA(lo_col_msg) = CAST cl_salv_column_table( lo_columns->get_column( 'MSG' ) ).
        lo_col_msg->set_short_text( CONV #( TEXT-006 ) ).
        lo_col_msg->set_medium_text( CONV #( TEXT-006 ) ).
        lo_col_msg->set_long_text( CONV #( TEXT-006 ) ).
        lo_col_msg->set_output_length( 40 ).
        lo_col_msg->set_fixed_header_text( 's' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " Enable row selection
    lo_selections = go_salv->get_selections( ).
    lo_selections->set_selection_mode( if_salv_c_selection_mode=>row_column ).

    " Register event handlers
    lo_events = go_salv->get_event( ).
    SET HANDLER on_user_command FOR lo_events.
    SET HANDLER on_double_click FOR lo_events.

    " Set title with record count
    sy-title = |{ sy-title } ({ lines( gt_alv ) })|.

    " Display
    go_salv->display( ).
  ENDMETHOD.


  METHOD display_alv_v2.
    DATA lo_columns    TYPE REF TO cl_salv_columns_table.
    DATA lo_column     TYPE REF TO cl_salv_column.
    DATA lo_events     TYPE REF TO cl_salv_events_table.
    DATA lo_selections TYPE REF TO cl_salv_selections.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = go_salv
                                CHANGING  t_table      = gt_alv ).
      CATCH cx_salv_msg INTO DATA(lx_msg).
        MESSAGE lx_msg->get_text( ) TYPE 'E'.
        RETURN.
    ENDTRY.

    " Use custom GUI status with our 4 buttons
    go_salv->set_screen_status( pfstatus      = 'MASS_ALV'
                                report        = sy-repid
                                set_functions = go_salv->c_functions_all ).

    " Configure columns
    lo_columns = go_salv->get_columns( ).
    lo_columns->set_optimize( abap_true ).

    TRY.
        lo_column = lo_columns->get_column( 'ICON' ).
        lo_column->set_short_text( 'Status' ).

        DATA(lo_col_msg) = CAST cl_salv_column_table( lo_columns->get_column( 'MSG' ) ).
        lo_col_msg->set_short_text( CONV #( TEXT-006 ) ).
        lo_col_msg->set_medium_text( CONV #( TEXT-006 ) ).
        lo_col_msg->set_long_text( CONV #( TEXT-006 ) ).
        lo_col_msg->set_output_length( 40 ).
        lo_col_msg->set_fixed_header_text( 's' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " Enable row selection
    lo_selections = go_salv->get_selections( ).
    lo_selections->set_selection_mode( if_salv_c_selection_mode=>row_column ).

    " Register event handlers
    lo_events = go_salv->get_event( ).
    SET HANDLER on_user_command FOR lo_events.
    SET HANDLER on_double_click FOR lo_events.

    " Set title with record count
    DATA(lo_display) = go_salv->get_display_settings( ).
    lo_display->set_list_header( CONV #( |{ sy-title } ({ lines( gt_alv ) })| ) ).

    " Display as fullscreen grid (no container — allows preview popups)
    go_salv->display( ).
  ENDMETHOD.


  METHOD on_user_command.
    CASE e_salv_function.
      WHEN 'PRINT_SEL'.
        DATA(lt_sel_rows) = go_salv->get_selections( )->get_selected_rows( ).
        IF p_spool = abap_true.
          execute_print_bundled( ).
        ELSEIF lines( lt_sel_rows ) > 50.
          execute_print_parallel( ).
        ELSE.
          execute_print( iv_save_as_pdf = abap_false
                         iv_merge       = abap_false ).
        ENDIF.
        go_salv->get_columns( )->set_optimize( abap_true ).
        go_salv->refresh( s_stable = VALUE #( row = abap_true
                                              col = abap_true ) ).

      WHEN 'PDF_SEL'.
        DATA(lt_pdf_rows) = go_salv->get_selections( )->get_selected_rows( ).
        IF lines( lt_pdf_rows ) > 50.
          execute_pdf_sel_parallel( ).
        ELSE.
          execute_print( iv_save_as_pdf = abap_true
                         iv_merge       = abap_false ).
        ENDIF.
        go_salv->get_columns( )->set_optimize( abap_true ).
        go_salv->refresh( s_stable = VALUE #( row = abap_true
                                              col = abap_true ) ).

      WHEN 'PDF_MERGE'.
        DATA(lt_merge_rows) = go_salv->get_selections( )->get_selected_rows( ).
        IF all_adobe( ).
          execute_pdf_merge_ads( ).
        ELSEIF lines( lt_merge_rows ) > 50.
          execute_print_parallel( iv_pdf_merge = abap_true ).
        ELSE.
          execute_print( iv_save_as_pdf = abap_true
                         iv_merge       = abap_true ).
        ENDIF.
        go_salv->get_columns( )->set_optimize( abap_true ).
        go_salv->refresh( s_stable = VALUE #( row = abap_true
                                              col = abap_true ) ).

      WHEN 'PREVIEW'.
        DATA(lt_prev_rows) = go_salv->get_selections( )->get_selected_rows( ).
        IF lt_prev_rows IS NOT INITIAL.
          execute_preview( iv_row = lt_prev_rows[ 1 ] ).
        ELSE.
          MESSAGE TEXT-008 TYPE 'S' DISPLAY LIKE 'W'.
        ENDIF.
    ENDCASE.
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
        lr_driver->execute( iv_save_as_pdf = abap_false
                            iv_no_dialog   = abap_false
                            iv_preview     = abap_true ).
      CATCH cx_root INTO DATA(lx).
        MESSAGE lx->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD execute_print_parallel.
    DATA lt_rows TYPE salv_t_row.
    DATA lt_in   TYPE cl_abap_parallel=>t_in_tab.

    lt_rows = go_salv->get_selections( )->get_selected_rows( ).

    IF lt_rows IS INITIAL.
      MESSAGE TEXT-008 TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " Serialize input: one xstring per order (with PDF mode flag)
    LOOP AT lt_rows INTO DATA(lv_row).
      ASSIGN gt_alv[ lv_row ] TO FIELD-SYMBOL(<ls_line>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA lv_in TYPE xstring.
      EXPORT aufnr    = <ls_line>-aufnr
             pdf_mode = iv_pdf_merge TO DATA BUFFER lv_in.
      APPEND lv_in TO lt_in.
    ENDLOOP.

    " Execute in parallel (max 10 tasks, 50% of available processes)
    DATA(lo_parallel) = NEW lcl_parallel_print( p_num_tasks  = 10
                                                p_percentage = 50 ).
    DATA lt_out TYPE cl_abap_parallel=>t_out_tab.

    cl_progress_indicator=>progress_indicate( i_text               = |Parallel processing { lines( lt_in ) } orders...|
                                              i_output_immediately = abap_true ).

    lo_parallel->run( EXPORTING p_in_tab  = lt_in
                      IMPORTING p_out_tab = lt_out ).

    " Process results
    TYPES: BEGIN OF ty_result,
             aufnr    TYPE aufnr,
             icon     TYPE icon_d,
             msg      TYPE string,
             pdf_data TYPE xstring,
           END OF ty_result.

    DATA lv_count_ok  TYPE i.
    DATA lv_count_err TYPE i.
    DATA lo_merger    TYPE REF TO cl_rspo_pdf_merge.

    IF iv_pdf_merge = abap_true.
      TRY.
          CREATE OBJECT lo_merger.
        CATCH cx_rspo_pdf_merge.
          MESSAGE TEXT-014 TYPE 'S' DISPLAY LIKE 'E'.
          RETURN.
      ENDTRY.
    ENDIF.

    LOOP AT lt_out INTO DATA(ls_out).
      DATA ls_result TYPE ty_result.
      CLEAR ls_result.

      IF ls_out-result IS NOT INITIAL.
        IMPORT result = ls_result FROM DATA BUFFER ls_out-result.
      ELSE.
        " Task failed (timeout or system error)
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

      " Collect PDF for merge
      IF iv_pdf_merge = abap_true AND ls_result-pdf_data IS NOT INITIAL.
        lo_merger->add_document( ls_result-pdf_data ).
      ENDIF.

      " Update ALV line
      ASSIGN gt_alv[ aufnr = ls_result-aufnr ] TO FIELD-SYMBOL(<ls_alv>).
      IF sy-subrc = 0.
        <ls_alv>-icon = ls_result-icon.
        <ls_alv>-msg  = COND #( WHEN iv_pdf_merge = abap_true AND ls_result-icon = icon_led_green
                                 THEN TEXT-011
                                 ELSE ls_result-msg ).
        IF ls_result-icon = icon_led_green.
          lv_count_ok = lv_count_ok + 1.
        ELSE.
          lv_count_err = lv_count_err + 1.
        ENDIF.
      ENDIF.
    ENDLOOP.

    " Merge and download combined PDF
    IF iv_pdf_merge = abap_true AND lv_count_ok > 0.
      DATA lv_merged  TYPE xstring.
      DATA lv_rc      TYPE i.

      lo_merger->merge_documents( IMPORTING merged_document = lv_merged
                                            rc              = lv_rc ).
      IF lv_rc = 0 AND lv_merged IS NOT INITIAL.
        DATA lv_filesize TYPE i.
        DATA lt_data     TYPE solix_tab.
        DATA lv_action   TYPE i.
        DATA lv_filename TYPE string.
        DATA lv_path     TYPE string.
        DATA lv_fpath    TYPE string.

        CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
          EXPORTING
            buffer     = lv_merged
          TABLES
            binary_tab = lt_data
          EXCEPTIONS
            OTHERS     = 1.

        cl_gui_frontend_services=>file_save_dialog(
          EXPORTING  default_file_name = |Repair_Merged_{ sy-datum }.pdf|
                     default_extension = 'pdf'
                     file_filter       = 'PDF Files (*.pdf)|*.pdf'
          CHANGING   filename          = lv_filename
                     path              = lv_path
                     fullpath          = lv_fpath
                     user_action       = lv_action
          EXCEPTIONS OTHERS            = 1 ).

        IF lv_action = cl_gui_frontend_services=>action_ok AND lv_fpath IS NOT INITIAL.
          lv_filesize = xstrlen( lv_merged ).
          cl_gui_frontend_services=>gui_download(
            EXPORTING  filename     = lv_fpath
                       filetype     = 'BIN'
                       bin_filesize = lv_filesize
            CHANGING   data_tab     = lt_data
            EXCEPTIONS OTHERS       = 19 ).
        ENDIF.
      ELSE.
        MESSAGE TEXT-015 TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.
    ENDIF.

    MESSAGE |{ TEXT-012 }: { lv_count_ok } OK, { lv_count_err } { TEXT-013 }.| TYPE 'S'.
  ENDMETHOD.

  METHOD execute_print.
    DATA lv_count_ok  TYPE i.
    DATA lv_count_err TYPE i.
    DATA lt_rows      TYPE salv_t_row.

    lt_rows = go_salv->get_selections( )->get_selected_rows( ).

    IF lt_rows IS INITIAL.
      MESSAGE TEXT-008 TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " Pre-set download directory from selection screen if PDF checkbox was checked
    IF     iv_save_as_pdf = abap_true AND p_pdf = abap_true AND p_dir IS NOT INITIAL
       AND iv_merge       = abap_false.
      /ctdi/cl_print_driver_base=>set_download_dir( p_dir ).
    ENDIF.

    " Merge mode: collect PDFs, merge at the end
    DATA lv_merge_mode TYPE abap_bool.
    DATA lo_merger     TYPE REF TO cl_rspo_pdf_merge.

    IF iv_save_as_pdf = abap_true AND iv_merge = abap_true.
      lv_merge_mode = abap_true.
      TRY.
          CREATE OBJECT lo_merger.
        CATCH cx_rspo_pdf_merge.
          MESSAGE TEXT-014 TYPE 'S' DISPLAY LIKE 'E'.
          RETURN.
      ENDTRY.
    ENDIF.

    LOOP AT lt_rows INTO DATA(lv_row).
      ASSIGN gt_alv[ lv_row ] TO FIELD-SYMBOL(<ls_line>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      cl_progress_indicator=>progress_indicate(
          i_text               = |{ TEXT-007 } { <ls_line>-aufnr } ({ sy-tabix }/{ lines( lt_rows ) })...|
          i_processed          = sy-tabix
          i_total              = lines( lt_rows )
          i_output_immediately = abap_true ).

      TRY.
          DATA(lr_driver) = /ctdi/cl_print_driver_base=>factory( iv_repair_id = <ls_line>-aufnr ).

          " In merge mode: collect PDF without downloading
          IF lv_merge_mode = abap_true.
            lr_driver->set_collect_pdf( abap_true ).
          ENDIF.

          lr_driver->execute( iv_save_as_pdf = iv_save_as_pdf
                              iv_no_dialog   = abap_true
                              iv_preview     = abap_false ).

          " Add to merger if in merge mode
          IF lv_merge_mode = abap_true.
            DATA(lv_pdf) = lr_driver->get_last_pdf( ).
            IF lv_pdf IS NOT INITIAL.
              lo_merger->add_document( lv_pdf ).
            ENDIF.
          ENDIF.

          <ls_line>-icon = icon_led_green.
          <ls_line>-msg  = COND #( WHEN iv_save_as_pdf = abap_true
                                   THEN TEXT-011
                                   ELSE TEXT-010 ).
          lv_count_ok = lv_count_ok + 1.

        CATCH /ctdi/cx_no_config_found INTO DATA(lx_noconf).
          <ls_line>-icon = icon_led_yellow.
          <ls_line>-msg  = COND #( WHEN lx_noconf->previous IS BOUND
                                   THEN lx_noconf->previous->get_text( )
                                   ELSE lx_noconf->get_text( ) ).
          lv_count_err = lv_count_err + 1.

        CATCH /ctdi/cx_print_driver_error INTO DATA(lx_driver).
          <ls_line>-icon = icon_led_red.
          <ls_line>-msg  = COND #( WHEN lx_driver->previous IS BOUND
                                   THEN lx_driver->previous->get_text( )
                                   ELSE lx_driver->get_text( ) ).
          lv_count_err = lv_count_err + 1.

        CATCH cx_root INTO DATA(lx_root).
          <ls_line>-icon = icon_led_red.
          <ls_line>-msg  = COND #( WHEN lx_root->previous IS BOUND
                                   THEN lx_root->previous->get_text( )
                                   ELSE lx_root->get_text( ) ).
          lv_count_err = lv_count_err + 1.
      ENDTRY.
    ENDLOOP.

    " Merge and download combined PDF
    IF lv_merge_mode = abap_true AND lv_count_ok > 0.
      DATA lv_merged TYPE xstring.
      DATA lv_rc     TYPE i.

      lo_merger->merge_documents( IMPORTING merged_document = lv_merged
                                            rc              = lv_rc ).
      IF lv_rc = 0 AND lv_merged IS NOT INITIAL.
        " Download merged file
        DATA lv_filesize TYPE i.
        DATA lt_data     TYPE solix_tab.
        DATA lv_action   TYPE i.
        DATA lv_filename TYPE string.
        DATA lv_path     TYPE string.
        DATA lv_fpath    TYPE string.

        CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
          EXPORTING
            buffer     = lv_merged
          TABLES
            binary_tab = lt_data
          EXCEPTIONS
            OTHERS     = 1. "#EC CI_SUBRC

        cl_gui_frontend_services=>file_save_dialog( EXPORTING  default_file_name = |Repair_Merged_{ sy-datum }.pdf|
                                                               default_extension = 'pdf'
                                                               file_filter       = 'PDF Files (*.pdf)|*.pdf'
                                                    CHANGING   filename          = lv_filename
                                                               path              = lv_path
                                                               fullpath          = lv_fpath
                                                               user_action       = lv_action
                                                    EXCEPTIONS OTHERS            = 1 ).

        IF lv_action = cl_gui_frontend_services=>action_ok AND lv_fpath IS NOT INITIAL.
          lv_filesize = xstrlen( lv_merged ).
          cl_gui_frontend_services=>gui_download( EXPORTING  filename     = lv_fpath
                                                             filetype     = 'BIN'
                                                             bin_filesize = lv_filesize
                                                  CHANGING   data_tab     = lt_data
                                                  EXCEPTIONS OTHERS       = 19 ).
        ENDIF.
      ELSE.
        MESSAGE TEXT-015 TYPE 'S' DISPLAY LIKE 'E'.
      ENDIF.
    ENDIF.

    MESSAGE |{ TEXT-012 }: { lv_count_ok } OK, { lv_count_err } { TEXT-013 }.| TYPE 'S'.
  ENDMETHOD.


  METHOD all_adobe.
    " Check if all SELECTED orders have form_type = 'A' (Adobe)
    DATA(lt_rows) = go_salv->get_selections( )->get_selected_rows( ).
    rv_result = abap_true.
    LOOP AT lt_rows INTO DATA(lv_row).
      ASSIGN gt_alv[ lv_row ] TO FIELD-SYMBOL(<ls>).
      IF sy-subrc = 0 AND <ls>-form_type <> 'A'.
        rv_result = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
    IF lt_rows IS INITIAL.
      rv_result = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD execute_print_bundled.
    DATA lt_rows TYPE salv_t_row.
    DATA lv_count_ok  TYPE i.
    DATA lv_count_err TYPE i.

    lt_rows = go_salv->get_selections( )->get_selected_rows( ).
    IF lt_rows IS INITIAL.
      MESSAGE TEXT-008 TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " Separate selected orders by form type
    DATA lt_adobe  TYPE TABLE OF ty_alv_line.
    DATA lt_smart  TYPE TABLE OF ty_alv_line.

    LOOP AT lt_rows INTO DATA(lv_row).
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
      DATA lv_printer      TYPE rspopname.
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
              lv_count_ok = lv_count_ok + 1.
            CATCH cx_root INTO DATA(lx_a).
              ASSIGN gt_alv[ aufnr = <ls_a>-aufnr ] TO <ls_alv_a>.
              IF sy-subrc = 0.
                <ls_alv_a>-icon = icon_led_red.
                <ls_alv_a>-msg  = lx_a->get_text( ).
              ENDIF.
              lv_count_err = lv_count_err + 1.
          ENDTRY.
        ENDLOOP.

        CALL FUNCTION 'FP_JOB_CLOSE' EXCEPTIONS OTHERS = 0.
      ENDIF.
    ENDIF.

    " --- SmartForm group: single spool via SSF_OPEN ---
    IF lt_smart IS NOT INITIAL.
      CALL FUNCTION 'SSF_OPEN'
        EXCEPTIONS
          OTHERS = 0.

      LOOP AT lt_smart ASSIGNING FIELD-SYMBOL(<ls_s>).
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
            lv_count_ok = lv_count_ok + 1.
          CATCH cx_root INTO DATA(lx_s).
            ASSIGN gt_alv[ aufnr = <ls_s>-aufnr ] TO <ls_alv_s>.
            IF sy-subrc = 0.
              <ls_alv_s>-icon = icon_led_red.
              <ls_alv_s>-msg  = lx_s->get_text( ).
            ENDIF.
            lv_count_err = lv_count_err + 1.
        ENDTRY.
      ENDLOOP.

      CALL FUNCTION 'SSF_CLOSE' EXCEPTIONS OTHERS = 0.
    ENDIF.

    MESSAGE |{ TEXT-012 }: { lv_count_ok } OK, { lv_count_err } { TEXT-013 }.| TYPE 'S'.
  ENDMETHOD.


  METHOD execute_pdf_merge_ads.
    DATA lt_rows TYPE salv_t_row.
    DATA lv_count_ok  TYPE i.
    DATA lv_count_err TYPE i.

    lt_rows = go_salv->get_selections( )->get_selected_rows( ).
    IF lt_rows IS INITIAL.
      MESSAGE TEXT-008 TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " Open ADS job in merge/bundle mode
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

    " Render each Adobe form inside the same ADS job
    LOOP AT lt_rows INTO DATA(lv_row).
      ASSIGN gt_alv[ lv_row ] TO FIELD-SYMBOL(<ls_line>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      cl_progress_indicator=>progress_indicate( i_text               = |{ TEXT-007 } { <ls_line>-aufnr } ({ sy-tabix }/{ lines( lt_rows ) })...|
                                                i_processed          = sy-tabix
                                                i_total              = lines( lt_rows )
                                                i_output_immediately = abap_true ).
      TRY.
          DATA(lr_driver) = /ctdi/cl_print_driver_base=>factory( iv_repair_id = <ls_line>-aufnr ).
          lr_driver->set_external_job( abap_true ).
          lr_driver->set_collect_pdf( abap_true ).
          lr_driver->execute( iv_save_as_pdf = abap_true
                              iv_no_dialog   = abap_true
                              iv_preview     = abap_false ).
          <ls_line>-icon = icon_led_green.
          <ls_line>-msg  = TEXT-011.
          lv_count_ok = lv_count_ok + 1.

        CATCH cx_root INTO DATA(lx).
          <ls_line>-icon = icon_led_red.
          <ls_line>-msg  = lx->get_text( ).
          lv_count_err = lv_count_err + 1.
      ENDTRY.
    ENDLOOP.

    " Close job and get merged PDF
    CALL FUNCTION 'FP_JOB_CLOSE' EXCEPTIONS OTHERS = 0.

    " Retrieve merged PDF from ADS
    DATA lt_pdf_table TYPE tfpcontent.
    CALL FUNCTION 'FP_GET_PDF_TABLE'
      IMPORTING
        e_pdf_table = lt_pdf_table.

    IF lt_pdf_table IS NOT INITIAL.
      DATA(lv_merged) = lt_pdf_table[ 1 ].

      " Download merged file
      DATA lv_filesize TYPE i.
      DATA lt_data     TYPE solix_tab.
      DATA lv_action   TYPE i.
      DATA lv_filename TYPE string.
      DATA lv_path     TYPE string.
      DATA lv_fpath    TYPE string.

      CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
        EXPORTING
          buffer     = lv_merged
        TABLES
          binary_tab = lt_data
        EXCEPTIONS
          OTHERS     = 1.

      cl_gui_frontend_services=>file_save_dialog(
        EXPORTING  default_file_name = |Repair_Merged_{ sy-datum }.pdf|
                   default_extension = 'pdf'
                   file_filter       = 'PDF Files (*.pdf)|*.pdf'
        CHANGING   filename          = lv_filename
                   path              = lv_path
                   fullpath          = lv_fpath
                   user_action       = lv_action
        EXCEPTIONS OTHERS            = 1 ).

      IF lv_action = cl_gui_frontend_services=>action_ok AND lv_fpath IS NOT INITIAL.
        lv_filesize = xstrlen( lv_merged ).
        cl_gui_frontend_services=>gui_download(
          EXPORTING  filename     = lv_fpath
                     filetype     = 'BIN'
                     bin_filesize = lv_filesize
          CHANGING   data_tab     = lt_data
          EXCEPTIONS OTHERS       = 19 ).
      ENDIF.
    ELSE.
      MESSAGE TEXT-015 TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.

    MESSAGE |{ TEXT-012 }: { lv_count_ok } OK, { lv_count_err } { TEXT-013 }.| TYPE 'S'.
  ENDMETHOD.


  METHOD execute_pdf_sel_parallel.
    DATA lt_rows TYPE salv_t_row.
    DATA lt_in   TYPE cl_abap_parallel=>t_in_tab.

    lt_rows = go_salv->get_selections( )->get_selected_rows( ).
    IF lt_rows IS INITIAL.
      MESSAGE TEXT-008 TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " Serialize input with pdf_mode = true
    LOOP AT lt_rows INTO DATA(lv_row).
      ASSIGN gt_alv[ lv_row ] TO FIELD-SYMBOL(<ls_line>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA lv_in TYPE xstring.
      EXPORT aufnr    = <ls_line>-aufnr
             pdf_mode = abap_true TO DATA BUFFER lv_in.
      APPEND lv_in TO lt_in.
    ENDLOOP.

    " Phase 1: Parallel render — collect PDF xstrings
    DATA(lo_parallel) = NEW lcl_parallel_print( p_num_tasks  = 10
                                                p_percentage = 50 ).
    DATA lt_out TYPE cl_abap_parallel=>t_out_tab.

    cl_progress_indicator=>progress_indicate( i_text               = |Parallel rendering { lines( lt_in ) } PDFs...|
                                              i_output_immediately = abap_true ).

    lo_parallel->run( EXPORTING p_in_tab  = lt_in
                      IMPORTING p_out_tab = lt_out ).

    " Phase 2: Sequential download of each PDF
    TYPES: BEGIN OF ty_result,
             aufnr    TYPE aufnr,
             icon     TYPE icon_d,
             msg      TYPE string,
             pdf_data TYPE xstring,
           END OF ty_result.

    DATA lv_count_ok  TYPE i.
    DATA lv_count_err TYPE i.

    " Ensure download directory is set
    IF p_pdf = abap_true AND p_dir IS NOT INITIAL.
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

      " Download PDF if available
      IF ls_result-pdf_data IS NOT INITIAL.
        DATA lt_data     TYPE solix_tab.
        DATA lv_filesize TYPE i.
        DATA lv_fpath    TYPE string.

        CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
          EXPORTING
            buffer     = ls_result-pdf_data
          TABLES
            binary_tab = lt_data
          EXCEPTIONS
            OTHERS     = 1.

        " Build filename from order number (full naming was done in the parallel task)
        DATA(lv_aufnr_out) = |{ ls_result-aufnr ALPHA = OUT }|.
        CONDENSE lv_aufnr_out.
        DATA(lv_fname) = |Repair_{ lv_aufnr_out }.pdf|.

        IF /ctdi/cl_print_driver_base=>get_download_dir( ) IS NOT INITIAL.
          lv_fpath = /ctdi/cl_print_driver_base=>get_download_dir( ) && lv_fname.
        ELSE.
          " First file: prompt for directory
          DATA lv_action   TYPE i.
          DATA lv_filename TYPE string.
          DATA lv_path     TYPE string.
          DATA lv_fullpath TYPE string.

          cl_gui_frontend_services=>file_save_dialog(
            EXPORTING  default_file_name = lv_fname
                       default_extension = 'pdf'
                       file_filter       = 'PDF Files (*.pdf)|*.pdf'
            CHANGING   filename          = lv_filename
                       path              = lv_path
                       fullpath          = lv_fullpath
                       user_action       = lv_action
            EXCEPTIONS OTHERS            = 1 ).

          IF lv_action <> cl_gui_frontend_services=>action_ok OR lv_fullpath IS INITIAL.
            CONTINUE.
          ENDIF.
          /ctdi/cl_print_driver_base=>set_download_dir( lv_path ).
          lv_fpath = lv_fullpath.
        ENDIF.

        lv_filesize = xstrlen( ls_result-pdf_data ).
        cl_gui_frontend_services=>gui_download(
          EXPORTING  filename     = lv_fpath
                     filetype     = 'BIN'
                     bin_filesize = lv_filesize
          CHANGING   data_tab     = lt_data
          EXCEPTIONS OTHERS       = 19 ).
      ENDIF.

      " Update ALV
      ASSIGN gt_alv[ aufnr = ls_result-aufnr ] TO FIELD-SYMBOL(<ls_alv>).
      IF sy-subrc = 0.
        <ls_alv>-icon = ls_result-icon.
        <ls_alv>-msg  = COND #( WHEN ls_result-icon = icon_led_green
                                 THEN TEXT-011
                                 ELSE ls_result-msg ).
        IF ls_result-icon = icon_led_green.
          lv_count_ok = lv_count_ok + 1.
        ELSE.
          lv_count_err = lv_count_err + 1.
        ENDIF.
      ENDIF.
    ENDLOOP.

    MESSAGE |{ TEXT-012 }: { lv_count_ok } OK, { lv_count_err } { TEXT-013 }.| TYPE 'S'.
  ENDMETHOD.

ENDCLASS.


" -----------------------------------------------------------------------

INITIALIZATION.
  " Default qmart pattern: Z*
  s_qmart[] = VALUE #( ( sign = 'I' option = 'CP' low = 'Z*' ) ).

  DATA lv_desktop_dir TYPE string.

  cl_gui_frontend_services=>get_desktop_directory( CHANGING   desktop_directory = lv_desktop_dir
                                                   EXCEPTIONS OTHERS            = 1 ).
  IF sy-subrc = 0 AND lv_desktop_dir IS NOT INITIAL.
    cl_gui_cfw=>flush( ).
    p_dir = lv_desktop_dir.
  ELSE.
    p_dir = 'C:\temp\'.
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
