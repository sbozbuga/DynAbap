*&---------------------------------------------------------------------*
*& Report /CTDI/COPY_FOREIGN_DDIC
*&---------------------------------------------------------------------*
REPORT /ctdi/copy_foreign_ddic.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-002.
  PARAMETERS: p_pack   TYPE devclass OBLIGATORY DEFAULT '/CTDI/WORKSHOP',
              p_prefix TYPE string OBLIGATORY DEFAULT 'Z_',
              p_excl_s TYPE abap_bool AS CHECKBOX DEFAULT 'X',
              p_run    TYPE abap_bool AS CHECKBOX DEFAULT ' ',
              p_act    TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b1.

*&---------------------------------------------------------------------*
*& Class lcl_cx_error
*&---------------------------------------------------------------------*
CLASS lcl_cx_error DEFINITION INHERITING FROM cx_static_check.
  PUBLIC SECTION.
    DATA: text TYPE string.
    METHODS: constructor IMPORTING iv_text TYPE string.
ENDCLASS.

CLASS lcl_cx_error IMPLEMENTATION.
  METHOD constructor.
    super->constructor( ).
    me->text = iv_text.
  ENDMETHOD.
ENDCLASS.

*&---------------------------------------------------------------------*
*& Class lcl_ddic_copier
*&---------------------------------------------------------------------*
CLASS lcl_ddic_copier DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_ddic_obj,
             type      TYPE trobjtype,
             name      TYPE ddobjname,
             package   TYPE devclass,
             copy      TYPE ddobjname,
             copied    TYPE abap_bool,
             activated TYPE abap_bool,
             message   TYPE string,
           END OF ty_ddic_obj.
    TYPES: tt_ddic_obj TYPE STANDARD TABLE OF ty_ddic_obj WITH DEFAULT KEY.

    METHODS:
      constructor
        IMPORTING
          iv_package TYPE devclass
          iv_prefix  TYPE string
          is_excl_s  TYPE abap_bool
          is_run     TYPE abap_bool
          is_act     TYPE abap_bool,
      run,
      display_results.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_field_info,
             rollname TYPE dd03l-rollname,
             domname  TYPE dd03l-domname,
           END OF ty_field_info.

    DATA: mv_package TYPE devclass,
          mv_prefix  TYPE string,
          mv_excl_s  TYPE abap_bool,
          mv_run     TYPE abap_bool,
          mv_act     TYPE abap_bool,
          mt_objects TYPE tt_ddic_obj.

    METHODS:
      collect_objects,
      resolve_dependencies,
      determine_copy_names,
      copy_objects,
      activate_objects,
      get_package
        IMPORTING
          iv_type           TYPE trobjtype
          iv_name           TYPE ddobjname
        RETURNING
          VALUE(rv_package) TYPE devclass,
      is_standard_package
        IMPORTING
          iv_package    TYPE devclass
          iv_name       TYPE ddobjname
        RETURNING
          VALUE(rv_std) TYPE abap_bool,
      add_object_to_list
        IMPORTING
          iv_type TYPE trobjtype
          iv_name TYPE ddobjname,
      get_object_type
        IMPORTING
          iv_name        TYPE ddobjname
        RETURNING
          VALUE(rv_type) TYPE trobjtype,
      copy_domain
        IMPORTING
          iv_old TYPE ddobjname
          iv_new TYPE ddobjname
        RAISING
          lcl_cx_error,
      copy_data_element
        IMPORTING
          iv_old TYPE ddobjname
          iv_new TYPE ddobjname
        RAISING
          lcl_cx_error,
      copy_structure
        IMPORTING
          iv_old TYPE ddobjname
          iv_new TYPE ddobjname
        RAISING
          lcl_cx_error,
      copy_table_type
        IMPORTING
          iv_old TYPE ddobjname
          iv_new TYPE ddobjname
        RAISING
          lcl_cx_error,
      update_tadir
        IMPORTING
          iv_type TYPE trobjtype
          iv_name TYPE ddobjname.
ENDCLASS.

CLASS lcl_ddic_copier IMPLEMENTATION.

  METHOD constructor.
    mv_package = iv_package.
    mv_prefix  = iv_prefix.
    mv_excl_s  = is_excl_s.
    mv_run     = is_run.
    mv_act     = is_act.
  ENDMETHOD.

  METHOD run.
    collect_objects( ).
    resolve_dependencies( ).
    determine_copy_names( ).
    IF mv_run = abap_true.
      copy_objects( ).
      IF mv_act = abap_true.
        activate_objects( ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD collect_objects.
    DATA: lt_env   TYPE TABLE OF senvi,
          ls_env   LIKE LINE OF lt_env,
          lt_funcs TYPE TABLE OF enlfdir-funcname,
          lv_func  TYPE enlfdir-funcname.

    " Query all objects in package from TADIR
    SELECT object, obj_name FROM tadir
      WHERE devclass = @mv_package
      INTO TABLE @DATA(lt_tadir).

    LOOP AT lt_tadir INTO DATA(ls_tadir).
      CASE ls_tadir-object.
        WHEN 'DOMA' OR 'DTEL' OR 'TABL' OR 'TTYP'.
          add_object_to_list( iv_type = ls_tadir-object iv_name = CONV #( ls_tadir-obj_name ) ).

        WHEN 'CLAS' OR 'INTF' OR 'PROG'.
          CLEAR lt_env.
          CALL FUNCTION 'REPOSITORY_ENVIRONMENT_SET'
            EXPORTING
              obj_type          = CONV euobj-id( ls_tadir-object )
              object_name       = ls_tadir-obj_name
            TABLES
              environment       = lt_env
            EXCEPTIONS
              OTHERS            = 1.
          IF sy-subrc = 0.
            LOOP AT lt_env INTO ls_env.
              DATA(lv_type) = VALUE trobjtype( ).
              CASE ls_env-type.
                WHEN 'STRU'. lv_type = 'TABL'.
                WHEN 'TTYP'. lv_type = 'TTYP'.
                WHEN 'DTEL'. lv_type = 'DTEL'.
                WHEN 'DOMA'. lv_type = 'DOMA'.
              ENDCASE.
              IF lv_type IS NOT INITIAL.
                add_object_to_list( iv_type = lv_type iv_name = CONV #( ls_env-object ) ).
              ENDIF.
            ENDLOOP.
          ENDIF.

        WHEN 'FUGR'.
          " Find function modules in group
          CLEAR lt_funcs.
          SELECT funcname FROM enlfdir
            WHERE area = @ls_tadir-obj_name
            INTO TABLE @lt_funcs.

          LOOP AT lt_funcs INTO lv_func.
            DATA: lt_env_f TYPE TABLE OF senvi.
            CALL FUNCTION 'REPOSITORY_ENVIRONMENT_SET'
              EXPORTING
                obj_type          = 'FUNC'
                object_name       = CONV sobj_name( lv_func )
              TABLES
                environment       = lt_env_f
              EXCEPTIONS
                OTHERS            = 1.
            IF sy-subrc = 0.
              LOOP AT lt_env_f INTO ls_env.
                DATA(lv_type_f) = VALUE trobjtype( ).
                CASE ls_env-type.
                  WHEN 'STRU'. lv_type_f = 'TABL'.
                  WHEN 'TTYP'. lv_type_f = 'TTYP'.
                  WHEN 'DTEL'. lv_type_f = 'DTEL'.
                  WHEN 'DOMA'. lv_type_f = 'DOMA'.
                ENDCASE.
                IF lv_type_f IS NOT INITIAL.
                  add_object_to_list( iv_type = lv_type_f iv_name = CONV #( ls_env-object ) ).
                ENDIF.
              ENDLOOP.
            ENDIF.
          ENDLOOP.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD resolve_dependencies.
    DATA: lv_index TYPE i VALUE 1.

    WHILE lv_index <= lines( mt_objects ).
      READ TABLE mt_objects ASSIGNING FIELD-SYMBOL(<ls_obj>) INDEX lv_index.
      IF <ls_obj> IS ASSIGNED.
        CASE <ls_obj>-type.
          WHEN 'TABL'.
            " Get fields
            SELECT rollname, domname FROM dd03l
              WHERE tabname = @<ls_obj>-name
                AND rollname IS NOT INITIAL
              INTO TABLE @DATA(lt_fields).

            LOOP AT lt_fields INTO DATA(ls_field).
              DATA(lv_ftype) = get_object_type( ls_field-rollname ).
              IF lv_ftype IS NOT INITIAL.
                add_object_to_list( iv_type = lv_ftype iv_name = ls_field-rollname ).
              ENDIF.
              IF ls_field-domname IS NOT INITIAL.
                add_object_to_list( iv_type = 'DOMA' iv_name = ls_field-domname ).
              ENDIF.
            ENDLOOP.

          WHEN 'TTYP'.
            SELECT SINGLE rowtype, rowkind FROM dd40l
              WHERE typename = @<ls_obj>-name
              INTO (@DATA(lv_rowtype), @DATA(lv_rowkind)).
            IF sy-subrc = 0 AND lv_rowtype IS NOT INITIAL.
              DATA(lv_rtype) = VALUE trobjtype( ).
              CASE lv_rowkind.
                WHEN 'S' OR 'T'. lv_rtype = 'TABL'.
                WHEN 'D'.        lv_rtype = 'DTEL'.
                WHEN OTHERS.     lv_rtype = get_object_type( lv_rowtype ).
              ENDCASE.
              IF lv_rtype IS NOT INITIAL.
                add_object_to_list( iv_type = lv_rtype iv_name = lv_rowtype ).
              ENDIF.
            ENDIF.

          WHEN 'DTEL'.
            SELECT SINGLE domname FROM dd04l
              WHERE rollname = @<ls_obj>-name
              INTO @DATA(lv_domname).
            IF sy-subrc = 0 AND lv_domname IS NOT INITIAL.
              add_object_to_list( iv_type = 'DOMA' iv_name = lv_domname ).
            ENDIF.
        ENDCASE.
      ENDIF.
      lv_index = lv_index + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD determine_copy_names.
    LOOP AT mt_objects ASSIGNING FIELD-SYMBOL(<ls_obj>).
      IF <ls_obj>-package <> mv_package AND
         ( mv_excl_s = abap_false OR is_standard_package( iv_package = <ls_obj>-package iv_name = <ls_obj>-name ) = abap_false ).

        DATA: lv_temp TYPE string.
        lv_temp = <ls_obj>-name.
        REPLACE ALL OCCURRENCES OF '/' IN lv_temp WITH '_'.
        IF lv_temp(1) = '_'.
          SHIFT lv_temp LEFT BY 1 PLACES.
        ENDIF.

        lv_temp = mv_prefix && lv_temp.
        IF strlen( lv_temp ) > 30.
          <ls_obj>-copy = lv_temp(30).
        ELSE.
          <ls_obj>-copy = lv_temp.
        ENDIF.
        TRANSLATE <ls_obj>-copy TO UPPER CASE.
      ELSE.
        <ls_obj>-copy = <ls_obj>-name.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD copy_objects.
    LOOP AT mt_objects ASSIGNING FIELD-SYMBOL(<ls_obj>).
      IF <ls_obj>-package <> mv_package AND <ls_obj>-copy <> <ls_obj>-name.
        TRY.
            CASE <ls_obj>-type.
              WHEN 'DOMA'.
                copy_domain( iv_old = <ls_obj>-name iv_new = <ls_obj>-copy ).
              WHEN 'DTEL'.
                copy_data_element( iv_old = <ls_obj>-name iv_new = <ls_obj>-copy ).
              WHEN 'TABL'.
                copy_structure( iv_old = <ls_obj>-name iv_new = <ls_obj>-copy ).
              WHEN 'TTYP'.
                copy_table_type( iv_old = <ls_obj>-name iv_new = <ls_obj>-copy ).
            ENDCASE.
            <ls_obj>-copied = abap_true.
          CATCH lcl_cx_error INTO DATA(lo_err).
            <ls_obj>-copied = abap_false.
            <ls_obj>-message = lo_err->text.
        ENDTRY.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD activate_objects.
    DATA: lt_gentab TYPE TABLE OF dcgentb,
          ls_gentab LIKE LINE OF lt_gentab,
          lt_deltab TYPE TABLE OF dcdeltb.

    LOOP AT mt_objects INTO DATA(ls_obj).
      IF ls_obj-copied = abap_true AND ls_obj-copy <> ls_obj-name.
        CLEAR ls_gentab.
        ls_gentab-pgmid = 'R3TR'.
        ls_gentab-type  = ls_obj-type.
        ls_gentab-name  = ls_obj-copy.
        APPEND ls_gentab TO lt_gentab.
      ENDIF.
    ENDLOOP.

    IF lt_gentab IS INITIAL.
      RETURN.
    ENDIF.

    DATA: lv_act_rc TYPE sy-subrc.

    CALL FUNCTION 'DD_MASS_ACT'
      EXPORTING
        ddmode   = 'O'
        version  = 'M'
        inactive = 'X'
        frcact   = ' '
        delall   = ' '
        delnoref = ' '
        device   = 'T'
        medium   = 'T'
        logname  = 'ZCOPY_MASS_ACT'
      IMPORTING
        act_rc   = lv_act_rc
      TABLES
        gentab   = lt_gentab
        deltab   = lt_deltab
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc <> 0.
      " Log or ignore
    ENDIF.

    LOOP AT mt_objects ASSIGNING FIELD-SYMBOL(<ls_obj>).
      IF <ls_obj>-copied = abap_true AND <ls_obj>-copy <> <ls_obj>-name.
        READ TABLE lt_gentab INTO DATA(ls_gen) WITH KEY name = <ls_obj>-copy type = <ls_obj>-type.
        IF sy-subrc = 0.
          IF ls_gen-rc = 0.
            <ls_obj>-activated = abap_true.
          ELSE.
            <ls_obj>-activated = abap_false.
            <ls_obj>-message = |Activation failed (RC={ ls_gen-rc })|.
          ENDIF.
        ELSE.
          <ls_obj>-activated = abap_false.
          <ls_obj>-message = 'Not found in activation list'.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_package.
    SELECT SINGLE devclass FROM tadir
      WHERE pgmid = 'R3TR'
        AND object = @iv_type
        AND obj_name = @iv_name
      INTO @rv_package.
    IF sy-subrc <> 0.
      rv_package = 'SYSTEM'.
    ENDIF.
  ENDMETHOD.

  METHOD is_standard_package.
    rv_std = abap_false.
    IF iv_package IS INITIAL OR iv_package = 'SYSTEM'.
      rv_std = abap_true.
      RETURN.
    ENDIF.

    IF iv_package(1) = 'S' OR iv_package(1) = 'L' OR iv_package(1) = 'U' OR
       iv_package(1) = 'I' OR iv_package(1) = 'Q' OR iv_package(1) = 'K' OR
       iv_package(1) = 'M' OR iv_package(1) = 'E' OR iv_package(1) = 'Y' OR
       iv_package(1) = 'W' OR iv_package(1) = 'H' OR iv_package(1) = 'C' OR
       iv_package(1) = 'A' OR iv_package(1) = 'B' OR iv_package(1) = 'D'.
      rv_std = abap_true.
    ENDIF.

    IF iv_name CP '/SAP/*'.
      rv_std = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD add_object_to_list.
    READ TABLE mt_objects TRANSPORTING NO FIELDS WITH KEY type = iv_type name = iv_name.
    IF sy-subrc <> 0.
      DATA: ls_obj TYPE ty_ddic_obj.
      ls_obj-type = iv_type.
      ls_obj-name = iv_name.
      ls_obj-package = get_package( iv_type = iv_type iv_name = iv_name ).
      APPEND ls_obj TO mt_objects.
    ENDIF.
  ENDMETHOD.

  METHOD get_object_type.
    SELECT SINGLE rollname FROM dd04l WHERE rollname = @iv_name INTO @DATA(lv_dtel).
    IF sy-subrc = 0.
      rv_type = 'DTEL'.
      RETURN.
    ENDIF.

    SELECT SINGLE tabname FROM dd02l WHERE tabname = @iv_name INTO @DATA(lv_tabl).
    IF sy-subrc = 0.
      rv_type = 'TABL'.
      RETURN.
    ENDIF.

    SELECT SINGLE typename FROM dd40l WHERE typename = @iv_name INTO @DATA(lv_ttyp).
    IF sy-subrc = 0.
      rv_type = 'TTYP'.
      RETURN.
    ENDIF.
  ENDMETHOD.

  METHOD copy_domain.
    DATA: ls_dd01v TYPE dd01v,
          lt_dd07v TYPE TABLE OF dd07v.

    CALL FUNCTION 'DDIF_DOMA_GET'
      EXPORTING
        name      = iv_old
        langu     = sy-langu
      IMPORTING
        dd01v_wa  = ls_dd01v
      TABLES
        dd07v_tab = lt_dd07v
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcl_cx_error EXPORTING iv_text = |Failed to get domain { iv_old }|.
    ENDIF.

    ls_dd01v-domname = iv_new.
    LOOP AT lt_dd07v ASSIGNING FIELD-SYMBOL(<ls_dd07v>).
      <ls_dd07v>-domname = iv_new.
    ENDLOOP.

    CALL FUNCTION 'DDIF_DOMA_PUT'
      EXPORTING
        name      = iv_new
        dd01v_wa  = ls_dd01v
      TABLES
        dd07v_tab = lt_dd07v
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcl_cx_error EXPORTING iv_text = |Failed to put domain { iv_new }|.
    ENDIF.

    update_tadir( iv_type = 'DOMA' iv_name = iv_new ).
  ENDMETHOD.

  METHOD copy_data_element.
    DATA: ls_dd04v TYPE dd04v.

    CALL FUNCTION 'DDIF_DTEL_GET'
      EXPORTING
        name     = iv_old
        langu    = sy-langu
      IMPORTING
        dd04v_wa = ls_dd04v
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcl_cx_error EXPORTING iv_text = |Failed to get data element { iv_old }|.
    ENDIF.

    ls_dd04v-rollname = iv_new.

    IF ls_dd04v-domname IS NOT INITIAL.
      READ TABLE mt_objects INTO DATA(ls_dom) WITH KEY type = 'DOMA' name = ls_dd04v-domname.
      IF sy-subrc = 0 AND ls_dom-copy <> ls_dom-name.
        ls_dd04v-domname = ls_dom-copy.
      ENDIF.
    ENDIF.

    CALL FUNCTION 'DDIF_DTEL_PUT'
      EXPORTING
        name     = iv_new
        dd04v_wa = ls_dd04v
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcl_cx_error EXPORTING iv_text = |Failed to put data element { iv_new }|.
    ENDIF.

    update_tadir( iv_type = 'DTEL' iv_name = iv_new ).
  ENDMETHOD.

  METHOD copy_structure.
    DATA: ls_dd02v TYPE dd02v,
          ls_dd09v TYPE dd09v,
          lt_dd03p TYPE TABLE OF dd03p,
          lt_dd05m TYPE TABLE OF dd05m,
          lt_dd08v TYPE TABLE OF dd08v,
          lt_dd35v TYPE TABLE OF dd35v,
          lt_dd36m TYPE TABLE OF dd36m.

    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name      = iv_old
        langu     = sy-langu
      IMPORTING
        dd02v_wa  = ls_dd02v
        dd09l_wa  = ls_dd09v
      TABLES
        dd03p_tab = lt_dd03p
        dd05m_tab = lt_dd05m
        dd08v_tab = lt_dd08v
        dd35v_tab = lt_dd35v
        dd36m_tab = lt_dd36m
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcl_cx_error EXPORTING iv_text = |Failed to get structure/table { iv_old }|.
    ENDIF.

    ls_dd02v-tabname = iv_new.
    IF ls_dd09v-tabname IS NOT INITIAL.
      ls_dd09v-tabname = iv_new.
    ENDIF.

    LOOP AT lt_dd03p ASSIGNING FIELD-SYMBOL(<ls_dd03p>).
      <ls_dd03p>-tabname = iv_new.

      IF <ls_dd03p>-rollname IS NOT INITIAL.
        READ TABLE mt_objects INTO DATA(ls_ref) WITH KEY name = <ls_dd03p>-rollname.
        IF sy-subrc = 0 AND ls_ref-copy <> ls_ref-name.
          <ls_dd03p>-rollname = ls_ref-copy.
        ENDIF.
      ENDIF.

      IF <ls_dd03p>-domname IS NOT INITIAL.
        READ TABLE mt_objects INTO DATA(ls_dom) WITH KEY type = 'DOMA' name = <ls_dd03p>-domname.
        IF sy-subrc = 0 AND ls_dom-copy <> ls_dom-name.
          <ls_dd03p>-domname = ls_dom-copy.
        ENDIF.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_dd05m ASSIGNING FIELD-SYMBOL(<ls_dd05m>).
      <ls_dd05m>-tabname = iv_new.
    ENDLOOP.

    LOOP AT lt_dd08v ASSIGNING FIELD-SYMBOL(<ls_dd08v>).
      <ls_dd08v>-tabname = iv_new.
    ENDLOOP.

    CALL FUNCTION 'DDIF_TABL_PUT'
      EXPORTING
        name      = iv_new
        dd02v_wa  = ls_dd02v
        dd09l_wa  = ls_dd09v
      TABLES
        dd03p_tab = lt_dd03p
        dd05m_tab = lt_dd05m
        dd08v_tab = lt_dd08v
        dd35v_tab = lt_dd35v
        dd36m_tab = lt_dd36m
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcl_cx_error EXPORTING iv_text = |Failed to put structure/table { iv_new }|.
    ENDIF.

    update_tadir( iv_type = 'TABL' iv_name = iv_new ).
  ENDMETHOD.

  METHOD copy_table_type.
    DATA: ls_dd40v TYPE dd40v.

    CALL FUNCTION 'DDIF_TTYP_GET'
      EXPORTING
        name     = iv_old
        langu    = sy-langu
      IMPORTING
        dd40v_wa = ls_dd40v
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcl_cx_error EXPORTING iv_text = |Failed to get table type { iv_old }|.
    ENDIF.

    ls_dd40v-typename = iv_new.

    IF ls_dd40v-rowtype IS NOT INITIAL.
      READ TABLE mt_objects INTO DATA(ls_row) WITH KEY name = ls_dd40v-rowtype.
      IF sy-subrc = 0 AND ls_row-copy <> ls_row-name.
        ls_dd40v-rowtype = ls_row-copy.
      ENDIF.
    ENDIF.

    CALL FUNCTION 'DDIF_TTYP_PUT'
      EXPORTING
        name     = iv_new
        dd40v_wa = ls_dd40v
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcl_cx_error EXPORTING iv_text = |Failed to put table type { iv_new }|.
    ENDIF.

    update_tadir( iv_type = 'TTYP' iv_name = iv_new ).
  ENDMETHOD.

  METHOD update_tadir.
    CALL FUNCTION 'TR_TADIR_INTERFACE'
      EXPORTING
        wi_tadir_pgmid    = 'R3TR'
        wi_tadir_object   = iv_type
        wi_tadir_obj_name = iv_name
        wi_tadir_devclass = '$TMP'
      EXCEPTIONS
        OTHERS            = 1.
    IF sy-subrc <> 0.
      " Ignore or log
    ENDIF.
  ENDMETHOD.

  METHOD display_results.
    IF mt_objects IS INITIAL.
      WRITE: / 'No objects found matching target criteria.'.
      RETURN.
    ENDIF.

    WRITE: / 'Analysis for Package:', mv_package.
    ULINE.
    WRITE: /(6) 'Type', (32) 'Original Name', (16) 'Original Package', (32) 'Copy Name ($TMP)', (50) 'Status / Message'.
    ULINE.

    LOOP AT mt_objects INTO DATA(ls_obj).
      IF ls_obj-package = mv_package.
        CONTINUE.
      ENDIF.

      DATA: lv_status TYPE string.
      IF ls_obj-copy = ls_obj-name.
        lv_status = 'Excluded (No Copy)'.
      ELSE.
        IF mv_run = abap_true.
          DATA(lv_cop) = COND string( WHEN ls_obj-copied = abap_true THEN 'Copied' ELSE 'Failed' ).
          DATA(lv_act) = COND string( WHEN ls_obj-activated = abap_true THEN 'Active' ELSE 'Inactive' ).
          lv_status = |{ lv_cop } / { lv_act }|.
          IF ls_obj-message IS NOT INITIAL.
            lv_status = |{ lv_status } - { ls_obj-message }|.
          ENDIF.
        ELSE.
          lv_status = 'Dry Run (Pending Copy)'.
        ENDIF.
      ENDIF.

      WRITE: /(6) ls_obj-type, (32) ls_obj-name, (16) ls_obj-package, (32) ls_obj-copy, (50) lv_status.
    ENDLOOP.
    ULINE.
  ENDMETHOD.

ENDCLASS.

START-OF-SELECTION.
  DATA(lo_copier) = NEW lcl_ddic_copier(
    iv_package = p_pack
    iv_prefix  = p_prefix
    is_excl_s  = p_excl_s
    is_run     = p_run
    is_act     = p_act
  ).

  lo_copier->run( ).
  lo_copier->display_results( ).
