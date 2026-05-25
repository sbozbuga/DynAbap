*&---------------------------------------------------------------------*
*&                   /CELLAG/ALCAREP02                                 *
*&                                                                     *
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* Description:                                                         *
* Repair Report for "ALCATEL-LUCENT" as a PDF-File.                    *
* The CS-ORDER NUMBER must be known as well as the SERIAL-NUMBER       *
*                                                                      *
* ATTENTION: This is a customer dependend program !                    *
*----------------------------------------------------------------------*
* Spec...: Uwe Sellmer                                                 *
*----------------------------------------------------------------------*
* Developer...:  User-ID    |  Vor- Nachname Firma/Abteilung           *
*                CAGLIVOAN  |  Liviu Oancea  (Cellent AG)              *
*----------------------------------------------------------------------*
* Änderungshistorie                                                    *
* Datum      Entwickler  Bemerkung                                     *
*======================================================================*
* 10.08.2011 CAGLIVOAN    New                                          *
* 14.10.2011 CAGLIVOAN    modified specification for some points       *
* 17.11.2011 CAGLIVOAN    modified specification for some points       *
*                         new case when the EQUNR from Service-Order   *
*                   is not equal with the one in the return delivery   *
*24.11.2011  CAGLIVOAN    RECEIVED and REPAIRED date changed           *
*24.11.2011  CAGLIVOAN    Nur Werkstat fertige Aufträge berücksichtigen*
*08.12.2011  CAGLIVOAN    SD_Auftrag-->N*-Positionen mit N*-Rücklief.  *
*10.05.2012  CAGLIVOAN    Direkte Druckausgabe aus IW42 möglich  !     *
*27.06.2013  CAGLIVOAN    Intercompany Fall - Meldungsnummer aus dem   *
*                          Urssprungswerk beim Druck in dem ausführenden Werk*
*03.07.2013  CAGLIVOAN    Bestellnummer des KUnden als PO Number  !    *
*17.07.2014  CAGNIKTAT    STAND AUS Z2-MELDUNG ins FORMULAR bringen    *
*14.02.2015  HERMB        1502-220 Serialnr und Partnr Inbound/Outbound*
*                         1.MAPAR in EQUZ leer, aus Matstamm nachlesen *
*15.02.2015               2.Fehler aus Ausruf Transaktion ZERC:        *
*                           Sernr nachlesen, falls nicht angegeben     *
*----------------------------------------------------------------------*
* LEGENDE:    @@@ = ToDo's                                             *
*----------------------------------------------------------------------*
*REPORT /CELLAG/ALCAREP02 MESSAGE-ID /CELLAG/CS01.

INCLUDE /cellag/alcarep02top                    .     " global Data
INCLUDE /cellag/alcarep02e01                    .     " events
INCLUDE /cellag/alcarep02f01                    .     " FORM-Routines
INCLUDE /cellag/alcarep02f02                    .     " FORM-Routines 2