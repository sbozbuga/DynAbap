"! Runtime print execution exception.
"! Raised during print pipeline execution (factory, read_data, render_form).
"! For customizing/validation errors during SM30 maintenance, see /CTDI/CX_PRINT_ERROR.
CLASS /ctdi/cx_print_driver_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Attribute to identify the repair/document that caused the error
    DATA repair_id TYPE aufnr  READ-ONLY.
    " Human-readable error message
    DATA message   TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING textid    LIKE textid   OPTIONAL
                !previous LIKE previous OPTIONAL
                repair_id TYPE aufnr    OPTIONAL
                !message  TYPE string   OPTIONAL.

    METHODS if_message~get_text REDEFINITION.

  PROTECTED SECTION.

  PRIVATE SECTION.
ENDCLASS.


CLASS /ctdi/cx_print_driver_error IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( textid   = textid
                        previous = previous ).
    me->repair_id = repair_id.
    me->message   = message.
  ENDMETHOD.

  METHOD if_message~get_text.
    IF me->message IS NOT INITIAL.
      result = me->message.
    ELSE.
      result = super->if_message~get_text( ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

