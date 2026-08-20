CLASS lcl_test_data_ctdi DEFINITION DEFERRED.
CLASS /ctdi/cl_print_data_ctdi DEFINITION LOCAL FRIENDS lcl_test_data_ctdi.

CLASS lcl_test_data_ctdi DEFINITION
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA f_cut TYPE REF TO /ctdi/cl_print_data_ctdi.

    METHODS setup.
    METHODS teardown.
    METHODS test_map_legacy_fields FOR TESTING.
    METHODS test_map_legacy_errors_dedup FOR TESTING.
    METHODS test_map_legacy_comments FOR TESTING.
    METHODS test_read_data_invalid_order FOR TESTING.
ENDCLASS.


CLASS lcl_test_data_ctdi IMPLEMENTATION.
  METHOD setup.
    CREATE OBJECT f_cut.
  ENDMETHOD.

  METHOD teardown.
    CLEAR f_cut.
  ENDMETHOD.

  METHOD test_map_legacy_fields.
    f_cut->ms_legacy-csaufnr       = '000000123456'.
    f_cut->ms_legacy-ctdi_order_no = '100234-01'.
    f_cut->ms_legacy-po_no         = 'PO4500001'.
    f_cut->ms_legacy-new_serial_no = 'SN9988'.

    f_cut->map_legacy_data( ).

    cl_abap_unit_assert=>assert_equals(
      act = f_cut->ms_repair-csaufnr
      exp = '000000123456'
      msg = 'csaufnr should be mapped to ms_repair' ).

    cl_abap_unit_assert=>assert_equals(
      act = f_cut->ms_repair-ctdi_order_no
      exp = '100234-01'
      msg = 'ctdi_order_no should be mapped to ms_repair' ).

    cl_abap_unit_assert=>assert_equals(
      act = f_cut->ms_repair-po_no
      exp = 'PO4500001'
      msg = 'po_no should be mapped to ms_repair' ).

    cl_abap_unit_assert=>assert_equals(
      act = f_cut->ms_repair-new_serial_no
      exp = 'SN9988'
      msg = 'new_serial_no should be mapped to ms_repair' ).
  ENDMETHOD.

  METHOD test_map_legacy_errors_dedup.
    f_cut->mt_legacy_error = VALUE #(
      ( oteil_ktxt = 'Display' fecod_ktxt = 'Glass cracked' )
      ( oteil_ktxt = 'Battery' fecod_ktxt = 'No charge' )
      ( oteil_ktxt = 'Display' fecod_ktxt = 'Glass cracked' ) ).

    f_cut->map_legacy_data( ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( f_cut->mt_repair_error )
      exp = 2
      msg = 'Duplicate errors should be eliminated after formatting' ).

    READ TABLE f_cut->mt_repair_error ASSIGNING FIELD-SYMBOL(<ls_err1>) INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = <ls_err1>-error_text
      exp = 'Battery / No charge'
      msg = 'First error should be sorted and formatted correctly' ).

    READ TABLE f_cut->mt_repair_error ASSIGNING FIELD-SYMBOL(<ls_err2>) INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = <ls_err2>-error_text
      exp = 'Display / Glass cracked'
      msg = 'Second error should be sorted and formatted correctly' ).
  ENDMETHOD.

  METHOD test_map_legacy_comments.
    f_cut->mt_comment_lines = VALUE #(
      ( tdformat = '*' tdline = 'Comment line 1' )
      ( tdformat = '/' tdline = 'Comment line 2' ) ).

    f_cut->map_legacy_data( ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( f_cut->mt_comments )
      exp = 2
      msg = 'Comments table should be populated from legacy comments' ).
  ENDMETHOD.

  METHOD test_read_data_invalid_order.
    TRY.
        f_cut->read_data( iv_aufnr = '999999999999' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>assert_not_initial(
          act = lx_err->get_text( )
          msg = 'Invalid repair order should raise informative error' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
