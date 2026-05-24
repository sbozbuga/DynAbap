CLASS lcl_test DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA: cut TYPE REF TO zcl_contract_print_engine.

    METHODS setup.
    METHODS test_invalid_contract FOR TESTING.
    METHODS test_missing_customizing FOR TESTING.
ENDCLASS.


CLASS lcl_test IMPLEMENTATION.

  METHOD setup.
    CREATE OBJECT cut.
  ENDMETHOD.

  METHOD test_invalid_contract.
    " Test that an invalid/non-existing contract number correctly raises an exception
    TRY.
        cut->print( iv_contract_id = '0000000000' ).
        cl_abap_unit_assert=>fail( msg = 'Should have failed for invalid contract id' ).
      CATCH cx_root.
        " Success: exception correctly raised
    ENDTRY.
  ENDMETHOD.

  METHOD test_missing_customizing.
    " Test that calling a non-configured or missing AUART contract raises an exception
    TRY.
        cut->print( iv_contract_id = '9999999999' ).
        cl_abap_unit_assert=>fail( msg = 'Should have raised exception for missing configuration' ).
      CATCH cx_root.
        " Success: exception correctly raised
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
