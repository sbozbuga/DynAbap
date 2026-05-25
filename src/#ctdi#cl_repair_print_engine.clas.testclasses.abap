CLASS lcl_mock_print_provider DEFINITION CREATE PUBLIC FOR TESTING.
  PUBLIC SECTION.
    INTERFACES /ctdi/if_repair_print_provider.

    CLASS-DATA: gv_execute_called TYPE abap_bool,
                gv_read_data_called TYPE abap_bool,
                gv_print_called     TYPE abap_bool,
                gv_repair_id        TYPE aufnr,
                gv_form_name        TYPE fpname,
                gv_save_as_pdf      TYPE abap_bool,
                gs_repair           TYPE /ctdi/repair,
                gt_repair_error     TYPE TABLE OF /ctdi/repair_error,
                gt_comment_lines    TYPE TABLE OF tline.

    CLASS-METHODS: clear.
ENDCLASS.

CLASS lcl_mock_print_provider IMPLEMENTATION.
  METHOD /ctdi/if_repair_print_provider~read_data.
    gv_read_data_called = abap_true.
  ENDMETHOD.

  METHOD /ctdi/if_repair_print_provider~execute.
    gv_execute_called = abap_true.
    gv_repair_id      = iv_repair_id.
    gv_form_name      = iv_form_name.
    gv_save_as_pdf    = iv_save_as_pdf.
    gs_repair         = cs_repair.
    gt_repair_error   = ct_repair_error.
    gt_comment_lines  = ct_comment_lines.
  ENDMETHOD.

  METHOD /ctdi/if_repair_print_provider~print.
    gv_print_called = abap_true.
    gv_repair_id   = iv_repair_id.
    gv_form_name   = iv_form_name.
    gv_save_as_pdf = iv_save_as_pdf.
    gs_repair      = cs_repair.
    gt_repair_error = ct_repair_error.
    gt_comment_lines = ct_comment_lines.
  ENDMETHOD.

  METHOD clear.
    CLEAR: gv_execute_called, gv_read_data_called, gv_print_called, gv_repair_id, gv_form_name, gv_save_as_pdf, gs_repair, gt_repair_error, gt_comment_lines.
  ENDMETHOD.
ENDCLASS.


CLASS lcl_mock_legacy_print DEFINITION CREATE PUBLIC FOR TESTING.
  PUBLIC SECTION.
    METHODS my_legacy_print
      IMPORTING
        !iv_repair_id TYPE aufnr
        !iv_form_name   TYPE fpname
        !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false.

    CLASS-DATA: gv_print_called TYPE abap_bool,
                gv_repair_id    TYPE aufnr,
                gv_form_name    TYPE fpname,
                gv_save_as_pdf  TYPE abap_bool.

    CLASS-METHODS: clear.
ENDCLASS.

CLASS lcl_mock_legacy_print IMPLEMENTATION.
  METHOD my_legacy_print.
    gv_print_called = abap_true.
    gv_repair_id   = iv_repair_id.
    gv_form_name   = iv_form_name.
    gv_save_as_pdf = iv_save_as_pdf.
  ENDMETHOD.

  METHOD clear.
    CLEAR: gv_print_called, gv_repair_id, gv_form_name, gv_save_as_pdf.
  ENDMETHOD.
ENDCLASS.


CLASS lcl_test DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA: go_db_environment TYPE REF TO if_osql_test_environment.
    DATA: cut TYPE REF TO /ctdi/cl_repair_print_engine.

    CLASS-METHODS: class_setup, class_teardown.
    METHODS: setup, teardown.
    METHODS: test_invalid_repair FOR TESTING.
    METHODS: test_missing_customizing FOR TESTING.
    METHODS: test_empty_config FOR TESTING.
    METHODS: test_successful_interface_print FOR TESTING.
    METHODS: test_legacy_dynamic_print FOR TESTING.
    METHODS: test_hashed_buffer FOR TESTING.
    METHODS: test_service_order_print FOR TESTING.    
    METHODS test_z_namespace_class_name FOR TESTING.
    METHODS test_interface_print_with_custom FOR TESTING.
ENDCLASS.


CLASS lcl_test IMPLEMENTATION.

  METHOD class_setup.
    DATA(lt_tables) = VALUE if_osql_test_environment=>ty_t_double_tables(
      ( 'VBAK' )
      ( '/CTDI/REP_FORMS' )
      ( 'AUFK' )
      ( 'AFIH' )
    ).
    go_db_environment = cl_osql_test_environment=>create( lt_tables ).
  ENDMETHOD.

  METHOD class_teardown.
    go_db_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    CREATE OBJECT cut.
    go_db_environment->clear_doubles( ).
    lcl_mock_print_provider=>clear( ).
    lcl_mock_legacy_print=>clear( ).
  ENDMETHOD.

  METHOD teardown.
    " Optional teardown logic
  ENDMETHOD.

  METHOD test_invalid_repair.
    " Test that an invalid/non-existing repair number correctly raises an exception
    TRY.
        cut->execute( iv_repair_id = '0000000000' ).
        cl_abap_unit_assert=>fail( msg = 'Should have failed for invalid repair id' ).
      CATCH cx_sy_dyn_call_illegal_value.
        " Success: expected exception type successfully raised
      CATCH cx_root.
        cl_abap_unit_assert=>fail( msg = 'Incorrect exception raised instead of cx_sy_dyn_call_illegal_value' ).
    ENDTRY.
  ENDMETHOD.

  METHOD test_missing_customizing.
    " 1. Insert Mock VBAK Record
    DATA: lt_vbak TYPE TABLE OF vbak,
          ls_vbak TYPE vbak.
    ls_vbak-vbeln = '0000000100'.
    ls_vbak-auart = 'ZREP'.
    APPEND ls_vbak TO lt_vbak.
    go_db_environment->insert_test_data( lt_vbak ).

    " Test that calling a non-configured or missing VBELN contract/repair raises a /ctdi/cx_no_config_found exception
    TRY.
        cut->execute( iv_repair_id = '0000000100' ).
        cl_abap_unit_assert=>fail( msg = 'Should have raised exception for missing configuration' ).
      CATCH /ctdi/cx_no_config_found.
        " Success: correct fallback exception successfully raised
      CATCH cx_root.
        cl_abap_unit_assert=>fail( msg = 'Incorrect exception raised instead of /ctdi/cx_no_config_found' ).
    ENDTRY.
  ENDMETHOD.

  METHOD test_empty_config.
    " 1. Insert Mock VBAK Record
    DATA: lt_vbak TYPE TABLE OF vbak,
          ls_vbak TYPE vbak.
    ls_vbak-vbeln = '0000000100'.
    ls_vbak-auart = 'ZREP'.
    APPEND ls_vbak TO lt_vbak.
    go_db_environment->insert_test_data( lt_vbak ).

    " 2. Insert Mock Customizing entry with empty class/method configuration
    DATA: lt_config TYPE TABLE OF /ctdi/rep_forms,
          ls_config TYPE /ctdi/rep_forms.
    ls_config-vbeln = '0000000100'.
    APPEND ls_config TO lt_config.
    go_db_environment->insert_test_data( lt_config ).

    TRY.
        cut->execute( iv_repair_id = '0000000100' ).
        cl_abap_unit_assert=>fail( msg = 'Should have failed due to blank class/method name' ).
      CATCH cx_sy_dyn_call_illegal_value.
        " Success: expected exception type successfully raised
      CATCH cx_root.
        cl_abap_unit_assert=>fail( msg = 'Incorrect exception raised instead of cx_sy_dyn_call_illegal_value' ).
    ENDTRY.
  ENDMETHOD.

  METHOD test_successful_interface_print.
    " 1. Insert Mock VBAK Record
    DATA: lt_vbak TYPE TABLE OF vbak,
          ls_vbak TYPE vbak.
    ls_vbak-vbeln = '0000000100'.
    ls_vbak-auart = 'ZREP'.
    APPEND ls_vbak TO lt_vbak.
    go_db_environment->insert_test_data( lt_vbak ).

    " 2. Insert Mock Customizing configuration
    DATA: lt_config TYPE TABLE OF /ctdi/rep_forms,
          ls_config TYPE /ctdi/rep_forms.
    ls_config-vbeln       = '0000000100'.
    ls_config-class_name  = 'LCL_MOCK_PRINT_PROVIDER'.
    ls_config-method_name = 'PRINT'.
    ls_config-form_name   = 'TEST_ADOBE_FORM'.
    APPEND ls_config TO lt_config.
    go_db_environment->insert_test_data( lt_config ).

    TRY.
        cut->execute(
          iv_repair_id   = '0000000100'
          iv_save_as_pdf = abap_true ).

        cl_abap_unit_assert=>assert_true(
          act = lcl_mock_print_provider=>gv_execute_called
          msg = 'execute should have been called' ).

        cl_abap_unit_assert=>assert_equals(
          act = lcl_mock_print_provider=>gv_repair_id
          exp = '0000000100'
          msg = 'Incorrect repair ID passed to execute' ).

        cl_abap_unit_assert=>assert_equals(
          act = lcl_mock_print_provider=>gv_form_name
          exp = 'TEST_ADOBE_FORM'
          msg = 'Incorrect form name passed to execute' ).

        cl_abap_unit_assert=>assert_equals(
          act = lcl_mock_print_provider=>gv_save_as_pdf
          exp = abap_true
          msg = 'Incorrect save as PDF flag passed to execute' ).

      CATCH cx_root INTO DATA(lx_err).
        cl_abap_unit_assert=>fail( msg = lx_err->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD test_legacy_dynamic_print.
    " 1. Insert Mock VBAK Record
    DATA: lt_vbak TYPE TABLE OF vbak,
          ls_vbak TYPE vbak.
    ls_vbak-vbeln = '0000000100'.
    ls_vbak-auart = 'ZREP'.
    APPEND ls_vbak TO lt_vbak.
    go_db_environment->insert_test_data( lt_vbak ).

    " 2. Insert Mock Customizing configuration (points to legacy class with no interface)
    DATA: lt_config TYPE TABLE OF /ctdi/rep_forms,
          ls_config TYPE /ctdi/rep_forms.
    ls_config-vbeln       = '0000000100'.
    ls_config-class_name  = 'LCL_MOCK_LEGACY_PRINT'.
    ls_config-method_name = 'MY_LEGACY_PRINT'.
    ls_config-form_name   = 'TEST_SMART_FORM'.
    APPEND ls_config TO lt_config.
    go_db_environment->insert_test_data( lt_config ).

    TRY.
        cut->execute(
          iv_repair_id   = '0000000100'
          iv_save_as_pdf = abap_false ).

        cl_abap_unit_assert=>assert_true(
          act = lcl_mock_legacy_print=>gv_print_called
          msg = 'my_legacy_print should have been called' ).

        cl_abap_unit_assert=>assert_equals(
          act = lcl_mock_legacy_print=>gv_repair_id
          exp = '0000000100'
          msg = 'Incorrect repair ID passed to legacy print' ).

        cl_abap_unit_assert=>assert_equals(
          act = lcl_mock_legacy_print=>gv_form_name
          exp = 'TEST_SMART_FORM'
          msg = 'Incorrect form name passed to legacy print' ).

        cl_abap_unit_assert=>assert_equals(
          act = lcl_mock_legacy_print=>gv_save_as_pdf
          exp = abap_false
          msg = 'Incorrect save as PDF flag passed to legacy print' ).

      CATCH cx_root INTO DATA(lx_err).
        cl_abap_unit_assert=>fail( msg = lx_err->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD test_hashed_buffer.
    " 1. Insert Mock VBAK Record
    DATA: lt_vbak TYPE TABLE OF vbak,
          ls_vbak TYPE vbak.
    ls_vbak-vbeln = '0000000100'.
    ls_vbak-auart = 'ZREP'.
    APPEND ls_vbak TO lt_vbak.
    go_db_environment->insert_test_data( lt_vbak ).

    " 2. Insert Mock Customizing configuration
    DATA: lt_config TYPE TABLE OF /ctdi/rep_forms,
          ls_config TYPE /ctdi/rep_forms.
    ls_config-vbeln       = '0000000100'.
    ls_config-class_name  = 'LCL_MOCK_PRINT_PROVIDER'.
    ls_config-method_name = 'PRINT'.
    ls_config-form_name   = 'FIRST_FORM'.
    APPEND ls_config TO lt_config.
    go_db_environment->insert_test_data( lt_config ).

    TRY.
        " Call print the first time (this will load config from DB into mt_config_buffer)
        cut->execute( iv_repair_id = '0000000100' ).

        cl_abap_unit_assert=>assert_equals(
          act = lcl_mock_print_provider=>gv_form_name
          exp = 'FIRST_FORM' ).

        " Clear mock variables
        lcl_mock_print_provider=>clear( ).

        " Now, change the configuration in the database double environment
        go_db_environment->clear_doubles( ).
        go_db_environment->insert_test_data( lt_vbak ).

        DATA: lt_config_new TYPE TABLE OF /ctdi/rep_forms,
              ls_config_new TYPE /ctdi/rep_forms.
        ls_config_new-vbeln       = '0000000100'.
        ls_config_new-class_name  = 'LCL_MOCK_PRINT_PROVIDER'.
        ls_config_new-method_name = 'PRINT'.
        ls_config_new-form_name   = 'CHANGED_FORM'.
        APPEND ls_config_new TO lt_config_new.
        go_db_environment->insert_test_data( lt_config_new ).

        " Print again - it should STILL use 'FIRST_FORM' because it was cached in mt_config_buffer
        cut->execute( iv_repair_id = '0000000100' ).

        cl_abap_unit_assert=>assert_equals(
          act = lcl_mock_print_provider=>gv_form_name
          exp = 'FIRST_FORM'
          msg = 'Hashed buffer cache was bypassed - engine queried DB again instead of reading buffer!' ).

      CATCH cx_root INTO DATA(lx_err).
        cl_abap_unit_assert=>fail( msg = lx_err->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD test_service_order_print.
    " 1. Insert Mock AUFK Record (Service Order)
    DATA: lt_aufk TYPE TABLE OF aufk,
          ls_aufk TYPE aufk.
    ls_aufk-aufnr = '000012345678'.
    ls_aufk-auart = 'SM01'. " Service Order Type
    APPEND ls_aufk TO lt_aufk.
    go_db_environment->insert_test_data( lt_aufk ).

    " 2. Insert Mock AFIH Record (Contract Link)
    DATA: lt_afih TYPE TABLE OF afih,
          ls_afih TYPE afih.
    ls_afih-aufnr = '000012345678'.
    ls_afih-kunum = '0000000200'. " Service Contract Vbeln
    APPEND ls_afih TO lt_afih.
    go_db_environment->insert_test_data( lt_afih ).

    " 3. Insert Mock VBAK Record (Sales Contract Header)
    DATA: lt_vbak TYPE TABLE OF vbak,
          ls_vbak TYPE vbak.
    ls_vbak-vbeln = '0000000200'.
    ls_vbak-auart = 'ZREP'. " Sales Document Type mapped in Customizing
    APPEND ls_vbak TO lt_vbak.
    go_db_environment->insert_test_data( lt_vbak ).

    " 4. Insert Mock Customizing configuration
    DATA: lt_config TYPE TABLE OF /ctdi/rep_forms,
          ls_config TYPE /ctdi/rep_forms.
    ls_config-vbeln       = '0000000200'.
    ls_config-class_name  = 'LCL_MOCK_PRINT_PROVIDER'.
    ls_config-method_name = 'PRINT'.
    ls_config-form_name   = 'TEST_PM_FORM'.
    APPEND ls_config TO lt_config.
    go_db_environment->insert_test_data( lt_config ).

    TRY.
        cut->execute(
          iv_repair_id   = '000012345678'
          iv_save_as_pdf = abap_true ).

        cl_abap_unit_assert=>assert_true(
          act = lcl_mock_print_provider=>gv_print_called
          msg = 'print should have been called for Service Order trigger' ).

        cl_abap_unit_assert=>assert_equals(
          act = lcl_mock_print_provider=>gv_repair_id
          exp = '000012345678'
          msg = 'Incorrect original Service Order ID passed to print' ).

        cl_abap_unit_assert=>assert_equals(
          act = lcl_mock_print_provider=>gv_form_name
          exp = 'TEST_PM_FORM'
          msg = 'Incorrect form name resolved and passed to print' ).

      CATCH cx_root INTO DATA(lx_err).
        cl_abap_unit_assert=>fail( msg = lx_err->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD test_z_namespace_class_name.
    DATA: ls_entry TYPE /ctdi/rep_forms.

    ls_entry-vbeln       = '0000000200'.
    ls_entry-class_name  = 'ZCL_REPAIR_PRINT_ENGINE'.
    ls_entry-method_name = 'EXECUTE'.

    TRY.
        /ctdi/cl_repair_cust_engine=>validate_entry( ls_entry ).
      CATCH cx_root INTO DATA(lx_err).
        cl_abap_unit_assert=>fail( msg = lx_err->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD test_interface_print_with_custom.
    " 1. Insert Mock VBAK Record
    DATA: lt_vbak TYPE TABLE OF vbak,
          ls_vbak TYPE vbak.
    ls_vbak-vbeln = '0000000100'.
    ls_vbak-auart = 'ZREP'.
    APPEND ls_vbak TO lt_vbak.
    go_db_environment->insert_test_data( lt_vbak ).

    " 2. Insert Mock Customizing configuration
    DATA: lt_config TYPE TABLE OF /ctdi/rep_forms,
          ls_config TYPE /ctdi/rep_forms.
    ls_config-vbeln       = '0000000100'.
    ls_config-class_name  = 'LCL_MOCK_PRINT_PROVIDER'.
    ls_config-method_name = 'PRINT'.
    ls_config-form_name   = 'TEST_ADOBE_FORM'.
    APPEND ls_config TO lt_config.
    go_db_environment->insert_test_data( lt_config ).

    " 3. Prepare mock custom parameters
    DATA: ls_repair        TYPE /ctdi/repair,
          lt_repair_error  TYPE TABLE OF /ctdi/repair_error,
          lt_comment_lines TYPE TABLE OF tline.

    ls_repair-vbeln = '0000000100'.
    APPEND VALUE #( vbeln = '0000000100' ) TO lt_repair_error.
    APPEND VALUE #( tdline = 'Comment line' ) TO lt_comment_lines.

    TRY.
        cut->execute(
          iv_repair_id     = '0000000100'
          iv_save_as_pdf   = abap_true
          is_repair        = ls_repair
          it_repair_error  = lt_repair_error
          it_comment_lines = lt_comment_lines ).

        cl_abap_unit_assert=>assert_true(
          act = lcl_mock_print_provider=>gv_execute_called
          msg = 'execute should have been called' ).

        cl_abap_unit_assert=>assert_equals(
          act = lcl_mock_print_provider=>gs_repair-vbeln
          exp = '0000000100'
          msg = 'Incorrect repair struct passed' ).

        cl_abap_unit_assert=>assert_equals(
          act = lines( lcl_mock_print_provider=>gt_repair_error )
          exp = 1
          msg = 'Incorrect error table passed' ).

        cl_abap_unit_assert=>assert_equals(
          act = lines( lcl_mock_print_provider=>gt_comment_lines )
          exp = 1
          msg = 'Incorrect comment table passed' ).

      CATCH cx_root INTO DATA(lx_err).
        cl_abap_unit_assert=>fail( msg = lx_err->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
