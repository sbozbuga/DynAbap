CLASS /ctdi/cl_print_driver_legacy DEFINITION
  PUBLIC
  INHERITING FROM /ctdi/cl_print_driver_base
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
    METHODS read_data REDEFINITION.
    METHODS get_user_print_defaults REDEFINITION.
  PRIVATE SECTION.
    DATA ms_alcarep_legacy TYPE /cellag/alcarep.
    DATA mt_alcarep_error  TYPE STANDARD TABLE OF /cellag/alcarep_error.
    DATA mv_user_settings  TYPE char1 VALUE space.
ENDCLASS.

CLASS /ctdi/cl_print_driver_legacy IMPLEMENTATION.

  METHOD read_data.
    DATA: lr_provider TYPE REF TO /ctdi/cl_print_data_legacy,
          lv_err      TYPE string.

    " 1. Obtain data provider (either via io_data or DB)
    IF io_data IS BOUND.
      TRY.
          lr_provider = CAST /ctdi/cl_print_data_legacy( io_data ).
          /ctdi/cl_print_driver_log=>log_info(
            |Legacy Print Driver successfully unpacked io_data for Repair { mv_repair_order }| ).
        CATCH cx_sy_move_cast_error INTO DATA(lx_cast).
          lv_err = |Invalid data object passed to Legacy Print Driver for { mv_repair_order }|.
          /ctdi/cl_print_driver_log=>log_error( lv_err ).
          RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
            EXPORTING
              message  = lv_err
              previous = lx_cast.
      ENDTRY.
    ELSE.
      TRY.
          lr_provider = NEW /ctdi/cl_print_data_legacy( ).
          lr_provider->read_data( iv_aufnr = mv_repair_order ).
          /ctdi/cl_print_driver_log=>log_info(
            |Legacy Print Driver successfully read data from DB for Repair { mv_repair_order }| ).
        CATCH cx_root INTO DATA(lx_root).
          lv_err = |Error reading data from DB for { mv_repair_order }: { lx_root->get_text( ) }|.
          /ctdi/cl_print_driver_log=>log_error( lv_err ).
          RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
            EXPORTING
              message  = lv_err
              previous = lx_root.
      ENDTRY.
    ENDIF.

    " 2. Map data to class attributes
    IF lr_provider IS BOUND.
      ms_alcarep_legacy = lr_provider->ms_legacy.
      mt_alcarep_error  = lr_provider->mt_legacy_error.
      mt_comments       = lr_provider->mt_comment_lines.

      MOVE-CORRESPONDING ms_alcarep_legacy TO ms_repair.

      LOOP AT mt_alcarep_error INTO DATA(ls_err).
        APPEND INITIAL LINE TO mt_errors ASSIGNING FIELD-SYMBOL(<ls_target_err>).
        MOVE-CORRESPONDING ls_err TO <ls_target_err>.
      ENDLOOP.

      " 3. Register legacy structures for dynamic Smart Form parameter injection
      register_custom_parameter( iv_name = '/CELLAG/ALCAREP'       iv_kind = abap_func_exporting ir_data = REF #( ms_alcarep_legacy ) ).
      register_custom_parameter( iv_name = 'USER_SETTINGS'         iv_kind = abap_func_exporting ir_data = REF #( mv_user_settings ) ).
      register_custom_parameter( iv_name = '/CELLAG/ALCAREP_ERROR' iv_kind = abap_func_tables    ir_data = REF #( mt_alcarep_error ) ).
      register_custom_parameter( iv_name = 'GT_COMMENT_LINES'      iv_kind = abap_func_tables    ir_data = REF #( mt_comments ) ).
    ENDIF.
  ENDMETHOD.

  METHOD get_user_print_defaults.
    " 1. Let the base class fetch the standard user defaults
    super->get_user_print_defaults(
      IMPORTING ev_printer = ev_printer
                ev_immed   = ev_immed
                ev_delete  = ev_delete ).

    " 2. Legacy override: Druckersteuerung durch ycl_printer
    ev_printer = ycl_printer=>select_printer(
                     iv_uname   = sy-uname
                     iv_medium  = ycl_printer=>co_paperprinter_dina4
                     iv_printer = ev_printer ).

    " 3. Hardcoded values from legacy print_sf subroutine
    ev_immed  = abap_true.
    ev_delete = abap_true.
  ENDMETHOD.

ENDCLASS.
