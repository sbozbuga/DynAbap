INTERFACE zif_contract_print_provider
  PUBLIC.

  METHODS print
    IMPORTING
      !iv_contract_id TYPE vbeln_va
      !iv_form_name   TYPE fpname
      !iv_form_type   TYPE char1 DEFAULT 'A'
    RAISING
      cx_static_check.

ENDINTERFACE.
