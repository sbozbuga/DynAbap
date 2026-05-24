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
    TYPES: BEGIN OF ty_project_info,
             vbeln       TYPE vbeln_va,
             project_id  TYPE ps_posid,
             description TYPE ps_post1,
             cust_ref    TYPE bstnk,
           END OF ty_project_info.

    DATA: lv_fm_name      TYPE rs38l_fnam,
          ls_outputparams TYPE sfpoutputparams,
          ls_docparams    TYPE sfpdocparams,
          ls_header       TYPE vbak,
          lt_items        TYPE TABLE OF vbap,
          ls_customer     TYPE kna1,
          ls_shipto       TYPE kna1,
          lv_kunnr_we     TYPE kunnr,
          ls_project      TYPE ty_project_info.

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

    " 1.3 Fetch Customer Project / WBS Element details linked to the contract items
    ls_project-vbeln    = iv_contract_id.
    ls_project-cust_ref = ls_header-bstnk. " Customer Purchase Order / Reference (often contains project/contract name)

    LOOP AT lt_items INTO DATA(ls_item) WHERE ps_psp_eln IS NOT INITIAL.
      SELECT SINGLE posid, post1 FROM prps INTO ( @ls_project-project_id, @ls_project-description )
        WHERE pspnr = @ls_item-ps_psp_eln.
      IF sy-subrc = 0.
        EXIT. " Use the first WBS element found for sample description
      ENDIF.
    ENDLOOP.

    " Fallback: If no WBS project is explicitly linked to the items, check standard VBAK fields
    IF ls_project-project_id IS INITIAL.
      " If VBAK-BSTNK has a project name (like 'Deutsche Telekom 5G Base Station Repair')
      " we can treat that as the project description fallback
      ls_project-description = ls_header-bstnk.
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
        " Pass header, items, customer, ship-to partner, and project details to the form
        is_header         = ls_header
        it_items          = lt_items
        is_customer       = ls_customer
        is_shipto         = ls_shipto
        is_project        = ls_project
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
