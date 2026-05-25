*&---------------------------------------------------------------------*
*&  Include           /CELLAG/ALCAREP02E01
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  CLEAR /cellag/alcarep.                            " clear interface structure
* sprache einstellen abh. systemsprache. DE wenn DE, sonst EN für alle anderen Fälle.
  IF sy-langu = 'D'.
    gf_spras  = 'D'.
  ELSE.
    gf_spras  = 'E'.
  ENDIF.
* Einstieg abhängig von Tcode
  IF sy-tcode = 'IW42'
   OR p_sf = 'X'.                " HPCJUTLIN, 18.04.2018
    PERFORM entry_sf.
  ELSE.
    PERFORM entry_pdf.
  ENDIF.

