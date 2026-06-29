CLASS lcl_test_data_ctdi DEFINITION DEFERRED.
CLASS /ctdi/cl_print_data_ctdi DEFINITION LOCAL FRIENDS lcl_test_data_ctdi.

CLASS lcl_test_data_ctdi DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
.
*?﻿<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
*?<asx:values>
*?<TESTCLASS_OPTIONS>
*?<TEST_CLASS>lcl_Test_Data_Ctdi
*?</TEST_CLASS>
*?<TEST_MEMBER>f_Cut
*?</TEST_MEMBER>
*?<OBJECT_UNDER_TEST>/CTDI/CL_PRINT_DATA_CTDI
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
      f_cut TYPE REF TO /ctdi/cl_print_data_ctdi.  "class under test

    CLASS-METHODS: class_setup.
    CLASS-METHODS: class_teardown.
    METHODS: setup.
    METHODS: teardown.
    METHODS: get_repair_result FOR TESTING.
    METHODS: map_legacy_data FOR TESTING.
    METHODS: read_data FOR TESTING.
ENDCLASS.       "lcl_Test_Data_Ctdi


CLASS lcl_test_data_ctdi IMPLEMENTATION.

  METHOD class_setup.



  ENDMETHOD.


  METHOD class_teardown.



  ENDMETHOD.


  METHOD setup.


    CREATE OBJECT f_cut.
  ENDMETHOD.


  METHOD teardown.



  ENDMETHOD.


  METHOD get_repair_result.


    f_cut->get_repair_result(  ).

  ENDMETHOD.


  METHOD map_legacy_data.


    f_cut->map_legacy_data(  ).

  ENDMETHOD.


  METHOD read_data.

    DATA iv_aufnr TYPE aufnr.
    DATA iv_sernr TYPE gernr.

    f_cut->read_data(
        iv_aufnr = iv_aufnr
*       IV_SERNR = iv_Sernr
    ).

  ENDMETHOD.




ENDCLASS.
