CLASS /ctdi/cl_print_driver_legacy DEFINITION
  PUBLIC
  INHERITING FROM /ctdi/cl_print_driver_base
  CREATE PUBLIC.

  PUBLIC SECTION.

  PROTECTED SECTION.
    METHODS fetch_data_from_db    REDEFINITION.
    METHODS map_and_register_data REDEFINITION.
    METHODS unpack_io_data        REDEFINITION.

  PRIVATE SECTION.
    DATA ms_alcarep_legacy TYPE /cellag/alcarep.
    DATA mt_alcarep_error  TYPE STANDARD TABLE OF /cellag/alcarep_error.
    DATA mr_provider       TYPE REF TO /ctdi/cl_print_data_legacy.
ENDCLASS.


CLASS /ctdi/cl_print_driver_legacy IMPLEMENTATION.
  METHOD fetch_data_from_db.
    mr_provider = NEW #( ).
    mr_provider->read_data( iv_aufnr = mv_repair_order
                            iv_sernr = mv_sernr ).
  ENDMETHOD.

  METHOD map_and_register_data.
    IF mr_provider IS NOT BOUND.
      RETURN.
    ENDIF.

    ms_alcarep_legacy = mr_provider->ms_legacy.
    mt_alcarep_error  = mr_provider->mt_legacy_error.
    mt_comments       = mr_provider->mt_comment_lines.

    MOVE-CORRESPONDING ms_alcarep_legacy TO ms_repair.

    LOOP AT mt_alcarep_error ASSIGNING FIELD-SYMBOL(<ls_err>).
      APPEND INITIAL LINE TO mt_errors ASSIGNING FIELD-SYMBOL(<ls_target_err>).
      MOVE-CORRESPONDING <ls_err> TO <ls_target_err>.
    ENDLOOP.

    " Register legacy structures for dynamic Smart Form parameter injection
    register_custom_parameter( iv_name = gc_param_legacy_rep
                               iv_kind = abap_func_exporting
                               ir_data = REF #( ms_alcarep_legacy ) ).
    register_custom_parameter( iv_name = gc_param_legacy_err
                               iv_kind = abap_func_tables
                               ir_data = REF #( mt_alcarep_error ) ).
    register_custom_parameter( iv_name = gc_param_legacy_comm
                               iv_kind = abap_func_tables
                               ir_data = REF #( mt_comments ) ).
  ENDMETHOD.

  METHOD unpack_io_data.
    mr_provider = CAST #( io_data ).
  ENDMETHOD.
ENDCLASS.

