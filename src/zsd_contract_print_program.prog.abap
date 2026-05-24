*&---------------------------------------------------------------------*
*& Report zsd_contract_print_program
*&---------------------------------------------------------------------*
*& Standard Output Determination Wrapper & Executable Contract Print
*&---------------------------------------------------------------------*
REPORT zsd_contract_print_program.

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
  DATA: lo_direct_engine TYPE REF TO zcl_contract_print_engine.

  TRY.
      CREATE OBJECT lo_direct_engine.
      lo_direct_engine->print( iv_contract_id = p_vbeln
                               iv_save_as_pdf = p_pdf ).
    CATCH cx_root.
      MESSAGE 'Error executing dynamic contract print.' TYPE 'E'.
  ENDTRY.

*&---------------------------------------------------------------------*
*& Form ENTRY
*&---------------------------------------------------------------------*
*& Entry point called by Output Determination (NACE / TNAPR)
*&---------------------------------------------------------------------*
FORM entry USING ent_retco TYPE sysubrc
                 ent_screen TYPE c.

  DATA: lv_contract_id TYPE vbeln_va,
        lo_engine      TYPE REF TO zcl_contract_print_engine,
        lv_save_as_pdf TYPE abap_bool,
        lv_answer      TYPE c.

  " Clear return code
  ent_retco = 0.

  " The NAST table holds the currently processed output record.
  " NAST-OBJKY contains the Sales Document / Contract Number (VBELN).
  IF nast-objky IS INITIAL.
    ent_retco = 4.
    RETURN.
  ENDIF.

  " Format the Sales Document / Contract ID (enforce standard internal format)
  lv_contract_id = |{ nast-objky ALPHA = IN }|.

  " If processed interactively in the foreground, prompt the user for printing options
  IF ent_screen = abap_true.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Contract Output Options'
        text_question         = 'Do you want to save this Customer Project Repair contract as a local PDF?'
        text_button_1         = 'Save as PDF'
        text_button_2         = 'Standard Print/Spool'
        default_button        = '1'
        display_cancel_button = abap_false
      IMPORTING
        answer                = lv_answer
      EXCEPTIONS
        text_not_found        = 1
        others                = 2.
    IF sy-subrc = 0 AND lv_answer = '1'.
      lv_save_as_pdf = abap_true.
    ENDIF.
  ENDIF.

  TRY.
      " Instantiate the dynamic mapping and printing engine
      CREATE OBJECT lo_engine.

      " Call the dynamic printing method passing the option to save as PDF or spool
      lo_engine->print( iv_contract_id = lv_contract_id
                        iv_save_as_pdf = lv_save_as_pdf ).

    CATCH cx_root.
      " Set return code to 4 to signal output execution failed
      ent_retco = 4.
  ENDTRY.

ENDFORM.
