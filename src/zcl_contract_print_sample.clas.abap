CLASS zcl_contract_print_sample DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_contract_print_provider.

    ALIASES print_contract
      FOR zif_contract_print_provider~print_contract.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_contract_print_sample IMPLEMENTATION.

  METHOD zif_contract_print_provider~print_contract.
    DATA: lv_fm_name      TYPE rs38l_fnam,
          ls_outputparams TYPE sfpoutputparams,
          ls_docparams    TYPE sfpdocparams,
          ls_header       TYPE vbak,
          lt_items        TYPE TABLE OF vbap,
          ls_customer     TYPE kna1,
          ls_shipto       TYPE kna1,
          lv_kunnr_we     TYPE kunnr.

    " 1. Fetch Contract Header and Item Data from VBAK and VBAP
    SELECT SINGLE * FROM vbak INTO @ls_header WHERE vbeln = @iv_contract_id.
    IF sy-subrc <> 0.
      " Exit if contract not found
      RETURN.
    ENDIF.

    SELECT * FROM vbap INTO TABLE @lt_items WHERE vbeln = @iv_contract_id.

    " 1.1 Fetch Sold-to Customer master data (KNA1) using VBAK-KUNNR
    IF ls_header-kunnr IS NOT INITIAL.
      SELECT SINGLE * FROM kna1 INTO @ls_customer WHERE kunnr = @ls_header-kunnr.
    ENDIF.

    " 1.2 Fetch Ship-to Customer from Partner table (VBPA) where Role = 'WE' (Ship-to)
    SELECT SINGLE kunnr FROM vbpa INTO @lv_kunnr_we
      WHERE vbeln = @iv_contract_id
        AND parvw = 'WE'.
    IF sy-subrc = 0 AND lv_kunnr_we IS NOT INITIAL.
      SELECT SINGLE * FROM kna1 INTO @ls_shipto WHERE kunnr = @lv_kunnr_we.
    ENDIF.

    " 2. Initialize Output Parameters (Standard SAP Interactive/Adobe Forms logic)
    ls_outputparams-connection = 'ADS'.       " Adobe Document Services default connection
    ls_outputparams-nodialog   = abap_true.   " Suppress print dialog for automated printing
    ls_outputparams-preview    = abap_true.    " Enable print preview

    " Open the printing job
    CALL FUNCTION 'FP_JOB_OPEN'
      CHANGING
        ie_outputparams = ls_outputparams
      EXCEPTIONS
        cancel          = 1
        usage_error     = 2
        system_error    = 3
        internal_error  = 4
        others          = 5.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
    ENDIF.

    " 3. Retrieve the dynamic PDF/Adobe function module name generated for the form
    TRY.
        CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
          EXPORTING
            i_name     = iv_form_name
          IMPORTING
            e_funcname = lv_fm_name.
      CATCH cx_root.
        " Ensure job is closed in case of error
        CALL FUNCTION 'FP_JOB_CLOSE'.
        RETURN.
    ENDTRY.

    " 4. Call the Adobe Form generated function module dynamically
    " Docparams controls language and country configurations
    ls_docparams-langu   = sy-langu.
    ls_docparams-country = 'US'.

    CALL FUNCTION lv_fm_name
      EXPORTING
        /1bcdwb/docparams = ls_docparams
        " Pass header, items, and additional customer/ship-to partner data to the form
        is_header         = ls_header
        it_items          = lt_items
        is_customer       = ls_customer
        is_shipto         = ls_shipto
      EXCEPTIONS
        usage_error       = 1
        system_error      = 2
        internal_error    = 3
        others            = 4.

    DATA(lv_subrc) = sy-subrc.

    " 5. Close the printing job
    CALL FUNCTION 'FP_JOB_CLOSE'
      EXCEPTIONS
        usage_error    = 1
        system_error   = 2
        internal_error = 3
        others         = 4.

    IF lv_subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_dyn_call_illegal_value.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
