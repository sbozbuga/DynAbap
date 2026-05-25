CLASS /ctdi/cx_form_error DEFINITION
  PUBLIC
  INHERITING FROM /ctdi/cx_print_error
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    DATA: subrc TYPE sysubrc.

    METHODS constructor
      IMPORTING
        !textid    LIKE textid OPTIONAL
        !previous  LIKE previous OPTIONAL
        !repair_id TYPE aufnr OPTIONAL
        !message   TYPE string OPTIONAL
        !subrc     TYPE sysubrc OPTIONAL.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /ctdi/cx_form_error IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    CALL METHOD super->constructor
      EXPORTING
        textid    = textid
        previous  = previous
        repair_id = repair_id
        message   = message.
    me->subrc = subrc.
  ENDMETHOD.
ENDCLASS.
