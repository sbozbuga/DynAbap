"! GOS Image Attachment Handler for the /CTDI/ Repair Print Framework.
"!
"! Retrieves image attachments (GOS/SOFFICE + SAP Content Server/ArchiveLink)
"! from repair orders and linked service notifications, converts them to PDF
"! pages, and merges them into the final print output.
"!
"! <h2>Attachment Sources</h2>
"! <ul>
"!   <li>GOS/SOFFICE (SRGBTBREL → SO_DOCUMENT_READ_API1) — BUS2088 or BUS2007</li>
"!   <li>Content Server/ArchiveLink (TOA01 → SCMS_AO_TABLE_GET) — BUS2088 + ZRS_JPG</li>
"!   <li>Linked Service Notification (BUS2078/QMEL) — both GOS and Content Server</li>
"! </ul>
"!
"! <h2>Image-to-PDF Render Modes</h2>
"! <ul>
"!   <li><strong>Raw PDF (gc_render_raw)</strong> — Builds PDF from scratch in ABAP.
"!     Only JPEG can be embedded directly via /DCTDecode.
"!     PNG/BMP/TIFF are converted to JPEG via IGS (CL_IGS_IMAGE_CONVERTER).</li>
"!   <li><strong>ADS Form (gc_render_ads)</strong> — Renders via Adobe Form /CTDI/REPAIR_IMG.
"!     ADS natively handles JPEG, PNG (including transparency), BMP.</li>
"! </ul>
"!
"! <h2>Raw PDF Construction (convert_images_to_pdf)</h2>
"! The raw PDF is built as a valid PDF 1.4 file with this object structure:
"! <ul>
"!   <li>Object 1: Catalog (root, points to Pages)</li>
"!   <li>Object 2: Pages Tree (lists all page objects, defines A4 MediaBox 595x842pt)</li>
"!   <li>Objects 3..N+2: Page objects (each references its content stream + fonts + images)</li>
"!   <li>Objects N+3..2N+2: Content Streams (PDF drawing operators per page)</li>
"!   <li>Objects 2N+3..2N+M+2: Image XObjects (raw JPEG binary with /DCTDecode filter)</li>
"!   <li>Object F: Font /F1 Helvetica (captions)</li>
"!   <li>Object F+1: Font /F2 Helvetica-Bold (title header)</li>
"! </ul>
"!
"! Content stream operators used:
"! <ul>
"!   <li><em>rg</em> — Set fill color (RGB)</li>
"!   <li><em>re f</em> — Draw filled rectangle (title bar)</li>
"!   <li><em>BT/ET, Tf, Td, Tj</em> — Text block, font selection, position, draw</li>
"!   <li><em>q/Q, cm, Do</em> — Save state, transform matrix (scale+position), draw image</li>
"!   <li><em>RG, re S</em> — Stroke color, draw border rectangle</li>
"! </ul>
"!
"! Layout uses flowing algorithm: images stack top-to-bottom, page breaks when
"! next image won't fit. First page includes a "Repair Images" title header bar.
"! Images are resized via IGS if they exceed 1600px (configurable threshold).
"!
"! <h2>Error Handling</h2>
"! Fail-safe: any error returns the original PDF unchanged. All errors are
"! logged via /CTDI/CL_PRINT_DRIVER_LOG (SLG1 application log).
CLASS /ctdi/cl_print_gos_images DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS gc_objtype_repair   TYPE swo_objtyp      VALUE 'BUS2007' ##NO_TEXT.
    CONSTANTS gc_objtype_cs_order TYPE swo_objtyp      VALUE 'BUS2088' ##NO_TEXT.
    CONSTANTS gc_objtype_qmel     TYPE swo_objtyp      VALUE 'BUS2078' ##NO_TEXT.

    " Image-to-PDF render mode
    CONSTANTS gc_render_raw TYPE char1           VALUE 'R' ##NO_TEXT.       " Raw PDF construction
    CONSTANTS gc_render_ads TYPE char1           VALUE 'A' ##NO_TEXT.       " ADS Adobe Form render
    CONSTANTS gc_objtype_qmel_alt TYPE swo_objtyp      VALUE 'QMEL' ##NO_TEXT.
    CONSTANTS gc_archiv_ar_jpg    TYPE toav0-ar_object VALUE 'ZRS_JPG' ##NO_TEXT.
    CONSTANTS gc_archiv_ar_pdf    TYPE toav0-ar_object VALUE 'ZRS_PDF' ##NO_TEXT.

    TYPES: BEGIN OF ty_image_attachment,
             atta_id  TYPE string,
             filename TYPE string,
             file_ext TYPE string,
             mimetype TYPE string,
             content  TYPE xstring,
             source   TYPE string, " 'Repair Order' or 'Notification'
             objkey   TYPE swo_typeid,
             width    TYPE i,
             height   TYPE i,
             dpi      TYPE i,
           END OF ty_image_attachment,
           tt_image_attachments TYPE STANDARD TABLE OF ty_image_attachment WITH EMPTY KEY.

    "! High-level entry point: retrieves images and merges them into the input PDF stream.
    "!
    "! @parameter iv_repair_order | Repair Order Number (AUFNR)
    "! @parameter iv_pdf          | Input PDF byte stream
    "! @parameter iv_render_mode  | Render mode: gc_render_raw (default) or gc_render_ads
    "! @parameter rv_pdf          | Output PDF byte stream (with images appended if found)
    METHODS append_images
      IMPORTING iv_repair_order TYPE aufnr
                iv_pdf          TYPE xstring
                iv_render_mode  TYPE char1 DEFAULT gc_render_raw
      RETURNING VALUE(rv_pdf)   TYPE xstring.

    "! Retrieves and filters all image attachments for an order and its linked notification.
    "!
    "! @parameter iv_repair_order | Repair Order Number (AUFNR)
    "! @parameter rt_attachments  | Table of filtered image attachments
    METHODS get_attachments
      IMPORTING iv_repair_order       TYPE aufnr
      RETURNING VALUE(rt_attachments) TYPE tt_image_attachments.

    "! Converts a table of image attachments into a valid DIN A4 PDF stream.
    "!
    "! @parameter it_attachments | Table of image attachments
    "! @parameter rv_pdf         | Generated PDF byte stream
    METHODS convert_images_to_pdf
      IMPORTING it_attachments TYPE tt_image_attachments
      RETURNING VALUE(rv_pdf)  TYPE xstring.

    "! Converts images to PDF using ADS (Adobe Document Services) form rendering.
    "! Requires form template /CTDI/GOS_IMG_PAGE to be active in the system.
    "!
    "! @parameter it_attachments | Table of image attachments
    "! @parameter rv_pdf         | Generated PDF byte stream
    METHODS convert_images_to_pdf_ads
      IMPORTING it_attachments TYPE tt_image_attachments
      RETURNING VALUE(rv_pdf)  TYPE xstring.

    "! Merges two PDF byte streams using CL_RSPO_PDF_MERGE.
    "!
    "! @parameter iv_base_pdf   | Primary PDF content
    "! @parameter iv_images_pdf | Appended PDF content
    "! @parameter rv_pdf        | Merged PDF content
    METHODS merge_pdfs
      IMPORTING iv_base_pdf   TYPE xstring
                iv_images_pdf TYPE xstring
      RETURNING VALUE(rv_pdf) TYPE xstring.

    "! Resolves the linked Service Notification (QMNUM) for a Repair Order.
    "!
    "! @parameter iv_aufnr | Repair Order Number
    "! @parameter rv_qmnum | Linked Quality / Service Notification Number
    METHODS resolve_notification
      IMPORTING iv_aufnr        TYPE aufnr
      RETURNING VALUE(rv_qmnum) TYPE qmnum.

    "! Checks whether a given file extension is a supported image type.
    "!
    "! @parameter iv_ext      | File extension (e.g. 'JPG', 'PNG')
    "! @parameter rv_is_image | True if supported image format
    CLASS-METHODS is_supported_image_ext
      IMPORTING iv_ext             TYPE clike
      RETURNING VALUE(rv_is_image) TYPE abap_bool.

    "! Mass check: returns order numbers that have image attachments (GOS or Content Server).
    "! Optimized for ALV — single DB roundtrip. Pass a range of AUFNR values.
    "!
    "! @parameter it_aufnr_range       | Selection range of order numbers
    "! @parameter et_with_attachments  | Orders with GOS attachments (may include non-image files)
    "! @parameter rt_aufnr_with_images | Orders with confirmed images (Content Server ZRS_JPG)
    TYPES ty_aufnr_range TYPE RANGE OF aufnr.
    TYPES ty_aufnr_tab   TYPE SORTED TABLE OF aufnr WITH UNIQUE KEY table_line.

    CLASS-METHODS get_orders_with_images
      IMPORTING it_aufnr_range              TYPE ty_aufnr_range
      EXPORTING et_with_attachments         TYPE ty_aufnr_tab
      RETURNING VALUE(rt_aufnr_with_images) TYPE ty_aufnr_tab.

    "! Extracts width and height from image binary stream if supported.
    "!
    "! @parameter iv_content | Image binary xstring
    "! @parameter iv_ext     | File extension
    "! @parameter ev_width   | Extracted width in pixels
    "! @parameter ev_height  | Extracted height in pixels
    CLASS-METHODS extract_image_dimensions
      IMPORTING iv_content TYPE xstring
                iv_ext     TYPE string
      EXPORTING ev_width   TYPE i
                ev_height  TYPE i.

    "! Deduplicates attachments by ID and binary SHA-256 hash while preserving retrieval order.
    "!
    "! @parameter it_attachments | Raw table of attachments
    "! @parameter rt_unique      | Deduplicated table of attachments
    CLASS-METHODS deduplicate_attachments
      IMPORTING it_attachments   TYPE tt_image_attachments
      RETURNING VALUE(rt_unique) TYPE tt_image_attachments.

  PROTECTED SECTION.
    "! Retrieves GOS attachments for a generic BOR object using CL_BINARY_RELATION and SO_DOCUMENT_READ_API1.
    "!
    "! @parameter iv_objtype |
    "! @parameter iv_objkey |
    "! @parameter iv_source |
    "! @parameter rt_attachments |
    METHODS get_gos_attachments
      IMPORTING iv_objtype            TYPE swo_objtyp
                iv_objkey             TYPE swo_typeid
                iv_source             TYPE string
      RETURNING VALUE(rt_attachments) TYPE tt_image_attachments.

    "! Retrieves image attachments from SAP Content Server via ArchiveLink (TOA01).
    "! Uses BUS2088 (CS-Order), BUS2007 (Repair), or BUS2078/QMEL (Notification) and filters to ZRS_JPG.
    "!
    "! @parameter iv_object_id   | Object ID (AUFNR / QMNUM, alpha-converted)
    "! @parameter iv_objtype     | BOR Object Type (default BUS2088)
    "! @parameter iv_source      | Source label for the attachment
    "! @parameter rt_attachments | Retrieved image attachments
    METHODS get_content_server_attachments
      IMPORTING iv_object_id          TYPE saeobjid
                iv_objtype            TYPE swo_objtyp DEFAULT gc_objtype_cs_order
                iv_source             TYPE string
      RETURNING VALUE(rt_attachments) TYPE tt_image_attachments.

  PRIVATE SECTION.
    TYPES tt_offsets TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    "! Formats an ASCII/ISO text string for literal PDF text output.
    "!
    "! @parameter iv_text |
    "! @parameter rv_hex |
    CLASS-METHODS escape_pdf_text
      IMPORTING iv_text       TYPE string
      RETURNING VALUE(rv_hex) TYPE string.

    "! Converts a non-JPEG image (PNG, BMP, TIFF) to JPEG using IGS.
    "! Returns the original content unchanged if already JPEG.
    "!
    "! @parameter iv_content | Image binary xstring
    "! @parameter iv_ext     | File extension (e.g. PNG, BMP, TIFF)
    "! @parameter rv_jpeg    | Converted JPEG xstring (or empty on failure)
    CLASS-METHODS convert_to_jpeg
      IMPORTING iv_content     TYPE xstring
                iv_ext         TYPE string
      RETURNING VALUE(rv_jpeg) TYPE xstring.

    "! Resizes an image via IGS if it exceeds max dimensions. Returns original if smaller.
    "! DPI-aware resize: scales image to fit within a physical print area (mm).
    "! Uses CL_FXS_IMAGE_PROCESSOR to read actual DPI from image metadata.
    "! If no DPI metadata, assumes 96 DPI (ADS default).
    "!
    "! @parameter iv_content  | Image binary (xstring)
    "! @parameter iv_width    | Current width in pixels
    "! @parameter iv_height   | Current height in pixels
    "! @parameter iv_max_w_mm | Maximum physical width in mm (default 192 = A4 content)
    "! @parameter iv_max_h_mm | Maximum physical height in mm (default 267 = A4 content)
    "! @parameter ev_eff_dpi |
    "! @parameter rv_content  | Resized image (or original if already fits)
    CLASS-METHODS resize_if_needed
      IMPORTING iv_content        TYPE xstring
                iv_width          TYPE i
                iv_height         TYPE i
                iv_max_w_mm       TYPE f DEFAULT '192.00'
                iv_max_h_mm       TYPE f DEFAULT '267.00'
      EXPORTING ev_eff_dpi        TYPE i
      RETURNING VALUE(rv_content) TYPE xstring.

    "! Checks if a PNG has an alpha channel (color type 4 or 6 in IHDR).
    "! @parameter iv_png       | PNG binary content
    "! @parameter rv_has_alpha | True if PNG has transparency
    CLASS-METHODS has_png_alpha
      IMPORTING iv_png              TYPE xstring
      RETURNING VALUE(rv_has_alpha) TYPE abap_bool.

    "! Returns the MIME type for a given file extension.
    "!
    "! @parameter iv_ext |
    "! @parameter rv_mimetype |
    CLASS-METHODS get_mimetype_for_ext
      IMPORTING iv_ext             TYPE clike
      RETURNING VALUE(rv_mimetype) TYPE string.

    "! Extracts the number of color channels from a JPEG SOF marker.
    "! @parameter iv_content  | JPEG binary
    "! @parameter ev_channels | Number of components (1=gray, 3=RGB, 4=CMYK)
    CLASS-METHODS extract_jpeg_channels
      IMPORTING iv_content  TYPE xstring
      EXPORTING ev_channels TYPE i.

    "! Appends an ASCII string as PDF object and records byte offset.
    "!
    "! @parameter iv_obj_num |
    "! @parameter iv_content |
    "! @parameter cv_pdf |
    "! @parameter ct_offsets |
    CLASS-METHODS append_obj_str
      IMPORTING iv_obj_num TYPE i
                iv_content TYPE string
      CHANGING  cv_pdf     TYPE xstring
                ct_offsets TYPE tt_offsets.

    "! Appends a binary stream PDF object (e.g. Image XObject).
    "!
    "! @parameter iv_obj_num |
    "! @parameter iv_dict |
    "! @parameter iv_stream |
    "! @parameter cv_pdf |
    "! @parameter ct_offsets |
    CLASS-METHODS append_obj_bin
      IMPORTING iv_obj_num TYPE i
                iv_dict    TYPE string
                iv_stream  TYPE xstring
      CHANGING  cv_pdf     TYPE xstring
                ct_offsets TYPE tt_offsets.

ENDCLASS.



CLASS /CTDI/CL_PRINT_GOS_IMAGES IMPLEMENTATION.


  METHOD append_images.
    rv_pdf = iv_pdf.

    IF iv_repair_order IS INITIAL OR iv_pdf IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        " 1. Retrieve all GOS image attachments (Order + Notification)
        DATA(lt_images) = get_attachments( iv_repair_order = iv_repair_order ).

        IF lt_images IS INITIAL.
          /ctdi/cl_print_driver_log=>log_info( |No GOS image attachments found for Repair Order { iv_repair_order }| ).
          RETURN.
        ENDIF.

        " 2. Convert images to A4 PDF pages (raw PDF or ADS based on render mode)
        DATA(lv_images_pdf) = COND xstring(
          WHEN iv_render_mode = gc_render_ads
          THEN convert_images_to_pdf_ads( it_attachments = lt_images )
          ELSE convert_images_to_pdf( it_attachments = lt_images ) ).

        IF lv_images_pdf IS INITIAL.
          /ctdi/cl_print_driver_log=>log_warning(
              |Failed to convert image attachments to PDF for Repair Order { iv_repair_order }| ).
          RETURN.
        ENDIF.

        " 3. Merge converted image pages into base PDF output
        rv_pdf = merge_pdfs( iv_base_pdf   = iv_pdf
                             iv_images_pdf = lv_images_pdf ).

        /ctdi/cl_print_driver_log=>log_info(
            |Successfully appended { lines( lt_images ) } GOS image(s) to Repair Order { iv_repair_order } PDF| ).

      CATCH cx_root INTO DATA(lx_error).
        " Fail-safe: on ANY error, return original PDF unchanged
        /ctdi/cl_print_driver_log=>log_exception( lx_error ).
        /ctdi/cl_print_driver_log=>log_warning(
            |GOS image append failed for order { iv_repair_order } - original PDF preserved| ).
        rv_pdf = iv_pdf.
    ENDTRY.
  ENDMETHOD.


  METHOD append_obj_bin.
    APPEND xstrlen( cv_pdf ) TO ct_offsets.

    DATA lv_head_x TYPE xstring.
    DATA lv_tail_x TYPE xstring.
    DATA(lv_head) = |{ iv_obj_num } 0 obj\n<< { iv_dict } >>\nstream\n|.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = lv_head
      IMPORTING
        buffer = lv_head_x
      EXCEPTIONS
        OTHERS = 1 ##SUBRC_OK.                  "#EC CI_SUBRC

    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = |\nendstream\nendobj\n|
      IMPORTING
        buffer = lv_tail_x
      EXCEPTIONS
        OTHERS = 1 ##SUBRC_OK.                  "#EC CI_SUBRC

    CONCATENATE cv_pdf lv_head_x iv_stream lv_tail_x INTO cv_pdf IN BYTE MODE.
  ENDMETHOD.


  METHOD append_obj_str.
    APPEND xstrlen( cv_pdf ) TO ct_offsets.

    DATA lv_x TYPE xstring.
    DATA(lv_full) = |{ iv_obj_num } 0 obj\n{ iv_content }\nendobj\n|.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = lv_full
      IMPORTING
        buffer = lv_x
      EXCEPTIONS
        OTHERS = 1 ##SUBRC_OK.                  "#EC CI_SUBRC

    CONCATENATE cv_pdf lv_x INTO cv_pdf IN BYTE MODE.
  ENDMETHOD.


  METHOD convert_images_to_pdf.
    CLEAR rv_pdf.

    IF it_attachments IS INITIAL.
      RETURN.
    ENDIF.

    " Prepare images for PDF embedding:
    " - JPEG: embed directly via /DCTDecode
    " - PNG/BMP/TIFF: convert to JPEG via IGS
    DATA lt_pdf_images TYPE tt_image_attachments.
    LOOP AT it_attachments ASSIGNING FIELD-SYMBOL(<ls_check>).
      DATA(lv_check_ext) = to_upper( <ls_check>-file_ext ).
      IF lv_check_ext = 'JPG' OR lv_check_ext = 'JPEG'.
        APPEND <ls_check> TO lt_pdf_images.
      ELSE.
        " Convert non-JPEG to JPEG via IGS
        DATA(lv_converted) = convert_to_jpeg( iv_content = <ls_check>-content
                                              iv_ext     = <ls_check>-file_ext ).
        IF lv_converted IS NOT INITIAL.
          DATA ls_converted TYPE ty_image_attachment.
          ls_converted = <ls_check>.
          ls_converted-content  = lv_converted.
          ls_converted-file_ext = 'JPG'.
          extract_image_dimensions( EXPORTING iv_content = ls_converted-content
                                              iv_ext     = 'JPG'
                                    IMPORTING ev_width   = ls_converted-width
                                              ev_height  = ls_converted-height ).

          " Detect blank images: RGBA PNGs with white/light foreground on transparent bg
          " produce nearly-empty JPEGs after conversion (white-on-white)
          IF lv_check_ext = 'PNG' AND has_png_alpha( <ls_check>-content ) = abap_true.
            DATA(lv_pixel_count) = ls_converted-width * ls_converted-height.
            DATA(lv_jpeg_size) = xstrlen( ls_converted-content ).
            IF lv_pixel_count > 0 AND lv_jpeg_size < ( lv_pixel_count / 100 ).
              /ctdi/cl_print_driver_log=>log_info(
                  |Skipping { <ls_check>-filename } - RGBA PNG produced blank JPEG ({ lv_jpeg_size } bytes for { lv_pixel_count } pixels)| ).
              CONTINUE.
            ENDIF.
          ENDIF.

          /ctdi/cl_print_driver_log=>log_info(
              |Converted { <ls_check>-filename }: { <ls_check>-file_ext }->JPG, dims={ ls_converted-width }x{ ls_converted-height }, size={ xstrlen(
                                                                                                                                                ls_converted-content ) }| ).

          " Log JPEG color channels (byte after height+width in SOF: 1=gray, 3=RGB, 4=CMYK)
          DATA lv_num_channels TYPE i.
          extract_jpeg_channels( EXPORTING iv_content  = ls_converted-content
                                 IMPORTING ev_channels = lv_num_channels ).
          /ctdi/cl_print_driver_log=>log_info( |  -> channels={ lv_num_channels }| ).

          APPEND ls_converted TO lt_pdf_images.
        ELSE.
          /ctdi/cl_print_driver_log=>log_info(
              |Attachment { <ls_check>-filename } ({ <ls_check>-file_ext }) skipped - IGS conversion failed| ).
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF lt_pdf_images IS INITIAL.
      RETURN.
    ENDIF.

    " Pre-process: DPI-aware resize to fit A4 print area (523pt x 770pt ≈ 184mm x 271mm)
    " Raw PDF uses points not mm, so use slightly smaller area accounting for margins + captions
    LOOP AT lt_pdf_images ASSIGNING FIELD-SYMBOL(<ls_resize>).
      DATA lv_raw_dpi TYPE i.
      DATA(lv_resized) = resize_if_needed( EXPORTING iv_content  = <ls_resize>-content
                                                     iv_width    = <ls_resize>-width
                                                     iv_height   = <ls_resize>-height
                                                     iv_max_w_mm = CONV f( '184.00' )
                                                     iv_max_h_mm = CONV f( '271.00' )
                                           IMPORTING ev_eff_dpi  = lv_raw_dpi ).
      <ls_resize>-dpi = lv_raw_dpi.
      IF lv_resized <> <ls_resize>-content.
        <ls_resize>-content = lv_resized.
        extract_image_dimensions( EXPORTING iv_content = <ls_resize>-content
                                            iv_ext     = 'JPG'
                                  IMPORTING ev_width   = <ls_resize>-width
                                            ev_height  = <ls_resize>-height ).
      ENDIF.
    ENDLOOP.

    " Layout: Flowing DIN A4 Portrait (595.28 x 841.89 pt)
    " Rule: Scale images to fit page width (no upscaling), stack top-to-bottom.
    "        When next image won't fit remaining space, start a new page.
    CONSTANTS lc_w_page    TYPE f VALUE '595.28'.
    CONSTANTS lc_h_page    TYPE f VALUE '841.89'.
    CONSTANTS lc_margin    TYPE f VALUE '36.00'.
    CONSTANTS lc_w_usable TYPE f VALUE '523.28'. " 595.28 - 2*36
    CONSTANTS lc_h_usable TYPE f VALUE '769.89'. " 841.89 - 2*36
    CONSTANTS lc_caption_h TYPE f VALUE '18.00'.  " space for filename caption
    CONSTANTS lc_gap TYPE f VALUE '12.00'.  " gap between images

    " --- Phase 1: Build page plan (flowing layout) ---
    " Pre-calculate rendered height for each image
    TYPES: BEGIN OF ty_img_layout,
             idx    TYPE i, " index in lt_pdf_images
             ren_w  TYPE f, " rendered width (points)
             ren_h  TYPE f, " rendered height (points)
             slot_h TYPE f, " total slot: caption + image + gap
           END OF ty_img_layout.
    DATA lt_layout TYPE STANDARD TABLE OF ty_img_layout WITH EMPTY KEY.

    DATA(lv_total_imgs) = lines( lt_pdf_images ).

    LOOP AT lt_pdf_images ASSIGNING FIELD-SYMBOL(<ls_pre>).
      DATA(lv_pre_idx) = sy-tabix.

      " Convert pixel dimensions to PDF points using image DPI
      " 1 point = 1/72 inch, so points = pixels / dpi * 72
      DATA(lv_img_dpi) = COND f( WHEN <ls_pre>-dpi > 0 THEN <ls_pre>-dpi ELSE 200 ).
      DATA(lv_raw_w) = COND f( WHEN <ls_pre>-width > 0
                               THEN <ls_pre>-width / lv_img_dpi * 72
                               ELSE 400 ).
      DATA(lv_raw_h) = COND f( WHEN <ls_pre>-height > 0
                               THEN <ls_pre>-height / lv_img_dpi * 72
                               ELSE 300 ).

      " Scale to fit printable page area (width and height minus caption/gap), never upscale
      DATA(lv_max_img_h) = lc_h_usable - lc_caption_h - lc_gap.
      DATA(lv_sc) = nmin( val1 = lc_w_usable / lv_raw_w
                          val2 = lv_max_img_h / lv_raw_h ).
      IF lv_sc > 1.
        lv_sc = 1.
      ENDIF.

      DATA(lv_ren_w) = lv_raw_w * lv_sc.
      DATA(lv_ren_h) = lv_raw_h * lv_sc.
      DATA(lv_slot_h) = lc_caption_h + lv_ren_h + 4 + lc_gap.  " 4pt bottom padding

      APPEND VALUE ty_img_layout( idx    = lv_pre_idx
                                  ren_w  = lv_ren_w
                                  ren_h  = lv_ren_h
                                  slot_h = lv_slot_h ) TO lt_layout.
    ENDLOOP.

    " Assign images to pages by flowing: fill top-to-bottom until page is full
    TYPES: BEGIN OF ty_page_plan,
             img_indices TYPE STANDARD TABLE OF i WITH EMPTY KEY,
           END OF ty_page_plan.
    DATA lt_pages       TYPE STANDARD TABLE OF ty_page_plan WITH EMPTY KEY.

    DATA lv_remaining_h TYPE f.
    DATA ls_cur_page    TYPE ty_page_plan.

    lv_remaining_h = lc_h_usable - 38.  " First page: reserve space for title header (28pt bar + 10pt gap)
    CLEAR ls_cur_page.

    LOOP AT lt_layout INTO DATA(ls_lay).
      " Will this image fit on current page?
      IF ls_lay-slot_h <= lv_remaining_h.
        " Fits — add to current page
        APPEND ls_lay-idx TO ls_cur_page-img_indices.
        lv_remaining_h = lv_remaining_h - ls_lay-slot_h.
      ELSE.
        " Doesn't fit — flush current page (if non-empty) and start new
        IF ls_cur_page-img_indices IS NOT INITIAL.
          APPEND ls_cur_page TO lt_pages.
        ENDIF.
        CLEAR ls_cur_page.
        APPEND ls_lay-idx TO ls_cur_page-img_indices.
        lv_remaining_h = lc_h_usable - ls_lay-slot_h.  " Subsequent pages: full height
      ENDIF.
    ENDLOOP.

    " Flush last page
    IF ls_cur_page-img_indices IS NOT INITIAL.
      APPEND ls_cur_page TO lt_pages.
    ENDIF.

    DATA(lv_num_pages) = lines( lt_pages ).
    IF lv_num_pages = 0.
      RETURN.
    ENDIF.

    " --- Phase 2: Build PDF structure ---
    DATA lt_offsets TYPE tt_offsets.

    " PDF Header (%PDF-1.4 with binary marker comment)
    rv_pdf = '255044462D312E340A25E2E3CFD30A'.

    " Object 1: Catalog
    append_obj_str( EXPORTING iv_obj_num = 1
                              iv_content = |<< /Type /Catalog /Pages 2 0 R >>|
                    CHANGING  cv_pdf     = rv_pdf
                              ct_offsets = lt_offsets ).

    " Object 2: Pages Tree
    DATA lv_kids TYPE string.
    DO lv_num_pages TIMES.
      lv_kids = |{ lv_kids }{ 2 + sy-index } 0 R |.
    ENDDO.

    append_obj_str(
      EXPORTING
        iv_obj_num = 2
        iv_content = |<< /Type /Pages /Kids [ { lv_kids }] /Count { lv_num_pages } /MediaBox [ 0 0 { lc_w_page } { lc_h_page } ] >>|
      CHANGING
        cv_pdf     = rv_pdf
        ct_offsets = lt_offsets ).

    DATA(lv_font_obj_id) = 2 + ( 2 * lv_num_pages ) + lv_total_imgs + 1.
    DATA(lv_font_bold_id) = lv_font_obj_id + 1.

    " --- Phase 3: Build Page Objects and Content Streams (flowing) ---
    DATA lt_cstreams TYPE TABLE OF string.

    DO lv_num_pages TIMES.
      DATA(lv_p)           = sy-index.
      DATA(lv_page_obj_id) = 2 + lv_p.
      DATA(lv_cs_obj_id)   = 2 + lv_num_pages + lv_p.

      " Get page plan
      ASSIGN lt_pages[ lv_p ] TO FIELD-SYMBOL(<ls_page>).

      " Build XObject resource dictionary for this page
      DATA lv_xobj_dict TYPE string.
      CLEAR lv_xobj_dict.
      LOOP AT <ls_page>-img_indices INTO DATA(lv_img_idx).
        DATA(lv_img_obj_id) = 2 + ( 2 * lv_num_pages ) + lv_img_idx.
        lv_xobj_dict = |{ lv_xobj_dict }/Im{ lv_img_idx } { lv_img_obj_id } 0 R |.
      ENDLOOP.

      " Append Page Object
      append_obj_str(
        EXPORTING
          iv_obj_num = lv_page_obj_id
          iv_content = |<< /Type /Page /Parent 2 0 R\n| &&
                       |   /Resources << /Font << /F1 { lv_font_obj_id } 0 R /F2 { lv_font_bold_id } 0 R >> /XObject << { lv_xobj_dict }>> >>\n| &&
                       |   /Contents { lv_cs_obj_id } 0 R >>|
        CHANGING
          cv_pdf     = rv_pdf
          ct_offsets = lt_offsets ).

      " Generate Content Stream — flow images top to bottom
      DATA lv_page_cs TYPE string.
      CLEAR lv_page_cs.
      DATA(lv_cursor_y) = lc_h_page - lc_margin.  " Start at top of usable area

      " Title header on first page only
      IF lv_p = 1.
        CONSTANTS lc_title_h TYPE f VALUE '28.00'. " Title bar height
        CONSTANTS lc_title_gap TYPE f VALUE '10.00'. " Gap below title

        " Dark blue-gray filled rectangle (full usable width)
        DATA(lv_rect_y) = lv_cursor_y - lc_title_h.
        lv_page_cs = lv_page_cs &&
          |0.20 0.25 0.33 rg { lc_margin } { lv_rect_y } { lc_w_usable } { lc_title_h } re f\n|.

        " White bold centered title text (Helvetica-Bold 16pt)
        DATA(lv_title_text) = escape_pdf_text( 'Repair Images' ).
        DATA(lv_title_x) = lc_margin + ( lc_w_usable / 2 ) - 48.  " Approximate center for 16pt
        DATA(lv_title_y) = lv_rect_y + 8.  " Vertically centered in bar
        lv_page_cs = lv_page_cs &&
          |BT /F2 16 Tf 1 1 1 rg { lv_title_x } { lv_title_y } Td { lv_title_text } Tj ET\n|.

        " Move cursor below title
        lv_cursor_y = lv_rect_y - lc_title_gap.
      ENDIF.

      LOOP AT <ls_page>-img_indices INTO lv_img_idx.
        ASSIGN lt_pdf_images[ lv_img_idx ] TO FIELD-SYMBOL(<ls_img>).
        ASSIGN lt_layout[ lv_img_idx ] TO FIELD-SYMBOL(<ls_dim>).

        " Caption background bar (full width, light blue-gray with thin border)
        DATA(lv_cap_bar_y) = lv_cursor_y - lc_caption_h.
        lv_page_cs = lv_page_cs &&
          |0.88 0.91 0.95 rg { lc_margin } { lv_cap_bar_y } { lc_w_usable } { lc_caption_h } re f\n| &&
          |0.3 w 0.6 0.6 0.6 RG { lc_margin } { lv_cap_bar_y } { lc_w_usable } { lc_caption_h } re S\n|.

        " Caption text
        DATA(lv_cap_y) = lv_cursor_y - 12.
        DATA(lv_cap_txt) = escape_pdf_text( |[{ <ls_img>-source }] { <ls_img>-filename }| ).
        lv_page_cs = lv_page_cs && |BT /F1 9 Tf 0.25 0.25 0.30 rg { lc_margin + 4 } { lv_cap_y } Td { lv_cap_txt } Tj ET\n|.

        " Image position: below caption
        CONSTANTS lc_img_pad TYPE f VALUE '4.00'.
        DATA(lv_img_y) = lv_cursor_y - lc_caption_h - <ls_dim>-ren_h - lc_img_pad.
        DATA(lv_img_x) = lc_margin.

        " Image draw
        lv_page_cs = lv_page_cs &&
          |q { <ls_dim>-ren_w } 0 0 { <ls_dim>-ren_h } { lv_img_x } { lv_img_y + lc_img_pad } cm /Im{ lv_img_idx } Do Q\n|.

        " Thin gray border (full usable width, bottom padding only)
        lv_page_cs = lv_page_cs &&
          |0.5 w 0.6 0.6 0.6 RG { lc_margin } { lv_img_y } { lc_w_usable } { <ls_dim>-ren_h + lc_img_pad } re S\n|.

        " Move cursor down
        lv_cursor_y = lv_img_y - lc_gap.
      ENDLOOP.

      " Page number footer: "Page X of Y" centered at bottom
      DATA(lv_page_text) = escape_pdf_text( |Attachment { lv_p } of { lv_num_pages }| ).
      DATA(lv_footer_x) = lc_margin + ( lc_w_usable / 2 ) - 25.
      DATA(lv_footer_y) = lc_margin - 2.
      lv_page_cs = lv_page_cs &&
        |BT /F1 8 Tf 0.4 0.4 0.4 rg { lv_footer_x } { lv_footer_y } Td { lv_page_text } Tj ET\n|.

      APPEND lv_page_cs TO lt_cstreams.
    ENDDO.

    " Emit Content Stream Objects
    DO lv_num_pages TIMES.
      lv_p = sy-index.
      lv_cs_obj_id = 2 + lv_num_pages + lv_p.
      READ TABLE lt_cstreams INTO lv_page_cs INDEX lv_p.

      DATA lv_cs_x TYPE xstring.
      CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
        EXPORTING
          text   = lv_page_cs
        IMPORTING
          buffer = lv_cs_x
        EXCEPTIONS
          OTHERS = 1 ##SUBRC_OK.                "#EC CI_SUBRC

      append_obj_bin( EXPORTING iv_obj_num = lv_cs_obj_id
                                iv_dict    = |/Length { xstrlen( lv_cs_x ) }|
                                iv_stream  = lv_cs_x
                      CHANGING  cv_pdf     = rv_pdf
                                ct_offsets = lt_offsets ).
    ENDDO.

    " Emit Image XObjects (all images are JPEG at this point)
    LOOP AT lt_pdf_images ASSIGNING <ls_img>.
      DATA(lv_i_idx)  = sy-tabix.
      DATA(lv_img_id) = 2 + ( 2 * lv_num_pages ) + lv_i_idx.
      DATA(lv_w_val)  = COND i( WHEN <ls_img>-width > 0 THEN <ls_img>-width ELSE 800 ).
      DATA(lv_h_val)  = COND i( WHEN <ls_img>-height > 0 THEN <ls_img>-height ELSE 600 ).

      DATA(lv_dict) =
        |/Type /XObject /Subtype /Image /Width { lv_w_val } /Height { lv_h_val } | &&
        |/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length { xstrlen( <ls_img>-content ) }|.

      append_obj_bin( EXPORTING iv_obj_num = lv_img_id
                                iv_dict    = lv_dict
                                iv_stream  = <ls_img>-content
                      CHANGING  cv_pdf     = rv_pdf
                                ct_offsets = lt_offsets ).
    ENDLOOP.

    " Font Objects
    append_obj_str( EXPORTING iv_obj_num = lv_font_obj_id
                              iv_content = |<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>|
                    CHANGING  cv_pdf     = rv_pdf
                              ct_offsets = lt_offsets ).

    append_obj_str( EXPORTING iv_obj_num = lv_font_bold_id
                              iv_content = |<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>|
                    CHANGING  cv_pdf     = rv_pdf
                              ct_offsets = lt_offsets ).

    " Cross-Reference Table & Trailer
    DATA(lv_startxref) = xstrlen( rv_pdf ).
    DATA(lv_total_cnt) = lv_font_bold_id.
    DATA(lv_xref)      = |xref\n0 { lv_total_cnt + 1 }\n0000000000 65535 f \n|.

    LOOP AT lt_offsets INTO DATA(lv_off).
      lv_xref = |{ lv_xref }{ lv_off WIDTH = 10 ALIGN = RIGHT PAD = '0' } 00000 n \n|.
    ENDLOOP.

    lv_xref = lv_xref && |trailer\n<< /Size { lv_total_cnt + 1 } /Root 1 0 R >>\nstartxref\n{ lv_startxref }\n%%EOF\n|.

    DATA lv_xref_x TYPE xstring.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = lv_xref
      IMPORTING
        buffer = lv_xref_x
      EXCEPTIONS
        OTHERS = 1 ##SUBRC_OK.                  "#EC CI_SUBRC

    CONCATENATE rv_pdf lv_xref_x INTO rv_pdf IN BYTE MODE.
  ENDMETHOD.


  METHOD convert_images_to_pdf_ads.
    " Render all images in a single ADS form call — form handles layout/pagination.
    " Pass the image table; the form iterates and places each image on the page.
    CLEAR rv_pdf.

    CONSTANTS lc_form_name TYPE fpname VALUE '/CTDI/REPAIR_IMG'.

    IF it_attachments IS INITIAL.
      RETURN.
    ENDIF.

    " Pre-resize images to fit within the ADS print area (192mm x 267mm)
    " DPI-aware: reads actual DPI from image metadata, assumes 96 if missing
    DATA lt_resized TYPE tt_image_attachments.
    lt_resized = it_attachments.

    LOOP AT lt_resized ASSIGNING FIELD-SYMBOL(<ls_ads_img>).
      DATA lv_ads_dpi TYPE i.
      DATA(lv_resized) = resize_if_needed( EXPORTING iv_content  = <ls_ads_img>-content
                                                     iv_width    = <ls_ads_img>-width
                                                     iv_height   = <ls_ads_img>-height
                                                     iv_max_w_mm = CONV f( '195.00' )
                                                     iv_max_h_mm = CONV f( '267.70' )
                                           IMPORTING ev_eff_dpi  = lv_ads_dpi ).
      <ls_ads_img>-dpi = lv_ads_dpi.
      IF lv_resized <> <ls_ads_img>-content.
        <ls_ads_img>-content = lv_resized.
        extract_image_dimensions( EXPORTING iv_content = <ls_ads_img>-content
                                            iv_ext     = <ls_ads_img>-file_ext
                                  IMPORTING ev_width   = <ls_ads_img>-width
                                            ev_height  = <ls_ads_img>-height ).
      ENDIF.
    ENDLOOP.

    " Determine form function module name
    DATA lv_fmname TYPE funcname.
    TRY.
        CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
          EXPORTING
            i_name     = lc_form_name
          IMPORTING
            e_funcname = lv_fmname.
      CATCH cx_root.
        /ctdi/cl_print_driver_log=>log_warning( |ADS form { lc_form_name } not found or inactive| ).
        RETURN.
    ENDTRY.

    " Open ADS print job (PDF output mode)
    DATA ls_outputparams TYPE sfpoutputparams.
    ls_outputparams-nodialog = abap_true.
    ls_outputparams-getpdf   = abap_true.

    CALL FUNCTION 'FP_JOB_OPEN'
      CHANGING
        ie_outputparams = ls_outputparams
      EXCEPTIONS
        OTHERS          = 1.
    IF sy-subrc <> 0.
      /ctdi/cl_print_driver_log=>log_warning( |ADS FP_JOB_OPEN failed for image rendering| ).
      RETURN.
    ENDIF.

    " Single form call — pass the entire image table
    DATA ls_formoutput TYPE fpformoutput.
    TRY.
        CALL FUNCTION lv_fmname
          EXPORTING
            /1bcdwb/docparams  = VALUE sfpdocparams( fillable = space )
            it_images          = lt_resized
          IMPORTING
            /1bcdwb/formoutput = ls_formoutput
          EXCEPTIONS
            OTHERS             = 1.

        IF sy-subrc <> 0.
          /ctdi/cl_print_driver_log=>log_warning( |ADS form { lc_form_name } execution failed| ).
        ENDIF.
      CATCH cx_root INTO DATA(lx_form).
        /ctdi/cl_print_driver_log=>log_warning( |ADS form call error: { lx_form->get_text( ) }| ).
    ENDTRY.

    " Close job
    CALL FUNCTION 'FP_JOB_CLOSE'
      EXCEPTIONS
        OTHERS = 0.

    " Retrieve PDF output
    IF ls_formoutput-pdf IS NOT INITIAL.
      rv_pdf = ls_formoutput-pdf.
      /ctdi/cl_print_driver_log=>log_info( |ADS rendered { lines( lt_resized ) } image(s) via form { lc_form_name }| ).
    ENDIF.
  ENDMETHOD.


  METHOD convert_to_jpeg.
    CLEAR rv_jpeg.

    DATA(lv_ext_upper) = to_upper( condense( iv_ext ) ).

    " Already JPEG — return as-is
    IF lv_ext_upper = 'JPG' OR lv_ext_upper = 'JPEG'.
      rv_jpeg = iv_content.
      RETURN.
    ENDIF.

    " Convert PNG/BMP/TIFF to JPEG via CL_FXS_IMAGE_PROCESSOR (wraps IGS)
    TRY.
        DATA(lo_proc) = NEW cl_fxs_image_processor( ).
        DATA(lv_handle) = lo_proc->add_image( iv_data = iv_content ).

        /ctdi/cl_print_driver_log=>log_info( |FXS convert_to_jpeg: ext={ lv_ext_upper }, size={ xstrlen( iv_content ) }| ).

        " Convert to JPEG
        lo_proc->convert( iv_handle = lv_handle
                          iv_format = cl_fxs_mime_types=>co_image_jpeg ).

        " Get result
        rv_jpeg = lo_proc->get_image( iv_handle = lv_handle ).

        /ctdi/cl_print_driver_log=>log_info( |FXS result: output_size={ xstrlen( rv_jpeg ) }| ).

        " Validate: JPEG must start with FFD8
        IF xstrlen( rv_jpeg ) < 2 OR rv_jpeg(2) <> 'FFD8'.
          /ctdi/cl_print_driver_log=>log_warning(
              |FXS output for { lv_ext_upper } is not valid JPEG, size={ xstrlen( rv_jpeg ) }| ).
          CLEAR rv_jpeg.
        ENDIF.

        lo_proc->discard_image( iv_handle = lv_handle ).

      CATCH cx_fxs_image_unsupported INTO DATA(lx_unsup).
        /ctdi/cl_print_driver_log=>log_warning( |Image format { lv_ext_upper } not supported: { lx_unsup->get_text( ) }| ).
        CLEAR rv_jpeg.
      CATCH cx_root INTO DATA(lx_err).
        /ctdi/cl_print_driver_log=>log_warning( |Image conversion error for { lv_ext_upper }: { lx_err->get_text( ) }| ).
        CLEAR rv_jpeg.
    ENDTRY.
  ENDMETHOD.


  METHOD deduplicate_attachments.
    CLEAR rt_unique.

    IF it_attachments IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_seen_hash,
             hash TYPE string,
           END OF ty_seen_hash.

    " TODO: variable is assigned but never used (ABAP cleaner)
    DATA lt_seen_hashes TYPE HASHED TABLE OF ty_seen_hash WITH UNIQUE KEY hash.
    " TODO: variable is assigned but never used (ABAP cleaner)
    DATA lt_seen_ids    TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT it_attachments ASSIGNING FIELD-SYMBOL(<ls_att>).
      " 1. Fast ID Check (Skips exact duplicate GOS/ArchiveLink pointers)
      IF <ls_att>-atta_id IS NOT INITIAL.
        INSERT <ls_att>-atta_id INTO TABLE lt_seen_ids.
        IF sy-subrc <> 0.
          CONTINUE. " ID already processed
        ENDIF.
      ENDIF.

      " 2. Binary Hash Check (Skips identical images under different IDs)
      DATA(lv_hash) = ||.
      TRY.
          cl_abap_message_digest=>calculate_hash_for_raw( EXPORTING if_algorithm  = 'SHA256'
                                                                    if_data       = <ls_att>-content
                                                          IMPORTING ef_hashstring = lv_hash ).
        CATCH cx_abap_message_digest.
          " Fallback if digest fails: byte length + sample slice
          DATA(lv_slice) = COND xstring( WHEN xstrlen( <ls_att>-content ) >= 16
                                         THEN <ls_att>-content(16)
                                         ELSE <ls_att>-content ).
          lv_hash = |{ xstrlen( <ls_att>-content ) }_{ lv_slice }|.
      ENDTRY.

      INSERT VALUE #( hash = lv_hash ) INTO TABLE lt_seen_hashes.
      IF sy-subrc <> 0.
        CONTINUE. " Exact binary duplicate already included
      ENDIF.

      " 3. Keep unique item in original sequence
      APPEND <ls_att> TO rt_unique.
    ENDLOOP.
  ENDMETHOD.


  METHOD escape_pdf_text.
    DATA(lv_s) = iv_text.
    REPLACE ALL OCCURRENCES OF '\' IN lv_s WITH '\\'.
    REPLACE ALL OCCURRENCES OF '(' IN lv_s WITH '\('.
    REPLACE ALL OCCURRENCES OF ')' IN lv_s WITH '\)'.
    rv_hex = |({ lv_s })|.
  ENDMETHOD.


  METHOD extract_image_dimensions.
    CLEAR: ev_width,
           ev_height.

    DATA(lv_len) = xstrlen( iv_content ).
    IF lv_len < 10.
      RETURN.
    ENDIF.

    DATA(lv_ext_upper) = to_upper( iv_ext ).

    " 1. JPEG Dimensions (SOF0: 0xFFC0, SOF2: 0xFFC2)
    IF lv_ext_upper = 'JPG' OR lv_ext_upper = 'JPEG'.
      DATA lv_pos TYPE i VALUE 2.
      WHILE lv_pos < lv_len - 8.
        IF iv_content+lv_pos(1) = 'FF'.
          DATA(lv_m_pos) = lv_pos + 1.
          DATA(lv_marker) = iv_content+lv_m_pos(1).
          IF lv_marker = 'C0' OR lv_marker = 'C1' OR lv_marker = 'C2'.
            DATA(lv_h_pos) = lv_pos + 5.
            DATA(lv_w_pos) = lv_pos + 7.
            ev_height = CONV i( iv_content+lv_h_pos(2) ).
            ev_width  = CONV i( iv_content+lv_w_pos(2) ).
            RETURN.
          ELSEIF lv_marker = 'DA' OR lv_marker = 'D9'.
            EXIT.
          ELSEIF lv_marker <> '00' AND lv_marker <> 'FF'.
            DATA(lv_l_pos) = lv_pos + 2.
            DATA(lv_seg_len) = CONV i( iv_content+lv_l_pos(2) ).
            lv_pos = lv_pos + 2 + lv_seg_len.
            CONTINUE.
          ENDIF.
        ENDIF.
        lv_pos = lv_pos + 1.
      ENDWHILE.
    ENDIF.

    " 2. PNG Dimensions (IHDR chunk at byte offset 16..23)
    IF lv_ext_upper = 'PNG' AND lv_len >= 24.
      ev_width  = CONV i( iv_content+16(4) ).
      ev_height = CONV i( iv_content+20(4) ).
    ENDIF.
  ENDMETHOD.


  METHOD extract_jpeg_channels.
    " SOF marker structure: FF C0/C1/C2 [len:2] [precision:1] [height:2] [width:2] [channels:1]
    " channels byte is at offset SOF_pos + 9
    CLEAR ev_channels.
    DATA(lv_len) = xstrlen( iv_content ).
    DATA(lv_pos) = 2.

    WHILE lv_pos < lv_len - 9.
      IF iv_content+lv_pos(1) = 'FF'.
        DATA(lv_mp) = lv_pos + 1.
        DATA(lv_m) = iv_content+lv_mp(1).
        IF lv_m = 'C0' OR lv_m = 'C1' OR lv_m = 'C2'.
          DATA(lv_ch_pos) = lv_pos + 9.
          IF lv_ch_pos < lv_len.
            ev_channels = CONV i( iv_content+lv_ch_pos(1) ).
          ENDIF.
          RETURN.
        ELSEIF lv_m = 'DA' OR lv_m = 'D9'.
          EXIT.
        ELSEIF lv_m <> '00' AND lv_m <> 'FF'.
          DATA(lv_lp) = lv_pos + 2.
          DATA(lv_sl) = CONV i( iv_content+lv_lp(2) ).
          lv_pos = lv_pos + 2 + lv_sl.
          CONTINUE.
        ENDIF.
      ENDIF.
      lv_pos = lv_pos + 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD get_attachments.
    CLEAR rt_attachments.

    IF iv_repair_order IS INITIAL.
      RETURN.
    ENDIF.

    " 1. GOS images from Repair Order — resolve BOR type from order category (AUTYP)
    DATA(lv_aufnr) = |{ iv_repair_order ALPHA = IN }|.

    " Determine correct BOR object type: AUTYP 30 = Service Order (BUS2088), else PM Order (BUS2007)
    DATA lv_autyp TYPE aufk-autyp.
    SELECT SINGLE autyp FROM aufk
      WHERE aufnr = @lv_aufnr
      INTO @lv_autyp ##WARN_OK.

    DATA(lv_gos_objtype) = COND swo_objtyp(
      WHEN lv_autyp = '30'
      THEN gc_objtype_cs_order    " BUS2088 (Service Order / IW31 CS)
      ELSE gc_objtype_repair ).                          " BUS2007 (PM Order / IW31 PM fallback)

    DATA(lt_order_images) = get_gos_attachments( iv_objtype = lv_gos_objtype
                                                 iv_objkey  = CONV #( lv_aufnr )
                                                 iv_source  = 'Repair Order' ).
    APPEND LINES OF lt_order_images TO rt_attachments.

    " 2. Content Server images from CS-Order (BUS2088 / ArchiveLink)
    DATA(lt_cs_images) = get_content_server_attachments( iv_object_id = CONV #( lv_aufnr )
                                                         iv_objtype   = gc_objtype_cs_order
                                                         iv_source    = 'Repair Order' ).
    APPEND LINES OF lt_cs_images TO rt_attachments.

    " 3. GOS images from linked Service Notification (BUS2078/QMEL)
    DATA(lv_qmnum) = resolve_notification( iv_aufnr = iv_repair_order ).
    IF lv_qmnum IS NOT INITIAL.
      DATA(lv_qmnum_key) = |{ lv_qmnum ALPHA = IN }|.
      DATA(lt_notif_images) = get_gos_attachments( iv_objtype = gc_objtype_qmel
                                                   iv_objkey  = CONV #( lv_qmnum_key )
                                                   iv_source  = 'Notification' ).
      IF lt_notif_images IS INITIAL.
        lt_notif_images = get_gos_attachments( iv_objtype = gc_objtype_qmel_alt
                                               iv_objkey  = CONV #( lv_qmnum_key )
                                               iv_source  = 'Notification' ).
      ENDIF.
      APPEND LINES OF lt_notif_images TO rt_attachments.

      " 4. Content Server images from linked Notification (BUS2078 / QMEL / ArchiveLink)
      DATA(lt_cs_notif) = get_content_server_attachments( iv_object_id = CONV #( lv_qmnum_key )
                                                          iv_objtype   = gc_objtype_qmel
                                                          iv_source    = 'Notification' ).
      IF lt_cs_notif IS INITIAL.
        lt_cs_notif = get_content_server_attachments( iv_object_id = CONV #( lv_qmnum_key )
                                                      iv_objtype   = gc_objtype_qmel_alt
                                                      iv_source    = 'Notification' ).
      ENDIF.
      APPEND LINES OF lt_cs_notif TO rt_attachments.
    ENDIF.

    " Deduplicate attachments (preserves order, eliminates cross-backend duplicates)
    rt_attachments = deduplicate_attachments( rt_attachments ).
  ENDMETHOD.


  METHOD get_content_server_attachments.
    CLEAR rt_attachments.

    " Find ArchiveLink documents on Content Server (TOA01)
    " Supported: BUS2088 (CS-Order), BUS2007 (Repair Order), BUS2078/QMEL (Notification)
    DATA lt_connections TYPE STANDARD TABLE OF toav0.

    cl_alink_connection=>find( EXPORTING  sap_object       = iv_objtype
                                          object_id        = iv_object_id
                               IMPORTING  connections      = lt_connections
                               EXCEPTIONS not_found        = 1
                                          error_authorithy = 2
                                          error_parameter  = 3
                                          OTHERS           = 4 ).

    IF sy-subrc <> 0 OR lt_connections IS INITIAL.
      RETURN.
    ENDIF.

    " Pre-read all TOAAT filenames for the found documents (avoid SELECT in loop)
    DATA lt_arc_doc_ids TYPE RANGE OF toaat-arc_doc_id.
    LOOP AT lt_connections INTO DATA(ls_conn_pre) WHERE ar_object = gc_archiv_ar_jpg.
      APPEND VALUE #( sign   = 'I'
                      option = 'EQ'
                      low    = ls_conn_pre-arc_doc_id ) TO lt_arc_doc_ids.
    ENDLOOP.

    DATA lt_toaat TYPE STANDARD TABLE OF toaat WITH KEY arc_doc_id.
    IF lt_arc_doc_ids IS NOT INITIAL.
      SELECT arc_doc_id, filename FROM toaat
        WHERE arc_doc_id IN @lt_arc_doc_ids
        INTO CORRESPONDING FIELDS OF TABLE @lt_toaat.
    ENDIF.

    LOOP AT lt_connections INTO DATA(ls_conn).
      " Only process image document types (ZRS_JPG)
      IF ls_conn-ar_object <> gc_archiv_ar_jpg.
        CONTINUE.
      ENDIF.

      " Get filename from pre-read TOAAT data
      DATA lv_filename TYPE toaat-filename.
      READ TABLE lt_toaat INTO DATA(ls_toaat) WITH KEY arc_doc_id = ls_conn-arc_doc_id.
      IF sy-subrc = 0.
        lv_filename = ls_toaat-filename.
      ELSE.
        lv_filename = |image_{ sy-tabix }.jpg|.
      ENDIF.

      " Retrieve binary content from Content Server
      DATA lt_bindata TYPE TABLE OF tbl1024.
      DATA lv_length  TYPE i.

      CLEAR: lt_bindata,
             lv_length.

      CALL FUNCTION 'SCMS_AO_TABLE_GET'
        EXPORTING
          arc_id       = ls_conn-archiv_id
          doc_id       = ls_conn-arc_doc_id
        IMPORTING
          length       = lv_length
        TABLES
          data         = lt_bindata
        EXCEPTIONS
          error_http   = 1
          error_archiv = 2
          error_kernel = 3
          error_config = 4
          OTHERS       = 5.

      IF sy-subrc <> 0 OR lv_length = 0 OR lt_bindata IS INITIAL.
        /ctdi/cl_print_driver_log=>log_warning( |Content Server read failed for doc { ls_conn-arc_doc_id }| ).
        CONTINUE.
      ENDIF.

      " Convert binary table to xstring
      DATA lv_content TYPE xstring.
      CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
        EXPORTING
          input_length = lv_length
        IMPORTING
          buffer       = lv_content
        TABLES
          binary_tab   = lt_bindata
        EXCEPTIONS
          OTHERS       = 1 ##SUBRC_OK.           "#EC CI_SUBRC

      IF lv_content IS INITIAL.
        CONTINUE.
      ENDIF.

      " Determine file extension from filename
      DATA(lv_ext) = 'JPG'.
      DATA(lv_dot_pos) = find( val = CONV string( lv_filename )
                               sub = '.'
                               occ = -1 ).
      IF lv_dot_pos >= 0.
        lv_ext = to_upper( substring( val = CONV string( lv_filename )
                                      off = lv_dot_pos + 1 ) ).
      ENDIF.

      IF is_supported_image_ext( lv_ext ) = abap_false.
        CONTINUE.
      ENDIF.

      " Build result entry
      DATA ls_img TYPE ty_image_attachment.
      ls_img-atta_id  = CONV #( ls_conn-arc_doc_id ).
      ls_img-filename = CONV string( lv_filename ).
      ls_img-file_ext = lv_ext.
      ls_img-mimetype = get_mimetype_for_ext( lv_ext ).
      ls_img-content  = lv_content.
      ls_img-source   = iv_source.
      ls_img-objkey   = iv_object_id.

      extract_image_dimensions( EXPORTING iv_content = ls_img-content
                                          iv_ext     = ls_img-file_ext
                                IMPORTING ev_width   = ls_img-width
                                          ev_height  = ls_img-height ).

      APPEND ls_img TO rt_attachments.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_gos_attachments.
    CLEAR rt_attachments.

    DATA(ls_object) = VALUE sibflporb( catid  = 'BO'
                                       typeid = iv_objtype
                                       instid = iv_objkey ).

    DATA lt_links TYPE obl_t_link.

    TRY.
        cl_binary_relation=>read_links_of_binrel( EXPORTING is_object   = ls_object
                                                            ip_relation = 'ATTA'
                                                  IMPORTING et_links    = lt_links ).
      CATCH cx_root INTO DATA(lx_rel).
        /ctdi/cl_print_driver_log=>log_warning(
            |GOS attachment link lookup failed for { iv_objtype } { iv_objkey }: { lx_rel->get_text( ) }| ).
        RETURN.
    ENDTRY.

    LOOP AT lt_links ASSIGNING FIELD-SYMBOL(<ls_link>).
      DATA(lv_doc_id) = CONV so_entryid( <ls_link>-instid_b ).

      DATA ls_doc_data    TYPE sofolenti1.
      DATA lt_hex_content TYPE solix_tab.
      DATA lv_content     TYPE xstring.

      CALL FUNCTION 'SO_DOCUMENT_READ_API1'
        EXPORTING
          document_id                = lv_doc_id
        IMPORTING
          document_data              = ls_doc_data
        TABLES
          contents_hex               = lt_hex_content
        EXCEPTIONS
          document_id_not_exist      = 1
          operation_no_authorization = 2
          x_error                    = 3
          OTHERS                     = 4.

      IF sy-subrc <> 0 OR lt_hex_content IS INITIAL.
        /ctdi/cl_print_driver_log=>log_warning(
            |Failed to read SOFM document { lv_doc_id } for { iv_objtype } { iv_objkey }| ).
        CONTINUE.
      ENDIF.

      " ABAP 7.50: Convert binary table to xstring
      CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
        EXPORTING
          input_length = CONV i( ls_doc_data-doc_size )
        IMPORTING
          buffer       = lv_content
        TABLES
          binary_tab   = lt_hex_content
        EXCEPTIONS
          OTHERS       = 1 ##SUBRC_OK.          "#EC CI_SUBRC

      IF lv_content IS INITIAL.
        CONTINUE.
      ENDIF.

      " Resolve file extension: Check obj_type -> filename parsing
      DATA(lv_fname) = CONV string( ls_doc_data-obj_descr ).
      DATA(lv_ext)   = to_upper( CONV string( ls_doc_data-obj_type ) ).

      IF lv_ext IS INITIAL OR lv_ext = 'EXT' OR lv_ext = 'RAW'.
        DATA(lv_dot_pos) = find( val = lv_fname
                                 sub = '.'
                                 occ = -1 ).
        IF lv_dot_pos >= 0.
          lv_ext = to_upper( substring( val = lv_fname
                                        off = lv_dot_pos + 1 ) ).
        ENDIF.
      ENDIF.

      IF is_supported_image_ext( lv_ext ) = abap_true.
        DATA(ls_img) = VALUE ty_image_attachment( atta_id  = CONV #( lv_doc_id )
                                                  filename = lv_fname
                                                  file_ext = lv_ext
                                                  mimetype = get_mimetype_for_ext( lv_ext )
                                                  content  = lv_content
                                                  source   = iv_source
                                                  objkey   = iv_objkey ).

        extract_image_dimensions( EXPORTING iv_content = ls_img-content
                                            iv_ext     = ls_img-file_ext
                                  IMPORTING ev_width   = ls_img-width
                                            ev_height  = ls_img-height ).

        APPEND ls_img TO rt_attachments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_mimetype_for_ext.
    DATA(lv_e) = to_upper( condense( CONV string( iv_ext ) ) ).
    rv_mimetype = COND #(
      WHEN lv_e = 'JPG' OR lv_e = 'JPEG' THEN 'image/jpeg'
      WHEN lv_e = 'PNG'                  THEN 'image/png'
      WHEN lv_e = 'BMP'                  THEN 'image/bmp'
      WHEN lv_e = 'TIF' OR lv_e = 'TIFF' THEN 'image/tiff'
      WHEN lv_e = 'GIF'                  THEN 'image/gif'
      ELSE                                    |image/{ to_lower( lv_e ) }| ).
  ENDMETHOD.


  METHOD get_orders_with_images.
    CLEAR: rt_aufnr_with_images,
           et_with_attachments.

    IF it_aufnr_range IS INITIAL.
      RETURN.
    ENDIF.

    " 1. Check GOS/SOFFICE attachments — then filter by image extension via SOOD
    SELECT DISTINCT instid_a, instid_b
      FROM srgbtbrel
      WHERE instid_a IN @it_aufnr_range
        AND ( typeid_a = @gc_objtype_cs_order OR typeid_a = @gc_objtype_repair )
        AND reltype = 'ATTA'
      INTO TABLE @DATA(lt_gos_links) ##TOO_MANY_ITAB_FIELDS.

    " Extract SOOD doc keys from instid_b
    " instid_b structure (34 chars):
    "   [0-2]   Area (FOL/RAW)  3 chars
    "   [3-4]   Year            2 chars
    "   [5-16]  Folder Number  12 chars
    "   [17-19] Doc Area (EXT/RAW) 3 chars
    "   [20-21] Doc Year        2 chars
    "   [22-33] Doc Number     12 chars  → SOOD-OBJNO
    DATA lt_sood_keys TYPE RANGE OF sood-objno.
    LOOP AT lt_gos_links INTO DATA(ls_link).
      DATA(lv_instid) = condense( CONV string( ls_link-instid_b ) ).
      IF strlen( lv_instid ) >= 34.
        DATA(lv_objno) = substring( val = lv_instid
                                    off = 22
                                    len = 12 ).
        APPEND VALUE #( sign   = 'I'
                        option = 'EQ'
                        low    = lv_objno ) TO lt_sood_keys.
      ENDIF.
    ENDLOOP.

    " Query SOOD for image file extensions only
    IF lt_sood_keys IS NOT INITIAL.
      SELECT objno, file_ext FROM sood
        WHERE objno IN @lt_sood_keys
          AND (    file_ext = 'jpg' OR file_ext = 'png'
                OR file_ext = 'bmp' OR file_ext = 'tif' )
        INTO TABLE @DATA(lt_img_docs).

      " Map back to order numbers
      DATA lt_img_objnos TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
      LOOP AT lt_img_docs INTO DATA(ls_doc).
        INSERT CONV string( ls_doc-objno ) INTO TABLE lt_img_objnos.
      ENDLOOP.

      LOOP AT lt_gos_links INTO ls_link.
        lv_instid = condense( ls_link-instid_b ).
        IF strlen( lv_instid ) >= 34.
          lv_objno = substring( val = lv_instid
                                off = 22
                                len = 12 ).
          READ TABLE lt_img_objnos WITH KEY table_line = lv_objno TRANSPORTING NO FIELDS.
          IF sy-subrc = 0.
            INSERT CONV aufnr( ls_link-instid_a ) INTO TABLE rt_aufnr_with_images.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " 2. Check Content Server / ArchiveLink (TOA01) — ZRS_JPG (confirmed images)
    SELECT DISTINCT object_id FROM toa01
      WHERE object_id IN @it_aufnr_range
        AND ( sap_object = @gc_objtype_cs_order OR sap_object = @gc_objtype_repair )
        AND ar_object = @gc_archiv_ar_jpg
      INTO TABLE @DATA(lt_cs_orders).

    LOOP AT lt_cs_orders INTO DATA(ls_cs).
      INSERT CONV aufnr( ls_cs-object_id ) INTO TABLE rt_aufnr_with_images.
    ENDLOOP.

    " 3. Orders with GOS attachments but no confirmed images → attachment icon
    LOOP AT lt_gos_links INTO ls_link.
      DATA(lv_aufnr) = CONV aufnr( ls_link-instid_a ).
      READ TABLE rt_aufnr_with_images WITH KEY table_line = lv_aufnr TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        INSERT lv_aufnr INTO TABLE et_with_attachments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD has_png_alpha.
    " PNG IHDR chunk: byte 25 (offset from file start) = color type
    " Color types: 0=Grayscale, 2=RGB, 3=Palette, 4=Grayscale+Alpha, 6=RGBA
    rv_has_alpha = abap_false.

    IF xstrlen( iv_png ) < 26.
      RETURN.
    ENDIF.

    " Verify PNG signature
    IF iv_png(8) <> '89504E470D0A1A0A'.
      RETURN.
    ENDIF.

    " Color type is at byte offset 25 (8 sig + 4 len + 4 type + 8 IHDR fields + 1 = 25)
    DATA(lv_color_type) = CONV i( iv_png+25(1) ).

    " Type 4 = Grayscale + Alpha, Type 6 = RGB + Alpha
    IF lv_color_type = 4 OR lv_color_type = 6.
      rv_has_alpha = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD is_supported_image_ext.
    DATA(lv_e) = to_upper( condense( CONV string( iv_ext ) ) ).
    rv_is_image = xsdbool( lv_e = 'JPG' OR lv_e = 'JPEG' OR lv_e = 'PNG' OR lv_e = 'BMP' OR lv_e = 'TIF' OR lv_e = 'TIFF' ).
  ENDMETHOD.


  METHOD merge_pdfs.
    rv_pdf = iv_base_pdf.

    IF iv_images_pdf IS INITIAL.
      RETURN.
    ENDIF.

    DATA lo_merger TYPE REF TO cl_rspo_pdf_merge.
    TRY.
        CREATE OBJECT lo_merger.
        lo_merger->add_document( iv_base_pdf ).
        lo_merger->add_document( iv_images_pdf ).

        DATA lv_rc     TYPE i.
        DATA lv_merged TYPE xstring.

        lo_merger->merge_documents( IMPORTING merged_document = lv_merged
                                              rc              = lv_rc ).

        IF lv_rc = 0 AND lv_merged IS NOT INITIAL.
          rv_pdf = lv_merged.
        ELSE.
          /ctdi/cl_print_driver_log=>log_warning( |CL_RSPO_PDF_MERGE failed with rc={ lv_rc }| ).
        ENDIF.
      CATCH cx_rspo_pdf_merge INTO DATA(lx_merge).
        /ctdi/cl_print_driver_log=>log_exception( lx_merge ).
      CATCH cx_root INTO DATA(lx_root).
        /ctdi/cl_print_driver_log=>log_exception( lx_root ).
    ENDTRY.
  ENDMETHOD.


  METHOD resize_if_needed.
    rv_content = iv_content.
    CLEAR ev_eff_dpi.

    IF iv_content IS INITIAL OR iv_width <= 0 OR iv_height <= 0.
      ev_eff_dpi = 96.
      RETURN.
    ENDIF.

    CONSTANTS lc_default_dpi TYPE i VALUE 96. " ADS native rendering DPI
    CONSTANTS lc_mm_per_inch TYPE f VALUE '25.4'.

    TRY.
        DATA(lo_proc) = NEW cl_fxs_image_processor( ).
        DATA(lv_handle) = lo_proc->add_image( iv_data = iv_content ).

        " Read actual DPI from image metadata
        DATA lv_xdpi TYPE i.
        DATA lv_ydpi TYPE i.
        lo_proc->get_info( EXPORTING iv_handle = lv_handle
                           IMPORTING ev_xdpi   = lv_xdpi
                                     ev_ydpi   = lv_ydpi ).

        " Fallback to default DPI if metadata is missing
        IF lv_xdpi <= 0.
          lv_xdpi = lc_default_dpi.
        ENDIF.
        IF lv_ydpi <= 0.
          lv_ydpi = lc_default_dpi.
        ENDIF.

        " Determine effective DPI for sizing:
        " - Large images (>2000px): force 96 DPI so ADS renders them at correct size
        " - Smaller images: use actual DPI from metadata (e.g. 300 DPI logos stay small)
        CONSTANTS lc_large_px TYPE i VALUE 2000.
        DATA(lv_eff_dpi) = lv_xdpi.
        IF iv_width > lc_large_px OR iv_height > lc_large_px.
          lv_eff_dpi = lc_default_dpi.
        ENDIF.
        ev_eff_dpi = lv_eff_dpi.

        " Calculate physical size in mm using effective DPI
        DATA(lv_phys_w_mm) = CONV f( iv_width ) / lv_eff_dpi * lc_mm_per_inch.
        DATA(lv_phys_h_mm) = CONV f( iv_height ) / lv_eff_dpi * lc_mm_per_inch.

        /ctdi/cl_print_driver_log=>log_info(
            |Image { iv_width }x{ iv_height }px, orig={ lv_xdpi }x{ lv_ydpi } eff={ lv_eff_dpi } DPI = { lv_phys_w_mm }x{ lv_phys_h_mm }mm (max={ iv_max_w_mm }x{ iv_max_h_mm })| ).

        " Check if image fits within print area at effective DPI
        IF lv_phys_w_mm <= iv_max_w_mm AND lv_phys_h_mm <= iv_max_h_mm.
          " Fits — no pixel resize needed
          lo_proc->discard_image( iv_handle = lv_handle ).
          RETURN.
        ENDIF.

        " Doesn't fit — resize pixels so it fits
        DATA(lv_scale) = nmin( val1 = iv_max_w_mm / lv_phys_w_mm
                               val2 = iv_max_h_mm / lv_phys_h_mm ).

        DATA(lv_target_w) = CONV i( iv_width * lv_scale ).
        DATA(lv_target_h) = CONV i( iv_height * lv_scale ).

        lo_proc->resize( iv_handle = lv_handle
                         iv_xres   = lv_target_w
                         iv_yres   = lv_target_h ).

        rv_content = lo_proc->get_image( iv_handle = lv_handle ).
        lo_proc->discard_image( iv_handle = lv_handle ).

        /ctdi/cl_print_driver_log=>log_info(
            |Resized: { iv_width }x{ iv_height } -> { lv_target_w }x{ lv_target_h }px | &&
            |(fits { iv_max_w_mm }x{ iv_max_h_mm }mm at { lv_eff_dpi } DPI)| ).

      CATCH cx_root INTO DATA(lx_err).
        /ctdi/cl_print_driver_log=>log_warning( |Image resize failed: { lx_err->get_text( ) } - using original| ).
        rv_content = iv_content.
        ev_eff_dpi = 96.
    ENDTRY.
  ENDMETHOD.


  METHOD resolve_notification.
    CLEAR rv_qmnum.

    IF iv_aufnr IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_aufnr) = |{ iv_aufnr ALPHA = IN }|.

    " 1. Query QMEL by AUFNR
    SELECT SINGLE qmnum FROM qmel
      WHERE aufnr = @lv_aufnr
      INTO @rv_qmnum ##WARN_OK.

    " 2. Fallback: Query AFIH by AUFNR
    IF rv_qmnum IS INITIAL.
      SELECT SINGLE qmnum FROM afih
        WHERE aufnr = @lv_aufnr
        INTO @rv_qmnum ##WARN_OK.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
