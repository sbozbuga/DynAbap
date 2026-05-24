CLASS lcl_test DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA: cut TYPE REF TO /cdti/cl_repair_print_engine.

    METHODS setup.
    METHODS test_invalid_repair FOR TESTING.
    METHODS test_missing_customizing FOR TESTING.
ENDCLASS.


CLASS lcl_test IMPLEMENTATION.

  METHOD setup.
    CREATE OBJECT cut.
  ENDMETHOD.

  METHOD test_invalid_repair.
    " Test that an invalid/non-existing repair number correctly raises an exception
    TRY.
        cut->print( iv_repair_id = '0000000000' ).
        cl_abap_unit_assert=>fail( msg = 'Should have failed for invalid repair id' ).
      CATCH cx_root.
        " Success: exception correctly raised
    ENDTRY.
  ENDMETHOD.

  METHOD test_missing_customizing.
    " Test that calling a non-configured or missing AUART repair raises a /cdti/cx_no_config_found exception
    TRY.
        cut->print( iv_repair_id = '9999999999' ).
        cl_abap_unit_assert=>fail( msg = 'Should have raised exception for missing configuration' ).
      CATCH /cdti/cx_no_config_found.
        " Success: correct fallback exception successfully raised
      CATCH cx_root.
        cl_abap_unit_assert=>fail( msg = 'Incorrect exception raised instead of /cdti/cx_no_config_found' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
