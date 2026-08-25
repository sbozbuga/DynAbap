CLASS /ctdi/cl_print_gos_images DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS gc_objtype_repair   TYPE swo_objtyp VALUE 'BUS2007' ##NO_TEXT.
    CONSTANTS gc_objtype_cs_order TYPE swo_objtyp VALUE 'BUS2088' ##NO_TEXT.
    CONSTANTS gc_objtype_qmel     TYPE swo_objtyp VALUE 'BUS2078' ##NO_TEXT.
    CONSTANTS gc_objtype_qmel_alt TYPE swo_objtyp VALUE 'QMEL' ##NO_TEXT.
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
           END OF ty_image_attachment,
           tt_image_attachments TYPE STANDARD TABLE OF ty_image_attachment WITH EMPTY KEY.

    "! High-level entry point: retrieves images and merges them into the input PDF stream.
    "!
    "! @parameter iv_repair_order | Repair Order Number (AUFNR)
    "! @parameter iv_pdf          | Input PDF byte stream
    "! @parameter rv_pdf          | Output PDF byte stream (with images appended if found)
    METHODS append_images
      IMPORTING iv_repair_order TYPE aufnr
                iv_pdf          TYPE xstring
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

    "! Filters raw attachments by file extension (JPG, PNG, BMP, TIFF).
    "!
    "! @parameter it_raw      | Raw attachment list
    "! @parameter rt_filtered | Filtered list containing only supported image files
    CLASS-METHODS filter_image_attachments
      IMPORTING it_raw             TYPE tt_image_attachments
      RETURNING VALUE(rt_filtered) TYPE tt_image_attachments.

    "! Checks whether a given file extension is a supported image type.
    "!
    "! @parameter iv_ext      | File extension (e.g. 'JPG', 'PNG')
    "! @parameter rv_is_image | True if supported image format
    CLASS-METHODS is_supported_image_ext
      IMPORTING iv_ext             TYPE clike
      RETURNING VALUE(rv_is_image) TYPE abap_bool.

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
      IMPORTING it_attachments  TYPE tt_image_attachments
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
    "! @parameter iv_ext | File extension (e.g. PNG, BMP, TIFF)
    "! @parameter rv_jpeg | Converted JPEG xstring (or empty on failure)
    CLASS-METHODS convert_to_jpeg
      IMPORTING iv_content     TYPE xstring
                iv_ext         TYPE string
      RETURNING VALUE(rv_jpeg) TYPE xstring.

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


CLASS /ctdi/cl_print_gos_images IMPLEMENTATION.
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

        " 2. Convert images to A4 PDF pages
        DATA(lv_images_pdf) = convert_images_to_pdf( it_attachments = lt_images ).

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

    DATA(lv_head) = |{ iv_obj_num } 0 obj\n<< { iv_dict } >>\nstream\n|.
    DATA(lv_head_x) = cl_bcs_convert=>string_to_xstring(
      iv_string   = lv_head
      iv_codepage = '1100' ).

    DATA(lv_tail_x) = cl_bcs_convert=>string_to_xstring(
      iv_string   = |\nendstream\nendobj\n|
      iv_codepage = '1100' ).

    CONCATENATE cv_pdf lv_head_x iv_stream lv_tail_x INTO cv_pdf IN BYTE MODE.
  ENDMETHOD.

  METHOD append_obj_str.
    APPEND xstrlen( cv_pdf ) TO ct_offsets.

    DATA(lv_full) = |{ iv_obj_num } 0 obj\n{ iv_content }\nendobj\n|.
    DATA(lv_x) = cl_bcs_convert=>string_to_xstring(
      iv_string   = lv_full
      iv_codepage = '1100' ).

    CONCATENATE cv_pdf lv_x INTO cv_pdf IN BYTE MODE.
  ENDMETHOD.

  METHOD convert_images_to_pdf.
    CLEAR rv_pdf.

    IF it_attachments IS INITIAL.
      RETURN.
    ENDIF.

    " Convert all images to JPEG for PDF embedding (/DCTDecode)
    " JPEG passes through; PNG/BMP/TIFF are converted via IGS
    DATA lt_jpeg_images TYPE tt_image_attachments.
    LOOP AT it_attachments ASSIGNING FIELD-SYMBOL(<ls_check>).
      DATA(lv_check_ext) = to_upper( <ls_check>-file_ext ).
      IF lv_check_ext = 'JPG' OR lv_check_ext = 'JPEG'.
        APPEND <ls_check> TO lt_jpeg_images.
      ELSE.
        " Convert non-JPEG to JPEG via IGS
        DATA(lv_converted) = convert_to_jpeg( iv_content = <ls_check>-content
                                              iv_ext     = <ls_check>-file_ext ).
        IF lv_converted IS NOT INITIAL.
          DATA ls_converted TYPE ty_image_attachment.
          ls_converted = <ls_check>.
          ls_converted-content  = lv_converted.
          ls_converted-file_ext = 'JPG'.
          " Re-extract dimensions from the converted JPEG
          extract_image_dimensions(
            EXPORTING iv_content = ls_converted-content  iv_ext = 'JPG'
            IMPORTING ev_width = ls_converted-width  ev_height = ls_converted-height ).
          APPEND ls_converted TO lt_jpeg_images.
        ELSE.
          /ctdi/cl_print_driver_log=>log_warning(
              |Skipping attachment { <ls_check>-filename } - conversion from { <ls_check>-file_ext } to JPEG failed| ).
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF lt_jpeg_images IS INITIAL.
      RETURN.
    ENDIF.

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
             idx    TYPE i,       " index in lt_jpeg_images
             ren_w  TYPE f,       " rendered width (points)
             ren_h  TYPE f,       " rendered height (points)
             slot_h TYPE f,       " total slot: caption + image + gap
           END OF ty_img_layout.
    DATA lt_layout TYPE STANDARD TABLE OF ty_img_layout WITH EMPTY KEY.

    DATA(lv_total_imgs) = lines( lt_jpeg_images ).

    LOOP AT lt_jpeg_images ASSIGNING FIELD-SYMBOL(<ls_pre>) .
      DATA(lv_pre_idx) = sy-tabix.
      DATA(lv_raw_w) = COND f( WHEN <ls_pre>-width > 0 THEN <ls_pre>-width ELSE 800 ).
      DATA(lv_raw_h) = COND f( WHEN <ls_pre>-height > 0 THEN <ls_pre>-height ELSE 600 ).

      " Scale to fit printable page area (width and height minus caption/gap), never upscale
      DATA(lv_max_img_h) = lc_h_usable - lc_caption_h - lc_gap.
      DATA(lv_sc) = nmin( val1 = lc_w_usable / lv_raw_w
                          val2 = lv_max_img_h / lv_raw_h ).
      IF lv_sc > 1. lv_sc = 1. ENDIF.

      DATA(lv_ren_w) = lv_raw_w * lv_sc.
      DATA(lv_ren_h) = lv_raw_h * lv_sc.
      DATA(lv_slot_h) = lc_caption_h + lv_ren_h + lc_gap.

      APPEND VALUE ty_img_layout( idx = lv_pre_idx  ren_w = lv_ren_w
                                  ren_h = lv_ren_h  slot_h = lv_slot_h ) TO lt_layout.
    ENDLOOP.

    " Assign images to pages by flowing: fill top-to-bottom until page is full
    TYPES: BEGIN OF ty_page_plan,
             img_indices TYPE STANDARD TABLE OF i WITH EMPTY KEY,
           END OF ty_page_plan.
    DATA lt_pages TYPE STANDARD TABLE OF ty_page_plan WITH EMPTY KEY.

    DATA lv_remaining_h TYPE f.
    DATA ls_cur_page TYPE ty_page_plan.

    lv_remaining_h = lc_h_usable.
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
        lv_remaining_h = lc_h_usable - ls_lay-slot_h.
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
                       |   /Resources << /Font << /F1 { lv_font_obj_id } 0 R >> /XObject << { lv_xobj_dict }>> >>\n| &&
                       |   /Contents { lv_cs_obj_id } 0 R >>|
        CHANGING
          cv_pdf     = rv_pdf
          ct_offsets = lt_offsets ).

      " Generate Content Stream — flow images top to bottom
      DATA lv_page_cs TYPE string.
      CLEAR lv_page_cs.
      DATA(lv_cursor_y) = lc_h_page - lc_margin.  " Start at top of usable area

      LOOP AT <ls_page>-img_indices INTO lv_img_idx.
        ASSIGN lt_jpeg_images[ lv_img_idx ] TO FIELD-SYMBOL(<ls_img>).
        ASSIGN lt_layout[ lv_img_idx ] TO FIELD-SYMBOL(<ls_dim>).

        " Caption at current cursor
        DATA(lv_cap_y) = lv_cursor_y - 12.
        DATA(lv_cap_txt) = escape_pdf_text( |[{ <ls_img>-source }] { <ls_img>-filename }| ).
        lv_page_cs = lv_page_cs && |BT /F1 9 Tf 0.3 0.3 0.3 rg { lc_margin } { lv_cap_y } Td { lv_cap_txt } Tj ET\n|.

        " Image position: below caption
        DATA(lv_img_y) = lv_cursor_y - lc_caption_h - <ls_dim>-ren_h.
        DATA(lv_img_x) = lc_margin.

        " Image draw
        lv_page_cs = lv_page_cs &&
          |q { <ls_dim>-ren_w } 0 0 { <ls_dim>-ren_h } { lv_img_x } { lv_img_y } cm /Im{ lv_img_idx } Do Q\n|.

        " Thin gray border
        lv_page_cs = lv_page_cs &&
          |0.5 w 0.6 0.6 0.6 RG { lv_img_x } { lv_img_y } { <ls_dim>-ren_w } { <ls_dim>-ren_h } re S\n|.

        " Move cursor down
        lv_cursor_y = lv_img_y - lc_gap.
      ENDLOOP.

      APPEND lv_page_cs TO lt_cstreams.
    ENDDO.

    " Emit Content Stream Objects
    DO lv_num_pages TIMES.
      lv_p = sy-index.
      lv_cs_obj_id = 2 + lv_num_pages + lv_p.
      READ TABLE lt_cstreams INTO lv_page_cs INDEX lv_p.

      DATA(lv_cs_x) = cl_bcs_convert=>string_to_xstring(
        iv_string   = lv_page_cs
        iv_codepage = '1100' ).

      append_obj_bin( EXPORTING iv_obj_num = lv_cs_obj_id
                                iv_dict    = |/Length { xstrlen( lv_cs_x ) }|
                                iv_stream  = lv_cs_x
                      CHANGING  cv_pdf     = rv_pdf
                                ct_offsets = lt_offsets ).
    ENDDO.

    " Emit Image XObjects (Binary Embedding)
    " NOTE: Only JPEG can be directly embedded via /DCTDecode.
    " PNG/BMP/TIFF are skipped here — they are filtered out earlier in get_attachments.
    LOOP AT lt_jpeg_images ASSIGNING <ls_img>.
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

    " Font Object (Standard Helvetica)
    append_obj_str( EXPORTING iv_obj_num = lv_font_obj_id
                              iv_content = |<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>|
                    CHANGING  cv_pdf     = rv_pdf
                              ct_offsets = lt_offsets ).

    " Cross-Reference Table & Trailer
    DATA(lv_startxref) = xstrlen( rv_pdf ).
    DATA(lv_total_cnt) = lv_font_obj_id.
    DATA(lv_xref)      = |xref\n0 { lv_total_cnt + 1 }\n0000000000 65535 f \n|.

    LOOP AT lt_offsets INTO DATA(lv_off).
      lv_xref = |{ lv_xref }{ lv_off WIDTH = 10 ALIGN = RIGHT PAD = '0' } 00000 n \n|.
    ENDLOOP.

    lv_xref = lv_xref && |trailer\n<< /Size { lv_total_cnt + 1 } /Root 1 0 R >>\nstartxref\n{ lv_startxref }\n%%EOF\n|.

    DATA(lv_xref_x) = cl_bcs_convert=>string_to_xstring(
      iv_string   = lv_xref
      iv_codepage = '1100' ).

    CONCATENATE rv_pdf lv_xref_x INTO rv_pdf IN BYTE MODE.
  ENDMETHOD.

  METHOD convert_to_jpeg.
    CLEAR rv_jpeg.

    DATA(lv_ext_upper) = to_upper( condense( CONV string( iv_ext ) ) ).

    " Already JPEG — return as-is
    IF lv_ext_upper = 'JPG' OR lv_ext_upper = 'JPEG'.
      rv_jpeg = iv_content.
      RETURN.
    ENDIF.

    " Convert PNG/BMP/TIFF to JPEG via IGS (Internet Graphics Server)
    TRY.
        " Convert xstring to binary table for IGS via CL_BCS_CONVERT
        DATA(lt_input) = cl_bcs_convert=>xstring_to_solix( iv_content ).

        " Create IGS converter and set parameters
        DATA(lo_converter) = NEW cl_igs_image_converter( ).
        lo_converter->input  = lv_ext_upper.
        lo_converter->output = 'JPG'.

        " Set input image
        lo_converter->set_image( blob      = lt_input
                                 blob_size = xstrlen( iv_content ) ).

        " Execute conversion
        lo_converter->execute(
          EXCEPTIONS
            communication_error = 1
            internal_error      = 2
            external_error      = 3
            OTHERS              = 4 ).

        IF sy-subrc <> 0.
          /ctdi/cl_print_driver_log=>log_warning(
              |IGS image conversion failed for { lv_ext_upper }->JPG, rc={ sy-subrc }| ).
          RETURN.
        ENDIF.

        " Get converted output
        DATA lt_output TYPE solix_tab.
        DATA lv_output_size TYPE w3param-cont_len.
        DATA lv_output_type TYPE w3param-cont_type.

        lo_converter->get_image(
          EXPORTING index     = 1
          IMPORTING blob      = lt_output
                    blob_size = lv_output_size
                    blob_type = lv_output_type ).

        IF lt_output IS INITIAL OR lv_output_size = 0.
          RETURN.
        ENDIF.

        " Convert binary table back to xstring via CL_BCS_CONVERT
        rv_jpeg = cl_bcs_convert=>solix_to_xstring(
          it_solix = lt_output
          iv_size  = CONV i( lv_output_size ) ).

      CATCH cx_root INTO DATA(lx_err).
        /ctdi/cl_print_driver_log=>log_warning(
            |Image conversion error for { lv_ext_upper }: { lx_err->get_text( ) }| ).
        CLEAR rv_jpeg.
    ENDTRY.
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

  METHOD filter_image_attachments.
    CLEAR rt_filtered.
    LOOP AT it_raw ASSIGNING FIELD-SYMBOL(<ls_raw>).
      IF is_supported_image_ext( <ls_raw>-file_ext ) = abap_true.
        APPEND <ls_raw> TO rt_filtered.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_attachments.
    CLEAR rt_attachments.

    IF iv_repair_order IS INITIAL.
      RETURN.
    ENDIF.

    " 1. GOS images from Repair Order (BUS2007)
    DATA(lv_aufnr) = |{ iv_repair_order ALPHA = IN }|.
    DATA(lt_order_images) = get_gos_attachments( iv_objtype = gc_objtype_repair
                                                 iv_objkey  = CONV #( lv_aufnr )
                                                 iv_source  = 'Repair Order' ).
    APPEND LINES OF lt_order_images TO rt_attachments.

    " 2. Content Server images from CS-Order (BUS2088 / BUS2007 / ArchiveLink)
    DATA(lt_cs_images) = get_content_server_attachments(
                           iv_object_id = CONV #( lv_aufnr )
                           iv_objtype   = gc_objtype_cs_order
                           iv_source    = 'Repair Order' ).
    IF lt_cs_images IS INITIAL.
      lt_cs_images = get_content_server_attachments(
                       iv_object_id = CONV #( lv_aufnr )
                       iv_objtype   = gc_objtype_repair
                       iv_source    = 'Repair Order' ).
    ENDIF.
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
      DATA(lt_cs_notif) = get_content_server_attachments(
                            iv_object_id = CONV #( lv_qmnum_key )
                            iv_objtype   = gc_objtype_qmel
                            iv_source    = 'Notification' ).
      IF lt_cs_notif IS INITIAL.
        lt_cs_notif = get_content_server_attachments(
                        iv_object_id = CONV #( lv_qmnum_key )
                        iv_objtype   = gc_objtype_qmel_alt
                        iv_source    = 'Notification' ).
      ENDIF.
      APPEND LINES OF lt_cs_notif TO rt_attachments.
    ENDIF.

    " Deduplicate attachments (preserves order, eliminates cross-backend duplicates)
    rt_attachments = deduplicate_attachments( rt_attachments ).
  ENDMETHOD.


  METHOD deduplicate_attachments.
    CLEAR rt_unique.

    IF it_attachments IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_seen_hash,
             hash TYPE string,
           END OF ty_seen_hash.

    DATA lt_seen_hashes TYPE HASHED TABLE OF ty_seen_hash WITH UNIQUE KEY hash.
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
          cl_abap_message_digest=>calculate_hash_for_raw(
            EXPORTING
              if_algorithm  = 'SHA256'
              if_data       = <ls_att>-content
            IMPORTING
              ef_hashstring = lv_hash ).
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


  METHOD get_content_server_attachments.
    CLEAR rt_attachments.

    " Find ArchiveLink documents on Content Server (TOA01)
    " Supported: BUS2088 (CS-Order), BUS2007 (Repair Order), BUS2078/QMEL (Notification)
    DATA lt_connections TYPE STANDARD TABLE OF toav0.

    cl_alink_connection=>find(
      EXPORTING
        sap_object  = iv_objtype
        object_id   = iv_object_id
      IMPORTING
        connections = lt_connections
      EXCEPTIONS
        not_found        = 1
        error_authorithy = 2
        error_parameter  = 3
        OTHERS           = 4 ).

    IF sy-subrc <> 0 OR lt_connections IS INITIAL.
      RETURN.
    ENDIF.

    " Pre-read all TOAAT filenames for the found documents (avoid SELECT in loop)
    DATA lt_arc_doc_ids TYPE RANGE OF toaat-arc_doc_id.
    LOOP AT lt_connections INTO DATA(ls_conn_pre) WHERE ar_object = gc_archiv_ar_jpg.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_conn_pre-arc_doc_id ) TO lt_arc_doc_ids.
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
      DATA lt_bindata TYPE solix_tab.
      DATA lv_length  TYPE i.

      CLEAR: lt_bindata, lv_length.

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
        /ctdi/cl_print_driver_log=>log_warning(
          |Content Server read failed for doc { ls_conn-arc_doc_id }| ).
        CONTINUE.
      ENDIF.

      " ABAP 7.50 native conversion: Handles byte padding and lengths automatically
      DATA(lv_content) = cl_bcs_convert=>solix_to_xstring(
        it_solix = lt_bindata
        iv_size  = lv_length ).

      IF lv_content IS INITIAL.
        CONTINUE.
      ENDIF.

      " Determine file extension from filename
      DATA(lv_ext) = 'JPG'.
      DATA(lv_dot_pos) = find( val = CONV string( lv_filename ) sub = '.' occ = -1 ).
      IF lv_dot_pos >= 0.
        lv_ext = to_upper( substring( val = CONV string( lv_filename ) off = lv_dot_pos + 1 ) ).
      ENDIF.

      IF is_supported_image_ext( lv_ext ) = abap_false.
        CONTINUE.
      ENDIF.

      " Build result entry
      DATA ls_img TYPE ty_image_attachment.
      ls_img-atta_id  = CONV #( ls_conn-arc_doc_id ).
      ls_img-filename = CONV string( lv_filename ).
      ls_img-file_ext = lv_ext.
      ls_img-content  = lv_content.
      ls_img-source   = iv_source.
      ls_img-objkey   = iv_object_id.

      extract_image_dimensions(
        EXPORTING iv_content = ls_img-content  iv_ext = ls_img-file_ext
        IMPORTING ev_width = ls_img-width  ev_height = ls_img-height ).

      APPEND ls_img TO rt_attachments.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_gos_attachments.
    CLEAR rt_attachments.

    DATA(ls_object) = VALUE sibflporb(
      catid  = 'BO'
      typeid = iv_objtype
      instid = iv_objkey
    ).

    DATA lt_links TYPE obl_t_link.

    TRY.
        cl_binary_relation=>read_links_of_binrel(
          EXPORTING
            is_object   = ls_object
            ip_relation = 'ATTA'
          IMPORTING
            et_links    = lt_links ).
      CATCH cx_root INTO DATA(lx_rel).
        /ctdi/cl_print_driver_log=>log_warning(
          |GOS attachment link lookup failed for { iv_objtype } { iv_objkey }: { lx_rel->get_text( ) }| ).
        RETURN.
    ENDTRY.

    LOOP AT lt_links ASSIGNING FIELD-SYMBOL(<ls_link>).
      DATA(lv_doc_id) = CONV so_entryid( <ls_link>-instid_b ).

      DATA ls_doc_data TYPE sofolenti1.
      DATA lt_hex_content TYPE solix_tab.

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

      " ABAP 7.50 native conversion: Handles byte padding and lengths automatically
      DATA(lv_content) = cl_bcs_convert=>solix_to_xstring(
        it_solix = lt_hex_content
        iv_size  = CONV i( ls_doc_data-doc_size ) ).

      IF lv_content IS INITIAL.
        CONTINUE.
      ENDIF.

      " Resolve file extension: Check file_ext field -> obj_type -> filename parsing
      DATA(lv_fname) = CONV string( ls_doc_data-obj_descr ).
      DATA(lv_ext)   = to_upper( CONV string( ls_doc_data-file_ext ) ).

      IF lv_ext IS INITIAL OR lv_ext = 'EXT'.
        lv_ext = to_upper( CONV string( ls_doc_data-obj_type ) ).
      ENDIF.

      IF lv_ext IS INITIAL OR lv_ext = 'EXT' OR lv_ext = 'RAW'.
        DATA(lv_dot_pos) = find( val = lv_fname sub = '.' occ = -1 ).
        IF lv_dot_pos >= 0.
          lv_ext = to_upper( substring( val = lv_fname off = lv_dot_pos + 1 ) ).
        ENDIF.
      ENDIF.

      IF is_supported_image_ext( lv_ext ) = abap_true.
        DATA(ls_img) = VALUE ty_image_attachment(
          atta_id  = CONV #( lv_doc_id )
          filename = lv_fname
          file_ext = lv_ext
          content  = lv_content
          source   = iv_source
          objkey   = iv_objkey
        ).

        extract_image_dimensions(
          EXPORTING
            iv_content = ls_img-content
            iv_ext     = ls_img-file_ext
          IMPORTING
            ev_width   = ls_img-width
            ev_height  = ls_img-height ).

        APPEND ls_img TO rt_attachments.
      ENDIF.
    ENDLOOP.
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