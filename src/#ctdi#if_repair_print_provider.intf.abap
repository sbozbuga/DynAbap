INTERFACE /ctdi/if_repair_print_provider
  PUBLIC.

  "! Reads repair data for the given repair ID
  "! @parameter iv_repair_id | Repair document ID
  METHODS read_data
    IMPORTING
      !iv_repair_id TYPE vbeln_va
    CHANGING
      !cs_repair TYPE /ctdi/repair OPTIONAL
      !ct_repair_error TYPE any table OPTIONAL
      !ct_comment_lines TYPE any table OPTIONAL
    RAISING
      /ctdi/cx_print_error.

  "! Executes the full read-and-print flow for one repair ID.
  "! @parameter iv_repair_id | Repair document ID
  "! @parameter iv_form_name | Form name used for printing
  "! @parameter iv_save_as_pdf | Flag to save output as PDF
  METHODS execute
    IMPORTING
      !iv_repair_id TYPE vbeln_va
      !iv_form_name TYPE fpname
      !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
    CHANGING
      !cs_repair TYPE /ctdi/repair OPTIONAL
      !ct_repair_error TYPE any table OPTIONAL
      !ct_comment_lines TYPE any table OPTIONAL
    RAISING
      /ctdi/cx_print_error.

  "! Prints repair document for the given repair ID.
  "! @parameter iv_repair_id | Repair document ID
  "! @parameter iv_form_name | Form name used for printing
  "! @parameter iv_save_as_pdf | Flag to save output as PDF
  METHODS print
    IMPORTING
      !iv_repair_id TYPE vbeln_va
      !iv_form_name   TYPE fpname
      !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
    CHANGING
      !cs_repair TYPE /ctdi/repair OPTIONAL
      !ct_repair_error TYPE any table OPTIONAL
      !ct_comment_lines TYPE any table OPTIONAL
    RAISING
      /ctdi/cx_print_error.

ENDINTERFACE.
