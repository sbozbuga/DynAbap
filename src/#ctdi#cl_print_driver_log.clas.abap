CLASS /ctdi/cl_print_driver_log DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-DATA gv_log_level TYPE char1 VALUE 'I'.

    CLASS-METHODS set_log_level
      IMPORTING iv_level TYPE char1.

    "! Log an informational message to SLG1
    "!
    "! @parameter iv_text |
    "! @parameter iv_object |
    "! @parameter iv_subobject |
    CLASS-METHODS log_info
      IMPORTING iv_text      TYPE string
                iv_object    TYPE balobj_d  DEFAULT '/CTDI/PRINT'
                iv_subobject TYPE balsubobj DEFAULT 'DRIVER'.

    "! Log a warning message to SLG1
    "!
    "! @parameter iv_text |
    "! @parameter iv_object |
    "! @parameter iv_subobject |
    CLASS-METHODS log_warning
      IMPORTING iv_text      TYPE string
                iv_object    TYPE balobj_d  DEFAULT '/CTDI/PRINT'
                iv_subobject TYPE balsubobj DEFAULT 'DRIVER'.

    "! Log an error message to SLG1
    "!
    "! @parameter iv_text |
    "! @parameter iv_object |
    "! @parameter iv_subobject |
    CLASS-METHODS log_error
      IMPORTING iv_text      TYPE string
                iv_object    TYPE balobj_d  DEFAULT '/CTDI/PRINT'
                iv_subobject TYPE balsubobj DEFAULT 'DRIVER'.

    "! Log an exception's text to SLG1
    "!
    "! @parameter ix_exception |
    "! @parameter iv_object |
    "! @parameter iv_subobject |
    CLASS-METHODS log_exception
      IMPORTING ix_exception TYPE REF TO cx_root
                iv_object    TYPE balobj_d  DEFAULT '/CTDI/PRINT'
                iv_subobject TYPE balsubobj DEFAULT 'DRIVER'.

    CLASS-METHODS save_log.
    CLASS-METHODS show_log.

  PRIVATE SECTION.
    CLASS-DATA go_app_log           TYPE REF TO /hpc/cl_uappl_log.
    CLASS-DATA gv_current_object    TYPE balobj_d.
    CLASS-DATA gv_current_subobject TYPE balsubobj.
    CLASS-DATA gv_has_unsaved_logs  TYPE abap_bool.

    CLASS-METHODS get_app_log
      IMPORTING iv_object     TYPE balobj_d
                iv_subobject  TYPE balsubobj
      RETURNING VALUE(ro_log) TYPE REF TO /hpc/cl_uappl_log.

    CLASS-METHODS add_to_log
      IMPORTING iv_text      TYPE string
                iv_msgty     TYPE symsgty
                iv_object    TYPE balobj_d
                iv_subobject TYPE balsubobj.
ENDCLASS.



CLASS /CTDI/CL_PRINT_DRIVER_LOG IMPLEMENTATION.


  METHOD add_to_log.
    CHECK iv_text IS NOT INITIAL.

    " 0. Check log level
    DATA lv_level_num TYPE i.
    DATA lv_msg_num   TYPE i.

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

    DATA(lo_log) = get_app_log( iv_object    = iv_object
                                iv_subobject = iv_subobject ).
    IF lo_log IS BOUND.
      lo_log->add_single_message( iv_msgty = iv_msgty
                                  iv_msg   = iv_text ).
      gv_has_unsaved_logs = abap_true.

      " Give visual feedback to the user on long-running processes
      IF sy-batch = abap_false.
        CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
          EXPORTING
            text = iv_text.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD get_app_log.
    IF go_app_log IS INITIAL.
      " Enhance log with execution context (TCode, Mode)
      DATA(lv_mode) = COND string( WHEN sy-batch = abap_true THEN 'BATCH' ELSE 'DIALOG' ).
      DATA(lv_extid) = |[{ lv_mode }] TCode: { sy-tcode } Prog: { sy-cprog }|.

      CREATE OBJECT go_app_log
        EXPORTING
          iv_category    = iv_object
          iv_subcategory = iv_subobject
          iv_extid       = CONV #( lv_extid ).
      gv_current_object = iv_object.
      gv_current_subobject = iv_subobject.
    ELSEIF gv_current_object <> iv_object OR gv_current_subobject <> iv_subobject.
      go_app_log->change_header( EXPORTING  iv_category    = iv_object
                                            iv_subcategory = iv_subobject
                                 EXCEPTIONS OTHERS         = 1 ).
      IF sy-subrc = 0.
        gv_current_object = iv_object.
        gv_current_subobject = iv_subobject.
      ENDIF.
    ENDIF.
    ro_log = go_app_log.
  ENDMETHOD.


  METHOD log_error.
    add_to_log( iv_text      = iv_text
                iv_msgty     = 'E'
                iv_object    = iv_object
                iv_subobject = iv_subobject ).
  ENDMETHOD.


  METHOD log_exception.
    DATA(lo_log) = get_app_log( iv_object    = iv_object
                                iv_subobject = iv_subobject ).
    IF lo_log IS BOUND.
      lo_log->add_exception( i_exception = ix_exception ).
      gv_has_unsaved_logs = abap_true.
    ENDIF.
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


  METHOD save_log.
    IF go_app_log IS BOUND AND gv_has_unsaved_logs = abap_true.
      go_app_log->finalize( ).
      gv_has_unsaved_logs = abap_false.
      CLEAR go_app_log.
      CLEAR gv_current_object.
      CLEAR gv_current_subobject.
    ENDIF.
  ENDMETHOD.


  METHOD set_log_level.
    gv_log_level = iv_level.
  ENDMETHOD.


  METHOD show_log.
    IF go_app_log IS BOUND AND gv_has_unsaved_logs = abap_true.
      go_app_log->display( iv_popup = abap_true ).
      gv_has_unsaved_logs = abap_false.
      CLEAR go_app_log.
      CLEAR gv_current_object.
      CLEAR gv_current_subobject.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
