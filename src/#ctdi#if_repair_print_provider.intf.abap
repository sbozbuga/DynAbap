interface /CTDI/IF_REPAIR_PRINT_PROVIDER
  public .


  "! Reads repair data for the given repair ID
  "! @parameter iv_repair_id | Repair document ID
  methods READ_DATA
    importing
      !IV_REPAIR_ID type AUFNR
    changing
      !CS_REPAIR type /CTDI/REPAIR optional
      !CT_DEVICE_DEFECTS type ANY TABLE optional
      !CT_COMMENT_LINES type ANY TABLE optional
    raising
      /CTDI/CX_PRINT_ERROR .
  "! Executes the full read-and-print flow for one repair ID.
  "! @parameter iv_repair_id | Repair document ID
  "! @parameter iv_form_name | Form name used for printing
  "! @parameter iv_save_as_pdf | Flag to save output as PDF
  methods EXECUTE
    importing
      !IV_REPAIR_ID type AUFNR
      !IV_FORM_NAME type FPNAME
      !IV_SAVE_AS_PDF type ABAP_BOOL default ABAP_FALSE
    changing
      !CS_REPAIR type /CTDI/REPAIR optional
      !CT_DEVICE_DEFECTS type ANY TABLE optional
      !CT_COMMENT_LINES type ANY TABLE optional
    raising
      /CTDI/CX_PRINT_ERROR .
  "! Prints repair document for the given repair ID.
  "! @parameter iv_repair_id | Repair document ID
  "! @parameter iv_form_name | Form name used for printing
  "! @parameter iv_save_as_pdf | Flag to save output as PDF
  methods PRINT
    importing
      !IV_REPAIR_ID type AUFNR
      !IV_FORM_NAME type FPNAME
      !IV_SAVE_AS_PDF type ABAP_BOOL default ABAP_FALSE
    changing
      !CS_REPAIR type /CTDI/REPAIR optional
      !CT_DEVICE_DEFECTS type STANDARD TABLE optional
      !CT_COMMENT_LINES type STANDARD TABLE optional
    raising
      /CTDI/CX_PRINT_ERROR .
endinterface.
