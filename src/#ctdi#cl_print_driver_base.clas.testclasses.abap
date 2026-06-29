CLASS lcl_tests DEFINITION DEFERRED.
CLASS /ctdi/cl_print_driver_base DEFINITION LOCAL FRIENDS lcl_tests.

CLASS lcl_tests DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
.
*?﻿<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
*?<asx:values>
*?<TESTCLASS_OPTIONS>
*?<TEST_CLASS>lcl_Tests
*?</TEST_CLASS>
*?<TEST_MEMBER>f_Cut
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
ENDCLASS.       "lcl_Tests


CLASS lcl_tests IMPLEMENTATION.

  METHOD class_setup.



  ENDMETHOD.


  METHOD class_teardown.



  ENDMETHOD.


  METHOD setup.


    CREATE OBJECT f_cut.
  ENDMETHOD.


  METHOD teardown.



  ENDMETHOD.


  METHOD detect_form_type.

    DATA rv_type TYPE char1.

    rv_type = f_cut->detect_form_type(  ).

    cl_abap_unit_assert=>assert_equals(
      act   = rv_type
      exp   = rv_type          "<--- please adapt expected value
    " msg   = 'Testing value rv_Type'
*     level =
    ).
  ENDMETHOD.


  METHOD download_pdf.

    DATA iv_pdf_data TYPE xstring.

    f_cut->download_pdf( iv_pdf_data ).

  ENDMETHOD.


  METHOD execute.

    DATA iv_save_as_pdf TYPE abap_bool.
    DATA io_data TYPE REF TO object.

    f_cut->execute(
*       IV_SAVE_AS_PDF = iv_Save_As_Pdf
*       IO_DATA = io_Data
    ).

  ENDMETHOD.


  METHOD execute_adobeform.

    DATA iv_save_as_pdf TYPE abap_bool.

    f_cut->execute_adobeform( iv_save_as_pdf ).

  ENDMETHOD.


  METHOD execute_smartform.

    DATA iv_save_as_pdf TYPE abap_bool.

    f_cut->execute_smartform( iv_save_as_pdf ).

  ENDMETHOD.


  METHOD factory.

    DATA iv_repair_id TYPE aufnr.
    DATA iv_sernr TYPE gernr.
    DATA ro_driver TYPE REF TO /ctdi/cl_print_driver_base.

    ro_driver = /ctdi/cl_print_driver_base=>factory(
        iv_repair_id = iv_repair_id
*       IV_SERNR = iv_Sernr
    ).

    cl_abap_unit_assert=>assert_equals(
      act   = ro_driver
      exp   = ro_driver          "<--- please adapt expected value
    " msg   = 'Testing value ro_Driver'
*     level =
    ).
  ENDMETHOD.


  METHOD fetch_data_from_db.


    f_cut->fetch_data_from_db(  ).

  ENDMETHOD.


  METHOD get_config_from_db.

    DATA iv_repair_id TYPE aufnr.
    DATA ev_form_name TYPE fpname.
    DATA ev_class_name TYPE seoclsname.
    DATA es_project TYPE /ctdi/rep_projec.

    /ctdi/cl_print_driver_base=>get_config_from_db(
      EXPORTING
        iv_repair_id = iv_repair_id
*     IMPORTING
*       EV_FORM_NAME = ev_Form_Name
*       EV_CLASS_NAME = ev_Class_Name
*       ES_PROJECT = es_Project
    ).

    cl_abap_unit_assert=>assert_equals(
      act   = ev_form_name
      exp   = ev_form_name          "<--- please adapt expected value
    " msg   = 'Testing value ev_Form_Name'
*     level =
    ).
    cl_abap_unit_assert=>assert_equals(
      act   = ev_class_name
      exp   = ev_class_name          "<--- please adapt expected value
    " msg   = 'Testing value ev_Class_Name'
*     level =
    ).
    cl_abap_unit_assert=>assert_equals(
      act   = es_project
      exp   = es_project          "<--- please adapt expected value
    " msg   = 'Testing value es_Project'
*     level =
    ).
  ENDMETHOD.


  METHOD get_user_print_defaults.

    DATA ev_printer TYPE rspopname.
    DATA ev_immed TYPE c.
    DATA ev_delete TYPE c.

    f_cut->get_user_print_defaults(
*     IMPORTING
*       EV_PRINTER = ev_Printer
*       EV_IMMED = ev_Immed
*       EV_DELETE = ev_Delete
    ).

    cl_abap_unit_assert=>assert_equals(
      act   = ev_printer
      exp   = ev_printer          "<--- please adapt expected value
    " msg   = 'Testing value ev_Printer'
*     level =
    ).
    cl_abap_unit_assert=>assert_equals(
      act   = ev_immed
      exp   = ev_immed          "<--- please adapt expected value
    " msg   = 'Testing value ev_Immed'
*     level =
    ).
    cl_abap_unit_assert=>assert_equals(
      act   = ev_delete
      exp   = ev_delete          "<--- please adapt expected value
    " msg   = 'Testing value ev_Delete'
*     level =
    ).
  ENDMETHOD.


  METHOD map_and_register_data.


    f_cut->map_and_register_data(  ).

  ENDMETHOD.


  METHOD read_data.

    DATA io_data TYPE REF TO object.

    f_cut->read_data( io_data ).

  ENDMETHOD.


  METHOD register_custom_parameter.

    DATA iv_name TYPE string.
    DATA ir_data TYPE REF TO data.
    DATA iv_kind TYPE i.

    f_cut->register_custom_parameter(
        iv_name = iv_name
        ir_data = ir_data
*       IV_KIND = iv_Kind
    ).

  ENDMETHOD.


  METHOD render_form.

    DATA iv_save_as_pdf TYPE abap_bool.

    f_cut->render_form( iv_save_as_pdf ).

  ENDMETHOD.


  METHOD resolve_contract.

    DATA iv_repair_id TYPE aufnr.
    DATA ev_contract_id TYPE vbeln_va.
    DATA ev_skz TYPE bemot.
    DATA ev_akz TYPE char4.

    /ctdi/cl_print_driver_base=>resolve_contract(
      EXPORTING
        iv_repair_id = iv_repair_id
*     IMPORTING
*       EV_CONTRACT_ID = ev_Contract_Id
*       EV_SKZ = ev_Skz
*       EV_AKZ = ev_Akz
    ).

    cl_abap_unit_assert=>assert_equals(
      act   = ev_contract_id
      exp   = ev_contract_id          "<--- please adapt expected value
    " msg   = 'Testing value ev_Contract_Id'
*     level =
    ).
    cl_abap_unit_assert=>assert_equals(
      act   = ev_skz
      exp   = ev_skz          "<--- please adapt expected value
    " msg   = 'Testing value ev_Skz'
*     level =
    ).
    cl_abap_unit_assert=>assert_equals(
      act   = ev_akz
      exp   = ev_akz          "<--- please adapt expected value
    " msg   = 'Testing value ev_Akz'
*     level =
    ).
  ENDMETHOD.


  METHOD unpack_io_data.

    DATA io_data TYPE REF TO object.

    f_cut->unpack_io_data( io_data ).

  ENDMETHOD.




ENDCLASS.
