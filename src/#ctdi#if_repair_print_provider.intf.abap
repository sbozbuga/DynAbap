INTERFACE /ctdi/if_repair_print_provider
  PUBLIC.

  METHODS read_data
    IMPORTING
      !iv_repair_id TYPE vbeln_va
    RAISING
      /ctdi/cx_print_error.

  METHODS print
    IMPORTING
      !iv_repair_id TYPE vbeln_va
      !iv_form_name   TYPE fpname
      !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
    RAISING
      /ctdi/cx_print_error.

ENDINTERFACE.
