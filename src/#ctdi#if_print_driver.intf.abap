INTERFACE /ctdi/if_print_driver PUBLIC.

  "! Executes the full print pipeline (read data + render form).
  "!
  "! @parameter iv_repair_id   | Repair / Service Order ID
  "! @parameter iv_form_name   | Smart Form or Adobe Form name
  "! @parameter iv_save_as_pdf | If TRUE, spool output is converted to PDF and downloaded locally
  "! @parameter io_data        | Optional print data object 
  "! @parameter cs_repair      | Repair header and item data (populated by read_data)
  "! @parameter cs_project     | Project header data
  "! @parameter ct_errors      | Table of device defects / error lines
  "! @parameter ct_comments    | Table of comment / long-text lines
  "! @raising   /ctdi/cx_print_driver_error | Any print or form-related failure
  METHODS execute
    IMPORTING
      !iv_repair_id   TYPE aufnr
      !iv_form_name   TYPE fpname
      !iv_save_as_pdf TYPE abap_bool DEFAULT abap_false
      !io_data        TYPE REF TO object OPTIONAL
    CHANGING
      !cs_repair      TYPE any
      !cs_project     TYPE any OPTIONAL
      !ct_errors      TYPE STANDARD TABLE
      !ct_comments    TYPE STANDARD TABLE
    RAISING
      /ctdi/cx_print_driver_error.

ENDINTERFACE.
