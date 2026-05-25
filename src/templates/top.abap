*&---------------------------------------------------------------------*
*& Include /CELLAG/ALCAREP02TOP                              Modulpool        /CELLAG/ALCAREP02
*&
*&---------------------------------------------------------------------*

REPORT /CELLAG/ALCAREP02 MESSAGE-ID /CELLAG/CS01.

PARAMETERS: p_aufnr type aufk-aufnr.
PARAMETERS: p_sernr TYPE equi-sernr.
PARAMETERS: P_sf TYPE sap_bool NO-DISPLAY.             " HPCJUTLIN, 18.04.2018

CONSTANTS:
           co_equi_vers       TYPE               imrc_psort     VALUE   'EQUI-VERS',
*MK 18.09.2014 Ticket 1408-176 Laut Frank Schmidt gilt nur noch Katalog Z
*           co_katalogart      TYPE               qkatart        VALUE   '5',
*           co_katalogart      TYPE               qkatart        VALUE   'Z', "MK 25.05.2016
*           co_sprache         TYPE               spras          VALUE   'E',
           co_qmart           TYPE               qmart          VALUE   'Z2',
           co_wfer_stat       type               j_estat        VALUE   'E0001',
           co_formname        TYPE               tdobjname      VALUE   '/CELLAG/ALCAREP',
           co_pafr_para       TYPE               tpara-paramid  VALUE   '/CELLAG/PAFR',
           co_zx_qmart        type               qmart          value    'ZX'.

TYPES: BEGIN OF gy_error,
          urgrp TYPE urgrp,
          urcod TYPE urcod,
       END OF gy_error.

DATA:
      gf_po_nr                TYPE                vbkd-bstkd_e,
      gf_po_pos               TYPE                vbkd-posex_e,

      gf_ctdi_odernr(20)      TYPE                c,
      gf_qmnum                TYPE                qmel-qmnum,
      gf_fenum                TYPE                qmfe-fenum,

      gf_oldpartnr            TYPE                itob-mapar,
      gf_newpartnr            TYPE                itob-mapar,

      gf_oldserialnr          TYPE                itob-serge,
      gf_newserialnr          TYPE                itob-serge,

      gf_time_received        TYPE                tims,
      gf_time_repaired        TYPE                tims,
      gf_time_thisdate        TYPE                tims,
      gf_kdauf                TYPE                aufk-kdauf,
      gf_spras                TYPE                sy-langu,
      gf_iso_spras            type                laiso.          " Sprachkennzeichen nach ISO 639

DATA: /cellag/alcarep         TYPE                /cellag/alcarep,
      /cellag/alcarep_error   TYPE TABLE OF       /cellag/alcarep_error,
      gt_comment_lines        TYPE TABLE OF       tline.

data: gf_retlief_nr           TYPE                VBELN_VL,
      gf_equnr_retlief        type                equnr,
      gf_swap_flag            TYPE                FLAG.

data: gf_qmcod type qmel-qmcod."MK 10.09.2015 AKZ Änderungskennzeichen(Reparatur) -> QMEL-QMCOD

data: gf_katalogart      TYPE               qkatart. "MK 25.05.2016
*data:  gf_wfer_txt TYPE J_TXT04 VALUE 'WFER'.       " Großschreibung wichtig
*data:  gf_wfer_stat           type                j_estat VALUE 'E0001'.
