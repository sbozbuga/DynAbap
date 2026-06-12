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
    " If the caller already provided populated data, do nothing!
    IF cs_repair IS NOT INITIAL.
      /ctdi/cl_print_driver_log=>log_info( |Data already populated externally for { iv_repair_id }. Skipping read.| ).
      RETURN.
    ENDIF.

    " If an external data object is passed, unpack it
    IF io_data IS BOUND.
      TRY.
          " Cast io_data to /ctdi/cl_print_data_legacy or its subclasses
          DATA(lr_alca_data) = CAST /ctdi/cl_print_data_legacy( io_data ).

          cs_repair   = lr_alca_data->ms_alcarep.
          ct_comments = lr_alca_data->mt_comment_lines.

          CLEAR ct_errors.
          LOOP AT lr_alca_data->mt_alcarep_error INTO DATA(ls_err).
            APPEND INITIAL LINE TO ct_errors ASSIGNING FIELD-SYMBOL(<ls_target_err>).
            MOVE-CORRESPONDING ls_err TO <ls_target_err>.
          ENDLOOP.

          /ctdi/cl_print_driver_log=>log_info(
            |Legacy Print Driver successfully unpacked io_data for Repair { iv_repair_id }| ).

        CATCH cx_sy_move_cast_error INTO DATA(lx_cast).
          DATA(lv_err) = |Invalid data object passed to Legacy Print Driver for { iv_repair_id }|.
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
          lr_data_db->read_data( iv_aufnr = iv_repair_id ).

          cs_repair   = lr_data_db->ms_alcarep.
          ct_comments = lr_data_db->mt_comment_lines.

          CLEAR ct_errors.
          LOOP AT lr_data_db->mt_alcarep_error INTO DATA(ls_err_db).
            APPEND INITIAL LINE TO ct_errors ASSIGNING FIELD-SYMBOL(<ls_target_err_db>).
            MOVE-CORRESPONDING ls_err_db TO <ls_target_err_db>.
          ENDLOOP.
          
          /ctdi/cl_print_driver_log=>log_info(
            |Legacy Print Driver successfully read data from DB for Repair { iv_repair_id }| ).
        CATCH cx_root INTO DATA(lx_root).
          lv_err = |Error reading data from DB for { iv_repair_id }: { lx_root->get_text( ) }|.
          /ctdi/cl_print_driver_log=>log_error( lv_err ).
          RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
            EXPORTING
              message  = lv_err
              previous = lx_root.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
