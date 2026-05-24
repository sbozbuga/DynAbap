CLASS /ctdi/cx_print_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC .

  PUBLIC SECTION.
    DATA: repair_id TYPE vbeln_va,
          message   TYPE string.

    METHODS constructor
      IMPORTING
        !textid    LIKE textid OPTIONAL
        !previous  LIKE previous OPTIONAL
        !repair_id TYPE vbeln_va OPTIONAL
        !message   TYPE string OPTIONAL.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /ctdi/cx_print_error IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    CALL METHOD super->constructor
      EXPORTING
        textid   = textid
        previous = previous.
    me->repair_id = repair_id.
    me->message   = message.
  ENDMETHOD.
ENDCLASS.
