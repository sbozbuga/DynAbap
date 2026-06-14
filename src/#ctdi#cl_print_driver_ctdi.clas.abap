CLASS /ctdi/cl_print_driver_ctdi DEFINITION
  PUBLIC
  INHERITING FROM /ctdi/cl_print_driver_base
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
    METHODS read_data REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.

CLASS /ctdi/cl_print_driver_ctdi IMPLEMENTATION.

  METHOD read_data.
    DATA: lr_provider TYPE REF TO /ctdi/cl_print_data_ctdi,
          lv_err      TYPE string.

    " 1. Obtain data provider (either via io_data or DB)
    IF io_data IS BOUND.
      TRY.
          lr_provider = CAST /ctdi/cl_print_data_ctdi( io_data ).
          /ctdi/cl_print_driver_log=>log_info(
            |CTDI Print Driver successfully unpacked io_data for Repair { mv_repair_order }| ).
        CATCH cx_sy_move_cast_error INTO DATA(lx_cast).
          lv_err = |Invalid data object passed to CTDI Print Driver for { mv_repair_order }|.
          /ctdi/cl_print_driver_log=>log_error( lv_err ).
          RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
            EXPORTING
              message  = lv_err
              previous = lx_cast.
      ENDTRY.
    ELSE.
      TRY.
          lr_provider = NEW /ctdi/cl_print_data_ctdi( ).
          lr_provider->read_data( iv_aufnr = mv_repair_order 
                                  iv_sernr = mv_sernr ).
          /ctdi/cl_print_driver_log=>log_info(
            |CTDI Print Driver successfully read data from DB for Repair { mv_repair_order }| ).
        CATCH cx_root INTO DATA(lx_root).
          lv_err = |Error reading data from DB for { mv_repair_order }: { lx_root->get_text( ) }|.
          /ctdi/cl_print_driver_log=>log_error( lv_err ).
          RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
            EXPORTING
              message  = lv_err
              previous = lx_root.
      ENDTRY.
    ENDIF.

    " 2. Map data directly to base class attributes for dynamic form injection
    IF lr_provider IS BOUND.
      ms_repair   = lr_provider->ms_repair.
      mt_errors   = lr_provider->mt_repair_error.
      mt_comments = lr_provider->mt_comments.

      " 3. Register standard CTDI structures dynamically for Smart/Adobe Forms
      register_custom_parameter( iv_name = 'REPAIR'        iv_kind = abap_func_exporting ir_data = REF #( ms_repair ) ).
      register_custom_parameter( iv_name = 'PROJECT'       iv_kind = abap_func_exporting ir_data = REF #( ms_project ) ).
      register_custom_parameter( iv_name = 'REPAIR_ERRORS' iv_kind = abap_func_tables    ir_data = REF #( mt_errors ) ).
      register_custom_parameter( iv_name = 'COMMENT_LINES' iv_kind = abap_func_tables    ir_data = REF #( mt_comments ) ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
