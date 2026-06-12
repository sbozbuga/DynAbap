*&---------------------------------------------------------------------*
*&  Include           /CTDI/WORKSHOP_INCL_SE54
*&---------------------------------------------------------------------*

FORM new_entry.
*  BREAK-POINT.
  CALL METHOD /ctdi/cl_print_cust_engine=>on_new_entry
    CHANGING
      cs_entry = /ctdi/rep_forms.

ENDFORM.

FORM 01_before_save.

  " The TOTAL internal table has a hidden structure containing the table data
  " and an action flag (<ACTION>).
*  BREAK-POINT.
  LOOP AT total.
    " Check if the row was newly added ('N') or updated ('U')
    IF <action> = 'N' OR <action> = 'U'.

      " 1. Read the current line's data into the table's header/work area
      " (The TMG automatically declares a structure matching your table name)
*      /ctdi/rep_forms = total.
      MOVE-CORRESPONDING total TO /ctdi/rep_forms.

      " 2. Apply your custom logic
      /ctdi/rep_forms-changed_by = sy-uname.
      GET TIME FIELD /ctdi/rep_forms-changed_on.

      " 3. Move the updated data back to TOTAL
      MOVE-CORRESPONDING /ctdi/rep_forms  TO total.

      " 4. Modify the TOTAL table
      MODIFY total.
    ENDIF.
  ENDLOOP.

  TRY.
      CALL METHOD /ctdi/cl_print_cust_engine=>validate_entry
        EXPORTING
          is_entry = /ctdi/rep_forms.
    CATCH /ctdi/cx_print_error INTO DATA(lx_print_error) .
      vim_abort_saving = abap_true.

      DATA(lv_msg) = CONV text200( lx_print_error->message ).
      sy-msgv1 = lv_msg(50).
      sy-msgv2 = lv_msg+50(50).
      sy-msgv3 = lv_msg+100(50).
      sy-msgv4 = lv_msg+150(50).
      MESSAGE i001(00) WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDTRY.

ENDFORM.
