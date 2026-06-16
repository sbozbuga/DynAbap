CLASS /ctdi/cl_print_driver_log DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-DATA gv_log_level TYPE char1 VALUE 'W'.

    CLASS-METHODS set_log_level
      IMPORTING
        !iv_level TYPE char1.

    "! Log an informational message to SLG1
    CLASS-METHODS log_info
      IMPORTING
        !iv_text       TYPE string
        !iv_object     TYPE balobj_d DEFAULT '/CTDI/PRINT'
        !iv_subobject  TYPE balsubobj DEFAULT 'DRIVER'.

    "! Log a warning message to SLG1
    CLASS-METHODS log_warning
      IMPORTING
        !iv_text       TYPE string
        !iv_object     TYPE balobj_d DEFAULT '/CTDI/PRINT'
        !iv_subobject  TYPE balsubobj DEFAULT 'DRIVER'.

    "! Log an error message to SLG1
    CLASS-METHODS log_error
      IMPORTING
        !iv_text       TYPE string
        !iv_object     TYPE balobj_d DEFAULT '/CTDI/PRINT'
        !iv_subobject  TYPE balsubobj DEFAULT 'DRIVER'.

    "! Log an exception's text to SLG1
    CLASS-METHODS log_exception
      IMPORTING
        !ix_exception  TYPE REF TO cx_root
        !iv_object     TYPE balobj_d DEFAULT '/CTDI/PRINT'
        !iv_subobject  TYPE balsubobj DEFAULT 'DRIVER'.

    CLASS-METHODS save_log.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA gv_log_handle TYPE balloghndl.
    CLASS-DATA gv_has_unsaved_logs TYPE abap_bool.

    CLASS-METHODS add_to_log
      IMPORTING
        !iv_text      TYPE string
        !iv_msgty     TYPE symsgty
        !iv_object    TYPE balobj_d
        !iv_subobject TYPE balsubobj.
ENDCLASS.



CLASS /ctdi/cl_print_driver_log IMPLEMENTATION.

  METHOD set_log_level.
    gv_log_level = iv_level.
  ENDMETHOD.

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
          lt_handles  TYPE bal_t_logh,
          lv_level_num TYPE i,
          lv_msg_num   TYPE i.

    " 0. Check log level
    CASE gv_log_level.
      WHEN 'I'. lv_level_num = 1.
      WHEN 'W'. lv_level_num = 2.
      WHEN 'E'. lv_level_num = 3.
      WHEN OTHERS. lv_level_num = 2.
    ENDCASE.

    CASE iv_msgty.
      WHEN 'I' OR 'S'. lv_msg_num = 1.
      WHEN 'W'. lv_msg_num = 2.
      WHEN 'E'. lv_msg_num = 3.
      WHEN OTHERS. lv_msg_num = 3.
    ENDCASE.

    IF lv_msg_num < lv_level_num.
      RETURN.
    ENDIF.

    " 1. Create log header if not yet created
    IF gv_log_handle IS INITIAL.
      ls_log-object    = iv_object.
      ls_log-subobject = iv_subobject.
      ls_log-aluser    = sy-uname.
      ls_log-alprog    = sy-repid.

      CALL FUNCTION 'BAL_LOG_CREATE'
        EXPORTING
          i_s_log      = ls_log
        IMPORTING
          e_log_handle = gv_log_handle
        EXCEPTIONS
          OTHERS       = 1.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
    ENDIF.

    " 2. Map free-text to BAL message (message 00 398: &1&2&3&4)
    ls_msg-msgty = iv_msgty.
    ls_msg-msgid = '00'.
    ls_msg-msgno = '398'.

    lv_len = strlen( iv_text ).
    IF lv_len > 0.
      ls_msg-msgv1 = substring( val = iv_text off = 0 len = nmin( val1 = 50 val2 = lv_len ) ).
    ENDIF.
    IF lv_len > 50.
      ls_msg-msgv2 = substring( val = iv_text off = 50 len = nmin( val1 = 50 val2 = lv_len - 50 ) ).
    ENDIF.
    IF lv_len > 100.
      ls_msg-msgv3 = substring( val = iv_text off = 100 len = nmin( val1 = 50 val2 = lv_len - 100 ) ).
    ENDIF.
    IF lv_len > 150.
      ls_msg-msgv4 = substring( val = iv_text off = 150 len = nmin( val1 = 50 val2 = lv_len - 150 ) ).
    ENDIF.

    " 3. Add message to log
    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        i_log_handle = gv_log_handle
        i_s_msg      = ls_msg
      EXCEPTIONS
        OTHERS       = 1.
    IF sy-subrc = 0.
      gv_has_unsaved_logs = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD save_log.
    DATA: lt_handles TYPE bal_t_logh.

    IF gv_log_handle IS NOT INITIAL AND gv_has_unsaved_logs = abap_true.
      INSERT gv_log_handle INTO TABLE lt_handles.

      " Use update task to ensure log is saved safely alongside main transactions
      " or directly if outside update task context.
      CALL FUNCTION 'BAL_DB_SAVE'
        EXPORTING
          i_t_log_handle   = lt_handles
        EXCEPTIONS
          OTHERS           = 1.
      IF sy-subrc = 0.
        gv_has_unsaved_logs = abap_false.
        CLEAR gv_log_handle. " Allow a fresh log header to be created for the next run
      ENDIF.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
