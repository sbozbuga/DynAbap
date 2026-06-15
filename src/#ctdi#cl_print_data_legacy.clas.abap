CLASS /ctdi/cl_print_data_legacy DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    DATA ms_legacy       TYPE /cellag/alcarep.
    DATA mt_legacy_error TYPE STANDARD TABLE OF /cellag/alcarep_error.
    DATA mt_comment_lines TYPE STANDARD TABLE OF tline.

    "! Reads the required data for the Alcatel repair process.
    METHODS read_data
      IMPORTING
        !iv_aufnr TYPE aufk-aufnr
        !iv_sernr TYPE equi-sernr OPTIONAL.



  PROTECTED SECTION.
    DATA mv_aufnr TYPE aufk-aufnr.
    DATA mv_qmcod TYPE qmel-qmcod.
    DATA mv_kdauf TYPE aufk-kdauf.
    DATA mv_swap_flag TYPE flag.

    METHODS get_repair_result.

  PRIVATE SECTION.
    CONSTANTS co_equi_vers TYPE imrc_psort VALUE 'EQUI-VERS'.
    CONSTANTS co_qmart     TYPE qmart      VALUE 'Z2'.
    CONSTANTS co_wfer_stat TYPE j_estat    VALUE 'E0001'.
    CONSTANTS co_zx_qmart  TYPE qmart      VALUE 'ZX'.

    DATA mv_sernr TYPE equi-sernr.

    DATA mv_po_nr           TYPE vbkd-bstkd_e.
    DATA mv_po_pos          TYPE vbkd-posex_e.
    DATA mv_ctdi_odernr     TYPE c LENGTH 20.
    DATA mv_qmnum           TYPE qmel-qmnum.
    DATA mv_fenum           TYPE qmfe-fenum.
    DATA mv_time_received   TYPE tims.
    DATA mv_time_repaired   TYPE tims.
    DATA mv_time_thisdate   TYPE tims.
    DATA mv_spras           TYPE sy-langu.
    DATA mv_retlief_nr      TYPE vbeln_vl.
    DATA mv_equnr_retlief   TYPE equnr.
    DATA mv_katalogart      TYPE qkatart.

    METHODS get_kddata.
    METHODS get_part_data.
    METHODS get_error_description.
    METHODS get_comment.
    METHODS check_sernr_swap.

    METHODS get_astatus_data
      IMPORTING
        !iv_objnr     TYPE j_objnr
      EXPORTING
        !ev_wfer_date TYPE dats
        !ev_wfer_time TYPE tims.

    METHODS get_rlf_wedate
      IMPORTING
        !iv_vbeln_vl  TYPE vbeln_vl
      EXPORTING
        !ev_vl_erdat  TYPE likp-erdat
        !ev_vl_zeit   TYPE likp-erzet.

    METHODS get_retlief
      EXPORTING
        !es_vbfa      TYPE vbfa
        !ev_vbfa_rl   TYPE vbeln_vl.

    METHODS convert_to_timestamp
      IMPORTING
        !iv_date      TYPE dats
        !iv_time      TYPE tims
      RETURNING
        VALUE(rv_tstamp) TYPE timestamp.

    " --- LEGACY CODE (Commented for reference) ---
*    METHODS get_last_record
*      IMPORTING
*        !it_cdhdr          TYPE STANDARD TABLE
*        !iv_equnr          TYPE equnr
*        !iv_tstamp_received TYPE timestamp
*        !iv_tstamp_repaired TYPE timestamp
*        !iv_fname          TYPE csequence
*      EXPORTING
*        !ev_old_val        TYPE any
*        !ev_new_val        TYPE any.
ENDCLASS.


CLASS /ctdi/cl_print_data_legacy IMPLEMENTATION.

  METHOD read_data.
    CLEAR: ms_legacy, mt_legacy_error, mt_comment_lines.

    mv_aufnr = iv_aufnr.
    mv_sernr = iv_sernr.

    " set language
    IF sy-langu = 'D'.
      mv_spras = 'D'.
    ELSE.
      mv_spras = 'E'.
    ENDIF.

    check_sernr_swap( ).
    get_kddata( ).
    get_part_data( ).
    get_error_description( ).
    get_repair_result( ).
    get_comment( ).
  ENDMETHOD.

  METHOD check_sernr_swap.
    DATA: lf_rmanr     TYPE vbap-vbeln,
          lf_posnv_rma TYPE posnr,
          lf_posnr_rma TYPE posnr,
          lt_order_sn  TYPE /cellag/cs_order_sn_t,
          ls_order_sn  TYPE /cellag/cs_order_sn,
          lt_snx_tab   TYPE /cellag/csauf_snx_t,
          ls_snx_tab   TYPE /cellag/csauf_snx.

    CLEAR: mv_swap_flag, mv_retlief_nr, mv_equnr_retlief.

    SELECT SINGLE rmanr, posnv_rma, posnr_rma
      FROM afko
      
      WHERE aufnr = @mv_aufnr INTO ( @lf_rmanr, @lf_posnv_rma, @lf_posnr_rma ).

    CALL FUNCTION '/CELLAG/SDPOS_RALMENGE_GET'
      EXPORTING
        i_vbeln     = lf_rmanr
        i_posnr     = lf_posnv_rma
      TABLES
        et_order_sn = lt_order_sn
      EXCEPTIONS
        OTHERS      = 1. "#EC CI_SUBRC

    READ TABLE lt_order_sn INTO ls_order_sn
      WITH KEY aufnr = mv_aufnr rmanr = lf_rmanr posnr_rma = lf_posnr_rma.
    IF sy-subrc = 0.
      mv_retlief_nr = ls_order_sn-vbeln_vl.
      lt_snx_tab = ls_order_sn-snx_tab.
      READ TABLE lt_snx_tab INTO ls_snx_tab INDEX 1.
      IF sy-subrc = 0.
        mv_equnr_retlief = ls_snx_tab-ral_equnr.
        mv_swap_flag     = ls_snx_tab-tausch.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD get_kddata.
    DATA: lf_kdauf       TYPE aufk-kdauf,
          lf_kdpos       TYPE aufk-kdpos,
          lf_objnr       TYPE j_objnr,
          lf_wfer_date   TYPE dats,
          lf_wfer_time   TYPE tims,
          lf_vl_erdat    TYPE likp-erdat,
          lf_vl_erzet    TYPE likp-erzet,
          lf_po_nr       TYPE vbkd-bstkd_e,
          lf_po_pos      TYPE vbkd-posex_e,
          lf_qmnum       TYPE vbak-qmnum,
          lf_fenum       TYPE vbap-/cellag/fenum,
          lf_kvgr1       TYPE vbak-kvgr1,
          lf_erdat       TYPE auferfdat,
          lf_tabg_status TYPE aufidat2,
          lf_erfzeit     TYPE tims,
          lf_aezeit      TYPE tims.

    CLEAR: lf_kdauf, lf_kdpos, lf_erdat, lf_tabg_status, lf_erfzeit, lf_aezeit, lf_objnr.

    SELECT SINGLE kdauf, kdpos, erdat, idat2, erfzeit, aezeit, objnr
      FROM aufk
      
      WHERE aufnr = @mv_aufnr INTO ( @lf_kdauf, @lf_kdpos, @lf_erdat, @lf_tabg_status, @lf_erfzeit, @lf_aezeit, @lf_objnr ).

    IF sy-subrc = 0.
      mv_kdauf = lf_kdauf.

      get_astatus_data(
        EXPORTING iv_objnr     = lf_objnr
        IMPORTING ev_wfer_date = lf_wfer_date
                  ev_wfer_time = lf_wfer_time ).

      get_rlf_wedate(
        EXPORTING iv_vbeln_vl  = mv_retlief_nr
        IMPORTING ev_vl_erdat  = lf_vl_erdat
                  ev_vl_zeit   = lf_vl_erzet ).

      mv_time_received = lf_vl_erzet.
      mv_time_repaired = lf_wfer_time.
      mv_time_thisdate = sy-uzeit.

      CLEAR lf_po_nr.
      SELECT SINGLE bstkd FROM vbkd
        WHERE vbeln = @lf_kdauf AND posnr = @lf_kdpos INTO @lf_po_nr.
      mv_po_nr = lf_po_nr.

      CLEAR: lf_qmnum, lf_kvgr1.
      SELECT SINGLE kvgr1, qmnum FROM vbak
        WHERE vbeln = @lf_kdauf INTO ( @lf_kvgr1, @lf_qmnum ).
      mv_qmnum = lf_qmnum.

      CLEAR: lf_fenum, lf_po_pos.
      SELECT SINGLE /cellag/fenum, posex FROM vbap
        WHERE vbeln = @lf_kdauf AND posnr = @lf_kdpos INTO ( @lf_fenum, @lf_po_pos ).
      mv_fenum = lf_fenum.
      mv_po_pos = lf_po_pos.

      DATA: lv_qmart   TYPE qmel-qmart,
            lv_aufnr   TYPE aufnr,
            lv_qmnum_u TYPE qmnum,
            lv_fenum_u TYPE fenum,
            lv_ebeln_u TYPE ebeln,
            lv_ebelp_u TYPE ebelp,
            lv_kdauf_u TYPE kdauf,
            lv_kdpos_u TYPE kdpos,
            lv_posex_u TYPE vbap-posex,
            lv_bstkd_u TYPE vbkd-bstkd.

      SELECT SINGLE qmart  FROM qmel WHERE qmnum = @mv_qmnum INTO @lv_qmart.

      IF lv_qmart = co_zx_qmart.
        SELECT SINGLE ebeln, ebelp FROM qmfe
          WHERE qmnum = @mv_qmnum AND fenum = @mv_fenum INTO ( @lv_ebeln_u, @lv_ebelp_u ).

        CLEAR: mv_qmnum, mv_fenum.
        SELECT SINGLE aufnr FROM ekkn
          WHERE ebeln = @lv_ebeln_u AND ebelp = @lv_ebelp_u INTO @lv_aufnr.

        IF lv_aufnr IS NOT INITIAL.
          SELECT SINGLE kdauf, kdpos FROM aufk
            WHERE aufnr = @lv_aufnr INTO ( @lv_kdauf_u, @lv_kdpos_u ).

          SELECT SINGLE /cellag/qmnum, /cellag/fenum, posex FROM vbap
            
            WHERE vbeln = @lv_kdauf_u AND posnr = @lv_kdpos_u INTO ( @lv_qmnum_u, @lv_fenum_u, @lv_posex_u ).

          mv_fenum = lv_fenum_u.
          mv_qmnum = lv_qmnum_u.

          SELECT SINGLE bstkd FROM vbkd
            WHERE vbeln = @lv_kdauf_u AND posnr = @lv_kdpos_u INTO @lv_bstkd_u.

          CLEAR: mv_po_nr, mv_po_pos.
          mv_po_pos = lv_posex_u.
          mv_po_nr  = lv_bstkd_u.
        ENDIF.
      ENDIF.

      mv_ctdi_odernr = |{ mv_qmnum }-{ mv_fenum }|.
    ENDIF.

    ms_legacy-csaufnr         = mv_aufnr.
    ms_legacy-sernr           = mv_sernr.
    ms_legacy-po_no           = mv_po_nr.
    ms_legacy-po_item_no      = mv_po_pos.
    ms_legacy-ctdi_order_no   = mv_ctdi_odernr.
    ms_legacy-date_received   = lf_vl_erdat.
    ms_legacy-date_repaired   = lf_wfer_date.
    ms_legacy-date_current    = sy-datum.
    ms_legacy-kvgr1           = lf_kvgr1.
  ENDMETHOD.

  METHOD get_part_data.
    DATA: lf_oldpartnr   TYPE itob-mapar,
          lf_newpartnr   TYPE itob-mapar,
          lf_oldserialnr TYPE itob-serge,
          lf_newserialnr TYPE itob-serge,
          lv_oldmatnr    TYPE matnr,
          lv_newmatnr    TYPE matnr,
          lf_equnr       TYPE equnr,
          lv_p_sernr     TYPE equi-sernr.

    DATA: lf_udate           TYPE cddatum,
          lf_utime           TYPE cduzeit,
          lf_tstamp_received TYPE timestamp,
          lf_tstamp_changed  TYPE timestamp,
          lf_tstamp_repaired TYPE timestamp,
          lf_tstamp_thisdate TYPE timestamp,
          ls_cdpos           TYPE cdpos,
          ls_cdpos_first     TYPE cdpos,
          ls_cdpos_serge     TYPE cdpos,
          ls_cdpos_mapar     TYPE cdpos,
          lt_cdhdr           TYPE TABLE OF cdhdr,
          lt_cdhdr_serge     TYPE TABLE OF cdhdr,
          lt_cdhdr_mapar     TYPE TABLE OF cdhdr,
          ls_cdhdr           TYPE cdhdr,
          lv_lines           TYPE i.

    DATA: lt_order_objk TYPE TABLE OF objk.
    FIELD-SYMBOLS: <ls_objk> TYPE objk.

    lv_p_sernr = mv_sernr.
    IF lv_p_sernr IS INITIAL.
      CALL FUNCTION '/CELLAG/CS_ORDER_SERNR_GET'
        EXPORTING
          i_aufnr       = mv_aufnr
        TABLES
          et_order_objk = lt_order_objk
        EXCEPTIONS
          OTHERS        = 1. "#EC CI_SUBRC
      LOOP AT lt_order_objk ASSIGNING <ls_objk>.
        lv_p_sernr = <ls_objk>-sernr.
        EXIT.
      ENDLOOP.
    ENDIF.

    SELECT SINGLE equnr FROM equi  WHERE sernr = @lv_p_sernr INTO @lf_equnr.
    IF lf_equnr IS NOT INITIAL.
      IF mv_swap_flag IS NOT INITIAL.
        SELECT SINGLE serge, matnr
           FROM equi 
           WHERE equnr = @lf_equnr INTO ( @lf_newserialnr, @lv_newmatnr ).
        SELECT SINGLE mapar FROM equz  WHERE equnr = @lf_equnr INTO @lf_newpartnr.

        SELECT SINGLE serge, matnr
           FROM equi 
           WHERE equnr = @mv_equnr_retlief INTO ( @lf_oldserialnr, @lv_oldmatnr ).
        SELECT SINGLE mapar FROM equz  WHERE equnr = @mv_equnr_retlief INTO @lf_oldpartnr.
      ELSE.
        " --- NEW OPTIMIZED LOGIC ---
        " Pre-fetch current values as defaults
        SELECT SINGLE serge, matnr FROM equi  WHERE equnr = @lf_equnr INTO ( @DATA(lv_cur_serge), @DATA(lv_cur_matnr) ).
        SELECT SINGLE mapar FROM equz  WHERE equnr = @lf_equnr INTO @DATA(lv_cur_mapar).

        lf_newserialnr = lv_cur_serge.
        lf_oldserialnr = lv_cur_serge.
        lv_newmatnr    = lv_cur_matnr.
        lv_oldmatnr    = lv_cur_matnr.
        lf_newpartnr   = lv_cur_mapar.
        lf_oldpartnr   = lv_cur_mapar.
        " Determine timestamp window
        lf_tstamp_received = convert_to_timestamp( iv_date = ms_legacy-date_received iv_time = mv_time_received ).
        lf_tstamp_repaired = convert_to_timestamp( iv_date = ms_legacy-date_repaired iv_time = mv_time_repaired ).

        SELECT changenr, udate, utime FROM cdhdr
          
          WHERE objectclas = 'EQUI' AND objectid = @lf_equnr INTO CORRESPONDING FIELDS OF TABLE @lt_cdhdr.

        IF lt_cdhdr IS NOT INITIAL.
          " Build a RANGE table for changenr to avoid ATC FOR ALL ENTRIES warning on cluster table
          DATA: lr_changenr TYPE RANGE OF cdhdr-changenr.
          lr_changenr = VALUE #( FOR <fs_hdr> IN lt_cdhdr ( sign = 'I' option = 'EQ' low = <fs_hdr>-changenr ) ).

          " Fetch all relevant CDPOS records in one go
          SELECT changenr, tabname, fname, value_old, value_new FROM cdpos
            
            WHERE objectclas = 'EQUI'
              AND objectid   = @lf_equnr
              AND changenr   IN @lr_changenr INTO TABLE @DATA(lt_cdpos_all).

          IF lt_cdpos_all IS NOT INITIAL.
            " Sort cdhdr descending by date/time to find the latest valid change first
            SORT lt_cdhdr DESCENDING BY udate utime DESCENDING.
            " Sort cdpos for binary search
            SORT lt_cdpos_all BY changenr tabname fname.

            DATA: lv_serge_found TYPE abap_bool VALUE abap_false,
                  lv_mapar_found TYPE abap_bool VALUE abap_false.

            LOOP AT lt_cdhdr INTO ls_cdhdr.
              " Stop if we found both
              IF lv_serge_found = abap_true AND lv_mapar_found = abap_true.
                EXIT.
              ENDIF.

              lf_tstamp_changed = convert_to_timestamp( iv_date = ls_cdhdr-udate iv_time = ls_cdhdr-utime ).

              " Only consider changes within the repair window
              IF lf_tstamp_changed >= lf_tstamp_received AND lf_tstamp_changed <= lf_tstamp_repaired.

                " Check for SERGE change
                IF lv_serge_found = abap_false.
                  READ TABLE lt_cdpos_all INTO DATA(ls_pos_serge) WITH KEY changenr = ls_cdhdr-changenr tabname = 'EQUI' fname = 'SERGE' BINARY SEARCH.
                  IF sy-subrc = 0.
                    lf_oldserialnr = ls_pos_serge-value_old.
                    lf_newserialnr = ls_pos_serge-value_new.
                    lv_serge_found = abap_true.
                  ENDIF.
                ENDIF.

                " Check for MAPAR change
                IF lv_mapar_found = abap_false.
                  READ TABLE lt_cdpos_all INTO DATA(ls_pos_mapar) WITH KEY changenr = ls_cdhdr-changenr tabname = 'EQUZ' fname = 'MAPAR' BINARY SEARCH.
                  IF sy-subrc = 0.
                    lf_oldpartnr = ls_pos_mapar-value_old.
                    lf_newpartnr = ls_pos_mapar-value_new.
                    lv_mapar_found = abap_true.
                  ENDIF.
                ENDIF.

              ENDIF.
            ENDLOOP.
          ENDIF.
        ENDIF.
      ENDIF.

        " --- LEGACY CODE (Commented for reference) ---
*        SELECT changenr, udate, utime FROM cdhdr INTO CORRESPONDING FIELDS OF TABLE @lt_cdhdr WHERE objectclas = 'EQUI' AND objectid = @lf_equnr.
*
*        IF lt_cdhdr IS NOT INITIAL.
*          lv_lines = lines( lt_cdhdr ).
*
*          lf_tstamp_received = convert_to_timestamp(
*            iv_date = ms_legacy-date_received
*            iv_time = mv_time_received ).
*
*          lf_tstamp_repaired = convert_to_timestamp(
*            iv_date = ms_legacy-date_repaired
*            iv_time = mv_time_repaired ).
*
*          lf_tstamp_thisdate = convert_to_timestamp(
*            iv_date = ms_legacy-date_current
*            iv_time = mv_time_thisdate ).
*
*          IF lv_lines > 1.
*            IF lt_cdhdr IS NOT INITIAL.
*              SELECT changenr, tabname, fname
*                FROM cdpos
*                INTO TABLE @DATA(lt_cdpos_opt)
*                FOR ALL ENTRIES IN @lt_cdhdr
*                WHERE objectclas = 'EQUI'
*                  AND objectid   = @lf_equnr
*                  AND changenr   = @lt_cdhdr-changenr
*                  AND ( ( tabname = 'EQUI' AND fname = 'SERGE' ) OR
*                        ( tabname = 'EQUZ' AND fname = 'MAPAR' ) ).
*              SORT lt_cdpos_opt BY changenr tabname fname.
*            ENDIF.
*
*            LOOP AT lt_cdhdr INTO ls_cdhdr.
*              READ TABLE lt_cdpos_opt TRANSPORTING NO FIELDS
*                WITH KEY changenr = ls_cdhdr-changenr
*                         tabname  = 'EQUI'
*                         fname    = 'SERGE'
*                BINARY SEARCH.
*              IF sy-subrc = 0.
*                APPEND ls_cdhdr TO lt_cdhdr_serge.
*              ENDIF.
*
*              READ TABLE lt_cdpos_opt TRANSPORTING NO FIELDS
*                WITH KEY changenr = ls_cdhdr-changenr
*                         tabname  = 'EQUZ'
*                         fname    = 'MAPAR'
*                BINARY SEARCH.
*              IF sy-subrc = 0.
*                APPEND ls_cdhdr TO lt_cdhdr_mapar.
*              ENDIF.
*            ENDLOOP.
*
*            IF lt_cdhdr_serge IS NOT INITIAL.
*              get_last_record(
*                EXPORTING it_cdhdr = lt_cdhdr_serge
*                          iv_equnr = lf_equnr
*                          iv_tstamp_received = lf_tstamp_received
*                          iv_tstamp_repaired = lf_tstamp_repaired
*                          iv_fname = 'SERGE'
*                IMPORTING ev_old_val = lf_oldserialnr
*                          ev_new_val = lf_newserialnr ).
*            ELSE.
*              SELECT SINGLE serge FROM equi INTO @lf_newserialnr WHERE equnr = @lf_equnr.
*              lf_oldserialnr = lf_newserialnr.
*            ENDIF.
*
*            IF lt_cdhdr_mapar IS NOT INITIAL.
*              get_last_record(
*                EXPORTING it_cdhdr = lt_cdhdr_mapar
*                          iv_equnr = lf_equnr
*                          iv_tstamp_received = lf_tstamp_received
*                          iv_tstamp_repaired = lf_tstamp_repaired
*                          iv_fname = 'MAPAR'
*                IMPORTING ev_old_val = lf_oldpartnr
*                          ev_new_val = lf_newpartnr ).
*            ELSE.
*              SELECT SINGLE mapar FROM equz INTO @lf_newpartnr WHERE equnr = @lf_equnr.
*              lf_oldpartnr = lf_newpartnr.
*            ENDIF.
*
*          ELSEIF lv_lines = 1.
*            CLEAR: ls_cdhdr, lf_udate, lf_utime.
*            READ TABLE lt_cdhdr INTO ls_cdhdr INDEX 1.
*            lf_udate = ls_cdhdr-udate.
*            lf_utime = ls_cdhdr-utime.
*
*            lf_tstamp_changed = convert_to_timestamp(
*              iv_date = lf_udate
*              iv_time = lf_utime ).
*
*            IF lf_tstamp_received <= lf_tstamp_changed AND lf_tstamp_changed <= lf_tstamp_repaired.
*              SELECT tabname, fname, value_old, value_new FROM cdpos
*                INTO TABLE @DATA(lt_cdpos_single)
*                WHERE objectclas = 'EQUI' AND objectid = @lf_equnr AND changenr = @ls_cdhdr-changenr
*                  AND ( ( tabname = 'EQUI' AND fname = 'SERGE' ) OR
*                        ( tabname = 'EQUZ' AND fname = 'MAPAR' ) ).
*
*              READ TABLE lt_cdpos_single INTO DATA(ls_serge) WITH KEY tabname = 'EQUI' fname = 'SERGE'.
*              IF sy-subrc = 0.
*                lf_oldserialnr = ls_serge-value_old.
*                lf_newserialnr = ls_serge-value_new.
*              ELSE.
*                SELECT SINGLE serge FROM equi INTO @lf_newserialnr WHERE equnr = @lf_equnr.
*                lf_oldserialnr = lf_newserialnr.
*              ENDIF.
*
*              READ TABLE lt_cdpos_single INTO DATA(ls_mapar) WITH KEY tabname = 'EQUZ' fname = 'MAPAR'.
*              IF sy-subrc = 0.
*                lf_oldpartnr = ls_mapar-value_old.
*                lf_newpartnr = ls_mapar-value_new.
*              ELSE.
*                SELECT SINGLE mapar FROM equz INTO @lf_newpartnr WHERE equnr = @lf_equnr.
*                lf_oldpartnr = lf_newpartnr.
*              ENDIF.
*            ENDIF.
*          ENDIF.
*
*        ELSE.
*          SELECT SINGLE serge, matnr
*            FROM equi INTO ( @lf_newserialnr, @lv_newmatnr )
*            WHERE equnr = @lf_equnr.
*          lf_oldserialnr = lf_newserialnr.
*
*          SELECT SINGLE mapar FROM equz INTO @lf_newpartnr WHERE equnr = @lf_equnr.
*          lf_oldpartnr = lf_newpartnr.
*        ENDIF.
*      ENDIF.
*
*      IF lf_newserialnr IS INITIAL.
*        SELECT SINGLE serge, matnr
*          FROM equi INTO ( @lf_newserialnr, @lv_newmatnr )
*          WHERE equnr = @lf_equnr.
*        lf_oldserialnr = lf_newserialnr.
*      ENDIF.
*
*      IF lf_newpartnr IS INITIAL.
*        SELECT SINGLE mapar FROM equz INTO @lf_newpartnr WHERE equnr = @lf_equnr.
*        lf_oldpartnr = lf_newpartnr.
*      ENDIF.

      IF lf_newpartnr IS INITIAL.
        IF lv_newmatnr IS INITIAL.
          SELECT SINGLE matnr FROM equi  WHERE equnr = @lf_equnr INTO @lv_newmatnr.
        ENDIF.
        IF lv_newmatnr IS NOT INITIAL.
          SELECT SINGLE mfrpn FROM mara  WHERE matnr = @lv_newmatnr INTO @lf_newpartnr.
        ENDIF.
      ENDIF.

      IF lf_oldpartnr IS INITIAL.
        IF lv_oldmatnr IS INITIAL.
          SELECT SINGLE matnr FROM equi  WHERE equnr = @mv_equnr_retlief INTO @lv_oldmatnr.
        ENDIF.
        IF lv_oldmatnr IS NOT INITIAL.
          SELECT SINGLE mfrpn FROM mara  WHERE matnr = @lv_oldmatnr INTO @lf_oldpartnr.
        ENDIF.
      ENDIF.

      ms_legacy-old_serial_no = lf_oldserialnr.
      ms_legacy-new_serial_no = lf_newserialnr.
      ms_legacy-old_part_no   = lf_oldpartnr.
      ms_legacy-new_part_no   = lf_newpartnr.
    ELSE.
      MESSAGE e024(/cellag/cs01) WITH lv_p_sernr.
    ENDIF.

    DATA lf_eqktx TYPE ktx01.
    SELECT SINGLE eqktx FROM eqkt
      WHERE equnr = @lf_equnr AND spras = @mv_spras INTO @lf_eqktx.
    ms_legacy-model = lf_eqktx.

    DATA: ls_afih  TYPE afih,
          lv_qmnum TYPE qmel-qmnum,
          ls_qmel  TYPE qmel.

    SELECT SINGLE qmnum, obknr FROM afih  WHERE aufnr = @mv_aufnr INTO CORRESPONDING FIELDS OF @ls_afih.
    IF ls_afih-qmnum IS NOT INITIAL.
      lv_qmnum = ls_afih-qmnum.
    ELSE.
      SELECT SINGLE ihnum  FROM objk
       WHERE obknr = @ls_afih-obknr AND ihnum <> @space INTO @lv_qmnum.
    ENDIF.

    IF lv_qmnum IS NOT INITIAL.
      SELECT SINGLE *  FROM qmel WHERE qmnum = @lv_qmnum INTO @ls_qmel. "#EC CI_ALL_FIELDS_NEEDED
    ENDIF.

    DATA: ls_eqstand_in  TYPE /cellag/cseqstand_in,
          ls_eqstand_out TYPE /cellag/cseqstand_out.

    IF ls_qmel IS NOT INITIAL.
      ms_legacy-rev_in  = ls_qmel-revin.
      ms_legacy-rev_out = ls_qmel-revout.

      MOVE-CORRESPONDING ls_qmel TO ls_eqstand_in.
      MOVE-CORRESPONDING ls_qmel TO ls_eqstand_out.

      MOVE-CORRESPONDING ls_eqstand_in TO ms_legacy.
      MOVE-CORRESPONDING ls_eqstand_out TO ms_legacy.
    ENDIF.
  ENDMETHOD.

  METHOD get_error_description.
    DATA: lf_qmnum           TYPE qmnum,
          lf_qmcod           TYPE qmel-qmcod,
          lf_besz_string(30) TYPE c,
          lf_besz            TYPE string,
          lt_error           TYPE TABLE OF /cellag/alcarep_error,
          ls_error           LIKE LINE OF lt_error.

    SELECT SINGLE qmnum, qmcod FROM qmel
      WHERE aufnr = @mv_aufnr AND qmart = @co_qmart INTO ( @lf_qmnum, @lf_qmcod ).

    IF sy-subrc = 0.
      mv_qmnum = lf_qmnum.
      mv_qmcod = lf_qmcod.

      SELECT otgrp, oteil, fegrp, fecod, besz  FROM qmfe
        WHERE qmnum = @lf_qmnum
        ORDER BY PRIMARY KEY INTO CORRESPONDING FIELDS OF TABLE @lt_error.

      IF lt_error IS NOT INITIAL.
        LOOP AT lt_error INTO ls_error.
          lf_besz_string = ls_error-besz.
          CONCATENATE lf_besz lf_besz_string '; ' INTO lf_besz.

          IF ms_legacy-kvgr1 = '0SU'.
            mv_katalogart = 'E'.
          ELSE.
            mv_katalogart = 'Z'.
          ENDIF.

          IF mv_katalogart = 'Z'.
            SELECT SINGLE kurztext FROM qpgt
                    WHERE katalogart  = @mv_katalogart AND
                          codegruppe  = @ls_error-otgrp AND
                          sprache     = @mv_spras INTO @ls_error-otgrp_ktxt.
          ENDIF.

          SELECT SINGLE kurztext FROM qpct
                    WHERE katalogart  = @mv_katalogart AND
                          codegruppe  = @ls_error-otgrp AND
                          code        = @ls_error-oteil AND
                          sprache     = @mv_spras INTO @ls_error-oteil_ktxt.

          IF mv_katalogart = 'Z'.
            SELECT SINGLE kurztext FROM qpgt
                    WHERE katalogart  = @mv_katalogart AND
                          codegruppe  = @ls_error-fegrp AND
                          sprache     = @mv_spras INTO @ls_error-fegrp_ktxt.
          ENDIF.

          IF mv_katalogart = 'E'.
            mv_katalogart = 'Z'.
          ENDIF.

          SELECT SINGLE kurztext FROM qpct
                    WHERE katalogart  = @mv_katalogart AND
                          codegruppe  = @ls_error-fegrp AND
                          code        = @ls_error-fecod AND
                          sprache     = @mv_spras INTO @ls_error-fecod_ktxt.

          APPEND ls_error TO mt_legacy_error.
          CLEAR ls_error.
        ENDLOOP.
      ENDIF.
    ENDIF.

    SHIFT lf_besz RIGHT DELETING TRAILING ';'.
    ms_legacy-besz_cld = lf_besz.
  ENDMETHOD.

  METHOD get_repair_result.
    DATA: lf_repres     TYPE /cellag/repair_result,
          lf_repres_txt TYPE /cellag/repair_result_txt.

    DATA: lv_bemot TYPE afru-bemot,
          lv_stokz TYPE afru-stokz,
          lv_stzhl TYPE afru-stzhl.

    IF ms_legacy-old_serial_no IS NOT INITIAL AND ms_legacy-old_serial_no <> ms_legacy-new_serial_no.
      SELECT SINGLE repres_barc, repres_txt FROM zalca_rep_result
             
             WHERE bemot = 'RE'
               AND akz   = '' INTO ( @lf_repres, @lf_repres_txt ).
    ELSE.
      SELECT bemot, stokz, stzhl FROM afru
        WHERE aufnr = @mv_aufnr
          AND vornr = '9010' INTO ( @lv_bemot, @lv_stokz, @lv_stzhl ).
        IF lv_stokz = ' ' AND lv_stzhl = '00000000'.
          EXIT.
        ENDIF.
      ENDSELECT.
      IF sy-subrc = 0.
        SELECT SINGLE repres_barc, repres_txt FROM zalca_rep_result
           
           WHERE bemot = @lv_bemot
             AND akz   = @mv_qmcod INTO ( @lf_repres, @lf_repres_txt ).
        IF sy-subrc <> 0.
          SELECT SINGLE repres_barc, repres_txt FROM zalca_rep_result
           
           WHERE bemot = @lv_bemot
             AND akz   = '' INTO ( @lf_repres, @lf_repres_txt ).
        ENDIF.
      ENDIF.
    ENDIF.

    ms_legacy-repair_result     = lf_repres.
    ms_legacy-repair_result_txt = lf_repres_txt.
  ENDMETHOD.

  METHOD get_comment.
    DATA: lt_lines      TYPE TABLE OF tline,
          lf_qmnum_conv TYPE qmel-qmnum,
          lf_name       TYPE thead-tdname,
          lf_spras      TYPE sy-langu.

    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = mv_qmnum
      IMPORTING
        output = lf_qmnum_conv.

    lf_name = lf_qmnum_conv.

    SELECT SINGLE tdspras FROM stxh
      WHERE tdobject = 'QMEL'
        AND tdname   = @lf_name
        AND tdid     = 'LTXT' INTO @lf_spras.
    IF sy-subrc <> 0.
      lf_spras = mv_spras.
    ENDIF.

    CLEAR lt_lines.
    CALL FUNCTION 'READ_TEXT'
      EXPORTING
        id                      = 'LTXT'
        language                = lf_spras
        name                    = lf_name
        object                  = 'QMEL'
      TABLES
        lines                   = lt_lines
      EXCEPTIONS
        OTHERS                  = 8. "#EC CI_SUBRC

    mt_comment_lines = lt_lines.
  ENDMETHOD.

  METHOD get_astatus_data.
    DATA: ls_jcds  TYPE jcds,
          lt_jcds  TYPE TABLE OF jcds.

    SELECT objnr, stat, chgnr, udate, utime, inact FROM jcds  WHERE objnr = @iv_objnr AND stat = @co_wfer_stat INTO CORRESPONDING FIELDS OF TABLE @lt_jcds.

    IF lt_jcds IS NOT INITIAL.
      SORT lt_jcds DESCENDING BY udate utime DESCENDING.
      CLEAR: ls_jcds.
      READ TABLE lt_jcds INTO ls_jcds INDEX 1.

      IF ls_jcds IS NOT INITIAL.
        IF ls_jcds-inact IS NOT INITIAL.
          MESSAGE e029(/cellag/cs01) WITH mv_aufnr.
        ENDIF.
        ev_wfer_date  = ls_jcds-udate.
        ev_wfer_time  = ls_jcds-utime.
      ENDIF.
    ELSE.
      MESSAGE e028(/cellag/cs01) WITH mv_aufnr.
    ENDIF.
  ENDMETHOD.

  METHOD get_rlf_wedate.
    SELECT SINGLE erdat, erzet FROM likp  WHERE vbeln = @iv_vbeln_vl INTO ( @ev_vl_erdat, @ev_vl_zeit ).
  ENDMETHOD.

  METHOD get_retlief.
    DATA: lf_rmanr     TYPE vbap-vbeln,
          lf_posnv_rma TYPE posnr,
          lf_posnr_rma TYPE posnr,
          ls_comwa     TYPE vbco6,
          lt_vbfa      TYPE TABLE OF vbfa,
          ls_vbfa_rl   TYPE vbfa.

    SELECT SINGLE rmanr, posnr_rma, posnv_rma FROM afko
      
      WHERE aufnr = @mv_aufnr INTO ( @lf_rmanr, @lf_posnr_rma, @lf_posnv_rma ).
    ls_comwa-vbeln = lf_rmanr.
    ls_comwa-posnr = lf_posnv_rma.

    CALL FUNCTION 'RV_ORDER_FLOW_INFORMATION'
      EXPORTING
        comwa         = ls_comwa
      TABLES
        vbfa_tab      = lt_vbfa
      EXCEPTIONS
        OTHERS        = 3. "#EC CI_SUBRC

    READ TABLE lt_vbfa INTO ls_vbfa_rl
                       WITH KEY vbelv = lf_rmanr
                                vbtyp_n = 'T'
                                vbtyp_v = 'C'.
    es_vbfa = ls_vbfa_rl.
    ev_vbfa_rl = ls_vbfa_rl-vbeln.
  ENDMETHOD.

  METHOD convert_to_timestamp.
    CONVERT DATE iv_date TIME iv_time
    INTO TIME STAMP rv_tstamp TIME ZONE sy-zonlo.
  ENDMETHOD.
ENDCLASS.
