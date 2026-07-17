*&---------------------------------------------------------------------*
*&  Include           /CTDI/WORKSHOP_INCL_SE54
*&---------------------------------------------------------------------*

FORM 05_new_entry.
*  BREAK-POINT.
  CALL METHOD /ctdi/cl_print_cust_engine=>on_new_entry
    CHANGING
      cs_entry = /ctdi/rep_forms.

ENDFORM.

FORM 01_before_save.

  DATA: ls_rep_forms TYPE /ctdi/rep_forms.

  LOOP AT total.
    " Check if the row was newly added ('N') or updated ('U')
    IF <action> = 'N' OR <action> = 'U'.

      " 1. Safely cast the flat TOTAL string to the typed table structure
      " This works natively in ABAP 7.50+ without dumping, ignoring action/mark flags
      ASSIGN total TO FIELD-SYMBOL(<ls_total>) CASTING TYPE /ctdi/rep_forms.
      ls_rep_forms = <ls_total>.

      " 2. Apply your custom logic

      " Create a temporary entry for validation so we can keep the short name in the database
      DATA(ls_validation_entry) = ls_rep_forms.
      ls_validation_entry-class_name = /ctdi/cl_print_cust_engine=>normalize_class_name( ls_validation_entry-class_name ).

      TRY.
          /ctdi/cl_print_cust_engine=>validate_entry( is_entry = ls_validation_entry ).
        CATCH /ctdi/cx_cust_error INTO DATA(lx_print_error).
          " Signal TMG framework to abort the save
          vim_abort_saving = abap_true.

          /ctdi/cl_print_driver_log=>log_exception( lx_print_error ).

          " Show the actual validation error to the user
          DATA(lv_msg) = CONV text200( lx_print_error->get_text( ) ).
          sy-msgv1 = lv_msg(50).
          sy-msgv2 = lv_msg+50(50).
          sy-msgv3 = lv_msg+100(50).
          sy-msgv4 = lv_msg+150(50).

          " Use type 'S' DISPLAY LIKE 'E' to show red error without freezing the screen
          MESSAGE s001(00) WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 DISPLAY LIKE 'E'.

          EXIT. " Prevent spamming multiple errors
      ENDTRY.

      " 3. Move the updated data back to TOTAL string
      " Because <ls_total> points to the exact memory of 'total', assigning it back updates it instantly
      <ls_total> = ls_rep_forms.
      MODIFY total.

      " 4. Update the EXTRACT table so the UI reflects changes immediately
      READ TABLE extract WITH KEY <vim_xtotal_key>.
      IF sy-subrc = 0.
        ASSIGN extract TO FIELD-SYMBOL(<ls_extract>) CASTING TYPE /ctdi/rep_forms.
        <ls_extract> = ls_rep_forms.
        MODIFY extract INDEX sy-tabix.
      ENDIF.

    ENDIF.
  ENDLOOP.

ENDFORM.
