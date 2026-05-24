CLASS /cdti/cl_repair_print_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS print
      IMPORTING
        !iv_repair_id TYPE vbeln_va
        !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
      RAISING
        /cdti/cx_no_config_found
        cx_static_check.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES: tt_config_buffer TYPE HASHED TABLE OF /cdti/sd_repair_form WITH UNIQUE KEY auart.

    DATA: mt_config_buffer TYPE tt_config_buffer.
ENDCLASS.



CLASS /cdti/cl_repair_print_engine IMPLEMENTATION.

  METHOD print.
    DATA: lv_auart    TYPE auart,
          ls_config   TYPE /cdti/sd_repair_form,
          lo_instance TYPE REF TO object,
          lo_provider TYPE REF TO /cdti/if_repair_print_provider.

    " 1. Retrieve repair type from standard Sales Document Header (VBAK)
    SELECT SINGLE auart FROM vbak INTO @lv_auart WHERE vbeln = @iv_repair_id.
    IF sy-subrc <> 0.
      " Raise a generic error if repair doesn't exist
      RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
    ENDIF.

    " 2. Fetch Customizing configuration for the repair type (Check buffer first)
    READ TABLE mt_config_buffer INTO ls_config WITH KEY auart = lv_auart.
    IF sy-subrc <> 0.
      SELECT SINGLE *
        FROM /cdti/sd_repair_form
        INTO CORRESPONDING FIELDS OF @ls_config
        WHERE auart = @lv_auart.

      IF sy-subrc <> 0.
        " No customizing found for this Sales Repair Type - Fallback to print_old exception
        RAISE EXCEPTION TYPE /cdti/cx_no_config_found.
      ENDIF.

      " Insert into hashed buffer
      INSERT ls_config INTO TABLE mt_config_buffer.
    ENDIF.

    " Validate that class and method names are configured
    IF ls_config-class_name IS INITIAL OR ls_config-method_name IS INITIAL.
      RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
    ENDIF.

    " 3. Instantiate configured printer class
    TRY.
        " Dynamically instantiate the class
        CREATE OBJECT lo_instance TYPE (ls_config-class_name).

      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        " Handle instantiation errors (e.g. class doesn't exist or constructor error)
        RAISE EXCEPTION lx_create.
    ENDTRY.

    " 4. Dynamic Casting to Interface or Fallback to Dynamic Method Call
    TRY.
        " Try to dynamically cast the instance to the standard print provider interface
        lo_provider ?= lo_instance.

        " Execute method type-safely via the interface
        lo_provider->read_data( iv_repair_id = iv_repair_id ).

        lo_provider->print(
          iv_repair_id = iv_repair_id
          iv_form_name   = ls_config-form_name
          iv_form_type   = ls_config-form_type
          iv_save_as_pdf = iv_save_as_pdf ).

      CATCH cx_sy_move_cast_error.
        " If class does not implement the interface, fallback to fully dynamic method execution
        " NOTE: For legacy classes, we assume the single method defined in customizing handles both
        TRY.
            CALL METHOD lo_instance->(ls_config-method_name)
              EXPORTING
                iv_repair_id = iv_repair_id
                iv_form_name   = ls_config-form_name
                iv_form_type   = ls_config-form_type
                iv_save_as_pdf = iv_save_as_pdf.
          CATCH cx_sy_dyn_call_error INTO DATA(lx_dyn_call).
            RAISE EXCEPTION lx_dyn_call.
        ENDTRY.

      CATCH cx_root INTO DATA(lx_root).
        " Catch other static or dynamic exceptions
        RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
