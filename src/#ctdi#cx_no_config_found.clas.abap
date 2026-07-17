CLASS /ctdi/cx_no_config_found DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    DATA message TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        !textid   LIKE textid OPTIONAL
        !previous LIKE previous OPTIONAL
        !message  TYPE string OPTIONAL.

    METHODS if_message~get_text REDEFINITION.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /CTDI/CX_NO_CONFIG_FOUND IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    CALL METHOD super->constructor
      EXPORTING
        textid   = textid
        previous = previous.
    me->message = message.
  ENDMETHOD.


  METHOD if_message~get_text.
    IF me->message IS NOT INITIAL.
      result = me->message.
    ELSE.
      result = super->if_message~get_text( ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
