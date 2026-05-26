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
    add_to_log( iv_text      = iv_text
                iv_msgty     = 'I'
                iv_object    = iv_object
                iv_subobject = iv_subobject ).
  ENDMETHOD.

  METHOD log_warning.
    add_to_log( iv_text      = iv_text
                iv_msgty     = 'W'
                iv_object    = iv_object
                iv_subobject = iv_subobject ).
  ENDMETHOD.

  METHOD log_error.
    add_to_log( iv_text      = iv_text
                iv_msgty     = 'E'
                iv_object    = iv_object
                iv_subobject = iv_subobject ).
  ENDMETHOD.

  METHOD log_exception.
    DATA(lv_text) = ix_exception->get_text( ).
    add_to_log( iv_text      = lv_text
                iv_msgty     = 'E'
                iv_object    = iv_object
                iv_subobject = iv_subobject ).
  ENDMETHOD.

  METHOD add_to_log.
    DATA: ls_log      TYPE bal_s_log,
          lv_handle   TYPE balloghndl,
          ls_msg      TYPE bal_s_msg,
          lv_len      TYPE i,
          lt_handles  TYPE bal_t_logh.

    " 1. Define Log Header
    ls_log-object    = iv_object.
    ls_log-subobject = iv_subobject.
    ls_log-aluser    = sy-uname.
    ls_log-alprog    = sy-repid.

    " 2. Create Log
    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log      = ls_log
      IMPORTING
        e_log_handle = lv_handle
      EXCEPTIONS
        OTHERS       = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " 3. Map free-text to BAL message components (max 4 blocks of 50 chars each)
    ls_msg-msgty = iv_msgty.
    ls_msg-msgid = '00'.
    ls_msg-msgno = '398'. " defined as &1&2&3&4

    lv_len = strlen( iv_text ).

    IF lv_len > 0.
      ls_msg-msgv1 = COND #( WHEN lv_len > 50
                             THEN substring( val = iv_text off = 0 len = 50 )
                             ELSE substring( val = iv_text off = 0 len = lv_len ) ).
    ENDIF.
    IF lv_len > 50.
      ls_msg-msgv2 = COND #( WHEN lv_len > 100
                             THEN substring( val = iv_text off = 50 len = 50 )
                             ELSE substring( val = iv_text off = 50 len = lv_len - 50 ) ).
    ENDIF.
    IF lv_len > 100.
      ls_msg-msgv3 = COND #( WHEN lv_len > 150
                             THEN substring( val = iv_text off = 100 len = 50 )
                             ELSE substring( val = iv_text off = 100 len = lv_len - 100 ) ).
    ENDIF.
    IF lv_len > 150.
      ls_msg-msgv4 = COND #( WHEN lv_len > 200
                             THEN substring( val = iv_text off = 150 len = 50 )
                             ELSE substring( val = iv_text off = 150 len = lv_len - 150 ) ).
    ENDIF.

    " 4. Add message to log
    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        i_log_handle = lv_handle
        i_s_msg      = ls_msg
      EXCEPTIONS
        OTHERS       = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " 5. Save log to database (SLG1)
    APPEND lv_handle TO lt_handles.

    CALL FUNCTION 'BAL_DB_SAVE'
      EXPORTING
        i_t_log_handle = lt_handles
      EXCEPTIONS
        OTHERS         = 1.
  ENDMETHOD.

ENDCLASS.
