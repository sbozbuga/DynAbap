*&---------------------------------------------------------------------*
*& Report zsd_contract_print_program
*&---------------------------------------------------------------------*
*& Standard Output Determination Wrapper for Sales Contract printing
*&---------------------------------------------------------------------*
REPORT zsd_contract_print_program.

" Global data structures for Output Determination (NAST is filled by standard SAP framework)
TABLES: nast, tnapr.

*&---------------------------------------------------------------------*
*& Form ENTRY
*&---------------------------------------------------------------------*
*& Entry point called by Output Determination (NACE / TNAPR)
*&---------------------------------------------------------------------*
FORM entry USING ent_retco TYPE sysubrc
                 ent_screen TYPE c.

  DATA: lv_contract_id TYPE vbeln_va,
        lo_engine      TYPE REF TO zcl_contract_print_engine.

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

  TRY.
      " Instantiate the dynamic mapping and printing engine
      CREATE OBJECT lo_engine.

      " Call the dynamic printing method
      lo_engine->print( iv_contract_id = lv_contract_id ).

    CATCH cx_root.
      " Set return code to 4 to signal output execution failed
      ent_retco = 4.
  ENDTRY.

ENDFORM.
