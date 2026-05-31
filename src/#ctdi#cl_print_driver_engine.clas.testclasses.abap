CLASS ltd_mock_provider DEFINITION CREATE PUBLIC FOR TESTING.
  PUBLIC SECTION.
    INTERFACES /ctdi/if_print_driver.

    CLASS-DATA: gv_execute_called TYPE abap_bool,
                gv_repair_id     TYPE aufnr,
                gv_form_name     TYPE fpname,
                gv_save_as_pdf   TYPE abap_bool,
                gv_raise_error   TYPE abap_bool.

    CLASS-METHODS clear.
ENDCLASS.

CLASS ltd_mock_provider IMPLEMENTATION.
  METHOD /ctdi/if_print_driver~execute.
    gv_execute_called = abap_true.
    gv_repair_id      = iv_repair_id.
    gv_form_name      = iv_form_name.
    gv_save_as_pdf    = iv_save_as_pdf.

    IF gv_raise_error = abap_true.
      RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
        EXPORTING repair_id = iv_repair_id
                  message   = 'Simulated error from mock provider'.
    ENDIF.
  ENDMETHOD.

  METHOD clear.
    CLEAR: gv_execute_called, gv_repair_id, gv_form_name,
           gv_save_as_pdf, gv_raise_error.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_non_provider DEFINITION CREATE PUBLIC FOR TESTING.
  PUBLIC SECTION.
    METHODS do_something.
ENDCLASS.

CLASS ltd_non_provider IMPLEMENTATION.
  METHOD do_something.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_print_driver_engine DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA: cut TYPE REF TO /ctdi/cl_print_driver_engine.
    METHODS: setup.
    METHODS: test_explicit_config FOR TESTING.
    METHODS: test_missing_config_raises_error FOR TESTING.
    METHODS: test_provider_raises_error FOR TESTING.
    METHODS: test_non_provider_class_raises_error FOR TESTING.
    METHODS: test_z_namespace_normalization FOR TESTING.
ENDCLASS.


CLASS ltc_print_driver_engine IMPLEMENTATION.

  METHOD setup.
    CREATE OBJECT cut.
    ltd_mock_provider=>clear( ).
  ENDMETHOD.

  METHOD test_explicit_config.
    DATA: ls_repair TYPE /ctdi/repair,
          lt_errors TYPE TABLE OF /ctdi/repair_error,
          lt_comments TYPE TABLE OF tline.

    cut->execute(
      EXPORTING
        iv_repair_id   = '0012345678'
        iv_form_name   = 'ZTEST_FORM'
        iv_class_name  = '/CTDI/CL_PRINT_DRIVER_BASE'
        iv_save_as_pdf = abap_false
      CHANGING
        cs_repair      = ls_repair
        ct_errors      = lt_errors
        ct_comments    = lt_comments ).

    cl_abap_unit_assert=>assert_initial(
      act   = sy-subrc
      msg   = 'Explicit config should complete without exception' ).
  ENDMETHOD.

  METHOD test_missing_config_raises_error.
    DATA: ls_repair TYPE /ctdi/repair,
          lt_errors TYPE TABLE OF /ctdi/repair_error,
          lt_comments TYPE TABLE OF tline.

    TRY.
        cut->execute(
          EXPORTING
            iv_repair_id   = '0099999999'
          CHANGING
            cs_repair      = ls_repair
            ct_errors      = lt_errors
            ct_comments    = lt_comments ).
        cl_abap_unit_assert=>fail(
          msg = 'Should raise error for missing config' ).
      CATCH /ctdi/cx_print_driver_error.
        " Expected — success
    ENDTRY.
  ENDMETHOD.

  METHOD test_provider_raises_error.
    DATA: ls_repair TYPE /ctdi/repair,
          lt_errors TYPE TABLE OF /ctdi/repair_error,
          lt_comments TYPE TABLE OF tline.

    ltd_mock_provider=>gv_raise_error = abap_true.

    TRY.
        cut->execute(
          EXPORTING
            iv_repair_id   = '0012345678'
            iv_form_name   = 'ZTEST_FORM'
            iv_class_name  = '/CTDI/CL_PRINT_DRIVER_BASE'
          CHANGING
            cs_repair      = ls_repair
            ct_errors      = lt_errors
            ct_comments    = lt_comments ).
        cl_abap_unit_assert=>fail(
          msg = 'Should propagate provider error' ).
      CATCH /ctdi/cx_print_driver_error.
        " Expected — success
    ENDTRY.
  ENDMETHOD.

  METHOD test_non_provider_class_raises_error.
    DATA: ls_repair TYPE /ctdi/repair,
          lt_errors TYPE TABLE OF /ctdi/repair_error,
          lt_comments TYPE TABLE OF tline.

    TRY.
        cut->execute(
          EXPORTING
            iv_repair_id   = '0012345678'
            iv_form_name   = 'ZTEST_FORM'
            iv_class_name  = 'LTD_NON_PROVIDER'
          CHANGING
            cs_repair      = ls_repair
            ct_errors      = lt_errors
            ct_comments    = lt_comments ).
        cl_abap_unit_assert=>fail(
          msg = 'Should raise error for non-interface class' ).
      CATCH /ctdi/cx_print_driver_error INTO DATA(lx_err).
        cl_abap_unit_assert=>assert_char_cp(
          act   = lx_err->message
          exp   = '*does not implement*' ).
    ENDTRY.
  ENDMETHOD.

  METHOD test_z_namespace_normalization.
    DATA: ls_repair TYPE /ctdi/repair,
          lt_errors TYPE TABLE OF /ctdi/repair_error,
          lt_comments TYPE TABLE OF tline.

    " ZCL_PRINT → /CTDI/CL_PRINT (should fail gracefully because class doesn't exist)
    TRY.
        cut->execute(
          EXPORTING
            iv_repair_id   = '0012345678'
            iv_form_name   = 'ZTEST_FORM'
            iv_class_name  = 'ZCL_PRINT_DRIVER_BASE'
          CHANGING
            cs_repair      = ls_repair
            ct_errors      = lt_errors
            ct_comments    = lt_comments ).
        cl_abap_unit_assert=>fail(
          msg = 'Should raise error for non-existent class' ).
      CATCH /ctdi/cx_print_driver_error.
        " Expected — class does not exist
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
