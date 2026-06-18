CLASS /ctdi/cl_print_driver_legacy DEFINITION
  PUBLIC
  INHERITING FROM /ctdi/cl_print_driver_base
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
    METHODS unpack_io_data        REDEFINITION.
    METHODS fetch_data_from_db    REDEFINITION.
    METHODS map_and_register_data REDEFINITION.
  PRIVATE SECTION.
    DATA ms_alcarep_legacy TYPE /cellag/alcarep.
    DATA mt_alcarep_error  TYPE STANDARD TABLE OF /cellag/alcarep_error.
    DATA mv_user_settings  TYPE char1 VALUE space.
    DATA mr_provider       TYPE REF TO /ctdi/cl_print_data_legacy.
ENDCLASS.

CLASS /ctdi/cl_print_driver_legacy IMPLEMENTATION.

  METHOD unpack_io_data.
    mr_provider = CAST #( io_data ).
  ENDMETHOD.

  METHOD fetch_data_from_db.
    mr_provider = NEW #( ).
    mr_provider->read_data( iv_aufnr = mv_repair_order
                            iv_sernr = mv_sernr ).
  ENDMETHOD.

  METHOD map_and_register_data.
    IF mr_provider IS BOUND.
      ms_alcarep_legacy = mr_provider->ms_legacy.
      mt_alcarep_error  = mr_provider->mt_legacy_error.
      mt_comments       = mr_provider->mt_comment_lines.

      MOVE-CORRESPONDING ms_alcarep_legacy TO ms_repair.

      LOOP AT mt_alcarep_error INTO DATA(ls_err).
        APPEND INITIAL LINE TO mt_errors ASSIGNING FIELD-SYMBOL(<ls_target_err>).
        MOVE-CORRESPONDING ls_err TO <ls_target_err>.
      ENDLOOP.

      " Register legacy structures for dynamic Smart Form parameter injection
      register_custom_parameter( iv_name = '/CELLAG/ALCAREP'       iv_kind = abap_func_exporting ir_data = REF #( ms_alcarep_legacy ) ).
      register_custom_parameter( iv_name = 'USER_SETTINGS'         iv_kind = abap_func_exporting ir_data = REF #( mv_user_settings ) ).
      register_custom_parameter( iv_name = '/CELLAG/ALCAREP_ERROR' iv_kind = abap_func_tables    ir_data = REF #( mt_alcarep_error ) ).
      register_custom_parameter( iv_name = 'GT_COMMENT_LINES'      iv_kind = abap_func_tables    ir_data = REF #( mt_comments ) ).
    ENDIF.
  ENDMETHOD.



ENDCLASS.
