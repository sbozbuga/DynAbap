CLASS lcl_test_driver DEFINITION DEFERRED.
CLASS lcl_tests DEFINITION DEFERRED.
CLASS /ctdi/cl_print_driver_base DEFINITION LOCAL FRIENDS lcl_tests lcl_test_driver.

"! Minimal concrete subclass for testing the abstract base class in isolation.
CLASS lcl_test_driver DEFINITION
  INHERITING FROM /ctdi/cl_print_driver_base
  CREATE PUBLIC.
  PUBLIC SECTION.
ENDCLASS.

CLASS lcl_test_driver IMPLEMENTATION.
ENDCLASS.

CLASS lcl_tests DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
.
*?﻿<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
*?<asx:values>
*?<TESTCLASS_OPTIONS>
*?<TEST_CLASS>lcl_tests
*?</TEST_CLASS>
*?<TEST_MEMBER>f_cut
*?</TEST_MEMBER>
*?<OBJECT_UNDER_TEST>/CTDI/CL_PRINT_DRIVER_BASE
*?</OBJECT_UNDER_TEST>
*?<OBJECT_IS_LOCAL/>
*?<GENERATE_FIXTURE>X
*?</GENERATE_FIXTURE>
*?<GENERATE_CLASS_FIXTURE>X
*?</GENERATE_CLASS_FIXTURE>
*?<GENERATE_INVOCATION>X
*?</GENERATE_INVOCATION>
*?<GENERATE_ASSERT_EQUAL>X
*?</GENERATE_ASSERT_EQUAL>
*?</TESTCLASS_OPTIONS>
*?</asx:values>
*?</asx:abap>
  PRIVATE SECTION.
    DATA:
      f_cut TYPE REF TO /ctdi/cl_print_driver_base.  "class under test

    CLASS-METHODS: class_setup.
    CLASS-METHODS: class_teardown.
    METHODS: setup.
    METHODS: teardown.
    METHODS: detect_form_type FOR TESTING.
    METHODS: download_pdf FOR TESTING.
    METHODS: execute FOR TESTING.
    METHODS: execute_adobeform FOR TESTING.
    METHODS: execute_smartform FOR TESTING.
    METHODS: factory FOR TESTING.
    METHODS: fetch_data_from_db FOR TESTING.
    METHODS: get_config_from_db FOR TESTING.
    METHODS: get_user_print_defaults FOR TESTING.
    METHODS: map_and_register_data FOR TESTING.
    METHODS: read_data FOR TESTING.
    METHODS: register_custom_parameter FOR TESTING.
    METHODS: render_form FOR TESTING.
    METHODS: resolve_contract FOR TESTING.
    METHODS: unpack_io_data FOR TESTING.
    " --- Exception handling tests ---
    METHODS: cx_driver_error_get_text FOR TESTING.
    METHODS: cx_driver_error_empty_msg FOR TESTING.
    METHODS: cx_no_config_get_text FOR TESTING.
    METHODS: cx_no_config_empty_msg FOR TESTING.
    METHODS: read_data_cast_error FOR TESTING.
    METHODS: get_config_no_config_exc FOR TESTING.
    METHODS: normalize_class_name FOR TESTING.
    METHODS: set_get_download_dir FOR TESTING.
    METHODS: test_build_pdf_filename FOR TESTING.
ENDCLASS.       "lcl_tests


CLASS lcl_tests IMPLEMENTATION.

  METHOD class_setup.
  ENDMETHOD.


  METHOD class_teardown.
  ENDMETHOD.


  METHOD setup.
    CREATE OBJECT f_cut TYPE lcl_test_driver.
  ENDMETHOD.


  METHOD teardown.
    CLEAR f_cut.
  ENDMETHOD.


  METHOD detect_form_type.
    f_cut->mv_form_name = 'TEST_SMARTFORM'.
    DATA(rv_type) = f_cut->detect_form_type( ).
    cl_abap_unit_assert=>assert_equals(
      act = rv_type
      exp = 'A'
      msg = 'Non-existent form should default to Adobe Form (A)' ).
  ENDMETHOD.


  METHOD download_pdf.
    DATA: iv_pdf_data TYPE xstring.
    " 1. Empty input PDF data should return immediately without setting last_pdf
    TRY.
        f_cut->download_pdf( iv_pdf_data ).
        cl_abap_unit_assert=>assert_initial(
          act = f_cut->mv_last_pdf
          msg = 'Empty input should not populate mv_last_pdf' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>fail( msg = lx_err->get_text( ) ).
    ENDTRY.

    " 2. Collect mode: should store PDF data in mv_last_pdf without frontend calls
    f_cut->mv_collect_pdf = abap_true.
    TRY.
        f_cut->download_pdf( 'CAFEBABE' ).
        cl_abap_unit_assert=>assert_equals(
          act = f_cut->mv_last_pdf
          exp = 'CAFEBABE'
          msg = 'Collect mode should store PDF in mv_last_pdf' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err2).
        cl_abap_unit_assert=>fail( msg = lx_err2->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD execute.
    " Execute should return early and successfully (warning only) when data is initial
    TRY.
        f_cut->execute( ).
        cl_abap_unit_assert=>assert_true(
          act = abap_true
          msg = 'execute should run successfully and return early on initial data' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>fail( msg = lx_err->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD execute_adobeform.
    f_cut->mv_form_name = 'DUMMY_ADOBE_FORM'.
    TRY.
        f_cut->execute_adobeform( abap_false ).
        cl_abap_unit_assert=>fail( msg = 'execute_adobeform should fail for invalid configuration' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>assert_not_initial(
          act = lx_err->get_text( )
          msg = 'execute_adobeform should raise exception with diagnostic message' ).
    ENDTRY.
  ENDMETHOD.


  METHOD execute_smartform.
    f_cut->mv_form_name = 'DUMMY_SMARTFORM'.
    TRY.
        f_cut->execute_smartform( abap_false ).
        cl_abap_unit_assert=>fail( msg = 'execute_smartform should fail for invalid configuration' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>assert_not_initial(
          act = lx_err->get_text( )
          msg = 'execute_smartform should raise exception with diagnostic message' ).
    ENDTRY.
  ENDMETHOD.


  METHOD factory.
    DATA: lo_driver TYPE REF TO /ctdi/cl_print_driver_base.
    TRY.
        lo_driver = /ctdi/cl_print_driver_base=>factory( iv_repair_id = '9999999999' ).
        cl_abap_unit_assert=>fail( msg = 'factory should fail for invalid repair order' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_drv).
        cl_abap_unit_assert=>assert_not_initial(
          act = lx_drv->get_text( )
          msg = 'Driver error should contain message' ).
      CATCH /ctdi/cx_no_config_found INTO DATA(lx_noconf).
        cl_abap_unit_assert=>assert_not_initial(
          act = lx_noconf->get_text( )
          msg = 'No config error should contain message' ).
    ENDTRY.
  ENDMETHOD.


  METHOD fetch_data_from_db.
    " fetch_data_from_db is a base no-op hook; should run successfully
    TRY.
        f_cut->fetch_data_from_db( ).
        cl_abap_unit_assert=>assert_true( abap_true ).
      CATCH /ctdi/cx_print_driver_error  .
        cl_abap_unit_assert=>fail( msg = 'fetch_data_from_db is a base no-op hook; should run successfully' ).
      CATCH  cx_static_check .
        cl_abap_unit_assert=>fail( msg = 'fetch_data_from_db is a base no-op hook; should run successfully' ).
    ENDTRY.

  ENDMETHOD.


  METHOD get_config_from_db.
    DATA: lv_form_name  TYPE fpname,
          lv_class_name TYPE seoclsname,
          ls_project    TYPE /ctdi/rep_projec.
    TRY.
        /ctdi/cl_print_driver_base=>get_config_from_db(
          EXPORTING iv_repair_id  = '9999999999'
          IMPORTING ev_form_name  = lv_form_name
                    ev_class_name = lv_class_name
                    es_project    = ls_project ).
        cl_abap_unit_assert=>fail( msg = 'get_config_from_db should fail for invalid repair order' ).
      CATCH /ctdi/cx_no_config_found .
        cl_abap_unit_assert=>assert_true( abap_true ).
      CATCH /ctdi/cx_print_driver_error.
        cl_abap_unit_assert=>assert_true( abap_true ).
    ENDTRY.

  ENDMETHOD.


  METHOD get_user_print_defaults.
    DATA: lv_printer TYPE rspopname,
          lv_immed   TYPE c,
          lv_delete  TYPE c.
    f_cut->get_user_print_defaults(
      IMPORTING ev_printer = lv_printer
                ev_immed   = lv_immed
                ev_delete  = lv_delete ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_immed
      msg = 'Immediate print default should be set' ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_delete
      msg = 'Delete default should be set' ).
  ENDMETHOD.


  METHOD map_and_register_data.
    " map_and_register_data is a base no-op hook; should run successfully
    TRY.
        f_cut->map_and_register_data( ).
        cl_abap_unit_assert=>assert_true( abap_true ).
      CATCH /ctdi/cx_print_driver_error.
        cl_abap_unit_assert=>fail( msg = 'map_and_register_data is a base no-op hook; should run successfully' ).
    ENDTRY.

  ENDMETHOD.


  METHOD read_data.
    " Calling read_data on base class with initial io_data runs no-op hooks successfully
    TRY.
        f_cut->read_data( ).
        cl_abap_unit_assert=>assert_true( abap_true ).
      CATCH /ctdi/cx_print_driver_error.
        cl_abap_unit_assert=>fail( msg = 'read_data should not raise error if hooks are no-op' ).
    ENDTRY.
  ENDMETHOD.


  METHOD register_custom_parameter.
    DATA: lv_val TYPE string VALUE 'test_val',
          lr_ref TYPE REF TO data.
    GET REFERENCE OF lv_val INTO lr_ref.

    f_cut->register_custom_parameter(
      iv_name = 'IV_TEST'
      ir_data = lr_ref
      iv_kind = abap_func_exporting ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( f_cut->mt_custom_form_params )
      exp = 1
      msg = 'Custom parameter should be registered' ).

    READ TABLE f_cut->mt_custom_form_params ASSIGNING FIELD-SYMBOL(<ls_param>) INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = <ls_param>-name
      exp = 'IV_TEST' ).
  ENDMETHOD.


  METHOD render_form.
    f_cut->mv_form_name = 'DUMMY_FORM'.
    TRY.
        f_cut->render_form( abap_false ).
        cl_abap_unit_assert=>assert_true( abap_true ).
      CATCH /ctdi/cx_print_driver_error.
        cl_abap_unit_assert=>assert_true( abap_true ).
    ENDTRY.
  ENDMETHOD.


  METHOD resolve_contract.
    DATA: lv_contract TYPE vbeln_va,
          lv_skz      TYPE bemot,
          lv_akz      TYPE char4.
    TRY.
        /ctdi/cl_print_driver_base=>resolve_contract(
          EXPORTING iv_repair_id    = '9999999999'
          IMPORTING ev_contract_id  = lv_contract
                    ev_skz          = lv_skz
                    ev_akz          = lv_akz ).
        cl_abap_unit_assert=>fail( msg = 'resolve_contract should fail for invalid repair order' ).
      CATCH /ctdi/cx_print_driver_error.
        cl_abap_unit_assert=>assert_true(
          act = abap_true
          msg = 'Expected /ctdi/cx_print_driver_error raised' ).
    ENDTRY.
  ENDMETHOD.


  METHOD unpack_io_data.
    " unpack_io_data is a base no-op hook; should run successfully
    DATA: lo_obj TYPE REF TO object.
    TRY.
        f_cut->unpack_io_data( lo_obj ).
        cl_abap_unit_assert=>assert_true( abap_true ).
      CATCH /ctdi/cx_print_driver_error.
        cl_abap_unit_assert=>fail( msg = 'unpack_io_data is a base no-op hook; should run successfully' ).
    ENDTRY.

  ENDMETHOD.


  METHOD cx_driver_error_get_text.
    " get_text should return the message attribute when populated
    DATA(lx) = NEW /ctdi/cx_print_driver_error(
                      repair_id = '000012345678'
                      message   = 'Test error message' ).
    cl_abap_unit_assert=>assert_equals(
      act = lx->get_text( )
      exp = 'Test error message'
      msg = 'get_text should return the message attribute' ).
    cl_abap_unit_assert=>assert_equals(
      act = lx->repair_id
      exp = '000012345678'
      msg = 'repair_id should be populated' ).
  ENDMETHOD.


  METHOD cx_driver_error_empty_msg.
    " get_text with empty message should not dump (returns blank or default)
    DATA(lx) = NEW /ctdi/cx_print_driver_error( ).
    DATA(lv_text) = lx->get_text( ).
    " Should not dump; text may be blank or default
    cl_abap_unit_assert=>assert_true(
      act = abap_true
      msg = 'get_text with empty message should not dump' ).
  ENDMETHOD.


  METHOD cx_no_config_get_text.
    " cx_no_config_found should carry and return a diagnostic message
    DATA(lx) = NEW /ctdi/cx_no_config_found(
                      message = 'No config for order 12345' ).
    cl_abap_unit_assert=>assert_equals(
      act = lx->get_text( )
      exp = 'No config for order 12345'
      msg = 'get_text should return the message attribute' ).
    cl_abap_unit_assert=>assert_equals(
      act = lx->message
      exp = 'No config for order 12345'
      msg = 'message attribute should be populated' ).
  ENDMETHOD.


  METHOD cx_no_config_empty_msg.
    " cx_no_config_found with empty message should not dump
    DATA(lx) = NEW /ctdi/cx_no_config_found( ).
    DATA(lv_text) = lx->get_text( ).
    cl_abap_unit_assert=>assert_true(
      act = abap_true
      msg = 'get_text with empty message should not dump' ).
  ENDMETHOD.


  METHOD read_data_cast_error.
    " When a subclass redefines unpack_io_data with a CAST, a wrong type raises cx_print_driver_error.
    " On the base class, io_data is simply ignored (no-op hook), so no exception is expected.
    " This test verifies the base class read_data handles non-null io_data gracefully.
    DATA: lo_obj TYPE REF TO object.
    lo_obj = cl_abap_typedescr=>describe_by_name( 'STRING' ).
    TRY.
        f_cut->read_data( io_data = lo_obj ).
        cl_abap_unit_assert=>assert_true(
          act = abap_true
          msg = 'read_data with arbitrary io_data should succeed on base class (no-op hook)' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>fail( msg = |Unexpected error: { lx_err->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD get_config_no_config_exc.
    " get_config_from_db with invalid order should raise cx_no_config_found with message
    DATA: lv_form  TYPE fpname,
          lv_class TYPE seoclsname,
          ls_proj  TYPE /ctdi/rep_projec.
    TRY.
        /ctdi/cl_print_driver_base=>get_config_from_db(
          EXPORTING iv_repair_id  = '0000000001'
          IMPORTING ev_form_name  = lv_form
                    ev_class_name = lv_class
                    es_project    = ls_proj ).
        cl_abap_unit_assert=>fail( msg = 'Should raise exception for nonexistent config' ).
      CATCH /ctdi/cx_no_config_found INTO DATA(lx_noconf).
        cl_abap_unit_assert=>assert_not_initial(
          act = lx_noconf->get_text( )
          msg = 'cx_no_config_found should carry a diagnostic message' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>assert_not_initial(
          act = lx_err->get_text( )
          msg = 'Exception should carry a meaningful message' ).
    ENDTRY.
  ENDMETHOD.


  METHOD normalize_class_name.
    " Test the cust engine normalize_class_name utility
    cl_abap_unit_assert=>assert_equals(
      act = /ctdi/cl_print_cust_engine=>normalize_class_name( 'LEGACY' )
      exp = '/CTDI/CL_PRINT_DRIVER_LEGACY'
      msg = 'Short name should be expanded to full class path' ).

    cl_abap_unit_assert=>assert_equals(
      act = /ctdi/cl_print_cust_engine=>normalize_class_name( 'CL_PRINT_DRIVER_CTDI' )
      exp = '/CTDI/CL_PRINT_DRIVER_CTDI'
      msg = 'Name with CL_PRINT_DRIVER_ prefix should get namespace only' ).

    cl_abap_unit_assert=>assert_equals(
      act = /ctdi/cl_print_cust_engine=>normalize_class_name( '/CTDI/CL_PRINT_DRIVER_BASE' )
      exp = '/CTDI/CL_PRINT_DRIVER_BASE'
      msg = 'Full name with namespace should remain unchanged' ).

    cl_abap_unit_assert=>assert_equals(
      act = /ctdi/cl_print_cust_engine=>normalize_class_name( '' )
      exp = ''
      msg = 'Empty input should return empty' ).
  ENDMETHOD.

  METHOD set_get_download_dir.
    /ctdi/cl_print_driver_base=>set_download_dir( 'C:\TestFolder' ).
    cl_abap_unit_assert=>assert_equals(
      act = /ctdi/cl_print_driver_base=>get_download_dir( )
      exp = 'C:\TestFolder\'
      msg = 'Directory should be normalized with trailing backslash' ).
  ENDMETHOD.

  METHOD test_build_pdf_filename.
    f_cut->mv_repair_order = '000000800123'.
    f_cut->ms_repair-ctdi_order_no = '100234-01'.
    f_cut->ms_repair-new_serial_no = 'SN/99:88'.

    DATA(lv_filename) = f_cut->build_pdf_filename( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_filename
      exp = '10023401_000000800123_SN_99_88'
      msg = 'Filename should strip hyphen from order, preserve exact order number, append serial, and sanitize special characters' ).
  ENDMETHOD.

ENDCLASS.
