class /CTDI/CL_PRINT_DRIVER_ENGINE definition
  public
  final
  create public .

public section.

    "! Main entry: executes the full print pipeline for a given repair ID.
    "!
    "! @parameter iv_repair_id   | Repair / Service Order ID
    "! @parameter iv_form_name   | Optional explicit form name (bypasses customizing)
    "! @parameter iv_class_name  | Optional explicit class name (bypasses customizing)
    "! @parameter iv_save_as_pdf | If TRUE, saves output as PDF
    "! @parameter iv_skz          | Optional explicit SKZ
    "! @parameter iv_akz          | Optional explicit AKZ
    "! @raising   /ctdi/cx_print_driver_error | Engine or provider failure
    "! @raising   /ctdi/cx_no_config_found    | Config not found failure
  methods EXECUTE
    importing
      !IV_REPAIR_ID type AUFNR
      !IV_SAVE_AS_PDF type ABAP_BOOL default ABAP_FALSE
      !IO_DATA type ref to OBJECT optional
    raising
      /CTDI/CX_PRINT_DRIVER_ERROR
      /CTDI/CX_NO_CONFIG_FOUND
      CX_STATIC_CHECK .
  PROTECTED SECTION.
private section.

  types:
    tt_config_buffer TYPE HASHED TABLE OF /ctdi/rep_forms WITH UNIQUE KEY vbeln skz akz .

  constants GC_CLASS_NAME type SEOCLSNAME value '/CTDI/CL_PRINT_DRIVER_BASE' ##NO_TEXT.
  constants GC_FORM_ALCA type FPNAME value '/CELLAG/ALCAREP' ##NO_TEXT.
  data MT_CONFIG_BUFFER type TT_CONFIG_BUFFER .
  data:
    mt_project_buffer TYPE HASHED TABLE OF /ctdi/rep_projec WITH UNIQUE KEY vbeln .

  methods RESOLVE_CONTRACT
    importing
      !IV_REPAIR_ID type AUFNR
    exporting
      !EV_CONTRACT_ID type VBELN_VA
      !EV_SKZ type BEMOT
      !EV_AKZ type CHAR4 .
  methods GET_CONFIG_FROM_DB
    importing
      !IV_REPAIR_ID type AUFNR
    exporting
      !EV_FORM_NAME type FPNAME
      !EV_CLASS_NAME type SEOCLSNAME
      !ES_PROJECT type /CTDI/REP_PROJEC
    raising
      /CTDI/CX_PRINT_DRIVER_ERROR
      /CTDI/CX_NO_CONFIG_FOUND .
  methods CREATE_PROVIDER
    importing
      !IV_CLASS_NAME type SEOCLSNAME
      !IV_REPAIR_ID type AUFNR
    returning
      value(RR_INSTANCE) type ref to OBJECT
    raising
      /CTDI/CX_PRINT_DRIVER_ERROR .
  methods RESOLVE_CLASS_NAME
    importing
      !IV_CLASS_NAME type SEOCLSNAME
    returning
      value(RV_CLASS_NAME) type SEOCLSNAME .
ENDCLASS.



CLASS /CTDI/CL_PRINT_DRIVER_ENGINE IMPLEMENTATION.


  METHOD create_provider.
    " Resolve and normalize class name
    DATA(lv_class) = resolve_class_name( iv_class_name ).

    " Instantiate the class
    TRY.
        CREATE OBJECT rr_instance TYPE (lv_class).
      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING
            repair_id = iv_repair_id
            message   = |Cannot instantiate class { lv_class }|
            previous  = lx_create.
    ENDTRY.
  ENDMETHOD.


  METHOD execute.
    DATA: lv_form_name  TYPE fpname,
          lv_class_name TYPE seoclsname,
          ls_project_db TYPE /ctdi/rep_projec.

    /ctdi/cl_print_driver_log=>log_info(
      |Print driver engine invoked for Repair { iv_repair_id }| ).

    " Always fetch config from DB to ensure project is loaded and cached
    get_config_from_db(
      EXPORTING iv_repair_id  = iv_repair_id
      IMPORTING ev_form_name  = lv_form_name
                ev_class_name = lv_class_name
                es_project    = ls_project_db ).



    IF lv_form_name = gc_form_alca.
      "Fallback to the old design for Alcatel
      RAISE EXCEPTION TYPE /ctdi/cx_no_config_found.
      RETURN.
    ENDIF.


    " Instantiate provider class
    DATA(lr_instance) = create_provider(
      iv_class_name = lv_class_name
      iv_repair_id  = iv_repair_id ).

    " Enforce casting to `/CTDI/IF_PRINT_DRIVER`
    TRY.
        DATA(lr_print_driver) = CAST /ctdi/if_print_driver( lr_instance ).
        lr_print_driver->execute(
          EXPORTING iv_repair_id   = iv_repair_id
                    iv_form_name   = lv_form_name
                    iv_save_as_pdf = iv_save_as_pdf
                    io_data        = io_data
                    is_project     = ls_project_db ).

        /ctdi/cl_print_driver_log=>log_info(
          |Print driver engine completed successfully via /CTDI/IF_PRINT_DRIVER for Repair { iv_repair_id }| ).

      CATCH cx_sy_move_cast_error INTO DATA(lx_cast).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING
            repair_id = iv_repair_id
            message   = |Class { lv_class_name } does not implement /CTDI/IF_PRINT_DRIVER|
            previous  = lx_cast.
    ENDTRY.
  ENDMETHOD.


  METHOD get_config_from_db.
    DATA: lv_contract TYPE vbeln_va,
          lv_skz      TYPE bemot,
          lv_akz      TYPE char4,
          ls_config   TYPE /ctdi/rep_forms.

    TYPES: BEGIN OF ty_query_step,
             vbeln TYPE vbeln_va,
             skz   TYPE bemot,
             akz   TYPE char4,
           END OF ty_query_step.
    DATA: lt_steps TYPE TABLE OF ty_query_step.


    IF ev_form_name IS SUPPLIED OR ev_class_name IS SUPPLIED.
      " Read Default CTDI Form& Class config with empty keys
      SELECT SINGLE form_name, class_name INTO @DATA(ls_dconf)
        FROM /ctdi/rep_forms
              WHERE vbeln = ''
                AND skz   = ''
                AND akz   = ''.
      IF sy-subrc EQ 0.
        ev_form_name = ls_dconf-form_name.

        IF ls_dconf-class_name IS INITIAL.
          ev_class_name = '/CTDI/CL_PRINT_DRIVER_BASE'. " Deafult logic&interface
        ELSE.
          ev_class_name = ls_dconf-class_name.
        ENDIF.
      ELSE.
        " Default line needs always to in the forms table
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error.
      ENDIF.

      " 1. Resolve Contract and Selectors
      resolve_contract( EXPORTING iv_repair_id    = iv_repair_id
                        IMPORTING ev_contract_id  = lv_contract
                                  ev_skz          = lv_skz
                                  ev_akz          = lv_akz ).

      " 2. Check hashed buffer cache
      READ TABLE mt_config_buffer WITH TABLE KEY
        vbeln = lv_contract
        skz   = lv_skz
        akz   = lv_akz
        INTO ls_config.

      IF sy-subrc = 0.

        ev_form_name  = ls_config-form_name.
        ev_class_name = resolve_class_name( ls_config-class_name ).
*      /ctdi/cl_print_driver_log=>log_info(
*        |Found print config in cache — Contract: { lv_contract }, | &&
*        |SKZ: { lv_skz }, AKZ: { lv_akz }, Form: { ev_form_name }, Class: { ev_class_name }| ).
*        RETURN.

      ELSE.

        " 3. Build Access Sequences
        IF lv_contract IS NOT INITIAL.
          IF lv_skz IS NOT INITIAL AND lv_akz IS NOT INITIAL.
            APPEND VALUE #( vbeln = lv_contract skz = lv_skz akz = lv_akz ) TO lt_steps.
          ENDIF.
          IF lv_skz IS NOT INITIAL.
            APPEND VALUE #( vbeln = lv_contract skz = lv_skz akz = '' ) TO lt_steps.
          ENDIF.
          IF lv_akz IS NOT INITIAL.
            APPEND VALUE #( vbeln = lv_contract skz = '' akz = lv_akz ) TO lt_steps.
          ENDIF.
          APPEND VALUE #( vbeln = lv_contract skz = '' akz = '' ) TO lt_steps.
        ENDIF.

        IF lv_skz IS NOT INITIAL AND lv_akz IS NOT INITIAL.
          APPEND VALUE #( vbeln = '' skz = lv_skz akz = lv_akz ) TO lt_steps.
        ENDIF.
        IF lv_skz IS NOT INITIAL.
          APPEND VALUE #( vbeln = '' skz = lv_skz akz = '' ) TO lt_steps.
        ENDIF.

        IF lv_akz IS NOT INITIAL.
          APPEND VALUE #( vbeln = '' skz = '' akz = lv_akz ) TO lt_steps.
        ENDIF.

        IF lt_steps IS NOT INITIAL.
          " Select from customizing using FOR ALL ENTRIES
          SELECT * FROM /ctdi/rep_forms
            INTO TABLE @DATA(lt_forms)
            FOR ALL ENTRIES IN @lt_steps
            WHERE vbeln = @lt_steps-vbeln
              AND skz   = @lt_steps-skz
              AND akz   = @lt_steps-akz.

          " Retrieve the highest priority match according to the Access Sequence
          LOOP AT lt_steps ASSIGNING FIELD-SYMBOL(<ls_step>).
            READ TABLE lt_forms INTO ls_config WITH KEY
              vbeln = <ls_step>-vbeln
              skz   = <ls_step>-skz
              akz   = <ls_step>-akz.
            IF sy-subrc = 0.
              EXIT.
            ENDIF.
          ENDLOOP.
        ENDIF.

*    " If still not found, try raw/formatted contract options for backward compatibility
*    IF ls_config IS INITIAL.
*      DATA(lv_raw) = |{ lv_contract ALPHA = OUT }|.
*      DATA(lv_in)  = |{ lv_contract ALPHA = IN }|.
*      SELECT SINGLE * FROM /ctdi/rep_forms
*        INTO @ls_config
*        WHERE ( vbeln = @lv_raw OR vbeln = @lv_in )
*          AND skz = ''
*          AND akz = ''.
*    ENDIF.

*    IF ls_config IS INITIAL AND ( ev_form_name IS SUPPLIED OR ev_class_name IS SUPPLIED ).
*      RAISE EXCEPTION TYPE /ctdi/cx_no_config_found.
*    ENDIF.

        IF ls_config IS NOT INITIAL.
          " Save to cache
          INSERT ls_config INTO TABLE mt_config_buffer.

          ev_form_name  = ls_config-form_name.
          ev_class_name = resolve_class_name( ls_config-class_name ).
        ENDIF.


      ENDIF.
      /ctdi/cl_print_driver_log=>log_info(
        |Config resolved and cached — Contract: { lv_contract }, | &&
        |SKZ: { lv_skz }, AKZ: { lv_akz }, Form: { ev_form_name }, Class: { ev_class_name }| ).

    ENDIF.


    " Look up the project in the project table (with memory caching)
    READ TABLE mt_project_buffer INTO es_project WITH TABLE KEY vbeln = lv_contract.

    IF sy-subrc <> 0.
      SELECT SINGLE *
        FROM /ctdi/rep_projec
        INTO @es_project
        WHERE vbeln = @lv_contract.

*      IF sy-subrc <> 0.
*        DATA(lv_raw_proj) = |{ lv_contract ALPHA = OUT }|.
*        DATA(lv_in_proj)  = |{ lv_contract ALPHA = IN }|.
*
*        SELECT SINGLE *
*          FROM /ctdi/rep_projec
*          INTO @es_project
*          WHERE vbeln = @lv_raw_proj
*             OR vbeln = @lv_in_proj.
*      ENDIF.

      IF es_project IS NOT INITIAL.
        INSERT es_project INTO TABLE mt_project_buffer.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD resolve_class_name.
    rv_class_name = iv_class_name.
    IF rv_class_name IS INITIAL.
      RETURN.
    ENDIF.

    " If name starts with 'Z' or 'Y', convert to /CTDI/ namespace
    IF rv_class_name(1) = 'Z' OR rv_class_name(1) = 'Y'.
      rv_class_name = |/CTDI/{ rv_class_name+1 }|.
    ENDIF.
  ENDMETHOD.


  METHOD resolve_contract.
    DATA(lv_aufnr) = |{ iv_repair_id ALPHA = IN }|.
    CLEAR: ev_contract_id, ev_skz, ev_akz.

    " 1. Try Resolving Contract via Service Order (AUFK -> VBAP)
    SELECT SINGLE
           v~/cellag/vbeln_vl
      INTO @DATA(lv_order_id)
      FROM aufk AS a
      LEFT OUTER JOIN vbap AS v
        ON v~vbeln = a~kdauf
       AND v~posnr = a~kdpos
      WHERE a~aufnr = @lv_aufnr.

    IF sy-subrc = 0 AND ev_contract_id IS NOT INITIAL.

      SELECT SINGLE vgbel
        INTO @ev_contract_id
       FROM vbak
      WHERE vbeln = @lv_order_id.
      IF sy-subrc NE 0.
        /ctdi/cl_print_driver_log=>log_info(
           |Could not find a Contract for Order { lv_order_id }| ).
        RETURN.
      ELSE.
      ENDIF.


      " Read AFRU confirmations for operation 9010
      SELECT bemot, stokz, stzhl
        FROM afru
        INTO TABLE @DATA(lt_afru)
        WHERE aufnr = @lv_aufnr
          AND vornr = '9010'.

      LOOP AT lt_afru ASSIGNING FIELD-SYMBOL(<ls_afru>).
        IF <ls_afru>-stokz = space AND <ls_afru>-stzhl = '00000000'.
          ev_skz = <ls_afru>-bemot.
          EXIT.
        ENDIF.
      ENDLOOP.

      " Read AKZ from notification
      SELECT SINGLE qmcod
        INTO @ev_akz
        FROM qmel
        WHERE aufnr = @lv_aufnr
          AND qmart = 'Z2'.

      /ctdi/cl_print_driver_log=>log_info(
        |Resolved Order { iv_repair_id } -> Contract { ev_contract_id }, SKZ { ev_skz }, AKZ { ev_akz }| ).
      RETURN.
    ENDIF.

    " 2. Fallback: Service Order -> Contract via AUFK-KDAUF
    SELECT SINGLE kdauf
      FROM aufk
      INTO @ev_contract_id
      WHERE aufnr = @lv_aufnr
        AND kdauf <> @space.

    IF sy-subrc = 0 AND ev_contract_id IS NOT INITIAL.
      /ctdi/cl_print_driver_log=>log_info(
        |Resolved Order { iv_repair_id } -> Contract { ev_contract_id } via KDAUF fallback| ).
      RETURN.
    ENDIF.

    " 3. Fallback: treat AUFNR as direct VBELN
    SELECT SINGLE vbeln
      FROM vbak
      INTO @ev_contract_id
      WHERE vbeln = @lv_aufnr.

    IF sy-subrc = 0.
      /ctdi/cl_print_driver_log=>log_info(
        |Using Repair { iv_repair_id } directly as Contract VBELN| ).
      RETURN.
    ENDIF.

    ev_contract_id = lv_aufnr.
    /ctdi/cl_print_driver_log=>log_warning(
      |Could not resolve Contract for Order { iv_repair_id } — using as-is| ).
  ENDMETHOD.
ENDCLASS.
