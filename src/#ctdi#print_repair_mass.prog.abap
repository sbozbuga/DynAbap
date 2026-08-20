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
         msg         TYPE string,         " Message (success/error)
       END OF ty_alv_line.

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
    CLASS-METHODS display_alv.

    CLASS-METHODS on_user_command FOR EVENT added_function OF cl_salv_events_table
      IMPORTING e_salv_function.

    CLASS-METHODS execute_print
      IMPORTING iv_save_as_pdf TYPE abap_bool
                iv_merge       TYPE abap_bool DEFAULT abap_false.
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
  ENDMETHOD.

  METHOD display_alv.
    DATA lo_functions  TYPE REF TO cl_salv_functions_list.
    DATA lo_columns    TYPE REF TO cl_salv_columns_table.
    DATA lo_column     TYPE REF TO cl_salv_column.
    DATA lo_events     TYPE REF TO cl_salv_events_table.
    DATA lo_selections TYPE REF TO cl_salv_selections.

    TRY.
        cl_salv_table=>factory( EXPORTING r_container  = cl_gui_container=>default_screen
                                IMPORTING r_salv_table = go_salv
                                CHANGING  t_table      = gt_alv ).
      CATCH cx_salv_msg INTO DATA(lx_msg).
        MESSAGE lx_msg->get_text( ) TYPE 'E'.
        RETURN.
    ENDTRY.

    " Enable ALV functions (sort, filter, export, etc.)
    lo_functions = go_salv->get_functions( ).
    lo_functions->set_all( abap_true ).

    " Add custom buttons
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

    " Register event handler
    lo_events = go_salv->get_event( ).
    SET HANDLER on_user_command FOR lo_events.

    " Set title with record count
    sy-title = |{ sy-title } ({ lines( gt_alv ) })|.

    " Display
    go_salv->display( ).

    " Required to trigger default_screen output
    WRITE space.
  ENDMETHOD.

  METHOD on_user_command.
    CASE e_salv_function.
      WHEN 'PRINT_SEL'.
        execute_print( iv_save_as_pdf = abap_false
                       iv_merge       = abap_false ).
        go_salv->get_columns( )->set_optimize( abap_true ).
        go_salv->refresh( s_stable = VALUE #( row = abap_true
                                              col = abap_true ) ).

      WHEN 'PDF_SEL'.
        execute_print( iv_save_as_pdf = abap_true
                       iv_merge       = abap_false ).
        go_salv->get_columns( )->set_optimize( abap_true ).
        go_salv->refresh( s_stable = VALUE #( row = abap_true
                                              col = abap_true ) ).

      WHEN 'PDF_MERGE'.
        execute_print( iv_save_as_pdf = abap_true
                       iv_merge       = abap_true ).
        go_salv->get_columns( )->set_optimize( abap_true ).
        go_salv->refresh( s_stable = VALUE #( row = abap_true
                                              col = abap_true ) ).
    ENDCASE.
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
