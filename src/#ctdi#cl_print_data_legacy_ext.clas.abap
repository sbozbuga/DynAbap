"! <summary>CTDI Print Data Provider Extension</summary>
"! <desc>Extends the base Alcatel class to read repair results from the new
"! /CTDI/REP_RESULT table using an 11-step access sequence based on Contract, SKZ, AKZ, and Swap Flag.</desc>
CLASS /ctdi/cl_print_data_legacy_ext DEFINITION
  PUBLIC
  INHERITING FROM /ctdi/cl_print_data_legacy
  CREATE PUBLIC.

  PUBLIC SECTION.

  PROTECTED SECTION.
    "! <summary>Redefined repair result retrieval</summary>
    "! <desc>First fetches the contract (vgbel) from VBAK. Then reads operation 9010
    "! from AFRU to get SKZ. Evaluates an access sequence against /CTDI/REP_RESULT.</desc>
    METHODS get_repair_result REDEFINITION.

  PRIVATE SECTION.
ENDCLASS.

CLASS /ctdi/cl_print_data_legacy_ext IMPLEMENTATION.

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

    " Access Sequences for /ctdi/rep_result
    TYPES: BEGIN OF ty_query_step,
             vbeln      TYPE vbeln_va,
             bemot      TYPE bemot,
             akz        TYPE char4,
             tauschfall TYPE flag,
           END OF ty_query_step.
    DATA: lt_steps TYPE TABLE OF ty_query_step.
    DATA: lv_contract TYPE vbak-vgbel.

    IF mv_kdauf IS NOT INITIAL.
      SELECT SINGLE vgbel FROM vbak INTO @lv_contract WHERE vbeln = @mv_kdauf and vbtyp = 'G'.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
    ENDIF.

    IF lv_contract IS NOT INITIAL.
      " 1. Kontrakt + SKZ + AKZ + Tauschflag
      APPEND VALUE #( vbeln = lv_contract bemot = lv_bemot akz = mv_qmcod tauschfall = mv_swap_flag ) TO lt_steps.
      " 2. Kontrakt + SKZ + AKZ
      APPEND VALUE #( vbeln = lv_contract bemot = lv_bemot akz = mv_qmcod tauschfall = space ) TO lt_steps.
      " 3. Kontrakt + SKZ + Tauschflag
      APPEND VALUE #( vbeln = lv_contract bemot = lv_bemot akz = space tauschfall = mv_swap_flag ) TO lt_steps.
      " 4. Kontrakt + SKZ
      APPEND VALUE #( vbeln = lv_contract bemot = lv_bemot akz = space tauschfall = space ) TO lt_steps.
      " 5. Kontrakt + AKZ
      APPEND VALUE #( vbeln = lv_contract bemot = space akz = mv_qmcod tauschfall = space ) TO lt_steps.
      " 6. kontrakt
      APPEND VALUE #( vbeln = lv_contract bemot = space akz = space tauschfall = space ) TO lt_steps.
    ENDIF.

    " 7. (Kontrakt = leer ) + SKZ + AKZ + Tauschflag
    APPEND VALUE #( vbeln = space bemot = lv_bemot akz = mv_qmcod tauschfall = mv_swap_flag ) TO lt_steps.
    " 8. (Kontrakt = leer ) + SKZ + AKZ
    APPEND VALUE #( vbeln = space bemot = lv_bemot akz = mv_qmcod tauschfall = space ) TO lt_steps.
    " 9. (Kontrakt = leer ) + SKZ + Tauschflag
    APPEND VALUE #( vbeln = space bemot = lv_bemot akz = space tauschfall = mv_swap_flag ) TO lt_steps.
    " 10. (Kontrakt = leer ) + SKZ
    APPEND VALUE #( vbeln = space bemot = lv_bemot akz = space tauschfall = space ) TO lt_steps.
    " 11. (Kontrakt = leer ) + AKZ
    APPEND VALUE #( vbeln = space bemot = space akz = mv_qmcod tauschfall = space ) TO lt_steps.

    " Read all config for the current contract or empty contract records
    SELECT * FROM /ctdi/rep_result
      INTO TABLE @DATA(lt_results)
      WHERE vbeln = @lv_contract
         OR vbeln = @space.

    IF lt_results IS NOT INITIAL AND lt_steps IS NOT INITIAL.
      LOOP AT lt_steps INTO DATA(ls_step).
        READ TABLE lt_results INTO DATA(ls_result) WITH KEY
          vbeln      = ls_step-vbeln
          bemot      = ls_step-bemot
          akz        = ls_step-akz
          tauschfall = ls_step-tauschfall.
        IF sy-subrc = 0.
          lf_repres_txt = ls_result-repres_txt.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    ms_alcarep-repair_result     = lf_repres.
    ms_alcarep-repair_result_txt = lf_repres_txt.
  ENDMETHOD.

ENDCLASS.
