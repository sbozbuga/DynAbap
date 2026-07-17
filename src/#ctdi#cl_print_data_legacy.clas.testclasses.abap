CLASS lcl_test_data_legacy DEFINITION DEFERRED.
CLASS /ctdi/cl_print_data_legacy DEFINITION LOCAL FRIENDS lcl_test_data_legacy.

CLASS lcl_test_data_legacy DEFINITION FOR TESTING
  DURATION MEDIUM
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA f_cut TYPE REF TO /ctdi/cl_print_data_legacy.

    METHODS setup.
    METHODS read_data_invalid_order FOR TESTING.
    METHODS read_data_empty_aufnr FOR TESTING.
    METHODS read_data_sets_language FOR TESTING.
    METHODS convert_timestamp FOR TESTING.
ENDCLASS.


CLASS lcl_test_data_legacy IMPLEMENTATION.

  METHOD setup.
    CREATE OBJECT f_cut.
  ENDMETHOD.


  METHOD read_data_invalid_order.
    TRY.
        f_cut->read_data( iv_aufnr = '999999999999' ).
        cl_abap_unit_assert=>assert_initial(
          act = f_cut->ms_legacy-date_repaired
          msg = 'Non-existent order should have no repair date' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>assert_not_initial(
          act = lx_err->get_text( )
          msg = 'Exception should carry a diagnostic message' ).
    ENDTRY.
  ENDMETHOD.


  METHOD read_data_empty_aufnr.
    TRY.
        f_cut->read_data( iv_aufnr = '' ).
        cl_abap_unit_assert=>assert_initial(
          act = f_cut->ms_legacy-csaufnr
          msg = 'Empty order should not populate csaufnr' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>assert_not_initial(
          act = lx_err->get_text( )
          msg = 'Exception should carry a message for empty order' ).
    ENDTRY.
  ENDMETHOD.


  METHOD read_data_sets_language.
    TRY.
        f_cut->read_data( iv_aufnr = '999999999999' ).
      CATCH /ctdi/cx_print_driver_error ##NO_HANDLER.
    ENDTRY.
    IF sy-langu = 'D'.
      cl_abap_unit_assert=>assert_equals(
        act = f_cut->mv_spras
        exp = 'D'
        msg = 'German logon should set spras to D' ).
    ELSE.
      cl_abap_unit_assert=>assert_equals(
        act = f_cut->mv_spras
        exp = 'E'
        msg = 'Non-German logon should default spras to E' ).
    ENDIF.
  ENDMETHOD.


  METHOD convert_timestamp.
    DATA(lv_ts) = f_cut->convert_to_timestamp(
                    iv_date = '20260101'
                    iv_time = '120000' ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_ts
      msg = 'Valid date/time should produce a non-zero timestamp' ).
  ENDMETHOD.

ENDCLASS.
