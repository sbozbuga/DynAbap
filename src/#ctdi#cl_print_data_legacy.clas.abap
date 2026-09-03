CLASS /ctdi/cl_print_data_legacy DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    DATA ms_legacy        TYPE /cellag/alcarep READ-ONLY.
    DATA mt_legacy_error  TYPE STANDARD TABLE OF /cellag/alcarep_error READ-ONLY.
    DATA mt_comment_lines TYPE STANDARD TABLE OF tline READ-ONLY.

    "! Reads the required data for the Alcatel repair process.
    "!
    "! @parameter iv_aufnr |
    "! @parameter iv_sernr |
    "! @raising /ctdi/cx_print_driver_error |
    METHODS read_data
      IMPORTING iv_aufnr TYPE aufk-aufnr
                iv_sernr TYPE equi-sernr OPTIONAL
      RAISING   /ctdi/cx_print_driver_error.

  PROTECTED SECTION.
    DATA mv_aufnr     TYPE aufk-aufnr.
    DATA mv_qmcod     TYPE qmel-qmcod.
    DATA mv_kdauf     TYPE aufk-kdauf.
    DATA mv_swap_flag TYPE flag.

    METHODS get_repair_result.

  PRIVATE SECTION.
    CONSTANTS co_qmart     TYPE qmart   VALUE 'Z2'.
    CONSTANTS co_wfer_stat TYPE j_estat VALUE 'E0001'.
    CONSTANTS co_zx_qmart  TYPE qmart   VALUE 'ZX'.

    DATA mv_sernr         TYPE equi-sernr.

    DATA mv_po_nr         TYPE vbkd-bstkd_e.
    DATA mv_po_pos        TYPE vbkd-posex_e.
    DATA mv_ctdi_odernr   TYPE c LENGTH 20.
    DATA mv_qmnum         TYPE qmel-qmnum.
    DATA mv_fenum         TYPE qmfe-fenum.
    DATA mv_time_received TYPE tims.
    DATA mv_time_repaired TYPE tims.
    DATA mv_time_thisdate TYPE tims.
    DATA mv_spras         TYPE sy-langu.
    DATA mv_retlief_nr    TYPE vbeln_vl.
    DATA mv_equnr_retlief TYPE equnr.

    DATA mv_old_serial    TYPE serge.
    DATA mv_new_serial    TYPE serge.
    DATA mv_old_part      TYPE mapar.
    DATA mv_new_part      TYPE mapar.
    DATA mv_old_matnr     TYPE matnr.
    DATA mv_new_matnr     TYPE matnr.

    METHODS get_kddata
      RAISING /ctdi/cx_print_driver_error.

    METHODS get_part_data
      RAISING /ctdi/cx_print_driver_error.

    METHODS resolve_equipment_number
      RETURNING VALUE(rv_equnr) TYPE equnr
      RAISING   /ctdi/cx_print_driver_error.

    METHODS determine_serial_and_part
      IMPORTING iv_equnr TYPE equnr.

    METHODS determine_swap_data
      IMPORTING iv_equnr TYPE equnr.

    METHODS determine_change_doc_data
      IMPORTING iv_equnr TYPE equnr.

    METHODS fallback_part_numbers
      IMPORTING iv_equnr TYPE equnr.

    METHODS get_equipment_model
      IMPORTING iv_equnr TYPE equnr.

    METHODS get_equipment_stands.

    METHODS get_error_description.
    METHODS get_comment.
    METHODS check_sernr_swap.

    METHODS get_astatus_data
      IMPORTING iv_objnr     TYPE j_objnr
      EXPORTING ev_wfer_date TYPE dats
                ev_wfer_time TYPE tims
      RAISING   /ctdi/cx_print_driver_error.

    METHODS get_rlf_wedate
      IMPORTING iv_vbeln_vl TYPE vbeln_vl
      EXPORTING ev_vl_erdat TYPE likp-erdat
                ev_vl_zeit  TYPE likp-erzet.

    METHODS convert_to_timestamp
      IMPORTING iv_date          TYPE dats
                iv_time          TYPE tims
      RETURNING VALUE(rv_tstamp) TYPE timestamp.

ENDCLASS.


CLASS /ctdi/cl_print_data_legacy IMPLEMENTATION.
  METHOD check_sernr_swap.
    DATA lf_rmanr     TYPE vbap-vbeln.
    DATA lf_posnv_rma TYPE posnr.
    DATA lf_posnr_rma TYPE posnr.
    DATA lt_order_sn  TYPE /cellag/cs_order_sn_t.
    DATA ls_order_sn  TYPE /cellag/cs_order_sn.
    DATA lt_snx_tab   TYPE /cellag/csauf_snx_t.
    DATA ls_snx_tab   TYPE /cellag/csauf_snx.

    CLEAR: mv_swap_flag,
           mv_retlief_nr,
           mv_equnr_retlief.

    SELECT SINGLE rmanr, posnv_rma, posnr_rma
      FROM afko
      WHERE aufnr = @mv_aufnr
      INTO ( @lf_rmanr, @lf_posnv_rma, @lf_posnr_rma ).

    CALL FUNCTION '/CELLAG/SDPOS_RALMENGE_GET'
      EXPORTING
        i_vbeln     = lf_rmanr
        i_posnr     = lf_posnv_rma
      TABLES
        et_order_sn = lt_order_sn
      EXCEPTIONS
        OTHERS      = 1. "#EC CI_SUBRC

    READ TABLE lt_order_sn INTO ls_order_sn
         WITH KEY aufnr     = mv_aufnr
                  rmanr     = lf_rmanr
                  posnr_rma = lf_posnr_rma.
    IF sy-subrc = 0.
      mv_retlief_nr = ls_order_sn-vbeln_vl.
      lt_snx_tab = ls_order_sn-snx_tab.

      " send lines with empty ral_equnr to the end of the list
      SORT lt_snx_tab BY ral_equnr DESCENDING.

      READ TABLE lt_snx_tab INTO ls_snx_tab INDEX 1.
      IF sy-subrc = 0.
        mv_equnr_retlief = ls_snx_tab-ral_equnr.
        mv_swap_flag     = ls_snx_tab-tausch.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD convert_to_timestamp.
    CONVERT DATE iv_date TIME iv_time
            INTO TIME STAMP rv_tstamp TIME ZONE sy-zonlo.
  ENDMETHOD.

  METHOD determine_change_doc_data.
    " Consolidate sequential equi and equz queries into a single JOIN
    " Pre-fetch current values as defaults
    SELECT SINGLE q~serge,
                  q~matnr,
                  z~mapar
      FROM equi AS q
             LEFT OUTER JOIN
               equz AS z ON z~equnr = q~equnr
      WHERE q~equnr = @iv_equnr
      INTO ( @mv_new_serial, @mv_new_matnr, @mv_new_part ).

    mv_old_serial = mv_new_serial.
    mv_old_part   = mv_new_part.
    mv_old_matnr  = mv_new_matnr.

    " Determine timestamp window
    DATA(lv_ts_received) = convert_to_timestamp( iv_date = ms_legacy-date_received
                                                 iv_time = mv_time_received ).
    DATA(lv_ts_repaired) = convert_to_timestamp( iv_date = ms_legacy-date_repaired
                                                 iv_time = mv_time_repaired ).

    SELECT changenr, udate, utime FROM cdhdr
      WHERE objectclas = 'EQUI' AND objectid = @iv_equnr
      INTO TABLE @DATA(lt_cdhdr).
    IF lt_cdhdr IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lr_changenr) = VALUE rseloption( FOR <fs_hdr> IN lt_cdhdr
                                          ( sign = 'I' option = 'EQ' low = <fs_hdr>-changenr ) ).

    " Optimization: Push SERGE and MAPAR filters down to the DB to prevent fetching excessive change records
    SELECT changenr, tabname, fname, value_old, value_new
      FROM cdpos
      WHERE objectclas  = 'EQUI'
        AND objectid    = @iv_equnr
        AND changenr   IN @lr_changenr
        AND ( ( tabname = 'EQUI' AND fname = 'SERGE' ) OR
              ( tabname = 'EQUZ' AND fname = 'MAPAR' ) )
      INTO TABLE @DATA(lt_cdpos).
    IF lt_cdpos IS INITIAL.
      RETURN.
    ENDIF.

    SORT lt_cdhdr BY udate DESCENDING
                     utime DESCENDING.
    SORT lt_cdpos BY changenr
                     tabname
                     fname.

    DATA lv_serge_found TYPE abap_bool.
    DATA lv_mapar_found TYPE abap_bool.

    LOOP AT lt_cdhdr ASSIGNING FIELD-SYMBOL(<ls_hdr>).
      IF lv_serge_found = abap_true AND lv_mapar_found = abap_true.
        EXIT.
      ENDIF.

      DATA(lv_ts_changed) = convert_to_timestamp( iv_date = <ls_hdr>-udate
                                                  iv_time = <ls_hdr>-utime ).

      IF lv_ts_changed < lv_ts_received OR lv_ts_changed > lv_ts_repaired.
        CONTINUE.
      ENDIF.

      IF lv_serge_found = abap_false.
        READ TABLE lt_cdpos ASSIGNING FIELD-SYMBOL(<ls_pos>)
             WITH KEY changenr = <ls_hdr>-changenr
                      tabname  = 'EQUI'
                      fname    = 'SERGE' BINARY SEARCH.
        IF sy-subrc = 0.
          mv_old_serial  = <ls_pos>-value_old.
          mv_new_serial  = <ls_pos>-value_new.
          lv_serge_found = abap_true.
        ENDIF.
      ENDIF.

      IF lv_mapar_found = abap_false.
        READ TABLE lt_cdpos ASSIGNING <ls_pos>
             WITH KEY changenr = <ls_hdr>-changenr
                      tabname  = 'EQUZ'
                      fname    = 'MAPAR' BINARY SEARCH.
        IF sy-subrc = 0.
          mv_old_part    = <ls_pos>-value_old.
          mv_new_part    = <ls_pos>-value_new.
          lv_mapar_found = abap_true.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD determine_serial_and_part.
    CLEAR: mv_old_serial,
           mv_new_serial,
           mv_old_part,
           mv_new_part,
           mv_old_matnr,
           mv_new_matnr.

    IF mv_swap_flag IS NOT INITIAL.
      determine_swap_data( iv_equnr ).
    ELSE.
      determine_change_doc_data( iv_equnr ).
    ENDIF.
  ENDMETHOD.

  METHOD determine_swap_data.
    " Optimization: Consolidate sequential equi and equz queries into a single JOIN
    SELECT SINGLE q~serge,
                  q~matnr,
                  z~mapar
      FROM equi AS q
             LEFT OUTER JOIN
               equz AS z ON z~equnr = q~equnr
      WHERE q~equnr = @iv_equnr
      INTO ( @mv_new_serial, @mv_new_matnr, @mv_new_part ).

    SELECT SINGLE q~serge,
                  q~matnr,
                  z~mapar
      FROM equi AS q
             LEFT OUTER JOIN
               equz AS z ON z~equnr = q~equnr
      WHERE q~equnr = @mv_equnr_retlief
      INTO ( @mv_old_serial, @mv_old_matnr, @mv_old_part ).
  ENDMETHOD.

  METHOD fallback_part_numbers.
    IF mv_new_part IS INITIAL.
      IF mv_new_matnr IS INITIAL.
        " Consolidated sequential equi and mara lookups into a single JOIN
        SELECT SINGLE e~matnr,
                      m~mfrpn
          FROM equi AS e
                 LEFT OUTER JOIN
                   mara AS m ON m~matnr = e~matnr
          WHERE e~equnr = @iv_equnr
          INTO ( @mv_new_matnr, @mv_new_part ).
      ELSEIF mv_new_matnr IS NOT INITIAL.
        SELECT SINGLE mfrpn FROM mara WHERE matnr = @mv_new_matnr INTO @mv_new_part.
      ENDIF.
    ENDIF.

    IF mv_old_part IS INITIAL.
      IF mv_old_matnr IS INITIAL.
        " Consolidated sequential equi and mara lookups into a single JOIN
        SELECT SINGLE e~matnr,
                      m~mfrpn
          FROM equi AS e
                 LEFT OUTER JOIN
                   mara AS m ON m~matnr = e~matnr
          WHERE e~equnr = @mv_equnr_retlief
          INTO ( @mv_old_matnr, @mv_old_part ).
      ELSEIF mv_old_matnr IS NOT INITIAL.
        SELECT SINGLE mfrpn FROM mara WHERE matnr = @mv_old_matnr INTO @mv_old_part.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD get_astatus_data.
    DATA lt_jcds TYPE TABLE OF jcds.

    SELECT objnr, stat, chgnr, udate, utime, inact
      FROM jcds
      WHERE objnr = @iv_objnr
        AND stat  = @co_wfer_stat
      ORDER BY udate DESCENDING,
               utime DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @lt_jcds
      UP TO 1 ROWS.

    IF lt_jcds IS NOT INITIAL.
      READ TABLE lt_jcds ASSIGNING FIELD-SYMBOL(<ls_jcds>) INDEX 1.
      IF <ls_jcds> IS ASSIGNED.
        IF <ls_jcds>-inact IS NOT INITIAL.
          MESSAGE e029(/cellag/cs01) WITH mv_aufnr INTO DATA(lv_msg1).
          RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
            EXPORTING
              repair_id = mv_aufnr
              message   = lv_msg1.
        ENDIF.
        ev_wfer_date = <ls_jcds>-udate.
        ev_wfer_time = <ls_jcds>-utime.
      ENDIF.
    ELSE.
      MESSAGE e028(/cellag/cs01) WITH mv_aufnr INTO DATA(lv_msg2).
      RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
        EXPORTING
          repair_id = mv_aufnr
          message   = lv_msg2.
    ENDIF.
  ENDMETHOD.

  METHOD get_comment.
    DATA lt_lines      TYPE TABLE OF tline.
    DATA lf_qmnum_conv TYPE qmel-qmnum.
    DATA lf_name       TYPE thead-tdname.
    DATA lf_spras      TYPE sy-langu.

    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = mv_qmnum
      IMPORTING
        output = lf_qmnum_conv.

    lf_name = lf_qmnum_conv.

    SELECT SINGLE tdspras FROM stxh
      WHERE tdobject = 'QMEL'
        AND tdname   = @lf_name
        AND tdid     = 'LTXT'
      INTO @lf_spras.
    IF sy-subrc <> 0.
      lf_spras = mv_spras.
    ENDIF.

    CLEAR lt_lines.
    CALL FUNCTION 'READ_TEXT'
      EXPORTING
        id       = 'LTXT'
        language = lf_spras
        name     = lf_name
        object   = 'QMEL'
      TABLES
        lines    = lt_lines
      EXCEPTIONS
        OTHERS   = 8. "#EC CI_SUBRC

    mt_comment_lines = lt_lines.

    " Remove empty lines
    DELETE mt_comment_lines WHERE tdline IS INITIAL OR tdline CO ' '.
  ENDMETHOD.

  METHOD get_equipment_model.
    SELECT SINGLE eqktx FROM eqkt
      WHERE equnr = @iv_equnr AND spras = @mv_spras
      INTO @ms_legacy-model.
  ENDMETHOD.

  METHOD get_equipment_stands.
    " Consolidated sequential afih and objk lookups into a single DB hit
    SELECT SINGLE a~qmnum,
                  a~obknr,
                  o~ihnum
      FROM afih AS a
             LEFT OUTER JOIN
               objk AS o ON o~obknr = a~obknr AND o~ihnum <> @space
      WHERE a~aufnr = @mv_aufnr
      INTO @DATA(ls_afih).

    DATA(lv_qmnum) = COND qmel-qmnum(
      WHEN ls_afih-qmnum IS NOT INITIAL
      THEN ls_afih-qmnum
      ELSE ls_afih-ihnum ).

    IF lv_qmnum IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM qmel WHERE qmnum = @lv_qmnum INTO @DATA(ls_qmel). "#EC CI_ALL_FIELDS_NEEDED

    IF ls_qmel IS INITIAL.
      RETURN.
    ENDIF.

    ms_legacy-rev_in  = ls_qmel-revin.
    ms_legacy-rev_out = ls_qmel-revout.

    DATA(ls_eqstand_in) = CORRESPONDING /cellag/cseqstand_in( ls_qmel ).
    DATA(ls_eqstand_out) = CORRESPONDING /cellag/cseqstand_out( ls_qmel ).

    MOVE-CORRESPONDING ls_eqstand_in  TO ms_legacy.
    MOVE-CORRESPONDING ls_eqstand_out TO ms_legacy.
  ENDMETHOD.

  METHOD get_error_description.
    DATA lf_qmnum       TYPE qmnum.
    DATA lf_qmcod       TYPE qmel-qmcod.
    DATA lf_besz_string TYPE c LENGTH 30.
    DATA lf_besz        TYPE string.
    " ---------------------------------------------------------------------
    TYPES: BEGIN OF ty_qpgt,
             katalogart TYPE qpgt-katalogart,
             codegruppe TYPE qpgt-codegruppe,
             kurztext   TYPE qpgt-kurztext,
           END OF ty_qpgt.
    TYPES: BEGIN OF ty_qpct,
             katalogart TYPE qpct-katalogart,
             codegruppe TYPE qpct-codegruppe,
             code       TYPE qpct-code,
             kurztext   TYPE qpct-kurztext,
           END OF ty_qpct.

    DATA lt_qpgt       TYPE SORTED TABLE OF ty_qpgt WITH NON-UNIQUE KEY katalogart codegruppe.
    DATA lt_qpct       TYPE SORTED TABLE OF ty_qpct WITH NON-UNIQUE KEY katalogart codegruppe code.

    " SBO - 14.08.2026 - DA1K990869
    " Table keys are changed to non-unique to allow processing duplicates
    DATA lt_katalogart TYPE SORTED TABLE OF qkatart WITH NON-UNIQUE KEY table_line.   " 14.08.2026
    DATA lt_codegruppe TYPE SORTED TABLE OF qcodegrp WITH NON-UNIQUE KEY table_line.  " 14.08.2026
    DATA lt_code TYPE SORTED TABLE OF qcode WITH NON-UNIQUE KEY table_line.           " 14.08.2026

    DATA lr_katalogart TYPE RANGE OF qkatart.
    DATA lr_codegruppe TYPE RANGE OF qcodegrp.
    DATA lr_code       TYPE RANGE OF qcode.
    " ---------------------------------------------------------------------

    SELECT SINGLE qmnum, qmcod FROM qmel
      WHERE aufnr = @mv_aufnr
        AND qmart = @co_qmart
      INTO ( @lf_qmnum, @lf_qmcod ).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    mv_qmnum = lf_qmnum.
    mv_qmcod = lf_qmcod.

    SELECT otkat, otgrp, oteil, fekat, fegrp, fecod, besz
      FROM qmfe
      WHERE qmnum = @lf_qmnum
      INTO TABLE @DATA(lt_fe).

    " If exactly repeated , remove
    SORT lt_fe BY table_line.
    DELETE ADJACENT DUPLICATES FROM lt_fe COMPARING ALL FIELDS.

    IF lt_fe IS INITIAL.
      RETURN.
    ENDIF.

    " ---------------------------------------------------------------------
    lt_katalogart = VALUE #( FOR <e> IN lt_fe
                             ( <e>-otkat )
                             ( <e>-fekat ) ).
    lt_codegruppe = VALUE #( FOR <e> IN lt_fe
                             ( <e>-otgrp )
                             ( <e>-fegrp ) ).
    lt_code =       VALUE #( FOR <e> IN lt_fe
                             ( <e>-oteil )
                             ( <e>-fecod ) ).

    DELETE ADJACENT DUPLICATES FROM lt_katalogart COMPARING ALL FIELDS. " 14.08.2026
    DELETE ADJACENT DUPLICATES FROM lt_codegruppe COMPARING ALL FIELDS. " 14.08.2026
    DELETE ADJACENT DUPLICATES FROM lt_code COMPARING ALL FIELDS.       " 14.08.2026

    lr_katalogart = VALUE #( FOR <a> IN lt_katalogart
                             ( sign = 'I' option = 'EQ' low = <a> ) ).
    lr_codegruppe = VALUE #( FOR <g> IN lt_codegruppe
                             ( sign = 'I' option = 'EQ' low = <g> ) ).
    lr_code =       VALUE #( FOR <c> IN lt_code
                             ( sign = 'I' option = 'EQ' low = <c> ) ).
    " ---------------------------------------------------------------------
    SELECT katalogart, codegruppe, kurztext             "#EC CI_GENBUFF
      FROM qpgt
      WHERE katalogart IN @lr_katalogart
        AND codegruppe IN @lr_codegruppe
        AND sprache     = @mv_spras
      INTO TABLE @lt_qpgt.

    SELECT katalogart, codegruppe, code, kurztext       "#EC CI_GENBUFF
      FROM qpct
      WHERE katalogart IN @lr_katalogart
        AND codegruppe IN @lr_codegruppe
        AND code       IN @lr_code
        AND sprache     = @mv_spras
        AND version     = '000001'
      INTO TABLE @lt_qpct.

    DELETE ADJACENT DUPLICATES FROM lt_qpgt COMPARING katalogart codegruppe.
    DELETE ADJACENT DUPLICATES FROM lt_qpct COMPARING katalogart codegruppe code.

    LOOP AT lt_fe ASSIGNING FIELD-SYMBOL(<fe>).

      lf_besz_string = <fe>-besz.
      CONCATENATE lf_besz lf_besz_string '; ' INTO lf_besz.

      APPEND INITIAL LINE TO mt_legacy_error ASSIGNING FIELD-SYMBOL(<le>).
      MOVE-CORRESPONDING <fe> TO <le>.
      <le>-qmnum = lf_qmnum.

      " Added BINARY SEARCH to prevent ineeficient nested loop lookups
      READ TABLE lt_qpgt ASSIGNING FIELD-SYMBOL(<gt>)
           WITH KEY katalogart = <fe>-otkat
                    codegruppe = <fe>-otgrp BINARY SEARCH.
      IF sy-subrc = 0.
        <le>-otgrp_ktxt = <gt>-kurztext.
      ENDIF.

      READ TABLE lt_qpgt ASSIGNING <gt>
           WITH KEY katalogart = <fe>-fekat
                    codegruppe = <fe>-fegrp BINARY SEARCH.
      IF sy-subrc = 0.
        <le>-fegrp_ktxt = <gt>-kurztext.
      ENDIF.

      READ TABLE lt_qpct ASSIGNING FIELD-SYMBOL(<ct>)
           WITH KEY katalogart = <fe>-otkat
                    codegruppe = <fe>-otgrp
                    code       = <fe>-oteil BINARY SEARCH.
      IF sy-subrc = 0.
        <le>-oteil_ktxt = <ct>-kurztext.
      ENDIF.

      READ TABLE lt_qpct ASSIGNING <ct>
           WITH KEY katalogart = <fe>-fekat
                    codegruppe = <fe>-fegrp
                    code       = <fe>-fecod BINARY SEARCH.
      IF sy-subrc = 0.
        <le>-fecod_ktxt = <ct>-kurztext.
      ENDIF.
    ENDLOOP.

    " aufbereitung für die ausgabe: lösche das letzte semikolon.
    SHIFT lf_besz RIGHT DELETING TRAILING ';'.
    lf_besz = condense( lf_besz ).
    ms_legacy-besz_cld = lf_besz.
  ENDMETHOD.

  METHOD get_kddata.
    CLEAR: mv_kdauf,
           mv_time_received,
           mv_time_repaired,
           mv_time_thisdate,
           mv_po_nr,
           mv_po_pos,
           mv_qmnum,
           mv_fenum,
           mv_ctdi_odernr.

    " Consolidate conditional sequential aufk and vbak lookups into a single DB hit
    SELECT SINGLE a~kdauf,
                  a~kdpos,
                  a~objnr,
                  k~kvgr1,
                  k~qmnum         AS vbak_qmnum,
                  p~/cellag/qmnum AS vbap_qmnum,
                  p~/cellag/fenum AS fenum,
                  p~posex         AS po_pos,
                  d~bstkd         AS po_nr
      FROM aufk AS a
             LEFT OUTER JOIN
               vbak AS k ON k~vbeln = a~kdauf
                 LEFT OUTER JOIN
                   vbap AS p ON p~vbeln = a~kdauf AND p~posnr = a~kdpos
                     LEFT OUTER JOIN
                       vbkd AS d ON d~vbeln = a~kdauf AND d~posnr = a~kdpos
      WHERE a~aufnr = @mv_aufnr
      INTO @DATA(ls_aufk).

    IF sy-subrc = 0.
      mv_kdauf = ls_aufk-kdauf.

      get_astatus_data( EXPORTING iv_objnr     = ls_aufk-objnr
                        IMPORTING ev_wfer_date = DATA(lv_wfer_date)
                                  ev_wfer_time = DATA(lv_wfer_time) ).
      /ctdi/cl_print_driver_log=>log_info( |  get_astatus_data completed for { mv_aufnr }| ).

      get_rlf_wedate( EXPORTING iv_vbeln_vl = mv_retlief_nr
                      IMPORTING ev_vl_erdat = DATA(lv_vl_erdat)
                                ev_vl_zeit  = DATA(lv_vl_erzet) ).
      /ctdi/cl_print_driver_log=>log_info( |  get_rlf_wedate completed for { mv_aufnr }| ).

      mv_time_received = lv_vl_erzet.
      mv_time_repaired = lv_wfer_time.
      mv_time_thisdate = sy-uzeit.

      DATA lv_qmart TYPE qmel-qmart.

      IF ls_aufk-kdauf IS NOT INITIAL.
        mv_qmnum  = COND #( WHEN ls_aufk-vbak_qmnum IS NOT INITIAL
                            THEN ls_aufk-vbak_qmnum
                            ELSE ls_aufk-vbap_qmnum ).
        mv_fenum  = ls_aufk-fenum.
        mv_po_nr  = ls_aufk-po_nr.
        mv_po_pos = ls_aufk-po_pos.

        ms_legacy-kvgr1 = ls_aufk-kvgr1.
      ENDIF.

      " Fallback 1: If QMNUM still initial, fetch directly from QMEL linked to Order
      IF mv_qmnum IS INITIAL.
        SELECT SINGLE qmnum, qmart FROM qmel
          WHERE aufnr = @mv_aufnr
            AND qmart = @co_qmart
          INTO ( @mv_qmnum, @lv_qmart ).
        IF sy-subrc <> 0.
          SELECT SINGLE qmnum, qmart FROM qmel
            WHERE aufnr = @mv_aufnr
            INTO ( @mv_qmnum, @lv_qmart ) ##SUBRC_OK.
        ENDIF.
      ELSE.
        SELECT SINGLE qmart FROM qmel WHERE qmnum = @mv_qmnum INTO @lv_qmart ##SUBRC_OK.
      ENDIF.

      " Fallback 2: If FENUM still initial and QMNUM is known, fetch first item from QMFE
      IF mv_fenum IS INITIAL AND mv_qmnum IS NOT INITIAL.
        SELECT SINGLE fenum FROM qmfe WHERE qmnum = @mv_qmnum INTO @mv_fenum ##SUBRC_OK.
      ENDIF.

      " Intercompany resolution (safe overwrite only when secondary order found)
      IF lv_qmart = co_zx_qmart AND mv_qmnum IS NOT INITIAL AND mv_fenum IS NOT INITIAL.
        SELECT SINGLE e~aufnr,
                      p~/cellag/qmnum AS qmnum_u,
                      p~/cellag/fenum AS fenum_u,
                      p~posex         AS posex_u,
                      d~bstkd         AS bstkd_u
          FROM qmfe AS q
                 LEFT OUTER JOIN
                   ekkn AS e ON e~ebeln = q~ebeln AND e~ebelp = q~ebelp
                     LEFT OUTER JOIN
                       aufk AS a ON a~aufnr = e~aufnr
                         LEFT OUTER JOIN
                           vbap AS p ON p~vbeln = a~kdauf AND p~posnr = a~kdpos
                             LEFT OUTER JOIN
                               vbkd AS d ON d~vbeln = a~kdauf AND d~posnr = a~kdpos
          WHERE q~qmnum = @mv_qmnum
            AND q~fenum = @mv_fenum
          INTO @DATA(ls_qmfe).

        IF ls_qmfe-aufnr IS NOT INITIAL.
          mv_fenum  = ls_qmfe-fenum_u.
          mv_qmnum  = ls_qmfe-qmnum_u.
          mv_po_pos = ls_qmfe-posex_u.
          mv_po_nr  = ls_qmfe-bstkd_u.
        ENDIF.
      ENDIF.

      IF mv_qmnum IS NOT INITIAL.
        DATA(lv_qm) = condense( CONV string( mv_qmnum ) ).
        DATA(lv_fe) = condense( CONV string( mv_fenum ) ).
        mv_ctdi_odernr = COND #( WHEN lv_fe IS NOT INITIAL
                                 THEN |{ lv_qm }-{ lv_fe }|
                                 ELSE lv_qm ).
      ELSE.
        CLEAR mv_ctdi_odernr.
      ENDIF.
    ENDIF.

    ms_legacy-csaufnr       = mv_aufnr.
    ms_legacy-sernr         = mv_sernr.
    ms_legacy-po_no         = mv_po_nr.
    ms_legacy-po_item_no    = mv_po_pos.
    ms_legacy-ctdi_order_no = mv_ctdi_odernr.
    ms_legacy-date_received = lv_vl_erdat.
    ms_legacy-date_repaired = lv_wfer_date.
    ms_legacy-date_current  = sy-datum.
  ENDMETHOD.

  METHOD get_part_data.
    DATA(lv_equnr) = resolve_equipment_number( ).
    /ctdi/cl_print_driver_log=>log_info( |  resolve_equipment_number completed for { mv_aufnr }| ).

    determine_serial_and_part( lv_equnr ).
    /ctdi/cl_print_driver_log=>log_info( |  determine_serial_and_part completed for { mv_aufnr }| ).

    fallback_part_numbers( lv_equnr ).
    /ctdi/cl_print_driver_log=>log_info( |  fallback_part_numbers completed for { mv_aufnr }| ).

    ms_legacy-old_serial_no = mv_old_serial.
    ms_legacy-new_serial_no = mv_new_serial.
    ms_legacy-old_part_no   = mv_old_part.
    ms_legacy-new_part_no   = mv_new_part.

    get_equipment_model( lv_equnr ).
    /ctdi/cl_print_driver_log=>log_info( |  get_equipment_model completed for { mv_aufnr }| ).

    get_equipment_stands( ).
    /ctdi/cl_print_driver_log=>log_info( |  get_equipment_stands completed for { mv_aufnr }| ).
  ENDMETHOD.

  METHOD get_repair_result.
    DATA lf_repres     TYPE /cellag/repair_result.
    DATA lf_repres_txt TYPE /cellag/repair_result_txt.

    DATA lv_bemot      TYPE afru-bemot.
    DATA lv_stokz      TYPE afru-stokz.
    DATA lv_stzhl      TYPE afru-stzhl.

    IF ms_legacy-old_serial_no IS NOT INITIAL AND ms_legacy-old_serial_no <> ms_legacy-new_serial_no.
      SELECT SINGLE repres_barc, repres_txt
        FROM zalca_rep_result
        WHERE bemot = 'RE'
          AND akz   = ''
        INTO ( @lf_repres, @lf_repres_txt ).
    ELSE.

      DATA lv_subrc TYPE sysubrc.

      SELECT bemot, stokz, stzhl FROM afru
        WHERE aufnr = @mv_aufnr
          AND vornr = @/ctdi/cl_print_driver_base=>gc_operation_wfer
        INTO TABLE @DATA(lt_afru_skz).

      lv_subrc = sy-subrc.

      LOOP AT lt_afru_skz ASSIGNING FIELD-SYMBOL(<ls_afru_skz>).
        lv_bemot = <ls_afru_skz>-bemot.
        lv_stokz = <ls_afru_skz>-stokz.
        lv_stzhl = <ls_afru_skz>-stzhl.
        IF lv_stokz = ' ' AND lv_stzhl = '00000000'.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF lv_subrc = 0.
        SELECT SINGLE repres_barc, repres_txt
          FROM zalca_rep_result
          WHERE bemot = @lv_bemot
            AND akz   = @mv_qmcod
          INTO ( @lf_repres, @lf_repres_txt ).
        IF sy-subrc <> 0.
          SELECT SINGLE repres_barc, repres_txt
            FROM zalca_rep_result
            WHERE bemot = @lv_bemot
              AND akz   = ''
            INTO ( @lf_repres, @lf_repres_txt ).
        ENDIF.
      ENDIF.
    ENDIF.

    ms_legacy-repair_result     = lf_repres.
    ms_legacy-repair_result_txt = lf_repres_txt.
  ENDMETHOD.

  METHOD get_rlf_wedate.
    SELECT SINGLE erdat, erzet FROM likp WHERE vbeln = @iv_vbeln_vl INTO ( @ev_vl_erdat, @ev_vl_zeit ).
  ENDMETHOD.

  METHOD read_data.
    CLEAR: me->ms_legacy,
           me->mt_legacy_error,
           me->mt_comment_lines.

    mv_aufnr = iv_aufnr.
    mv_sernr = iv_sernr.

    " set language
    IF sy-langu = 'D'.
      mv_spras = 'D'.
    ELSE.
      mv_spras = 'E'.
    ENDIF.

    check_sernr_swap( ).
    /ctdi/cl_print_driver_log=>log_info( |check_sernr_swap completed for { mv_aufnr }| ).

    get_kddata( ).
    /ctdi/cl_print_driver_log=>log_info( |get_kddata completed for { mv_aufnr }| ).

    get_part_data( ).
    /ctdi/cl_print_driver_log=>log_info( |get_part_data completed for { mv_aufnr }| ).

    get_error_description( ).
    /ctdi/cl_print_driver_log=>log_info( |get_error_description completed for { mv_aufnr }| ).

    get_repair_result( ).
    /ctdi/cl_print_driver_log=>log_info( |get_repair_result completed for { mv_aufnr }| ).

    get_comment( ).
    /ctdi/cl_print_driver_log=>log_info( |get_comment completed for { mv_aufnr }| ).
  ENDMETHOD.

  METHOD resolve_equipment_number.
    DATA lv_sernr      TYPE equi-sernr.
    DATA lt_order_objk TYPE TABLE OF objk.

    lv_sernr = mv_sernr.

    IF lv_sernr IS INITIAL.
      CALL FUNCTION '/CELLAG/CS_ORDER_SERNR_GET'
        EXPORTING
          i_aufnr       = mv_aufnr
        TABLES
          et_order_objk = lt_order_objk
        EXCEPTIONS
          OTHERS        = 1.           "#EC CI_SUBRC
      READ TABLE lt_order_objk INDEX 1 ASSIGNING FIELD-SYMBOL(<ls_objk>).
      IF sy-subrc = 0.
        lv_sernr = <ls_objk>-sernr.
      ENDIF.
    ENDIF.

    " Write resolved serial back so it's available for filename and repair structure
    IF mv_sernr IS INITIAL AND lv_sernr IS NOT INITIAL.
      mv_sernr        = lv_sernr.
      ms_legacy-sernr = lv_sernr.
    ENDIF.

    SELECT SINGLE equnr FROM equi
      WHERE sernr = @lv_sernr
      INTO @rv_equnr.

    IF rv_equnr IS INITIAL.
      MESSAGE e024(/cellag/cs01) WITH lv_sernr INTO DATA(lv_msg).
      RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
        EXPORTING
          repair_id = mv_aufnr
          message   = lv_msg.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

