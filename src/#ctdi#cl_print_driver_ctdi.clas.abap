CLASS /ctdi/cl_print_driver_ctdi DEFINITION
  PUBLIC
  INHERITING FROM /ctdi/cl_print_driver_base
  CREATE PUBLIC.

  PUBLIC SECTION.

  PROTECTED SECTION.
    METHODS fetch_data_from_db    REDEFINITION.
    METHODS map_and_register_data REDEFINITION.
    METHODS unpack_io_data        REDEFINITION.

  PRIVATE SECTION.
    DATA mr_provider TYPE REF TO /ctdi/cl_print_data_ctdi.
ENDCLASS.



CLASS /CTDI/CL_PRINT_DRIVER_CTDI IMPLEMENTATION.


  METHOD fetch_data_from_db.
    mr_provider = NEW #( ).
    mr_provider->read_data( iv_aufnr = mv_repair_order
                            iv_sernr = mv_sernr ).
  ENDMETHOD.


  METHOD map_and_register_data.
    IF mr_provider IS BOUND.
      ms_repair   = mr_provider->ms_repair.
      mt_errors   = mr_provider->mt_repair_error.
      mt_comments = mr_provider->mt_comments.

      " Register standard CTDI structures dynamically for Smart/Adobe Forms
      register_custom_parameter( iv_name = 'REPAIR'
                                 iv_kind = abap_func_exporting
                                 ir_data = REF #( ms_repair ) ).
      register_custom_parameter( iv_name = 'PROJECT'
                                 iv_kind = abap_func_exporting
                                 ir_data = REF #( ms_project ) ).
      register_custom_parameter( iv_name = 'REPAIR_ERRORS'
                                 iv_kind = abap_func_tables
                                 ir_data = REF #( mt_errors ) ).
      register_custom_parameter( iv_name = 'COMMENT_LINES'
                                 iv_kind = abap_func_tables
                                 ir_data = REF #( mt_comments ) ).
    ENDIF.
  ENDMETHOD.


  METHOD unpack_io_data.
    mr_provider = CAST #( io_data ).
  ENDMETHOD.
ENDCLASS.
