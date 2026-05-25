*&---------------------------------------------------------------------*
*& Report /ctdi/sd_repair_print_program
*&---------------------------------------------------------------------*
*& Standard Output Determination Wrapper & Executable Repair Print
*&---------------------------------------------------------------------*
REPORT /ctdi/sd_repair_print_program.

" Global data structures for Output Determination (NAST is filled by standard SAP framework)
TABLES: nast, tnapr.

*&---------------------------------------------------------------------*
*& Selection Screen Definition (For Standalone Executable Mode)
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE 'Selection Criteria'(002).
  PARAMETERS: p_aufnr TYPE aufk-aufnr.
  PARAMETERS: p_sernr TYPE equi-sernr.
  PARAMETERS: p_pdf   TYPE abap_bool.
SELECTION-SCREEN END OF BLOCK b1.

*&---------------------------------------------------------------------*
*& START-OF-SELECTION (Triggered when run directly via SE38/SA38)
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  DATA: lo_direct_engine TYPE REF TO /ctdi/cl_repair_print_engine,
        ls_repair        TYPE /ctdi/repair,
        lt_repair_error  TYPE TABLE OF /ctdi/repair_error,
        lt_comment_lines TYPE TABLE OF tline.

  TRY.
      " Optional: populate standard repair data here if needed by your print class/forms
      ls_repair-vbeln = p_aufnr.
      ls_repair-sernr = p_sernr.

      CREATE OBJECT lo_direct_engine.
      lo_direct_engine->execute( EXPORTING iv_repair_id     = p_aufnr
                                           iv_save_as_pdf   = p_pdf
                                 CHANGING  cs_repair        = ls_repair
                                           ct_repair_error  = lt_repair_error
                                           ct_comment_lines = lt_comment_lines ).
    CATCH /ctdi/cx_no_config_found.
      " Fall back to legacy printing logic
      PERFORM print_old USING p_aufnr p_pdf.
    CATCH /ctdi/cx_print_error INTO DATA(lx_direct_print_err).
      DATA(lv_direct_err) = |{ 'Print failed: &1'(003) }|.
      REPLACE '&1' IN lv_direct_err WITH lx_direct_print_err->message.
      MESSAGE lv_direct_err TYPE 'E'.
    CATCH cx_root INTO DATA(lx_direct_root).
      DATA(lv_direct_root_err) = |{ 'Error executing dynamic repair print: &1'(004) }|.
      REPLACE '&1' IN lv_direct_root_err WITH lx_direct_root->get_text( ).
      MESSAGE lv_direct_root_err TYPE 'E'.
    ENDTRY.

*&---------------------------------------------------------------------*
*& Form ENTRY
*&---------------------------------------------------------------------*
*& Entry point called by Output Determination (NACE / TNAPR)
*&---------------------------------------------------------------------*
FORM entry USING ent_retco TYPE sysubrc
                 ent_screen TYPE c.

  DATA: lv_repair_id     TYPE vbeln_va,
        lo_engine        TYPE REF TO /ctdi/cl_repair_print_engine,
        ls_repair        TYPE /ctdi/repair,
        lt_repair_error  TYPE TABLE OF /ctdi/repair_error,
        lt_comment_lines TYPE TABLE OF tline.

  " Clear return code
  ent_retco = 0.

  " The NAST table holds the currently processed output record.
  " NAST-OBJKY contains the Sales Document / Repair Number (VBELN).
  IF nast-objky IS INITIAL.
    ent_retco = 4.
    RETURN.
  ENDIF.

  " Format the Sales Document / Repair ID (enforce standard internal format)
  lv_repair_id = |{ nast-objky ALPHA = IN }|.

  TRY.
      " Optional: populate standard repair data here if needed by your print class/forms
      ls_repair-vbeln = lv_repair_id.

      " Instantiate the dynamic mapping and printing engine
      CREATE OBJECT lo_engine.

      " Call the dynamic printing method (Output Determination always defaults to Spool/Print)
      lo_engine->execute( EXPORTING iv_repair_id     = lv_repair_id
                          CHANGING  cs_repair        = ls_repair
                                    ct_repair_error  = lt_repair_error
                                    ct_comment_lines = lt_comment_lines ).

    CATCH /ctdi/cx_no_config_found.
      " Fall back to legacy printing logic
      PERFORM print_old USING lv_repair_id abap_false.
    CATCH /ctdi/cx_print_error INTO DATA(lx_print_err).
      " Output determination logs error
      DATA(lv_entry_err) = |{ 'Dynamic repair print failed: &1'(005) }|.
      REPLACE '&1' IN lv_entry_err WITH lx_print_err->message.
      MESSAGE lv_entry_err TYPE 'E'.
      ent_retco = 4.
    CATCH cx_root.
      " Set return code to 4 to signal output execution failed
      ent_retco = 4.
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form print_old
*&---------------------------------------------------------------------*
*& Old/legacy repair printing routine (fallback logic)
*&---------------------------------------------------------------------*
FORM print_old USING iv_repair_id TYPE vbeln_va
                     iv_save_as_pdf TYPE abap_bool.

  " Place your legacy repair printing routines here.
  " This triggers when no custom mapping exists for the Sales Repair AUART in /CTDI/REP_FORMS.
  DATA(lv_legacy_msg) = |{ 'Executing legacy printing routine (print_old) for repair &1'(006) }|.
  REPLACE '&1' IN lv_legacy_msg WITH iv_repair_id.
  MESSAGE lv_legacy_msg TYPE 'I'.

ENDFORM.
