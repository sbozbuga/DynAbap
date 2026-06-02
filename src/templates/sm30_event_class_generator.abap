*&---------------------------------------------------------------------*
*& Template: SM30 Table Maintenance Event Include
*&---------------------------------------------------------------------*
*& This template provides a highly simplified, encapsulated FORM routine
*& include that delegates all SM30 event processing and SE24 class
*& generation logic directly to the dynamic print engine class.
*&
*& Setup Instructions:
*& 1. Go to Transaction SE54
*& 2. Enter table /CTDI/REP_FORMS
*& 3. Click "Generated Objects" -> "Events"
*& 4. Add Event '05' (Creating a new entry) with Form routine ON_NEW_ENTRY
*& 5. Add Event '01' (Before saving) with Form routine ON_BEFORE_SAVE
*& 6. Place this code in the generated function group include
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Form ON_NEW_ENTRY
*&---------------------------------------------------------------------*
*& Triggered when a new row is created in SM30 maintenance view.
*& Delegates class generation and default initialization to engine class.
*&---------------------------------------------------------------------*
FORM on_new_entry.
  DATA: ls_entry TYPE /ctdi/rep_forms.

  " Read the new entry from the maintenance view work area structure
  ls_entry = <vim_total_struc>.

  " Delegate auto-generation to customizing engine static method
  /ctdi/cl_print_cust_engine=>on_new_entry( CHANGING cs_entry = ls_entry ).

  " Update the maintenance view work area structure
  <vim_total_struc> = ls_entry.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ON_BEFORE_SAVE
*&---------------------------------------------------------------------*
*& Triggered before saving all changes to the database.
*& Delegates form, class, and method existence validation to engine.
*&---------------------------------------------------------------------*
FORM on_before_save.
  DATA: ls_entry TYPE /ctdi/rep_forms.

  LOOP AT total.
    " Copy current record from total header line
    ls_entry = total.

    " Unconditionally enforce standard method name EXECUTE for obligatory interface usage
    ls_entry-method_name = 'EXECUTE'.

    TRY.
        " Delegate all class, form, and method validations to customizing engine class
        /ctdi/cl_print_cust_engine=>validate_entry( ls_entry ).
      CATCH /ctdi/cx_print_error INTO DATA(lx_err).
        " Issue warning message in SM30
        MESSAGE lx_err->message TYPE 'W'.
    ENDTRY.

    " Copy updated entry back to total and update structure
    total = ls_entry.
    MODIFY total.
  ENDLOOP.
ENDFORM.
