CLASS lcl_test_driver_log DEFINITION DEFERRED.

CLASS /ctdi/cl_print_driver_log DEFINITION LOCAL FRIENDS lcl_test_driver_log.

CLASS lcl_test_driver_log DEFINITION
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS test_set_log_level FOR TESTING.
    METHODS test_log_methods_safe FOR TESTING.
    METHODS test_log_exception_safe FOR TESTING.
ENDCLASS.

CLASS lcl_test_driver_log IMPLEMENTATION.
  METHOD setup.
    /ctdi/cl_print_driver_log=>set_log_level( 'I' ).
  ENDMETHOD.

  METHOD teardown.
    /ctdi/cl_print_driver_log=>set_log_level( 'I' ).
  ENDMETHOD.

  METHOD test_set_log_level.
    /ctdi/cl_print_driver_log=>set_log_level( 'E' ).
    cl_abap_unit_assert=>assert_equals(
      act = /ctdi/cl_print_driver_log=>gv_log_level
      exp = 'E'
      msg = 'Log level should be set to E' ).

    /ctdi/cl_print_driver_log=>set_log_level( 'W' ).
    cl_abap_unit_assert=>assert_equals(
      act = /ctdi/cl_print_driver_log=>gv_log_level
      exp = 'W'
      msg = 'Log level should be set to W' ).
  ENDMETHOD.

  METHOD test_log_methods_safe.
    " Logging with empty and valid texts should execute safely without runtime exceptions
    /ctdi/cl_print_driver_log=>log_info( '' ).
    /ctdi/cl_print_driver_log=>log_info( 'Informational test message' ).
    /ctdi/cl_print_driver_log=>log_warning( 'Warning test message' ).
    /ctdi/cl_print_driver_log=>log_error( 'Error test message' ).

    cl_abap_unit_assert=>assert_true(
      act = abap_true
      msg = 'Logging calls should execute safely' ).
  ENDMETHOD.

  METHOD test_log_exception_safe.
    DATA lx_test TYPE REF TO cx_root.

    lx_test = NEW /ctdi/cx_print_driver_error( message = 'Test exception message' ).

    /ctdi/cl_print_driver_log=>log_exception( lx_test ).

    cl_abap_unit_assert=>assert_true(
      act = abap_true
      msg = 'log_exception should process exception message safely' ).
  ENDMETHOD.
ENDCLASS.
