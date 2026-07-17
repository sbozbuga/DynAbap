"! Customizing validation exception.
"! Raised during SM30 maintenance of /CTDI/REP_FORMS when form or class validation fails.
"! NOT used during print execution — use /CTDI/CX_PRINT_DRIVER_ERROR for runtime errors.
CLASS /ctdi/cx_cust_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC .

  PUBLIC SECTION.
    DATA: contract_id TYPE vbeln_va READ-ONLY,
          message     TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        !textid      LIKE textid OPTIONAL
        !previous    LIKE previous OPTIONAL
        !contract_id TYPE vbeln_va OPTIONAL
        !message     TYPE string OPTIONAL.

    METHODS if_message~get_text REDEFINITION.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /ctdi/cx_cust_error IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    CALL METHOD super->constructor
      EXPORTING
        textid   = textid
        previous = previous.
    me->contract_id = contract_id.
    me->message     = message.
  ENDMETHOD.

  METHOD if_message~get_text.
    IF me->message IS NOT INITIAL.
      result = me->message.
    ELSE.
      result = super->if_message~get_text( ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
