*&---------------------------------------------------------------------*
*&  Include           /CELLAG/ALCAREP02F01
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*&      Form  entry_sf
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM entry_sf.
  DATA l_fail VALUE abap_true.
*PERFORM check_if_swap USING pi_equnr CHANGING pc_equnr_rlf.
  PERFORM check_sernr_swap CHANGING gf_swap_flag gf_retlief_nr. "
*PERFORM get_retlief_from_aufnr CHANGING gf_retlief_nr gf_equnr_retlief.     " Retourenlieferung mit der LIEFNR und EQUNR

  PERFORM get_kddata.                               " get customer related data
  PERFORM get_part_data.                            " get parts related data
  PERFORM get_error_description CHANGING gf_qmnum gf_qmcod.  " get error descriptions
  PERFORM get_repair_result USING gf_qmnum gf_qmcod.         " get repair result
  PERFORM get_comment.                              " get comment

  PERFORM print_new USING abap_false CHANGING l_fail.
  IF l_fail IS NOT INITIAL."not included in new print logic : fallback to old
    PERFORM print_sf.                                 " Fehlereport
  ENDIF.

ENDFORM.                    "entry_sf

*&---------------------------------------------------------------------*
*&      Form  entry_pdf
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM entry_pdf.
  DATA l_fail VALUE abap_true.
*PERFORM check_if_swap USING pi_equnr CHANGING pc_equnr_rlf.
  PERFORM check_sernr_swap CHANGING gf_swap_flag gf_retlief_nr. "
*PERFORM get_retlief_from_aufnr CHANGING gf_retlief_nr gf_equnr_retlief.     " Retourenlieferung mit der LIEFNR und EQUNR

  PERFORM get_kddata.                               " get customer related data
  PERFORM get_part_data.                            " get parts related data
  PERFORM get_error_description CHANGING gf_qmnum gf_qmcod.  " get error descriptions
  PERFORM get_repair_result USING gf_qmnum gf_qmcod.         " get repair result
  PERFORM get_comment.                              " get comment
*------- create PDF -----------------*
  PERFORM print_new USING abap_true CHANGING l_fail.
  IF l_fail IS NOT INITIAL.
    PERFORM create_pdf.                               " create pdf and open popup window to save the document
  ENDIF.
ENDFORM.                    "entry_pdf

*&---------------------------------------------------------------------*
*&      Form  get_kddata
*&---------------------------------------------------------------------*
*       get customer related data and order master data
*----------------------------------------------------------------------*
FORM get_kddata.

  DATA: lf_kdauf     TYPE        aufk-kdauf,
        lf_aufnr     TYPE        aufk-aufnr,
        lf_kdpos     TYPE        aufk-kdpos,
        lf_objnr     TYPE        j_objnr,
        lf_wfer_date TYPE        dats,
        lf_wfer_time TYPE        tims,
        lf_vl_erdat  TYPE        likp-erdat,
        lf_vl_erzet  TYPE       likp-erzet,
        ls_vbfa_rl   TYPE        vbfa,
        lf_vbeln_vl  TYPE        vbeln_vl.

  DATA: lf_po_nr       TYPE        vbkd-bstkd_e,
        lf_po_pos      TYPE        vbkd-posex_e,

*        lf_ctdi_odernr    TYPE        vbak-qmnum,
        lf_qmnum       TYPE        vbak-qmnum,
        lf_fenum       TYPE        vbap-/cellag/fenum,
        lf_kvgr1       TYPE        vbak-kvgr1,
        lf_erdat       TYPE        auferfdat,
*        lf_tragr          TYPE        lips-tragr,
        lf_tabg_status TYPE        aufidat2,
        lf_erfzeit     TYPE        tims,
        lf_aezeit      TYPE        tims.
*        lf_time_puffer    TYPE        tims VALUE          '000060'

  lf_aufnr = p_aufnr.
* Benötigte Daten aus der AUFK Tabelle ermitteln
  CLEAR: lf_kdauf, lf_kdpos, lf_erdat, lf_tabg_status, lf_erfzeit, lf_aezeit, lf_objnr.
  SELECT SINGLE kdauf kdpos erdat idat2 erfzeit aezeit objnr FROM aufk
    INTO (lf_kdauf, lf_kdpos, lf_erdat, lf_tabg_status, lf_erfzeit, lf_aezeit, lf_objnr)
      WHERE aufnr = lf_aufnr.
*  lf_erfzeit = lf_erfzeit - 60.
  IF sy-subrc = 0.
    gf_kdauf = lf_kdauf.
*    PERFORM get_retlief                           CHANGING ls_vbfa_rl   lf_vbeln_vl.
    PERFORM get_astatus_data USING lf_objnr       CHANGING lf_wfer_date lf_wfer_time.
*    PERFORM get_rlf_wedate   USING lf_vbeln_vl   CHANGING lf_vl_erdat  lf_vl_erzet.
    PERFORM get_rlf_wedate   USING gf_retlief_nr    CHANGING lf_vl_erdat  lf_vl_erzet.

*   Uhrzeiten in die entsprechenden globalen Variablen updaten
    gf_time_received = lf_vl_erzet.
    gf_time_repaired = lf_wfer_time.
    gf_time_thisdate = sy-uzeit.
*   Bestellnummer des Kunden
    CLEAR:lf_po_nr.
    SELECT SINGLE bstkd FROM vbkd INTO lf_po_nr WHERE vbeln = lf_kdauf AND posnr = lf_kdpos.
    gf_po_nr   = lf_po_nr.
*   Z1-Meldungsnummer
    CLEAR: lf_qmnum, lf_kvgr1.
    SELECT SINGLE kvgr1 qmnum FROM vbak INTO (lf_kvgr1, lf_qmnum) WHERE vbeln = lf_kdauf.
    gf_qmnum = lf_qmnum.

    CLEAR: lf_fenum,lf_vbeln_vl,lf_po_pos.
    SELECT SINGLE /cellag/fenum /cellag/vbeln_vl posex FROM vbap INTO (lf_fenum, lf_vbeln_vl, lf_po_pos)
          WHERE vbeln = lf_kdauf AND posnr = lf_kdpos.
    gf_fenum   = lf_fenum.
    gf_po_pos  = lf_po_pos .
* check if we are in an intercompany process +caglioan 27.06.2013
    DATA: l_qmart    LIKE qmel-qmart.
    DATA: l_aufnr    TYPE aufnr.
    DATA: l_qmnum_u  TYPE qmnum.
    DATA: l_fenum_u  TYPE fenum.
    DATA: l_ebeln_u  TYPE ebeln.
    DATA: l_ebelp_u  TYPE ebelp.
    DATA: l_kdauf_u  TYPE kdauf.
    DATA: l_kdpos_u  TYPE kdpos.
    DATA: l_posex_u  LIKE vbap-posex.
    DATA: l_bstkd_u LIKE vbkd-bstkd.
*
    SELECT SINGLE qmart INTO l_qmart FROM qmel WHERE qmnum = gf_qmnum.
    IF l_qmart EQ co_zx_qmart.
      "get the Z1 Notification from the initial company
      SELECT SINGLE ebeln ebelp FROM qmfe INTO (l_ebeln_u, l_ebelp_u) WHERE qmnum = gf_qmnum AND fenum = gf_fenum.
      CLEAR:gf_qmnum,gf_fenum.
      SELECT SINGLE aufnr FROM ekkn INTO l_aufnr
                      WHERE ebeln = l_ebeln_u AND ebelp = l_ebelp_u.
      IF l_aufnr IS NOT INITIAL.
*        SELECT SINGLE qmnum FROM qmel INTO l_qmnum_u WHERE aufnr = l_aufnr.
*        gf_qmnum = l_qmnum_u.
        SELECT SINGLE kdauf kdpos FROM aufk INTO (l_kdauf_u, l_kdpos_u)
                      WHERE aufnr = l_aufnr.
        SELECT SINGLE /cellag/qmnum /cellag/fenum posex  FROM vbap INTO (l_qmnum_u, l_fenum_u, l_posex_u)
                      WHERE vbeln = l_kdauf_u AND posnr = l_kdpos_u.
        gf_fenum = l_fenum_u.
        gf_qmnum = l_qmnum_u.
* die Bestellnummer aus dem Werk A (Ursprungswerk Intercompany) ermitteln
        SELECT SINGLE bstkd FROM vbkd INTO l_bstkd_u WHERE vbeln = l_kdauf_u AND posnr = l_kdpos_u.
        CLEAR:gf_po_nr,gf_po_pos.
        gf_po_pos = l_posex_u.
        gf_po_nr  = l_bstkd_u.

      ENDIF.
    ENDIF.
    CONCATENATE gf_qmnum '-' gf_fenum INTO gf_ctdi_odernr. " @@@ Bindestrich ??? required or NOT ?

  ENDIF.

  /cellag/alcarep-csaufnr         = p_aufnr.
  /cellag/alcarep-sernr           = p_sernr.
  /cellag/alcarep-po_no           = gf_po_nr.
  /cellag/alcarep-po_item_no      = gf_po_pos.
  /cellag/alcarep-ctdi_order_no   = gf_ctdi_odernr.
* /cellag/alcarep-date_received   = lf_erdat .                  " WE Datum der Retourenlieferung @@@ ist das so?
  /cellag/alcarep-date_received   = lf_vl_erdat .               " WE Datum der Retourenlieferung @@@ ist das so?
  /cellag/alcarep-date_repaired   = lf_wfer_date.               " Datum Status = WFER (Werkstatt fertig)
  /cellag/alcarep-date_current    = sy-datum.                   " aktuelles Datum als Referenz

*MK 20140102 Kundengruppe wegen Überschrift und LOGO (ITALTEL)
  /cellag/alcarep-kvgr1           = lf_kvgr1.
****************************************************

ENDFORM.                    "get_kddata


*&---------------------------------------------------------------------*
*&      Form  get_part_data
*&---------------------------------------------------------------------*
*       get part data
*----------------------------------------------------------------------*
FORM get_part_data.
  DATA: lf_oldpartnr   TYPE              itob-mapar,
        lf_newpartnr   TYPE              itob-mapar,

        lf_oldserialnr TYPE              itob-serge,
        lf_newserialnr TYPE              itob-serge,

        lv_oldmatnr    TYPE              matnr,             "HB140215
        lv_newmatnr    TYPE              matnr,             "HB140215

        lf_equnr       TYPE              equnr,          " Equipmentnummer aus dem CS-Auftrag
        lf_equnr_rlf   TYPE              equnr,          " Equipmentnummer aus der Retourenlieferung
*          lf_eqlfn_penultimate  TYPE              eqlfn,
*          lf_eqlfn_last         TYPE              eqlfn.

        lv_p_sernr     TYPE              equi-sernr.

  TYPES: BEGIN OF ls_revs,
           mdocm TYPE imrc_mdocm,
           mdtxt TYPE imrc_mdtxt,
         END OF ls_revs.
*--------------------------------------------------------------*
*get revision data / maybe we should move this coding to a form
*--------------------------------------------------------------*
  DATA: lf_rev_in         TYPE              imrc_mdtxt,
        lf_rev_out        TYPE              imrc_mdtxt,
        lf_objnr          TYPE              imptt-mpobj,
        lf_point          TYPE              imrc_point,
        lf_max_imrg_mdocm TYPE              imrc_mdocm,
        lf_eqktx          TYPE              ktx01,
        lt_revs           TYPE TABLE OF     ls_revs,
        ls_revs_out       TYPE              ls_revs,
        ls_revs_in        TYPE              ls_revs,
        lin               TYPE              p.

*&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
*/cellag/alcarep-date_received
*/cellag/alcarep-date_repaired
  DATA: lf_udate           TYPE            cddatum,
        lf_utime           TYPE            cduzeit,
*         lf_changenr                TYPE            cdchangenr,
        lf_tstamp_received TYPE            timestamp,
*         lf_tstamp_changed_first    TYPE            timestamp,
        lf_tstamp_changed  TYPE            timestamp,
*         lf_tstamp_changed_last     TYPE            timestamp,
        lf_tstamp_repaired TYPE            timestamp,
        lf_tstamp_thisdate TYPE            timestamp,
*         lt_cdpos                   TYPE  TABLE OF  cdpos,
        ls_cdpos           TYPE            cdpos,
        ls_cdpos_first     TYPE            cdpos,
*         ls_cdpos_last              TYPE            cdpos,
        ls_cdpos_serge     TYPE            cdpos,
        ls_cdpos_mapar     TYPE            cdpos,
*         ls_cdhdr_first             TYPE            cdhdr,
*         ls_cdhdr_last              TYPE            cdhdr,
        lt_cdhdr           TYPE TABLE OF   cdhdr,
        lt_cdhdr_serge     TYPE TABLE OF   cdhdr,
        lt_cdhdr_mapar     TYPE TABLE OF   cdhdr,
        ls_cdhdr           TYPE            cdhdr,
        lines              TYPE            i.

  DATA:  lt_order_objk              TYPE TABLE OF objk.

  FIELD-SYMBOLS:
         <ls_objk>                  TYPE objk.

* Es gibt 3 Fälle, wie die alte bzw. neue HTN (Herstellerteilenummer) und HSNR (Herstellersernr) ermittelt werden
* FALL 1 : Equipmentnummern aus dem CS-Auftrag und Retourenlieferung ungleich    => ein Tausch hat stattgefunden
* FALL 2 : Equipmentnummern aus dem CS-Auftrag und Retourenlieferung sind gleich => kein Tausch => HTN+HSNR kommen aus den Änderungsbelegen
* FALL 3 : Equipmentnummern aus dem CS-Auftrag und Retourenlieferung sind gleich, aber kein Änderungsbeleg zwischen WE und TABG vorhanden =>
*          => NUR die neuen Daten werden ermittelt und zwar direkt aus EQUI und EQUZ die neue HTSerNr und Herst.PartNr. (OLD bleibt LEER beim Ausdruck)

* get equnr

  "Aufruf aus ZERC: p_sernr ggf./meist nicht befüllt!  HB150215
  lv_p_sernr = p_sernr.
  IF lv_p_sernr IS INITIAL.
    "Nachlesen
    CALL FUNCTION '/CELLAG/CS_ORDER_SERNR_GET'
      EXPORTING
        i_aufnr       = p_aufnr
      TABLES
        et_order_objk = lt_order_objk.
    LOOP AT lt_order_objk ASSIGNING <ls_objk>.
      lv_p_sernr = <ls_objk>-sernr.
      EXIT. "ersten nehmen
    ENDLOOP. " at LT_ORDER_OBJK
  ENDIF.


  SELECT SINGLE equnr FROM equi INTO (lf_equnr) WHERE sernr = lv_p_sernr.
  IF lf_equnr IS NOT INITIAL.
* prüfen ob das Equipment ausgetauscht wurde.
*    PERFORM check_if_swap USING lf_equnr CHANGING lf_equnr_rlf.
* falls die Equipmentnummer aus dem CS-Auftrag <> Equipmentnummer aus dem Retourenlieferung, dann old_partnumber und old_sernr aus dem
* Equipment der Retourenlieferung

***********************
*   IF SWAP           *
***********************
*    IF lf_equnr <> gf_equnr_retlief .                       " FALL 1
    IF gf_swap_flag IS NOT INITIAL .                        " FALL 1
      SELECT SINGLE serge
                    matnr                                   "HB140215
         FROM equi INTO
         (lf_newserialnr,
          lv_newmatnr)
         WHERE equnr = lf_equnr.
      SELECT SINGLE mapar FROM equz INTO lf_newpartnr   WHERE equnr = lf_equnr.
*      SELECT SINGLE serge FROM equi INTO lf_oldserialnr WHERE equnr = lf_equnr_rlf.
      SELECT SINGLE serge
                    matnr                                   "HB140215
         FROM equi INTO
         (lf_oldserialnr,
          lv_oldmatnr)
         WHERE equnr = gf_equnr_retlief.
*      SELECT SINGLE mapar FROM equz INTO lf_oldpartnr   WHERE equnr = lf_equnr_rlf.
      SELECT SINGLE mapar FROM equz INTO lf_oldpartnr   WHERE equnr = gf_equnr_retlief.
    ELSE.                                                   " FALL 2
*  wenn die Equipmentnummern aus dem CS-Auftrag und Retourenlieferung gleich sind, dann holen wir uns die old/new-serialnr/partnr aus den Änderungsbelegen zum Equipment
      SELECT * FROM cdhdr INTO TABLE lt_cdhdr WHERE objectclas = 'EQUI' AND objectid = lf_equnr.

      IF lt_cdhdr IS NOT INITIAL.
        lines = lines( lt_cdhdr ).
        PERFORM convert_to_timestamp USING /cellag/alcarep-date_received gf_time_received  CHANGING lf_tstamp_received.
        PERFORM convert_to_timestamp USING /cellag/alcarep-date_repaired gf_time_repaired  CHANGING lf_tstamp_repaired.
        PERFORM convert_to_timestamp USING /cellag/alcarep-date_current  gf_time_thisdate  CHANGING lf_tstamp_thisdate.
        IF lines > 1.
*################### LOOP über die Änderungsbelege  #######################
          CLEAR:ls_cdhdr.
*   SERGE
          LOOP AT lt_cdhdr INTO ls_cdhdr.
            CLEAR: ls_cdpos_serge.
            SELECT SINGLE * FROM cdpos INTO ls_cdpos_first
                WHERE objectclas = 'EQUI' AND objectid = lf_equnr AND changenr = ls_cdhdr-changenr AND tabname = 'EQUI' AND fname = 'SERGE'.
            IF sy-subrc = 0.
              APPEND ls_cdhdr TO lt_cdhdr_serge.
            ENDIF.
*    MAPAR
            CLEAR: ls_cdpos_mapar.
            SELECT SINGLE * FROM cdpos INTO ls_cdpos_mapar
                WHERE objectclas = 'EQUI' AND objectid = lf_equnr AND changenr = ls_cdhdr-changenr AND tabname = 'EQUZ' AND fname = 'MAPAR'.
            IF sy-subrc = 0.
              APPEND ls_cdhdr TO lt_cdhdr_mapar.
            ENDIF.
          ENDLOOP.
*################### ENDLOOP über die Änderungsbelege  #######################
* get SERGE (old/new)
          IF lt_cdhdr_serge IS NOT INITIAL.
            PERFORM get_last_record USING lt_cdhdr_serge
                                          lf_equnr
                                          lf_tstamp_received
                                          lf_tstamp_repaired
                                          'SERGE'
                                    CHANGING
                                          lf_oldserialnr
                                          lf_newserialnr.
          ELSE.
            SELECT SINGLE serge FROM equi INTO lf_newserialnr WHERE equnr = lf_equnr.
            lf_oldserialnr = lf_newserialnr.                "05122011
          ENDIF.
* get MAPAR (old/new)
          IF lt_cdhdr_mapar IS NOT INITIAL.
            PERFORM get_last_record USING lt_cdhdr_mapar
                                          lf_equnr
                                          lf_tstamp_received
                                          lf_tstamp_repaired
                                          'MAPAR'
                                    CHANGING
                                          lf_oldpartnr
                                          lf_newpartnr.
          ELSE.
            SELECT SINGLE mapar FROM equz INTO lf_newpartnr WHERE equnr = lf_equnr.
            lf_oldpartnr = lf_newpartnr.                    "05122011
          ENDIF.
        ELSEIF lines = 1.
          CLEAR: ls_cdhdr, lf_udate, lf_utime .
          READ TABLE lt_cdhdr INTO ls_cdhdr INDEX 1.
          lf_udate = ls_cdhdr-udate.
          lf_utime = ls_cdhdr-utime.
          PERFORM convert_to_timestamp USING lf_udate lf_utime                               CHANGING lf_tstamp_changed .
          IF lf_tstamp_received <= lf_tstamp_changed AND lf_tstamp_changed <= lf_tstamp_repaired.
            CLEAR:ls_cdpos.
            SELECT SINGLE * FROM cdpos INTO ls_cdpos
                WHERE objectclas = 'EQUI' AND objectid = lf_equnr AND changenr = ls_cdhdr-changenr AND tabname = 'EQUI' AND fname = 'SERGE'.
            IF sy-subrc = 0.
              lf_oldserialnr = ls_cdpos-value_old.
              lf_newserialnr = ls_cdpos-value_new.
            ELSE.
              SELECT SINGLE serge FROM equi INTO lf_newserialnr WHERE equnr = lf_equnr.
              lf_oldserialnr = lf_newserialnr.              "05122011
            ENDIF.
            CLEAR:ls_cdpos.
            SELECT SINGLE * FROM cdpos INTO ls_cdpos WHERE objectclas = 'EQUI' AND objectid = lf_equnr AND changenr = ls_cdhdr-changenr AND tabname = 'EQUZ' AND fname = 'MAPAR'.
            IF sy-subrc = 0.
              lf_oldpartnr = ls_cdpos-value_old.
              lf_newpartnr = ls_cdpos-value_new.
            ELSE.
              SELECT SINGLE mapar FROM equz INTO lf_newpartnr WHERE equnr = lf_equnr.
              lf_oldpartnr = lf_newpartnr.                  "05122011
            ENDIF.
          ENDIF.
        ENDIF.
** wenn keine Änderungsbelege vorhanden sind
      ELSE.
*       Liegt keine Änderung im Zeitraum vor, wird links UND rechts das gleiche gedruckt. Aus EQUI Stamm.-->email 02.12.2011 von U.Sellmer!
*       herst.sernr aus EQUI
        SELECT SINGLE serge
                      matnr                                 "HB140215
          FROM equi INTO
         (lf_newserialnr,
          lv_newmatnr)
         WHERE equnr = lf_equnr.
        lf_oldserialnr = lf_newserialnr.
*       herst-teilenr aus EQUZ
        SELECT SINGLE mapar FROM equz INTO lf_newpartnr WHERE equnr = lf_equnr.
        lf_oldpartnr = lf_newpartnr.
      ENDIF.

    ENDIF.
**************
*** FALL 3 ***
**************
* falls die Suche in den Änderungsbelegen erfolglos ist, dann direkt aus EQUI und EQUZ die neue HTSerNr und Herst.PartNr. / +caglivoan 15112011
    IF lf_newserialnr IS INITIAL.
      SELECT SINGLE serge
                    matnr                                   "HB140215
        FROM equi INTO
         (lf_newserialnr,
          lv_newmatnr)
         WHERE equnr = lf_equnr.
      lf_oldserialnr = lf_newserialnr.
    ENDIF.

    IF lf_newpartnr IS INITIAL.
      SELECT SINGLE mapar FROM equz INTO lf_newpartnr WHERE equnr = lf_equnr.
      lf_oldpartnr = lf_newpartnr.
    ENDIF.

    "--------------------------------------------------------------------------------------------
    "Workaround: falls lf_oldpartnr leer oder lf_newpartnr lerr, jeweils nachlesen aus Matstamm HB140215
    "--------------------------------------------------------------------------------------------
    IF lf_newpartnr IS INITIAL.
      IF lv_newmatnr IS INITIAL.
        "nachlesen
        SELECT SINGLE matnr                                 "HB140215
          FROM equi INTO lv_newmatnr
           WHERE equnr = lf_equnr.
      ENDIF.
      IF NOT lv_newmatnr IS INITIAL.
        SELECT SINGLE mfrpn
          FROM mara
          INTO lf_newpartnr
          WHERE matnr = lv_newmatnr.
      ENDIF.
    ENDIF.

    IF lf_oldpartnr IS INITIAL.
      IF lv_oldmatnr IS INITIAL.
        "nachlesen
        SELECT SINGLE matnr                                 "HB140215
          FROM equi INTO lv_oldmatnr
           WHERE equnr = gf_equnr_retlief.
      ENDIF.
      IF NOT lv_oldmatnr IS INITIAL.
        SELECT SINGLE mfrpn
          FROM mara
          INTO lf_oldpartnr
          WHERE matnr = lv_oldmatnr.
      ENDIF.
    ENDIF.

*   die globalen Variablen plus die zu übergebende Struktur an das Smartform werden hier upgedated. ToDo: get rid of global variables!!!
*    CLEAR: gf_oldserialnr, gf_newserialnr, gf_oldpartnr, gf_newpartnr.
*    gf_oldserialnr = lf_oldserialnr.
*    gf_newserialnr = lf_newserialnr. "@@@  TO DO ??? n dieser Stelle nachhacken ???
*    gf_oldpartnr   = lf_oldpartnr.
*    gf_newpartnr   = lf_newpartnr.

    /cellag/alcarep-old_serial_no = lf_oldserialnr.
    /cellag/alcarep-new_serial_no = lf_newserialnr.
    /cellag/alcarep-old_part_no   = lf_oldpartnr.
    /cellag/alcarep-new_part_no   = lf_newpartnr.

  ELSE.
    MESSAGE e024 WITH p_sernr.
  ENDIF.
*#################################  END suche nach dem neuen und alten HERST-SERNR ####################################
*  TEXTE
  SELECT SINGLE eqktx FROM eqkt INTO lf_eqktx
    WHERE equnr = lf_equnr AND spras = gf_spras.   " @@@ SPRACHE

  /cellag/alcarep-model = lf_eqktx.
*-------------------------------------------------------------------*
* get revision get data / maybe we should move this coding to a form
*-------------------------------------------------------------------*
* Z2 Meldung finden und Daten versorgen zu STAND IN OUT *{+nta140717
* get AFIH
  DATA: ls_afih TYPE afih.
  DATA: l_qmnum TYPE qmel-qmnum.
  SELECT SINGLE * INTO ls_afih FROM afih WHERE aufnr = p_aufnr.
  IF NOT ls_afih-qmnum IS INITIAL.
*   qmnum aus AFIH
    l_qmnum = ls_afih-qmnum.
  ELSE.
*   qmnum aus OBJECT LIST
    SELECT SINGLE ihnum INTO l_qmnum FROM objk
     WHERE obknr = ls_afih-obknr
       AND ihnum <> space.
  ENDIF.
* stand abholen IN OUT zum Prozess
  DATA: ls_qmel TYPE qmel.
  IF NOT l_qmnum IS INITIAL.
    SELECT SINGLE * INTO ls_qmel FROM qmel
      WHERE qmnum = l_qmnum.
  ENDIF.
* Übergabe STAND
  DATA: BEGIN OF ls_eqstand.
          INCLUDE STRUCTURE /cellag/cseqstand_in.
          INCLUDE STRUCTURE /cellag/cseqstand_out.
        DATA: END   OF ls_eqstand.
  IF NOT ls_qmel IS INITIAL.
    /cellag/alcarep-rev_in  = ls_qmel-revin.
    /cellag/alcarep-rev_out = ls_qmel-revout.
    MOVE-CORRESPONDING ls_qmel    TO ls_eqstand.
    MOVE-CORRESPONDING ls_eqstand TO /cellag/alcarep.
  ENDIF.
*}+nta140717
*-------------------------------------------------------------------*
*{-nta140717 STAND aus Z2 MELDUNG keine MPB
*  SELECT SINGLE objnr FROM equi INTO lf_objnr WHERE equnr =  lf_equnr.
*
*  SELECT SINGLE point FROM imptt INTO lf_point WHERE mpobj = lf_objnr AND psort = co_equi_vers.  " IE000000000000310001
*
*  IF sy-subrc = 0.
*    SELECT  SINGLE MAX( mdocm ) FROM imrg INTO lf_max_imrg_mdocm
*         WHERE point = lf_point.
*
*    SELECT  mdocm mdtxt  FROM imrg INTO CORRESPONDING FIELDS OF TABLE lt_revs UP TO 2 ROWS
*         WHERE point = lf_point ORDER BY mdocm DESCENDING.
*
**    CLEAR: lf_rev_out, lf_rev_in.
**    SELECT SINGLE mdtxt FROM imrg INTO lf_rev_out
**             WHERE point = lf_point AND mdocm = lf_max_imrg_mdocm.
*  ENDIF.
*
*  DESCRIBE TABLE lt_revs LINES lin.
*
*  CASE lin.
*    WHEN 2.
*      READ TABLE lt_revs INTO ls_revs_out INDEX 1.
*      lf_rev_out = ls_revs_out-mdtxt.
*      READ TABLE lt_revs INTO ls_revs_in INDEX 2.
*      lf_rev_in = ls_revs_in-mdtxt.
*
*    WHEN 1.
*      READ TABLE lt_revs INTO ls_revs_out INDEX 1.
*      lf_rev_out = ls_revs_out-mdtxt.
*      lf_rev_in =  ls_revs_out-mdtxt.
*
*    WHEN 0.
*      " do nothing
*  ENDCASE.
*  *}-nta140717 STAND aus Z2 MELDUNG
ENDFORM.                    "get_part_data


*&-----------------------------------------------------------------------*
*&      Form  get_qmnum
*&-----------------------------------------------------------------------*
*       get the texts related to: "Code Group Causes" and "Cause Code"
*------------------------------------------------------------------------*
FORM get_error_description CHANGING fc_qmnum fc_qmcod.

  DATA:
    lf_qmnum           TYPE              qmnum,
    lf_qmcod           TYPE              qmel-qmcod,
    lf_besz_string(30) TYPE              c,
    lf_besz            TYPE              string,
    lt_error           TYPE TABLE OF     /cellag/alcarep_error,
    ls_error           LIKE LINE OF      lt_error.

  SELECT SINGLE qmnum qmcod FROM qmel INTO (lf_qmnum, lf_qmcod) WHERE aufnr = p_aufnr AND qmart = co_qmart.

  IF sy-subrc = 0.
    fc_qmnum = lf_qmnum.
    fc_qmcod = lf_qmcod.
*    SELECT qmnum fenum urnum urgrp urcod INTO CORRESPONDING FIELDS OF TABLE lt_error
*                               FROM qmur WHERE qmnum = lf_qmnum.

    SELECT otgrp oteil fegrp fecod besz INTO CORRESPONDING FIELDS OF TABLE lt_error FROM qmfe
      WHERE qmnum = lf_qmnum
      ORDER BY PRIMARY KEY.   "INS S4CONV ECC - HPC(2508-614)

    IF lt_error IS NOT INITIAL.
      LOOP AT lt_error INTO ls_error.
        lf_besz_string = ls_error-besz.
        CONCATENATE lf_besz lf_besz_string '; ' INTO lf_besz.
        IF /cellag/alcarep-kvgr1 = '0SU'.
          gf_katalogart = 'E'.
        ELSE.
          gf_katalogart = 'Z'.
        ENDIF.
        IF gf_katalogart = 'Z'.
          SELECT SINGLE  kurztext FROM qpgt INTO  ls_error-otgrp_ktxt
                  WHERE katalogart  =   gf_katalogart AND
                        codegruppe  =   ls_error-otgrp AND
                        sprache     =   gf_spras.
        ENDIF.
        SELECT SINGLE  kurztext FROM qpct INTO  ls_error-oteil_ktxt
                  WHERE katalogart  =   gf_katalogart AND
                        codegruppe  =   ls_error-otgrp AND
                        code        =   ls_error-oteil AND
                        sprache     =   gf_spras.
        IF gf_katalogart = 'Z'.
          SELECT SINGLE  kurztext FROM qpgt INTO  ls_error-fegrp_ktxt
                  WHERE katalogart  =   gf_katalogart AND
                        codegruppe  =   ls_error-fegrp AND
                        sprache     =   gf_spras.
        ENDIF.
        IF gf_katalogart = 'E'.
          gf_katalogart = 'Z'.
        ENDIF.
        SELECT SINGLE  kurztext FROM qpct INTO  ls_error-fecod_ktxt
                  WHERE katalogart  =   gf_katalogart AND
                        codegruppe  =   ls_error-fegrp AND
                        code        =   ls_error-fecod AND
                        sprache     =   gf_spras.
        APPEND ls_error TO /cellag/alcarep_error.
        CLEAR ls_error.
      ENDLOOP.
    ENDIF.
  ENDIF.
* Aufbereitung für die Ausgabe: lösche das letzte Semikolon.
  SHIFT lf_besz RIGHT DELETING TRAILING ';' .

  /cellag/alcarep-besz_cld = lf_besz.
ENDFORM.                    "get_qmnum

*&---------------------------------------------------------------------*
*&      Form  get_repair_result
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->FI_QMNUM   text
*----------------------------------------------------------------------*
FORM get_repair_result USING fi_qmnum fi_qmcod.
  DATA:
    lf_qmnum      TYPE              qmel-qmnum,
*        lf_fenum                TYPE              fenum,
*        lf_fegrp                TYPE              qmfe-fegrp,
*        lf_fecod                TYPE              qmfe-fecod,
*        lf_qmgrp                TYPE              qmgrp,
    lf_qmcod      TYPE              qmcod,
*        lf_erdat                TYPE              erdat,
    lf_repres     TYPE              /cellag/repair_result,
    lf_repres_txt TYPE              /cellag/repair_result_txt.

  DATA: l_bemot TYPE afru-bemot,
        l_stokz TYPE afru-stokz,
        l_stzhl TYPE afru-stzhl,
        l_akz   TYPE qmel-qmcod.

  CLEAR lf_qmnum.
  lf_qmnum = fi_qmnum.
  lf_qmcod = fi_qmcod.
*  SELECT SINGLE fenum fegrp fecod otgrp oteil FROM qmfe INTO (lf_fenum, lf_fegrp, lf_fecod, lf_otgrp, lf_oteil)
*      WHERE qmnum = lf_qmnum. " this works because the
*  SELECT urgrp urcod erdat FROM qmur INTO (lf_urgrp, lf_urcod, lf_erdat) UP TO 1 ROWS
*    WHERE qmnum = lf_qmnum AND kzloesch NE 'X' ORDER BY erdat.
*  ENDSELECT.

*  SELECT SINGLE qmgrp qmcod FROM qmel INTO (lf_qmgrp,lf_qmcod) WHERE qmnum = lf_qmnum.
*
*  IF sy-subrc = 0.
*    CLEAR:lf_repres, lf_repres_txt.
*    SELECT SINGLE repair_result repairresult_txt FROM /cellag/rep_res INTO (lf_repres, lf_repres_txt)
*        WHERE urgrp = lf_qmgrp AND urcod = lf_qmcod.
*  ENDIF.

  IF /cellag/alcarep-old_serial_no IS NOT INITIAL AND /cellag/alcarep-old_serial_no NE /cellag/alcarep-new_serial_no.
    SELECT SINGLE repres_barc repres_txt FROM zalca_rep_result
           INTO (lf_repres, lf_repres_txt)
                   WHERE bemot = 'RE' "Repairersatz
                     AND akz   = ''.
  ELSE."MK 04112015 BG nicht getauscht
    SELECT bemot stokz stzhl FROM afru INTO (l_bemot, l_stokz, l_stzhl)
                                WHERE aufnr = p_aufnr
                                  AND vornr = '9010'.
      IF l_stokz = ' ' AND l_stzhl = '00000000'.
        EXIT.
      ENDIF.
    ENDSELECT.
    IF sy-subrc = 0.
*          select single qmcod from qmel into l_akz where qmnum = lf_qmnum.
*          if sy-subrc = 0.
      SELECT SINGLE repres_barc repres_txt FROM zalca_rep_result
         INTO (lf_repres, lf_repres_txt)
                 WHERE bemot = l_bemot
                   AND akz   = lf_qmcod.
      IF sy-subrc NE 0.
        SELECT SINGLE repres_barc repres_txt FROM zalca_rep_result
         INTO (lf_repres, lf_repres_txt)
                 WHERE bemot = l_bemot
                   AND akz   = ''.
      ENDIF.
*          endif.
    ENDIF.
  ENDIF.

  /cellag/alcarep-repair_result     = lf_repres.
  /cellag/alcarep-repair_result_txt = lf_repres_txt.

*  CONCATENATE lf_qmnum '-' lf_fenum INTO gf_ctdi_odernr.
*  /cellag/alcarep-ctdi_order_no   = gf_ctdi_odernr.

ENDFORM.                    "get_repair_result


*&---------------------------------------------------------------------*
*&      Form  get_comment
*&---------------------------------------------------------------------*
*       get comment
*----------------------------------------------------------------------*
FORM get_comment.

  DATA:
    lt_lines      TYPE TABLE OF     tline,
*        ls_lines           TYPE              tline,
    lf_qmnum_conv TYPE              qmel-qmnum,
    lf_name       TYPE              thead-tdname.

  DATA: lf_spras                TYPE                sy-langu.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = gf_qmnum
    IMPORTING
      output = lf_qmnum_conv.

  lf_name = lf_qmnum_conv.

  SELECT SINGLE tdspras FROM stxh INTO lf_spras
                                         WHERE tdobject = 'QMEL'
                                         AND   tdname   = lf_name
                                         AND   tdid     = 'LTXT'.
  IF sy-subrc NE 0.
    lf_spras = gf_spras.
  ENDIF.

  CLEAR lt_lines.
  CALL FUNCTION 'READ_TEXT'
    EXPORTING
*     CLIENT                  = SY-MANDT
      id                      = 'LTXT'
      language                = lf_spras
      name                    = lf_name
      object                  = 'QMEL'
*     ARCHIVE_HANDLE          = 0
*     LOCAL_CAT               = ' '
*   IMPORTING
*     HEADER                  =
    TABLES
      lines                   = lt_lines
    EXCEPTIONS
      id                      = 1
      language                = 2
      name                    = 3
      not_found               = 4
      object                  = 5
      reference_check         = 6
      wrong_access_to_archive = 7
      OTHERS                  = 8.
*  IF sy-subrc <> 0.
*    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
*  ENDIF.

  gt_comment_lines = lt_lines.

ENDFORM.                    "get_comment

*&---------------------------------------------------------------------*
*&      Form  create_pdf
*&---------------------------------------------------------------------*
*       create the Repair Report as a PDF file and save it into the
*     filesystem (user option).
*----------------------------------------------------------------------*
FORM create_pdf.

  DATA: output_options       TYPE                      ssfcompop,
        control_parameters   TYPE                      ssfctrlop,
        document_output_info TYPE                      ssfcrespd,
        job_output_info      TYPE                      ssfcrescl.

  DATA: name     TYPE                      string,
        path     TYPE                      string,
        fullpath TYPE                      string,
*        ext                     TYPE                      string,
        filter   TYPE                      string,
*        size                    TYPE                      i,
        guiobj   TYPE REF TO               cl_gui_frontend_services,
        uact     TYPE i.

  DATA:
*        it_otf                  TYPE STANDARD TABLE OF    itcoo,
    it_docs        TYPE STANDARD TABLE OF    docs,
    it_pdf_output  TYPE STANDARD TABLE OF    tline,
    l_language     TYPE                      sflangu                             VALUE 'D',
    l_devtype      TYPE                      rspoptype,
    l_bin_filesize TYPE                      i,
*        l_name                  TYPE                      string,
*        l_path                  TYPE                      string,
*        l_fullpath              TYPE                      string,
*        l_filter                TYPE                      string,
*        l_uact                  TYPE                      i,
*        l_guiobj                TYPE REF TO               cl_gui_frontend_services,
    l_funcname     TYPE                      funcname,
    lf_formname    TYPE                      tdsfname.
*      l_fm_name type rs38l_fnam.

  lf_formname = co_formname.

  CALL FUNCTION 'SSF_FUNCTION_MODULE_NAME'
    EXPORTING
      formname           = lf_formname
*     variant            = ' '
*     direct_call        = ' '
    IMPORTING
      fm_name            = l_funcname
    EXCEPTIONS
      no_form            = 1
      no_function_module = 2
      OTHERS             = 3.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

  CALL FUNCTION 'SSF_GET_DEVICE_TYPE'
    EXPORTING
*     i_language    = l_language
      i_language    = gf_spras
      i_application = 'SAPDEFAULT'
    IMPORTING
      e_devtype     = l_devtype.

  output_options-tdprinter  = l_devtype.
  output_options-tddest     = ''.                           "  'YN29'.
  control_parameters-no_dialog = 'X'.
  control_parameters-getotf = 'X'.

*  wa_zalcarep02-tdname = '100000000030100000001'. "TEST

*  CALL FUNCTION '/1BCDWB/SF00000011'
*    EXPORTING
**                   ARCHIVE_INDEX               =
**                   ARCHIVE_INDEX_TAB           =
**                   ARCHIVE_PARAMETERS          =
**                   CONTROL_PARAMETERS          =
**                   MAIL_APPL_OBJ               =
**                   MAIL_RECIPIENT              =
**                   MAIL_SENDER                 =
**                   OUTPUT_OPTIONS              =
**                   USER_SETTINGS               = 'X'
*      /cellag/alcarep             =
**                 IMPORTING
**                   DOCUMENT_OUTPUT_INFO        =
**                   JOB_OUTPUT_INFO             =
**                   JOB_OUTPUT_OPTIONS          =
*    tables
*      /cellag/alcarep_error       =
**                 EXCEPTIONS
**                   FORMATTING_ERROR            = 1
**                   INTERNAL_ERROR              = 2
**                   SEND_ERROR                  = 3
**                   USER_CANCELED               = 4
**                   OTHERS                      = 5
*            .
*  IF sy-subrc <> 0.
** MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
**         WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
*  ENDIF.


  CALL FUNCTION l_funcname
    EXPORTING
      user_settings         = ' '
      /cellag/alcarep       = /cellag/alcarep
      control_parameters    = control_parameters
      output_options        = output_options
    IMPORTING
      document_output_info  = document_output_info
      job_output_info       = job_output_info
    TABLES
      /cellag/alcarep_error = /cellag/alcarep_error
      gt_comment_lines      = gt_comment_lines
    EXCEPTIONS
      formatting_error      = 1
      internal_error        = 2
      send_error            = 3
      user_canceled         = 4
      OTHERS                = 5.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

***********CONVERT_OTF_2_PDF***********
***************************************
  CALL FUNCTION 'CONVERT_OTF_2_PDF'
    IMPORTING
      bin_filesize           = l_bin_filesize
    TABLES
      otf                    = job_output_info-otfdata
      doctab_archive         = it_docs
      lines                  = it_pdf_output
    EXCEPTIONS
      err_conv_not_possible  = 1
      err_otf_mc_noendmarker = 2
      OTHERS                 = 3.
  IF sy-subrc NE 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

**************DOWNLOAD_PDF*************
***************************************
  name = 'test.pdf'.
  filter = '(*.pdf)|*.pdf|'.

  CREATE OBJECT guiobj.
  CALL METHOD guiobj->file_save_dialog
    EXPORTING
      default_extension = 'pdf'
      default_file_name = name
      file_filter       = filter
    CHANGING
      filename          = name
      path              = path
      fullpath          = fullpath
      user_action       = uact.
  IF uact = guiobj->action_cancel.
    EXIT.
  ENDIF.

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      bin_filesize            = l_bin_filesize
      filename                = fullpath
      filetype                = 'BIN'
    TABLES
      data_tab                = it_pdf_output
    EXCEPTIONS
      file_write_error        = 1
      no_batch                = 2
      gui_refuse_filetransfer = 3
      invalid_type            = 4
      no_authority            = 5
      unknown_error           = 6
      header_not_allowed      = 7
      separator_not_allowed   = 8
      filesize_not_allowed    = 9
      header_too_long         = 10
      dp_error_create         = 11
      dp_error_send           = 12
      dp_error_write          = 13
      unknown_dp_error        = 14
      access_denied           = 15
      dp_out_of_memory        = 16
      disk_full               = 17
      dp_timeout              = 18
      file_not_found          = 19
      dataprovider_exception  = 20
      control_flush_error     = 21.
  IF sy-subrc NE 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

ENDFORM.                    "create_pdf


*&---------------------------------------------------------------------*
*&      Form  print_sf
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM print_sf.
  DATA:
    ls_output_options    TYPE                      ssfcompop,
    control_parameters   TYPE                      ssfctrlop,
    document_output_info TYPE                      ssfcrespd,
    job_output_info      TYPE                      ssfcrescl,
    lf_prog              TYPE                      sy-repid.

  DATA:
    name     TYPE                      string,
    path     TYPE                      string,
    fullpath TYPE                      string,
*       ext                     TYPE                      string,
    filter   TYPE                      string,
*       size                    TYPE                      i,
    guiobj   TYPE REF TO               cl_gui_frontend_services,
    uact     TYPE                      i.

  DATA:
*       it_otf                  TYPE STANDARD TABLE OF    itcoo,
    it_docs          TYPE STANDARD TABLE OF    docs,
    it_pdf_output    TYPE STANDARD TABLE OF    tline,
    l_language       TYPE                      sflangu                             VALUE 'D',
    l_devtype        TYPE                      rspoptype,
    l_bin_filesize   TYPE                      i,
*       l_guiobj                TYPE REF TO               cl_gui_frontend_services,
    l_funcname       TYPE                      funcname,
    lf_formname      TYPE                      tdsfname,
    ls_user_defaults TYPE                      usdefaults.
*       l_fm_name type rs38l_fnam.

  lf_formname = co_formname.
* Print destination over user parameter or user default settings
  GET PARAMETER ID co_pafr_para FIELD lf_prog.
  IF lf_prog IS NOT INITIAL.
    ls_output_options-tddest = lf_prog.
  ELSE.
    CALL FUNCTION 'SUSR_USER_DEFAULTS_GET'
      EXPORTING
        user_name     = sy-uname
      IMPORTING
        user_defaults = ls_user_defaults
      EXCEPTIONS
        OTHERS        = 1.
    ls_output_options-tddest = ls_user_defaults-spld.
  ENDIF.

  "Drucker gegebenenfalls übersteuern durch Benutzerparameter
  ls_output_options-tddest = ycl_printer=>select_printer(
                   iv_uname   = sy-uname
                   iv_medium  = ycl_printer=>co_paperprinter_dina4
                   iv_printer = ls_output_options-tddest
                      ).
* get smartforms function name
  CALL FUNCTION 'SSF_FUNCTION_MODULE_NAME'
    EXPORTING
      formname           = lf_formname
    IMPORTING
      fm_name            = l_funcname
    EXCEPTIONS
      no_form            = 1
      no_function_module = 2
      OTHERS             = 3.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.
* Smart Forms: Kontrollstruktur
*  control_parameters-device        =  'PRINTER'.
*  ls_output_options-tdprinter     = l_devtype.
  control_parameters-no_dialog     = 'X'.
*  control_parameters-getotf        = 'X'.
***  ls_output_options-tddest     =  wworkpaper-tddest.        " destination
***  ls_output_options-tdcopies   =  wworkpaper-tdcopies.      " Anzahl Kopien
***  ls_output_options-tdimmed    =  wworkpaper-tdimmed.       " Sofort ausgeben
***  ls_output_options-tdnewid    =  wworkpaper-tdnewid.       " ls_out_params-PRNEW.
*  ls_output_options-tddest     =  'YN28'.         " destination

* set hard settings for output
  ls_output_options-tdcopies   =  1  .            " Anzahl Kopien
  ls_output_options-tdimmed    =  'X'.            " Sofort ausgeben
  ls_output_options-tdnewid    =  'X'.            " ls_out_params-PRNEW.     "
  ls_output_options-tddelete   =  'X'.            " Löschen nach Ausgabe
* call Fb to print
  CALL FUNCTION l_funcname
    EXPORTING
      user_settings         = ''
      /cellag/alcarep       = /cellag/alcarep
      control_parameters    = control_parameters
      output_options        = ls_output_options
*    IMPORTING
*     document_output_info  = document_output_info
*     job_output_info       = job_output_info
    TABLES
      /cellag/alcarep_error = /cellag/alcarep_error
      gt_comment_lines      = gt_comment_lines
    EXCEPTIONS
      formatting_error      = 1
      internal_error        = 2
      send_error            = 3
      user_canceled         = 4
      OTHERS                = 5.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

**********************************************************************
*  IF pa_pprev IS INITIAL.
*    IF device = 'PREVIEW'.
*      control_parameters-preview   =  'X'.
*    ELSE.
*      control_parameters-preview   =  ''.
*    ENDIF.
*  ELSE.
*    control_parameters-preview   =  'X'.
*  ENDIF.
***  ls_output_options-tddest     =  wworkpaper-tddest.        " destination
***  ls_output_options-tdcopies   =  wworkpaper-tdcopies.      " Anzahl Kopien
***  ls_output_options-tdimmed    =  wworkpaper-tdimmed.       " Sofort ausgeben
***  ls_output_options-tdnewid    =  wworkpaper-tdnewid.       " ls_out_params-PRNEW.     "

*  ls_output_options-tddest     =  'YNM229'.       " destination
*  ls_output_options-tdcopies   =  1.              " Anzahl Kopien
*  ls_output_options-tdimmed    =  ''.             " Sofort ausgeben
*  ls_output_options-tdnewid    =  'X'.            " ls_out_params-PRNEW.     "
*  ls_OUTPUT_OPTIONS-RQPOSNAME  =  '\\qlz79\DLZ0N213'.      "
*
*  gf_anzahl_seiten = gf_anzahl_seiten + document_output_info-tdfpages.


ENDFORM.                    "print_sf
*&---------------------------------------------------------------------*
*&      Form  convert_to_timestamp
*&---------------------------------------------------------------------*
*       convert date and time to timestamp
*----------------------------------------------------------------------*
*      -->PI_DATE    date
*      -->PI_TIME    time
*      -->PC_TSTAMP  timestamp
*----------------------------------------------------------------------*
FORM convert_to_timestamp USING pi_date pi_time CHANGING pc_tstamp.
  DATA:
    lf_tstamp TYPE timestamp,
    lf_date   TYPE dats,
    lf_time   TYPE tims.

  lf_date = pi_date.
  lf_time = pi_time.

  CONVERT DATE lf_date TIME lf_time
  INTO TIME STAMP lf_tstamp TIME ZONE sy-zonlo.

  pc_tstamp = lf_tstamp.
ENDFORM.                    "convert_to_timestamp

*&---------------------------------------------------------------------*
*&      Form  get_last_record
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->PT_CDHDR              Kopftabelle Änderungsbelege
*      -->PI_EQUNR              Equipmentnr.
*      -->CDPOS                 Positionstabelle Änderubgsbelege
*      -->PI_TSTAMP_RECEIVED    Zeitstempel Auftrag anlage
*      -->PI_TSTAMP_REPAIRED    Zeitstempel TBAG (Technisch abgeschlossen)
*      -->PI_FNAME              Feldname (SERGE or MAPAR)
*----------------------------------------------------------------------*
FORM get_last_record USING pt_cdhdr pi_equnr pi_tstamp_received pi_tstamp_repaired pi_fname CHANGING pc_old_val pc_new_val.
  DATA:
    lf_udate           TYPE                     cddatum,
    lf_utime           TYPE                     cduzeit,
    ls_cdhdr           TYPE                     cdhdr,
    ls_cdpos           TYPE                     cdpos,
    lt_cdhdr           TYPE STANDARD TABLE OF   cdhdr,
    lf_tstamp_changed  TYPE                     timestamp,
    lf_tstamp_received TYPE                     timestamp,
    lf_tstamp_repaired TYPE                     timestamp.

  lt_cdhdr = pt_cdhdr.
  lf_tstamp_received = pi_tstamp_received.
  lf_tstamp_repaired = pi_tstamp_repaired.

  SORT lt_cdhdr DESCENDING BY udate utime DESCENDING.

  CLEAR: ls_cdhdr, lf_udate, lf_utime .
  READ TABLE lt_cdhdr INTO ls_cdhdr INDEX 1.
  lf_udate = ls_cdhdr-udate.
  lf_utime = ls_cdhdr-utime.
  PERFORM convert_to_timestamp USING lf_udate lf_utime CHANGING lf_tstamp_changed.
  IF lf_tstamp_received <= lf_tstamp_changed AND lf_tstamp_changed <= lf_tstamp_repaired.
    CLEAR: ls_cdpos.
    SELECT SINGLE * FROM cdpos INTO ls_cdpos
        WHERE objectclas = 'EQUI' AND objectid = pi_equnr AND changenr = ls_cdhdr-changenr AND fname = pi_fname.
*old sernr
    pc_old_val = ls_cdpos-value_old.
    pc_new_val = ls_cdpos-value_new.

  ENDIF.
ENDFORM.                    "get_record

*&---------------------------------------------------------------------*
*&      Form  check_if_swap
*&---------------------------------------------------------------------*
*       Prüfen, ob es sich um eienn Tausch handelt, und gebe die alte  *
*     EQUNR + Lieferungsnumemr zurück (Retourenlieferung)              *
*----------------------------------------------------------------------*
*      -->PI_EQUNR   text
*----------------------------------------------------------------------*
FORM check_if_swap USING pi_equnr CHANGING pc_equnr_rlf.
  DATA:
    lf_equnr    TYPE              equnr,
*        ls_comwa        LIKE              vbco6,
*        lt_vbfa         TYPE TABLE OF     vbfa,
    ls_vbfa_rl  TYPE              vbfa,
    lf_vbeln_vl TYPE              vbeln_vl,
    ls_key_data LIKE              rserob,   " Beleg Identifikation
    lt_sernos   LIKE TABLE OF     rserob,
    ls_sernos   LIKE              rserob.

  CLEAR: lf_equnr.
  lf_equnr = pi_equnr.

  PERFORM get_retlief CHANGING ls_vbfa_rl lf_vbeln_vl.

  IF ls_vbfa_rl IS NOT INITIAL.
    ls_key_data-taser   = 'SER01'.
    ls_key_data-lief_nr = ls_vbfa_rl-vbeln.
    ls_key_data-posnr   = ls_vbfa_rl-posnn.

    CALL FUNCTION 'GET_SERNOS_OF_DOCUMENT'
      EXPORTING
        key_data            = ls_key_data
*       STATUS_PRE_READ     = ' '
*       EQUNR_CORR          = 'X'
*       NO_DELETED          = ' '
      TABLES
        sernos              = lt_sernos
*       SERXX               =
      EXCEPTIONS
        key_parameter_error = 1
        no_supported_access = 2
        no_data_found       = 3
        OTHERS              = 4.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

    READ TABLE lt_sernos INTO ls_sernos INDEX 1.   " Fall1 wir haben nur einen Treffer

    pc_equnr_rlf = ls_sernos-equnr.
  ENDIF.
ENDFORM.                    "check_if_swap

*&---------------------------------------------------------------------*
*&      Form  get_astatus_data
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->PI_OBJNR      text
*      -->PC_WFER_DATE  text
*      -->PC_WFER_TIME  text
*----------------------------------------------------------------------*
FORM get_astatus_data USING pi_objnr CHANGING pc_wfer_date pc_wfer_time.
* das Datum und Uhrzeit, wenn der Auftrag auf den Anwenderstatus WFER-Werkstatt fertig gesetzt wird
  DATA:
*        lf_wfer_date      TYPE    dats,
*        lf_wfer_time      TYPE    tims,
    lf_chgnr TYPE    j_chgnr,
    lf_objnr TYPE    j_objnr,
    ls_jcds  TYPE    jcds,
    lt_jcds  LIKE TABLE OF    ls_jcds.
*        lf_wfer_stat      TYPE    j_estat.

  lf_objnr  = pi_objnr.

*  SELECT * FROM tj30t INTO ls_tj30t WHERE stsma = 'ZREP001'AND  estat = 'E0001' AND spras = 'DE'.
* WFER ZREP001  E0001
*  SELECT SINGLE chgnr FROM jest INTO lf_chgnr WHERE objnr = lf_objnr AND stat = co_wfer_stat.
  SELECT * FROM jcds INTO TABLE lt_jcds WHERE objnr = lf_objnr AND stat = co_wfer_stat.

  IF lt_jcds IS NOT INITIAL.
    SORT lt_jcds DESCENDING BY udate utime DESCENDING.
    CLEAR:ls_jcds.
    READ TABLE lt_jcds INTO ls_jcds INDEX 1.

    IF ls_jcds IS NOT INITIAL.
      IF ls_jcds-inact IS NOT INITIAL.   " Status INACTIV = X gesetzt
        MESSAGE e029 WITH p_aufnr.
      ENDIF.
*      lf_wfer_date  = ls_jcds-udate .
*      lf_wfer_time  = ls_jcds-utime .
      pc_wfer_date  = ls_jcds-udate .
      pc_wfer_time  = ls_jcds-utime .
    ENDIF.
  ELSE.
*   Error-Meldung falls WFER- Status nicht gesetzt !
    MESSAGE e028 WITH p_aufnr.
  ENDIF.
ENDFORM.                    "get_astatus_data

*&---------------------------------------------------------------------*
*&      Form  get_rlf_wedate
*&---------------------------------------------------------------------*
*       Wareneingangsdatum der Retourenlieferung ermitteln
*
*----------------------------------------------------------------------*
*      -->PI_KDAUF      text
*      -->PC_WADAT_IST  text
*      -->PC_WAUHR      text
*----------------------------------------------------------------------*
FORM get_rlf_wedate USING pi_vbeln_vl CHANGING pc_vl_erdat pc_vl_zeit.
  DATA: lf_vbeln_vl TYPE    vbeln_vl,
        lf_vl_erdat TYPE    likp-erdat,
        lf_vl_zeit  TYPE    likp-erzet.

  lf_vbeln_vl = pi_vbeln_vl.
  SELECT SINGLE erdat erzet FROM likp INTO (lf_vl_erdat,lf_vl_zeit) WHERE vbeln = lf_vbeln_vl.
  IF sy-subrc = 0.
    pc_vl_erdat    = lf_vl_erdat.
    pc_vl_zeit     = lf_vl_zeit.
  ENDIF.
ENDFORM.                    "get_rlf_wedate

*&---------------------------------------------------------------------*
*&      Form  get_retlief
*&---------------------------------------------------------------------*
*       Retourenlieferung aus dem Belegfluss lesen (Ausgangspunkt-->Vertriebsbeleg)
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
FORM get_retlief CHANGING pc_vbfa pc_vbfa_rl.
  DATA:
*        lf_kdauf        TYPE              aufk-kdauf,
    ls_comwa     LIKE              vbco6,
    lt_vbfa      TYPE TABLE OF     vbfa,
    ls_vbfa_rl   TYPE              vbfa,
    lf_rmanr     TYPE              vbap-vbeln,
    lf_posnv_rma TYPE              posnr,
    lf_posnr_rma TYPE              posnr.
*        ls_key_data     LIKE              rserob.
* Belegfluss des Vertriebsbelegs lesen. Aus dem Belegfluss interessiert uns nur die Retourenlieferung!
  SELECT SINGLE rmanr posnr_rma posnv_rma FROM afko INTO (lf_rmanr,lf_posnr_rma,lf_posnv_rma) WHERE aufnr = p_aufnr.
*  ls_comwa-vbeln = gf_kdauf.
  ls_comwa-vbeln = lf_rmanr.
  ls_comwa-posnr = lf_posnv_rma.
  CALL FUNCTION 'RV_ORDER_FLOW_INFORMATION'   "#EC CI_USAGE_OK[2198647] "INS S4CONV ECC - HPC(2508-614)
    EXPORTING
*     AUFBEREITUNG  = '2'
*     BELEGTYP      = ' '
      comwa         = ls_comwa
*     NACHFOLGER    = 'X'
*     N_STUFEN      = '50'
*     VORGAENGER    = 'X'
*     V_STUFEN      = '50'
* IMPORTING
*     BELEGTYP_BACK =
    TABLES
      vbfa_tab      = lt_vbfa
    EXCEPTIONS
      no_vbfa       = 1
      no_vbuk_found = 2
      OTHERS        = 3.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

* "Retourenlieferung zum Auftrag" rauspicken
  READ TABLE lt_vbfa INTO ls_vbfa_rl
                     WITH KEY vbelv = lf_rmanr      "gf_kdauf
                              vbtyp_n = 'T'   " T = Retourenlieferung zum Auftrag (Nachfolgebeleg)
                              vbtyp_v = 'C'   " R =  Auftrag (Vorgängerbeleg )
                              .
  pc_vbfa = ls_vbfa_rl.
  pc_vbfa_rl = ls_vbfa_rl-vbeln.
ENDFORM.                    "get_retlief

*&---------------------------------------------------------------------*
*&      Form  get_retlief_from_aufnr
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM get_retlief_from_aufnr CHANGING pc_retlief_nr pc_equnr_retlief.
  DATA: lf_rmanr     TYPE            vbap-vbeln,
        lf_posnv_rma TYPE            vbap-posnv,
        lt_sernos    TYPE TABLE OF   rserob,
        lt_order_sn  TYPE            /cellag/cs_order_sn_t,
        ls_order_sn  TYPE            /cellag/cs_order_sn,
        lt_snral_tab TYPE             rserob_t,
        ls_snral_tab TYPE             rserob.

  SELECT SINGLE rmanr posnv_rma FROM afko INTO (lf_rmanr,lf_posnv_rma) WHERE aufnr = p_aufnr.

  CALL FUNCTION '/CELLAG/SDPOS_RALMENGE_GET'
    EXPORTING
      i_vbeln     = lf_rmanr
      i_posnr     = lf_posnv_rma
    TABLES
      et_order_sn = lt_order_sn.

  READ TABLE lt_order_sn INTO ls_order_sn WITH KEY aufnr = p_aufnr.
  lt_snral_tab = ls_order_sn-snral_tab.
  READ TABLE lt_snral_tab INTO ls_snral_tab INDEX 1. "INDEX = 1 weil ALCATEL spezifisch / an dieser Stelle noch mal betont
  pc_equnr_retlief = ls_snral_tab-equnr.
  pc_retlief_nr    = ls_snral_tab-lief_nr.

ENDFORM.                    "get_retlief_from_aufnr

*&---------------------------------------------------------------------*
*&      Form  check_sernr_swap
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->PC_SWAP_FLAG   text
*      -->PC_RETLIEF_NR  text
*----------------------------------------------------------------------*
FORM check_sernr_swap CHANGING pc_swap_flag pc_retlief_nr.
  DATA: lf_rmanr     TYPE            vbap-vbeln,
        lf_posnv_rma TYPE            posnr,
        lf_posnr_rma TYPE            posnr,
        lt_sernos    TYPE TABLE OF   rserob,
        lt_order_sn  TYPE            /cellag/cs_order_sn_t,
        ls_order_sn  TYPE            /cellag/cs_order_sn,
        lt_snral_tab TYPE            rserob_t,
        lt_snx_tab   TYPE            /cellag/csauf_snx_t,
        ls_snral_tab TYPE            rserob,
        ls_snx_tab   TYPE            /cellag/csauf_snx.

  SELECT SINGLE rmanr posnv_rma posnr_rma FROM afko INTO (lf_rmanr,lf_posnv_rma,lf_posnr_rma) WHERE aufnr = p_aufnr.

  CALL FUNCTION '/CELLAG/SDPOS_RALMENGE_GET'
    EXPORTING
      i_vbeln     = lf_rmanr
      i_posnr     = lf_posnv_rma
* IMPORTING
*     E_LFIMG     =
    TABLES
*     ET_RAL      =
*     ET_SERNOS   =
      et_order_sn = lt_order_sn.

  READ TABLE lt_order_sn INTO ls_order_sn WITH KEY aufnr = p_aufnr rmanr = lf_rmanr posnr_rma = lf_posnr_rma.
  pc_retlief_nr = ls_order_sn-vbeln_vl.

  lt_snx_tab = ls_order_sn-snx_tab.

  READ TABLE lt_snx_tab INTO ls_snx_tab INDEX 1. "INDEX = 1 weil ALCATEL spezifisch / an dieser Stelle noch mal betont
  gf_equnr_retlief = ls_snx_tab-ral_equnr.
  pc_swap_flag     = ls_snx_tab-tausch   .
ENDFORM.                    "check_sernr_swap


*&---------------------------------------------------------------------*
*&      Form  print_new
*&---------------------------------------------------------------------*
*       Checks if there is a customized print configuration for the
*       given repair order. If found, triggers the print engine;
*       otherwise, signals failure (cv_fail = abap_true) to fallback.
*----------------------------------------------------------------------*
FORM print_new USING    iv_save_as_pdf TYPE abap_bool
               CHANGING cv_fail        TYPE abap_bool.
  DATA: lx_no_config  TYPE REF TO /ctdi/cx_no_config_found,
        lx_driver_err TYPE REF TO /ctdi/cx_print_driver_error,
        lx_root       TYPE REF TO cx_root.

  cv_fail = abap_true.

  " Guard: Order ID must be present
  IF p_aufnr IS INITIAL.
    RETURN.
  ENDIF.

  TRY.
      " Populate the data object with already-read global memory
      DATA(lo_data) = NEW /ctdi/cl_print_data_ctdi( ).
      lo_data->ms_legacy       = /cellag/alcarep.
      lo_data->mt_legacy_error = /cellag/alcarep_error[].
      lo_data->mt_comment_lines = gt_comment_lines[].
      lo_data->map_legacy_data( ).

      " Instantiate unified print driver
      DATA(lo_driver) = /ctdi/cl_print_driver_base=>factory( p_aufnr ).

      " Trigger execution
      lo_driver->execute(
        EXPORTING
          io_data        = lo_data
          iv_save_as_pdf = iv_save_as_pdf ).

      " If it completes without cx_no_config_found, the new print was successful
      cv_fail = abap_false.

    CATCH /ctdi/cx_no_config_found INTO lx_no_config.
      " No customizing found for the new print driver - fallback to old print
      cv_fail = abap_true.

    CATCH /ctdi/cx_print_driver_error INTO lx_driver_err.
      " Log the engine/provider error
      /ctdi/cl_print_driver_log=>log_exception( lx_driver_err ).
      cv_fail = abap_true.

    CATCH cx_root INTO lx_root.
      " Log any other unexpected exception
      /ctdi/cl_print_driver_log=>log_exception( lx_root ).
      cv_fail = abap_true.
  ENDTRY.

  " Ensure any logs collected during the execution or exception handling are saved
  /ctdi/cl_print_driver_log=>save_log( ).

ENDFORM.                    "print_new