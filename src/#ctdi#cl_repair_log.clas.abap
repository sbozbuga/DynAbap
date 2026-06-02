CLASS /ctdi/cl_repair_log DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CLASS-METHODS log_info
      IMPORTING
        !iv_text TYPE string
        !iv_object TYPE balobj_d DEFAULT '/CTDI/PRINT'
        !iv_subobject TYPE balsubobj DEFAULT 'ENGINE'.

    CLASS-METHODS log_warning
      IMPORTING
        !iv_text TYPE string
        !iv_object TYPE balobj_d DEFAULT '/CTDI/PRINT'
        !iv_subobject TYPE balsubobj DEFAULT 'ENGINE'.

    CLASS-METHODS log_error
      IMPORTING
        !iv_text TYPE string
        !iv_object TYPE balobj_d DEFAULT '/CTDI/PRINT'
        !iv_subobject TYPE balsubobj DEFAULT 'ENGINE'.

    CLASS-METHODS log_exception
      IMPORTING
        !ix_exception TYPE REF TO cx_root
        !iv_object TYPE balobj_d DEFAULT '/CTDI/PRINT'
        !iv_subobject TYPE balsubobj DEFAULT 'ENGINE'.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS add_to_log
      IMPORTING
        !iv_text TYPE string
        !iv_msgty TYPE symsgty
        !iv_object TYPE balobj_d
        !iv_subobject TYPE balsubobj.
ENDCLASS.



CLASS /ctdi/cl_repair_log IMPLEMENTATION.

  METHOD log_info.
    /ctdi/cl_print_driver_log=>log_info(
      iv_text      = iv_text
      iv_object    = iv_object
      iv_subobject = iv_subobject ).
  ENDMETHOD.

  METHOD log_warning.
    /ctdi/cl_print_driver_log=>log_warning(
      iv_text      = iv_text
      iv_object    = iv_object
      iv_subobject = iv_subobject ).
  ENDMETHOD.

  METHOD log_error.
    /ctdi/cl_print_driver_log=>log_error(
      iv_text      = iv_text
      iv_object    = iv_object
      iv_subobject = iv_subobject ).
  ENDMETHOD.

  METHOD log_exception.
    /ctdi/cl_print_driver_log=>log_exception(
      ix_exception = ix_exception
      iv_object    = iv_object
      iv_subobject = iv_subobject ).
  ENDMETHOD.

  METHOD add_to_log.
    " Obsolete: delegated directly to /ctdi/cl_print_driver_log
  ENDMETHOD.

ENDCLASS.
