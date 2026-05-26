*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: /CTDI/REP_FORMS.................................*
DATA:  BEGIN OF STATUS_/CTDI/REP_FORMS               .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_/CTDI/REP_FORMS               .
CONTROLS: TCTRL_/CTDI/REP_FORMS
            TYPE TABLEVIEW USING SCREEN '0001'.
*...processing: /CTDI/REP_PROJEC................................*
DATA:  BEGIN OF STATUS_/CTDI/REP_PROJEC              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_/CTDI/REP_PROJEC              .
CONTROLS: TCTRL_/CTDI/REP_PROJEC
            TYPE TABLEVIEW USING SCREEN '0003'.
*...processing: /CTDI/REP_RESULT................................*
DATA:  BEGIN OF STATUS_/CTDI/REP_RESULT              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_/CTDI/REP_RESULT              .
CONTROLS: TCTRL_/CTDI/REP_RESULT
            TYPE TABLEVIEW USING SCREEN '0002'.
*.........table declarations...................................*
TABLES: */CTDI/REP_FORMS               .
TABLES: */CTDI/REP_PROJEC              .
TABLES: */CTDI/REP_RESULT              .
TABLES: /CTDI/REP_FORMS                .
TABLES: /CTDI/REP_PROJEC               .
TABLES: /CTDI/REP_RESULT               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
