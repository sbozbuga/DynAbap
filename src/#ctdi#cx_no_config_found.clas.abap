CLASS /ctdi/cx_no_config_found DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    DATA repair_id TYPE aufnr READ-ONLY.
    DATA message   TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        !textid    LIKE textid OPTIONAL
        !previous  LIKE previous OPTIONAL
        !repair_id TYPE aufnr OPTIONAL
        !message   TYPE string OPTIONAL.

    METHODS get_text REDEFINITION.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /ctdi/cx_no_config_found IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    CALL METHOD super->constructor
      EXPORTING
        textid   = textid
        previous = previous.
    me->repair_id = repair_id.
    me->message   = message.
  ENDMETHOD.

  METHOD get_text.
    IF me->message IS NOT INITIAL.
      result = me->message.
    ELSE.
      result = super->get_text( ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
