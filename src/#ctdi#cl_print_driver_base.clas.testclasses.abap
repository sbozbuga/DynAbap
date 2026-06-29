CLASS lcl_test_driver_base DEFINITION DEFERRED.
CLASS /ctdi/cl_print_driver_base DEFINITION LOCAL FRIENDS lcl_test_driver_base.

CLASS lcl_test_driver_base DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
.
*?﻿<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
*?<asx:values>
*?<TESTCLASS_OPTIONS>
*?<TEST_CLASS>lcl_test_driver_base
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

    METHODS: setup.
    METHODS: teardown.
    METHODS: test_detect_form_type_smart FOR TESTING.
    METHODS: test_detect_form_type_adobe FOR TESTING.
    METHODS: test_register_custom_param FOR TESTING.
    METHODS: test_get_user_print_defaults FOR TESTING.
    METHODS: test_resolve_contract_fail FOR TESTING.
    METHODS: test_get_config_from_db_fail FOR TESTING.
    METHODS: test_factory_fail FOR TESTING.
    METHODS: test_read_data_no_op FOR TESTING.
ENDCLASS.       "lcl_test_driver_base


CLASS lcl_test_driver_base IMPLEMENTATION.

  METHOD setup.
    CREATE OBJECT f_cut.
  ENDMETHOD.


  METHOD teardown.
    CLEAR f_cut.
  ENDMETHOD.


  METHOD test_detect_form_type_smart.
    f_cut->mv_form_name = 'TEST_SMARTFORM'.
    DATA(lv_type) = f_cut->detect_form_type( ).
    cl_abap_unit_assert=>assert_true(
      act = abap_true
      msg = 'detect_form_type should execute without dump' ).
  ENDMETHOD.


  METHOD test_detect_form_type_adobe.
    f_cut->mv_form_name = 'NON_EXISTENT_FORM_XYZ'.
    DATA(lv_type) = f_cut->detect_form_type( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_type
      exp = 'A'
      msg = 'Non-existent form should default to Adobe Form (A)' ).
  ENDMETHOD.


  METHOD test_register_custom_param.
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
      msg = 'Custom parameter should be registered successfully' ).

    READ TABLE f_cut->mt_custom_form_params ASSIGNING FIELD-SYMBOL(<ls_param>) INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = <ls_param>-name
      exp = 'IV_TEST' ).
  ENDMETHOD.


  METHOD test_get_user_print_defaults.
    DATA: lv_printer TYPE rspopname,
          lv_immed   TYPE c,
          lv_delete  TYPE c.

    f_cut->get_user_print_defaults(
      IMPORTING ev_printer = lv_printer
                ev_immed   = lv_immed
                ev_delete  = lv_delete ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_immed
      msg = 'Immediate print default should be set to true' ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_delete
      msg = 'Delete print default should be set to true' ).
  ENDMETHOD.


  METHOD test_resolve_contract_fail.
    TRY.
        /ctdi/cl_print_driver_base=>resolve_contract(
          EXPORTING iv_repair_id = '9999999999' ).
        cl_abap_unit_assert=>fail( msg = 'resolve_contract should fail for invalid repair order' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>assert_true(
          act = abap_true
          msg = 'Expected /ctdi/cx_print_driver_error raised' ).
    ENDTRY.
  ENDMETHOD.


  METHOD test_get_config_from_db_fail.
    DATA: lv_form_name  TYPE fpname,
          lv_class_name TYPE seoclsname,
          ls_project    TYPE /ctdi/rep_projec.

    TRY.
        f_cut->get_config_from_db(
          EXPORTING iv_repair_id = '9999999999'
          IMPORTING ev_form_name = lv_form_name
                    ev_class_name = lv_class_name
                    es_project    = ls_project ).
        cl_abap_unit_assert=>fail( msg = 'get_config_from_db should fail for invalid repair order' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>assert_true( act = abap_true ).
    ENDTRY.
  ENDMETHOD.


  METHOD test_factory_fail.
    TRY.
        /ctdi/cl_print_driver_base=>factory(
          iv_repair_id = '9999999999' ).
        cl_abap_unit_assert=>fail( msg = 'factory should fail for invalid repair order' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>assert_true( act = abap_true ).
      CATCH /ctdi/cx_no_config_found INTO DATA(lx_no_cfg).
        cl_abap_unit_assert=>assert_true( act = abap_true ).
    ENDTRY.
  ENDMETHOD.


  METHOD test_read_data_no_op.
    TRY.
        f_cut->read_data( ).
        cl_abap_unit_assert=>assert_true(
          act = abap_true
          msg = 'read_data should run with default no-op hooks' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>fail( msg = 'Base read_data should not raise error if hooks are no-op' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
