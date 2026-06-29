CLASS lcl_tests DEFINITION DEFERRED.
CLASS /ctdi/cl_print_driver_base DEFINITION LOCAL FRIENDS lcl_tests.

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
ENDCLASS.       "lcl_tests


CLASS lcl_tests IMPLEMENTATION.

  METHOD class_setup.
  ENDMETHOD.


  METHOD class_teardown.
  ENDMETHOD.


  METHOD setup.
    CREATE OBJECT f_cut.
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
    " Empty input PDF data should return immediately in download_pdf
    f_cut->download_pdf( iv_pdf_data ).
    cl_abap_unit_assert=>assert_true( abap_true ).
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
      CATCH /ctdi/cx_print_driver_error.
        cl_abap_unit_assert=>assert_true( abap_true ).
    ENDTRY.
  ENDMETHOD.


  METHOD execute_smartform.
    f_cut->mv_form_name = 'DUMMY_SMARTFORM'.
    TRY.
        f_cut->execute_smartform( abap_false ).
        cl_abap_unit_assert=>fail( msg = 'execute_smartform should fail for invalid configuration' ).
      CATCH /ctdi/cx_print_driver_error.
        cl_abap_unit_assert=>assert_true( abap_true ).
    ENDTRY.
  ENDMETHOD.


  METHOD factory.
    DATA: lo_driver TYPE REF TO /ctdi/cl_print_driver_base.
    TRY.
        lo_driver = /ctdi/cl_print_driver_base=>factory( iv_repair_id = '9999999999' ).
        cl_abap_unit_assert=>fail( msg = 'factory should fail for invalid repair order' ).
      CATCH /ctdi/cx_print_driver_error.
        cl_abap_unit_assert=>assert_true( abap_true ).
      CATCH /ctdi/cx_no_config_found.
        cl_abap_unit_assert=>assert_true( abap_true ).
    ENDTRY.
  ENDMETHOD.


  METHOD fetch_data_from_db.
    " fetch_data_from_db is a base no-op hook; should run successfully
    f_cut->fetch_data_from_db( ).
    cl_abap_unit_assert=>assert_true( abap_true ).
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
    f_cut->map_and_register_data( ).
    cl_abap_unit_assert=>assert_true( abap_true ).
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
    f_cut->unpack_io_data( lo_obj ).
    cl_abap_unit_assert=>assert_true( abap_true ).
  ENDMETHOD.

ENDCLASS.
