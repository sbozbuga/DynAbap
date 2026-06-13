CLASS /ctdi/cl_print_driver_legacy DEFINITION
  PUBLIC
  INHERITING FROM /ctdi/cl_print_driver_base
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
    METHODS read_data REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.

CLASS /ctdi/cl_print_driver_legacy IMPLEMENTATION.

  METHOD read_data.

    " If an external data object is passed, unpack it
    IF io_data IS BOUND.
      TRY.
          " Cast io_data to /ctdi/cl_print_data_legacy or its subclasses
          DATA(lr_legacy_data) = CAST /ctdi/cl_print_data_legacy( io_data ).

          MOVE-CORRESPONDING lr_legacy_data->ms_alcarep TO ms_repair.
          mt_comments = lr_legacy_data->mt_comment_lines.

          LOOP AT lr_legacy_data->mt_alcarep_error INTO DATA(ls_err).
            APPEND INITIAL LINE TO mt_errors ASSIGNING FIELD-SYMBOL(<ls_target_err>).
            MOVE-CORRESPONDING ls_err TO <ls_target_err>.
          ENDLOOP.

          /ctdi/cl_print_driver_log=>log_info(
            |Legacy Print Driver successfully unpacked io_data for Repair { mv_repair_order }| ).

        CATCH cx_sy_move_cast_error INTO DATA(lx_cast).
          DATA(lv_err) = |Invalid data object passed to Legacy Print Driver for { mv_repair_order }|.
          /ctdi/cl_print_driver_log=>log_error( lv_err ).
          RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
            EXPORTING
              message  = lv_err
              previous = lx_cast.
      ENDTRY.
    ELSE.
      " If no external object is provided, fallback to instantiating and reading from DB directly
      TRY.
          DATA(lr_data_db) = NEW /ctdi/cl_print_data_legacy_ext( ).
          lr_data_db->read_data( iv_aufnr = mv_repair_order ).

          MOVE-CORRESPONDING lr_data_db->ms_alcarep TO ms_repair.
          mt_comments = lr_data_db->mt_comment_lines.

          LOOP AT lr_data_db->mt_alcarep_error INTO DATA(ls_err_db).
            APPEND INITIAL LINE TO mt_errors ASSIGNING FIELD-SYMBOL(<ls_target_err_db>).
            MOVE-CORRESPONDING ls_err_db TO <ls_target_err_db>.
          ENDLOOP.
          
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
  ENDMETHOD.

ENDCLASS.
