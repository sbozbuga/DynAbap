INTERFACE zif_contract_print_provider
  PUBLIC.

  METHODS print_contract
    IMPORTING
      !iv_contract_id TYPE vbeln_va
      !iv_form_name   TYPE fpname
    RAISING
      cx_static_check.

ENDINTERFACE.
