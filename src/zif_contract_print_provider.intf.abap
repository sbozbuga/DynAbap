INTERFACE zif_contract_print_provider
  PUBLIC.

  METHODS print
    IMPORTING
      !iv_contract_id TYPE vbeln_va
      !iv_form_name   TYPE fpname
      !iv_form_type   TYPE char1 DEFAULT 'A'
      !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
    RAISING
      cx_static_check.

ENDINTERFACE.
