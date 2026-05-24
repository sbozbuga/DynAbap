*&---------------------------------------------------------------------*
*& Template: SM30 Table Maintenance Event for Auto-Generating Print Classes
*&---------------------------------------------------------------------*
*& This template provides a FORM routine that can be attached to the
*& table maintenance events of /CTDI/SD_REPAIR_FORM via SE54.
*&
*& Setup Instructions:
*& 1. Go to Transaction SE54
*& 2. Enter table /CTDI/SD_REPAIR_FORM
*& 3. Click "Generated Objects" -> "Events"
*& 4. Add Event '05' (Creating a new entry) with Form routine ON_NEW_ENTRY
*& 5. Add Event '01' (Before saving) with Form routine ON_BEFORE_SAVE
*& 6. Place this code in the generated function group include
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Form ON_NEW_ENTRY
*&---------------------------------------------------------------------*
*& Triggered when a new row is created in SM30 maintenance view.
*& Automatically generates a new SE24 class implementing
*& /CTDI/IF_REPAIR_PRINT_PROVIDER if the CLASS_NAME field is empty.
*&---------------------------------------------------------------------*
FORM on_new_entry.
  DATA: ls_entry TYPE /ctdi/sd_repair_form.

  " Read the new entry from the maintenance view work area
  ls_entry = <vim_total_struc>.

  " Skip if class name is already provided by the user
  IF ls_entry-class_name IS NOT INITIAL.
    " Check if the manually entered class already exists
    SELECT SINGLE clsname FROM seoclass
      INTO @DATA(lv_exists)
      WHERE clsname = @ls_entry-class_name.
    IF sy-subrc = 0.
      RETURN. " Class already exists, nothing to generate
    ENDIF.
  ENDIF.

  " Auto-generate a class name from the Contract VBELN if not provided
  IF ls_entry-class_name IS INITIAL.
    ls_entry-class_name = |/CTDI/CL_REPAIR_PRINT_{ ls_entry-vbeln }|.
  ENDIF.

  " Verify the auto-generated class does not already exist
  SELECT SINGLE clsname FROM seoclass
    INTO @lv_exists
    WHERE clsname = @ls_entry-class_name.
  IF sy-subrc = 0.
    " Class already exists, just update the customizing entry
    ls_entry-method_name = 'PRINT'.
    MODIFY /ctdi/sd_repair_form FROM ls_entry.
    RETURN.
  ENDIF.

  " ---------------------------------------------------------------
  " Generate the SE24 class with interface /CTDI/IF_REPAIR_PRINT_PROVIDER
  " ---------------------------------------------------------------
  DATA: ls_class TYPE vseoclass,
        lt_intfs TYPE seor_implementing_keys.

  ls_class-clsname    = ls_entry-class_name.
  ls_class-langu      = sy-langu.
  ls_class-descript   = |Print Provider for Contract { ls_entry-vbeln }|.
  ls_class-state      = '1'. " Active
  ls_class-clsccincl  = 'X'.
  ls_class-fixpt      = 'X'.
  ls_class-unicode    = 'X'.
  ls_class-exposure   = '2'. " Public

  " Add interface implementation
  APPEND VALUE #( clsname    = ls_entry-class_name
                  refclsname = '/CTDI/IF_REPAIR_PRINT_PROVIDER' )
    TO lt_intfs.

  CALL FUNCTION 'SEO_CLASS_CREATE_COMPLETE'
    EXPORTING
      devclass   = '$TMP'     " Assign to $TMP initially; reassign via transport later
      overwrite  = abap_false
    CHANGING
      class      = ls_class
      intkey     = lt_intfs
    EXCEPTIONS
      existing   = 1
      is_class   = 2
      db_error   = 3
      component_error = 4
      no_access  = 5
      other      = 6
      others     = 7.

  IF sy-subrc = 0.
    " Update the customizing entry with the generated class name and method
    ls_entry-method_name = 'PRINT'.
    MODIFY /ctdi/sd_repair_form FROM ls_entry.
    MESSAGE |Class { ls_entry-class_name } successfully generated.| TYPE 'S'.
  ELSE.
    MESSAGE |Error generating class { ls_entry-class_name }. RC={ sy-subrc }| TYPE 'W'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form ON_BEFORE_SAVE
*&---------------------------------------------------------------------*
*& Triggered before saving all changes to the database.
*& Validates that all entries have valid class and method configurations.
*&---------------------------------------------------------------------*
FORM on_before_save.
  DATA: ls_entry TYPE /ctdi/sd_repair_form.

  LOOP AT total INTO ls_entry.
    " Validate class name is not empty
    IF ls_entry-class_name IS INITIAL.
      MESSAGE |Class name is required for Contract { ls_entry-vbeln }.| TYPE 'E'.
      RETURN.
    ENDIF.

    " Validate method name defaults to PRINT if empty
    IF ls_entry-method_name IS INITIAL.
      ls_entry-method_name = 'PRINT'.
      MODIFY total FROM ls_entry.
    ENDIF.

    " Validate class exists in the repository
    SELECT SINGLE clsname FROM seoclass
      INTO @DATA(lv_exists)
      WHERE clsname = @ls_entry-class_name.
    IF sy-subrc <> 0.
      MESSAGE |Class { ls_entry-class_name } does not exist. Create it first or use auto-generation.| TYPE 'W'.
    ENDIF.
  ENDLOOP.

ENDFORM.
