class /CTDI/APP_LOG definition
  public
  final
  create public .

*"* public components of class /CTDI/APP_LOG
*"* do not include other source files here!!!
public section.

  interfaces IF_LOGGER .
  interfaces IF_SBAL_LOGGER .

  aliases MESSAGE_COUNTER
    for IF_LOGGER~MESSAGE_COUNTER .
  aliases ADD_EXCEPTION
    for IF_SBAL_LOGGER~ADD_EXCEPTION .
  aliases ADD_MESSAGE
    for IF_SBAL_LOGGER~ADD_MESSAGE .
  aliases FINALIZE
    for IF_SBAL_LOGGER~FINALIZE .
  aliases GET_LOG_HANDLES
    for IF_SBAL_LOGGER~GET_LOG_HANDLES .
  aliases RESET
    for IF_SBAL_LOGGER~RESET .

  constants C_MESSAGE_INFO type SYMSGTY value 'I' ##NO_TEXT.
  constants C_PROBCLASS_HIGH type BAL_S_MSG-PROBCLASS value '2' ##NO_TEXT.
  constants C_PROBCLASS_LOW type BAL_S_MSG-PROBCLASS value '4' ##NO_TEXT.
  constants C_PROBCLASS_MEDIUM type BAL_S_MSG-PROBCLASS value '3' ##NO_TEXT.
  constants C_PROBCLASS_NONE type BAL_S_MSG-PROBCLASS value SPACE ##NO_TEXT.
  constants C_PROBCLASS_VHIGH type BAL_S_MSG-PROBCLASS value '1' ##NO_TEXT.
  class-data DUMMY type STRING .

  events DISPLAY_PROFILE
    exporting
      value(R_DISP_PROF) type ref to BAL_S_PROF .

  class-methods GET_BAPIRET2_MSG_BAL
    importing
      !IS_RETURN type BAPIRET2
    returning
      value(RS_MSG) type BAL_S_MSG .
  class-methods GET_SYS_MSG_BAL
    returning
      value(RS_MSG) type BAL_S_MSG .
  methods ADD_BAL_MESSAGE
    importing
      value(IS_MSG) type BAL_S_MSG .
  methods ADD_BAPIRET2_MESSAGE
    importing
      !IT_BAPIRET2 type BAPIRET2_T .
  methods ADD_SINGLE_MESSAGE
    importing
      !IV_MSGTY type MSGTY default 'I'
      !IV_MSG type CLIKE .
  methods ADD_SYS_MESSAGE .
  methods CHANGE_HEADER
    importing
      !IV_CATEGORY type BALOBJ_D
      !IV_SUBCATEGORY type BALSUBOBJ
      !IV_KEEP_DAYS type I default 30
      !IV_EXTID type BAL_S_LOG-EXTNUMBER optional
    exceptions
      ERROR .
  methods CONSTRUCTOR
    importing
      !IV_CATEGORY type BALOBJ_D optional
      !IV_SUBCATEGORY type BALSUBOBJ optional
      !IV_KEEP_DAYS type I default 30
      !IV_EXTID type BAL_S_LOG-EXTNUMBER optional .
  methods DISPLAY
    importing
      !IV_POPUP type XFELD default SPACE
      !IV_USE_GRID type XFELD default ABAP_TRUE .
  methods GET_MESSAGES
    importing
      !IV_LANGU type SY-LANGU default SY-LANGU
    returning
      value(RT_MSG) type BAL_T_MSG .
  methods GET_SYS_MSG_BAPIRET2
    changing
      !CT_BAPIRET2 type BAPIRETTAB optional
      !CS_BAPIRET2 type BAPIRET2 optional .
  methods GET_TYPE_FROM_MESSAGE
    returning
      value(RV_MSGTY) type MSGTY .
  methods SET_CONTEXT
    importing
      !IV_CONTEXT type BAL_S_CONT .
PROTECTED SECTION.
*"* protected components of class /CTDI/APP_LOG
*"* do not include other source files here!!!

  ALIASES initialize
    FOR if_logger~initialize .
private section.
*"* private components of class /CTDI/APP_LOG
*"* do not include other source files here!!!

  aliases LOG_CATEGORY
    for IF_LOGGER~LOG_CATEGORY .
  aliases LOG_SUBCATEGORY
    for IF_LOGGER~LOG_SUBCATEGORY .

  data CURR_HANDLE type BALLOGHNDL .
  data CURR_HEADER type BAL_S_LOG .
  data S_CONTEXT type BAL_S_CONT .
  data T_HANDLES type BAL_T_LOGH .

  methods GET_CALLER
    returning
      value(RV_ALPROG) type BALPROG .
  methods PROBLEM_CLASS_GET
    importing
      !IV_MSGTY type SYMSGTY
      !IV_PROBCLASS type BALPROBCL
    returning
      value(RV_PROBCLASS) type BALPROBCL .
ENDCLASS.



CLASS /CTDI/APP_LOG IMPLEMENTATION.


method ADD_BAL_MESSAGE.
* Adds message given in BAL format to the log

* Define data of message for Application Log
  is_msg-probclass = me->problem_class_get( iv_msgty = is_msg-msgty
                                            iv_probclass = is_msg-probclass ).
* Add this message to log file
  CALL FUNCTION 'BAL_LOG_MSG_ADD'
    EXPORTING
      i_s_msg       = is_msg
      i_log_handle  = curr_handle
    EXCEPTIONS
      log_not_found = 0
      OTHERS        = 1.
  IF sy-subrc = 0.
* Ignore any exception.
    ADD 1 TO message_counter.
  ENDIF.

endmethod.


METHOD ADD_BAPIRET2_MESSAGE.
* Adds BAPIRET2 messages to the log

  DATA: ls_msg TYPE bal_s_msg.

  LOOP AT it_bapiret2 ASSIGNING FIELD-SYMBOL(<fs_bapiret2>).

    ls_msg = get_bapiret2_msg_bal( is_return = <fs_bapiret2> ).
    ls_msg-context = me->s_context.
    me->add_bal_message( is_msg = ls_msg ).

  ENDLOOP.

ENDMETHOD.


method ADD_SINGLE_MESSAGE.
* Add text message to log

  sy-msgty = iv_msgty.
  cl_message_helper=>set_msg_vars_for_clike( text = iv_msg ).
  add_sys_message( ).

endmethod.


METHOD ADD_SYS_MESSAGE.
* Adds a message from SYST to the log

  DATA: ls_msg TYPE bal_s_msg.

  ls_msg = get_sys_msg_bal( ).
  ls_msg-context = me->s_context.
  me->add_bal_message( is_msg = ls_msg ).

ENDMETHOD.


method CHANGE_HEADER.
* Change log header

  me->log_category = iv_category.
  me->log_subcategory = iv_subcategory.
  me->curr_header-object = iv_category.
  me->curr_header-subobject = iv_subcategory.
  me->curr_header-extnumber = iv_extid.
  " Delete logs after X days.
  me->curr_header-aldate_del = sy-datum + iv_keep_days.
  CALL FUNCTION 'BAL_LOG_HDR_CHANGE'
    EXPORTING
      i_log_handle            = me->curr_handle
      i_s_log                 = me->curr_header
    EXCEPTIONS
      log_not_found           = 1
      log_header_inconsistent = 2
      OTHERS                  = 3.
  IF sy-subrc <> 0.
    RAISE error.
  ENDIF.

endmethod.


METHOD CONSTRUCTOR.
* Initialize application log, set defaults

  me->log_category    = iv_category.
  me->log_subcategory = iv_subcategory.
  me->curr_header-object    = iv_category.
  me->curr_header-subobject = iv_subcategory.
  me->curr_header-extnumber = iv_extid.
  me->curr_header-aluser    = sy-uname.
  me->curr_header-altcode   = sy-tcode.
  me->curr_header-alprog    = me->get_caller( ).
  " Delete logs after X days.
  me->curr_header-aldate_del = sy-datum + iv_keep_days.

  " Create log
  me->if_sbal_logger~reset( ).

ENDMETHOD.


METHOD DISPLAY.
* Display application log (popup/fullscreen, alv/list)

  DATA: ls_prof    TYPE bal_s_prof,
        lr_prof    LIKE REF TO ls_prof,
        lt_handles TYPE bal_t_logh.

  IF iv_popup = abap_true.

    " Use popup display profile for log
    CALL FUNCTION 'BAL_DSP_PROFILE_POPUP_GET'
      EXPORTING
        start_col           = 5
        start_row           = 5
        end_col             = 120
        end_row             = 15
      IMPORTING
        e_s_display_profile = ls_prof.

  ELSE.

    " Use standard display profile for log
    CALL FUNCTION 'BAL_DSP_PROFILE_SINGLE_LOG_GET'
      IMPORTING
        e_s_display_profile = ls_prof.

  ENDIF.

  ls_prof-use_grid = iv_use_grid.
  " Classes which have registered themselves as receiver for this event can modify
  " the generated display profile to suit it to their requirements.
  GET REFERENCE OF ls_prof INTO lr_prof.
  RAISE EVENT display_profile EXPORTING r_disp_prof = lr_prof.
  lt_handles = me->get_log_handles( ).

  " Display log
  CALL FUNCTION 'BAL_DSP_LOG_DISPLAY'
    EXPORTING
      i_s_display_profile  = ls_prof
      i_t_log_handle       = lt_handles
    EXCEPTIONS
      profile_inconsistent = 1
      internal_error       = 2
      no_data_available    = 3
      no_authority         = 4
      OTHERS               = 5.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

ENDMETHOD.


METHOD GET_BAPIRET2_MSG_BAL.
* Get message from BAPIRET into BAL structure

  rs_msg-msgty = is_return-type.
  rs_msg-msgid = is_return-id.
  rs_msg-msgno = is_return-number.
  rs_msg-msgv1 = is_return-message_v1.
  rs_msg-msgv2 = is_return-message_v2.
  rs_msg-msgv3 = is_return-message_v3.
  rs_msg-msgv4 = is_return-message_v4.

ENDMETHOD.


METHOD GET_CALLER.
* Determine caller from callstack

  DATA: lt_callstack TYPE abap_callstack,
        ls_callstack LIKE LINE OF lt_callstack.

  " Determine caller
  CALL FUNCTION 'SYSTEM_CALLSTACK'
    EXPORTING
      max_level = 3
    IMPORTING
      callstack = lt_callstack.

  READ TABLE lt_callstack INDEX 3 INTO ls_callstack.
  rv_alprog = ls_callstack-mainprogram.

ENDMETHOD.


METHOD GET_MESSAGES.
* Return all stored Messages

  DATA: ls_msg_handle TYPE balmsghndl,
        ls_msg        TYPE bal_s_msg.

  CLEAR rt_msg.

  ls_msg_handle-log_handle = curr_handle.
  DO message_counter TIMES.
    ls_msg_handle-msgnumber = sy-index.
    CLEAR: ls_msg.
    CALL FUNCTION 'BAL_LOG_MSG_READ'
      EXPORTING
        i_s_msg_handle = ls_msg_handle
        i_langu        = iv_langu
      IMPORTING
        e_s_msg        = ls_msg
      EXCEPTIONS
        log_not_found  = 1
        msg_not_found  = 2
        OTHERS         = 3.
    IF sy-subrc IS INITIAL.
      INSERT ls_msg INTO TABLE rt_msg.
    ELSE.
      EXIT.
    ENDIF.
  ENDDO.

ENDMETHOD.


METHOD GET_SYS_MSG_BAL.
* Get message from SYST into BAL structure

  rs_msg-msgty = sy-msgty.
  rs_msg-msgid = sy-msgid.
  rs_msg-msgno = sy-msgno.
  rs_msg-msgv1 = sy-msgv1.
  rs_msg-msgv2 = sy-msgv2.
  rs_msg-msgv3 = sy-msgv3.
  rs_msg-msgv4 = sy-msgv4.

ENDMETHOD.


method GET_SYS_MSG_BAPIRET2.
* Add message from SYST structure into bapiret2 table/structure

  DATA: ls_bapiret2 LIKE LINE OF ct_bapiret2.

  CALL FUNCTION 'BALW_BAPIRETURN_GET2'
    EXPORTING
      type   = sy-msgty
      cl     = sy-msgid
      number = sy-msgno
      par1   = sy-msgv1
      par2   = sy-msgv2
      par3   = sy-msgv3
      par4   = sy-msgv4
    IMPORTING
      return = ls_bapiret2.
  IF cs_bapiret2 IS SUPPLIED.
    cs_bapiret2 = ls_bapiret2.
  ENDIF.
  IF ct_bapiret2 IS SUPPLIED.
    APPEND ls_bapiret2 TO ct_bapiret2.
  ENDIF.

endmethod.


METHOD GET_TYPE_FROM_MESSAGE.
* Get Message type from messages (1. "E", 2. "W", 3. "I")

* Deliver "highest" Message type.
* 1.) "E" if at least one "E" or "A" message exists
* 2.) "W" if at least one "W" exists
* 3.) "I" if at least one "I" or "S" message exists

  DATA: lt_msg TYPE bal_t_msg.

  FIELD-SYMBOLS: <ls_msg> TYPE bal_s_msg.

  lt_msg = get_messages( ).
  CLEAR: rv_msgty.
  LOOP AT lt_msg ASSIGNING <ls_msg>.
    CASE <ls_msg>-msgty.
      WHEN if_logger~c_message_success OR c_message_info.
        IF rv_msgty <> if_logger~c_message_warning.
          rv_msgty = me->c_message_info.
        ENDIF.
      WHEN if_logger~c_message_warning.
        rv_msgty = <ls_msg>-msgty.
      WHEN OTHERS.
        rv_msgty = if_logger~c_message_error.
        EXIT.
    ENDCASE.
  ENDLOOP.

ENDMETHOD.


METHOD IF_LOGGER~ADD_EXCEPTION.
* Add exception to the log

  CALL FUNCTION 'BAL_LOG_EXC_ADD'
    EXPORTING
      i_log_handle     = curr_handle
      i_msgty          = if_logger~c_message_error
      i_probclass      = i_probcl
      i_exception      = i_exception
    EXCEPTIONS
      log_not_found    = 1
      msg_inconsistent = 2
      log_is_full      = 3
      OTHERS           = 4.
  IF sy-subrc = 0.
* Ignore any exception.
    ADD 1 TO message_counter.
  ENDIF.

ENDMETHOD.


METHOD IF_LOGGER~ADD_MESSAGE.
* Add message to the log

  DATA: ls_msg TYPE bal_s_msg.

* Define data of message for Application Log
  ls_msg-msgty = i_msgty.
  ls_msg-msgid = i_msgid.
  ls_msg-msgno = i_msgno.
  ls_msg-msgv1 = i_msgv1.
  ls_msg-msgv2 = i_msgv2.
  ls_msg-msgv3 = i_msgv3.
  ls_msg-msgv4 = i_msgv4.
  ls_msg-probclass = me->problem_class_get(
                                    iv_msgty     = i_msgty
                                    iv_probclass = i_probcl  ).
  ls_msg-context = me->s_context.

* Add this message to log file
  CALL FUNCTION 'BAL_LOG_MSG_ADD'
    EXPORTING
      i_s_msg       = ls_msg
      i_log_handle  = curr_handle
    EXCEPTIONS
      log_not_found = 0
      OTHERS        = 1.
  IF sy-subrc = 0.
* Ignore any exception.
    ADD 1 TO message_counter.
  ENDIF.

ENDMETHOD.


METHOD IF_LOGGER~FINALIZE.
* Save log to DB and clear members

  IF message_counter > 0.
* Save logs to DB
    INSERT curr_handle INTO TABLE t_handles.

    CALL FUNCTION 'BAL_DB_SAVE'
      EXPORTING
        i_t_log_handle = t_handles
      EXCEPTIONS
        OTHERS         = 1.

    CLEAR me->message_counter.
    CLEAR me->t_handles.
    CLEAR me->curr_handle.
  ENDIF.

ENDMETHOD.


METHOD IF_LOGGER~INITIALIZE.
* Initializes members

  DATA: ls_handle LIKE LINE OF me->t_handles.

  LOOP AT me->t_handles INTO ls_handle.
    CALL FUNCTION 'BAL_LOG_REFRESH'
      EXPORTING
        i_log_handle  = ls_handle
      EXCEPTIONS
        log_not_found = 1
        OTHERS        = 2.
  ENDLOOP.

  CLEAR me->message_counter.
  CLEAR me->t_handles.
  CLEAR me->curr_handle.

ENDMETHOD.


method IF_SBAL_LOGGER~GET_LOG_HANDLES.
* Get log handles

  READ TABLE t_handles WITH TABLE KEY table_line = curr_handle
                       TRANSPORTING NO  FIELDS.

  IF sy-subrc NE 0 AND message_counter > 0.
    APPEND curr_handle TO t_handles.
  ENDIF.
  r_t_handles = t_handles.

endmethod.


METHOD IF_SBAL_LOGGER~RESET.
* Reset current application log

  me->initialize( ).
* Get the log handle.
  CALL FUNCTION 'BAL_LOG_CREATE'
    EXPORTING
      i_s_log                 = me->curr_header
    IMPORTING
      e_log_handle            = me->curr_handle
    EXCEPTIONS
      log_header_inconsistent = 1
      OTHERS                  = 2.

ENDMETHOD.


method PROBLEM_CLASS_GET.
* Derive problem class from message type

  IF iv_probclass NE if_logger~c_probclass_default AND iv_probclass IS NOT INITIAL.
    rv_probclass = iv_probclass.
  ELSE.
* Set problem class dependent of the message type
    CASE iv_msgty.
      WHEN if_logger~c_message_success OR me->c_message_info.
        rv_probclass = if_logger~c_probclass_low.
      WHEN if_logger~c_message_warning.
        rv_probclass = if_logger~c_probclass_medium.
      WHEN OTHERS.
        rv_probclass = if_logger~c_probclass_high.
    ENDCASE.
  ENDIF.

endmethod.


method SET_CONTEXT.
* Sets context structure for following messages

  me->s_context = iv_context.

endmethod.
ENDCLASS.
