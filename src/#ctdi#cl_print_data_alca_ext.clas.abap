CLASS /ctdi/cl_print_data_alca_ext DEFINITION
  PUBLIC
  INHERITING FROM /ctdi/cl_print_data_alcarep
  CREATE PUBLIC.

  PUBLIC SECTION.

  PROTECTED SECTION.
    METHODS get_repair_result REDEFINITION.

  PRIVATE SECTION.
ENDCLASS.

CLASS /ctdi/cl_print_data_alca_ext IMPLEMENTATION.

  METHOD get_repair_result.
    DATA: lf_repres     TYPE /cellag/repair_result,
          lf_repres_txt TYPE /cellag/repair_result_txt.

    DATA: lv_bemot TYPE afru-bemot,
          lv_stokz TYPE afru-stokz,
          lv_stzhl TYPE afru-stzhl.

    " Always get SKZ from AFRU for operation 9010
    SELECT bemot, stokz, stzhl FROM afru INTO ( @lv_bemot, @lv_stokz, @lv_stzhl )
      WHERE aufnr = @mv_aufnr
        AND vornr = '9010'.
      IF lv_stokz = ' ' AND lv_stzhl = '00000000'.
        EXIT.
      ENDIF.
    ENDSELECT.

    " Access Sequences for /ctdi/rep_results
    TYPES: BEGIN OF ty_query_step,
             vbeln  TYPE vbeln_va,
             bemot  TYPE bemot,
             akz    TYPE char4,
             tausch TYPE flag,
           END OF ty_query_step.
    DATA: lt_steps TYPE TABLE OF ty_query_step.

    IF mv_kdauf IS NOT INITIAL.
      " 1. Kontrakt + SKZ + AKZ + Tauschflag
      APPEND VALUE #( vbeln = mv_kdauf bemot = lv_bemot akz = mv_qmcod tausch = mv_swap_flag ) TO lt_steps.
      " 2. Kontrakt + SKZ + AKZ
      APPEND VALUE #( vbeln = mv_kdauf bemot = lv_bemot akz = mv_qmcod tausch = space ) TO lt_steps.
      " 3. Kontrakt + SKZ + Tauschflag
      APPEND VALUE #( vbeln = mv_kdauf bemot = lv_bemot akz = space tausch = mv_swap_flag ) TO lt_steps.
      " 4. Kontrakt + SKZ
      APPEND VALUE #( vbeln = mv_kdauf bemot = lv_bemot akz = space tausch = space ) TO lt_steps.
      " 5. Kontrakt + AKZ
      APPEND VALUE #( vbeln = mv_kdauf bemot = space akz = mv_qmcod tausch = space ) TO lt_steps.
      " 6. kontrakt
      APPEND VALUE #( vbeln = mv_kdauf bemot = space akz = space tausch = space ) TO lt_steps.
    ENDIF.

    " 7. (Kontrakt = leer ) + SKZ + AKZ + Tauschflag
    APPEND VALUE #( vbeln = space bemot = lv_bemot akz = mv_qmcod tausch = mv_swap_flag ) TO lt_steps.
    " 8. (Kontrakt = leer ) + SKZ + AKZ
    APPEND VALUE #( vbeln = space bemot = lv_bemot akz = mv_qmcod tausch = space ) TO lt_steps.
    " 9. (Kontrakt = leer ) + SKZ + Tauschflag
    APPEND VALUE #( vbeln = space bemot = lv_bemot akz = space tausch = mv_swap_flag ) TO lt_steps.
    " 10. (Kontrakt = leer ) + SKZ
    APPEND VALUE #( vbeln = space bemot = lv_bemot akz = space tausch = space ) TO lt_steps.
    " 11. (Kontrakt = leer ) + AKZ
    APPEND VALUE #( vbeln = space bemot = space akz = mv_qmcod tausch = space ) TO lt_steps.

    IF lt_steps IS NOT INITIAL.
      SELECT * FROM /ctdi/rep_results
        INTO TABLE @DATA(lt_results)
        FOR ALL ENTRIES IN @lt_steps
        WHERE vbeln  = @lt_steps-vbeln
          AND bemot  = @lt_steps-bemot
          AND akz    = @lt_steps-akz
          AND tausch = @lt_steps-tausch.

      LOOP AT lt_steps INTO DATA(ls_step).
        READ TABLE lt_results INTO DATA(ls_result) WITH KEY
          vbeln  = ls_step-vbeln
          bemot  = ls_step-bemot
          akz    = ls_step-akz
          tausch = ls_step-tausch.
        IF sy-subrc = 0.
          lf_repres     = ls_result-repres_barc.
          lf_repres_txt = ls_result-repres_txt.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    ms_alcarep-repair_result     = lf_repres.
    ms_alcarep-repair_result_txt = lf_repres_txt.
  ENDMETHOD.

ENDCLASS.
