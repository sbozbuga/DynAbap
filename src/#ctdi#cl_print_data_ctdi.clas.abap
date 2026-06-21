"! <summary>CTDI Print Data Provider Extension</summary>
"! <desc>Extends the base Alcatel class to read repair results from the new
"! /CTDI/REP_RESULT table using an 11-step access sequence based on Contract, SKZ, AKZ, and Swap Flag.</desc>
CLASS /ctdi/cl_print_data_ctdi DEFINITION
  PUBLIC
  INHERITING FROM /ctdi/cl_print_data_legacy
  CREATE PUBLIC.

  PUBLIC SECTION.
    DATA ms_repair       TYPE /ctdi/repair.
    DATA mt_repair_error TYPE /ctdi/repair_error_tt.
    DATA mt_comments     TYPE STANDARD TABLE OF tline.

    METHODS map_legacy_data.
    METHODS read_data REDEFINITION.

  PROTECTED SECTION.

    "! <summary>Redefined repair result retrieval</summary>
    "! <desc>First fetches the contract (vgbel) from VBAK. Then reads operation 9010
    "! from AFRU to get SKZ. Evaluates an access sequence against /CTDI/REP_RESULT.</desc>
    METHODS get_repair_result REDEFINITION.

  PRIVATE SECTION.
ENDCLASS.

CLASS /ctdi/cl_print_data_ctdi IMPLEMENTATION.

  METHOD read_data.
    " 1. Call super class logic to fetch raw legacy data into ms_legacy, mt_legacy_error, etc.
    super->read_data( iv_aufnr = iv_aufnr iv_sernr = iv_sernr ).

    " 2. Convert legacy structures to new CTDI structures
    map_legacy_data( ).
  ENDMETHOD.

  METHOD map_legacy_data.
    CLEAR: ms_repair, mt_repair_error, mt_comments.

    MOVE-CORRESPONDING ms_legacy TO ms_repair.

    LOOP AT mt_legacy_error INTO DATA(ls_error).
      APPEND INITIAL LINE TO mt_repair_error ASSIGNING FIELD-SYMBOL(<ls_repair_error>).
      MOVE-CORRESPONDING ls_error TO <ls_repair_error>.
    ENDLOOP.

    mt_comments = mt_comment_lines.
  ENDMETHOD.

  METHOD get_repair_result.
    DATA: lf_repres     TYPE /cellag/repair_result,
          lf_repres_txt TYPE /cellag/repair_result_txt.

    DATA: lv_bemot TYPE afru-bemot,
          lv_stokz TYPE afru-stokz,
          lv_stzhl TYPE afru-stzhl.

    " Removed SELECT...ENDSELECT in favor of SELECT INTO TABLE
    " Always get SKZ from AFRU for operation 9010
    SELECT bemot, stokz, stzhl
      FROM afru
      WHERE aufnr = @mv_aufnr
        AND vornr = @/ctdi/cl_print_driver_base=>gc_operation_wfer
      INTO TABLE @DATA(lt_afru_skz).

    LOOP AT lt_afru_skz INTO DATA(ls_afru_skz).
      lv_bemot = ls_afru_skz-bemot.
      lv_stokz = ls_afru_skz-stokz.
      lv_stzhl = ls_afru_skz-stzhl.
      IF lv_stokz = ' ' AND lv_stzhl = '00000000'.
        EXIT.
      ENDIF.
    ENDLOOP.

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
      SELECT SINGLE vgbel FROM vbak WHERE vbeln = @mv_kdauf INTO @lv_contract.
      IF sy-subrc = 0 AND lv_contract IS NOT INITIAL.
        " Verify the linked document is actually a contract (vbtyp = 'G')
        SELECT SINGLE vbtyp FROM vbak WHERE vbeln = @lv_contract INTO @DATA(lv_vbtyp).
        IF lv_vbtyp <> 'G'.
          CLEAR lv_contract.
        ENDIF.
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
      WHERE vbeln = @lv_contract
         OR vbeln = @space
      INTO TABLE @DATA(lt_results).

    IF lt_results IS NOT INITIAL AND lt_steps IS NOT INITIAL.
      SORT lt_results BY vbeln bemot akz tauschfall.
      LOOP AT lt_steps ASSIGNING FIELD-SYMBOL(<ls_step>).
        READ TABLE lt_results ASSIGNING FIELD-SYMBOL(<ls_result>) WITH KEY
          vbeln      = <ls_step>-vbeln
          bemot      = <ls_step>-bemot
          akz        = <ls_step>-akz
          tauschfall = <ls_step>-tauschfall BINARY SEARCH.
        IF sy-subrc = 0.
          lf_repres_txt = <ls_result>-repres_txt.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    ms_legacy-repair_result     = lf_repres.
    ms_legacy-repair_result_txt = lf_repres_txt.
  ENDMETHOD.

ENDCLASS.
