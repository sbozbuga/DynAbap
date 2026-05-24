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
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-002.
  PARAMETERS: p_vbeln TYPE vbeln_va OBLIGATORY,
              p_pdf   TYPE abap_bool AS CHECKBOX DEFAULT abap_false.
SELECTION-SCREEN END OF BLOCK b1.

*&---------------------------------------------------------------------*
*& START-OF-SELECTION (Triggered when run directly via SE38/SA38)
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  DATA: lo_direct_engine TYPE REF TO /ctdi/cl_repair_print_engine.

  TRY.
      CREATE OBJECT lo_direct_engine.
      lo_direct_engine->execute( iv_repair_id = p_vbeln
                                 iv_save_as_pdf = p_pdf ).
    CATCH /ctdi/cx_no_config_found.
      " Fall back to legacy printing logic
      PERFORM print_old USING p_vbeln p_pdf.
    CATCH /ctdi/cx_print_error INTO DATA(lx_direct_print_err).
      MESSAGE |Print failed: { lx_direct_print_err->message }| TYPE 'E'.
    CATCH cx_root INTO DATA(lx_direct_root).
      MESSAGE |Error executing dynamic repair print: { lx_direct_root->get_text( ) }| TYPE 'E'.
    ENDTRY.

*&---------------------------------------------------------------------*
*& Form ENTRY
*&---------------------------------------------------------------------*
*& Entry point called by Output Determination (NACE / TNAPR)
*&---------------------------------------------------------------------*
FORM entry USING ent_retco TYPE sysubrc
                 ent_screen TYPE c.

  DATA: lv_repair_id TYPE vbeln_va,
        lo_engine      TYPE REF TO /ctdi/cl_repair_print_engine.

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
      " Instantiate the dynamic mapping and printing engine
      CREATE OBJECT lo_engine.

      " Call the dynamic printing method (Output Determination always defaults to Spool/Print)
      lo_engine->execute( iv_repair_id = lv_repair_id ).

    CATCH /ctdi/cx_no_config_found.
      " Fall back to legacy printing logic
      PERFORM print_old USING lv_repair_id abap_false.
    CATCH /ctdi/cx_print_error INTO DATA(lx_print_err).
      " Output determination logs error
      MESSAGE |Dynamic repair print failed: { lx_print_err->message }| TYPE 'E'.
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
  " This triggers when no custom mapping exists for the Sales Repair AUART in /CTDI/SD_REPAIR_FORM.
  MESSAGE |Executing legacy printing routine (print_old) for repair { iv_repair_id }| TYPE 'I'.

ENDFORM.
