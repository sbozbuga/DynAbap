CLASS /ctdi/cl_print_gos_images DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS gc_objtype_repair   TYPE swo_objtyp VALUE 'BUS2007' ##NO_TEXT.
    CONSTANTS gc_objtype_qmel     TYPE swo_objtyp VALUE 'BUS2078' ##NO_TEXT.
    CONSTANTS gc_objtype_qmel_alt TYPE swo_objtyp VALUE 'QMEL' ##NO_TEXT.

    CONSTANTS gc_page_width_pt    TYPE f          VALUE '595.28'.  " DIN A4 width in pt (210mm)
    CONSTANTS gc_page_height_pt   TYPE f          VALUE '841.89'.  " DIN A4 height in pt (297mm)
    CONSTANTS gc_margin_pt        TYPE f          VALUE '36.00'.   " 0.5 inch margins

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

  PRIVATE SECTION.
    TYPES tt_offsets TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    "! Formats an ASCII/ISO text string for literal PDF text output.
    "!
    "! @parameter iv_text |
    "! @parameter rv_hex |
    CLASS-METHODS escape_pdf_text
      IMPORTING iv_text       TYPE string
      RETURNING VALUE(rv_hex) TYPE string.

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
  ENDMETHOD.

  METHOD append_obj_bin.
    APPEND xstrlen( cv_pdf ) TO ct_offsets.

    DATA lv_head_x TYPE xstring.
    DATA lv_tail_x TYPE xstring.
    DATA(lv_head) = |{ iv_obj_num } 0 obj\n<< { iv_dict } >>\nstream\n|.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING  text   = lv_head
      IMPORTING  buffer = lv_head_x
      EXCEPTIONS OTHERS = 1.

    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING  text   = |\nendstream\nendobj\n|
      IMPORTING  buffer = lv_tail_x
      EXCEPTIONS OTHERS = 1.

    CONCATENATE cv_pdf lv_head_x iv_stream lv_tail_x INTO cv_pdf IN BYTE MODE.
  ENDMETHOD.

  METHOD append_obj_str.
    APPEND xstrlen( cv_pdf ) TO ct_offsets.

    DATA lv_x TYPE xstring.
    DATA(lv_full) = |{ iv_obj_num } 0 obj\n{ iv_content }\nendobj\n|.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING  text   = lv_full
      IMPORTING  buffer = lv_x
      EXCEPTIONS OTHERS = 1.

    CONCATENATE cv_pdf lv_x INTO cv_pdf IN BYTE MODE.
  ENDMETHOD.

  METHOD convert_images_to_pdf.
    CLEAR rv_pdf.

    IF it_attachments IS INITIAL.
      RETURN.
    ENDIF.

    " Layout: Standard DIN A4 Portrait (595.28 x 841.89 pt), Max 2 images stacked vertically
    CONSTANTS lc_w_page   TYPE f VALUE '595.28'.
    CONSTANTS lc_h_page   TYPE f VALUE '841.89'.
    CONSTANTS lc_margin   TYPE f VALUE '36.00'.
    CONSTANTS lc_w_usable TYPE f VALUE '523.28'. " 595.28 - 2*36
    CONSTANTS lc_slot_h   TYPE f VALUE '360.00'.

    DATA lt_offsets TYPE tt_offsets.
    DATA(lv_total_imgs) = lines( it_attachments ).
    DATA(lv_num_pages)  = CONV i( ceil( CONV f( lv_total_imgs ) / 2 ) ).

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

    " Build Page Objects, Content Streams, and Image XObjects
    DATA lt_cstreams TYPE TABLE OF string.

    DO lv_num_pages TIMES.
      DATA(lv_p)           = sy-index.
      DATA(lv_page_obj_id) = 2 + lv_p.
      DATA(lv_cs_obj_id)   = 2 + lv_num_pages + lv_p.
      DATA(lv_start_idx)   = ( lv_p - 1 ) * 2 + 1.
      DATA(lv_end_idx)     = nmin( val1 = lv_p * 2
                                   val2 = lv_total_imgs ).

      " Build XObject resource dictionary for this page
      DATA lv_xobj_dict TYPE string.
      DATA(lv_k) = lv_start_idx.
      WHILE lv_k <= lv_end_idx.
        DATA(lv_img_obj_id) = 2 + ( 2 * lv_num_pages ) + lv_k.
        lv_xobj_dict = |{ lv_xobj_dict }/Im{ lv_k } { lv_img_obj_id } 0 R |.
        lv_k = lv_k + 1.
      ENDWHILE.

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

      " Generate Content Stream operators for page slots
      DATA lv_page_cs TYPE string.
      DATA lv_slot    TYPE i VALUE 0.

      lv_k = lv_start_idx.
      WHILE lv_k <= lv_end_idx.
        lv_slot = lv_slot + 1.
        ASSIGN it_attachments[ lv_k ] TO FIELD-SYMBOL(<ls_img>).

        " Slot top coordinate (Slot 1 = Top, Slot 2 = Bottom)
        DATA(lv_slot_y) = COND f( WHEN lv_slot = 1
                                  THEN lc_h_page - lc_margin
                                  ELSE lc_h_page - lc_margin - lc_slot_h - 20 ).

        " Caption
        DATA(lv_cap_y) = lv_slot_y - 12.
        DATA(lv_cap_txt) = escape_pdf_text( |[{ <ls_img>-source }] { <ls_img>-filename }| ).
        lv_page_cs = lv_page_cs && |BT /F1 10 Tf 0 0 0 rg { lc_margin } { lv_cap_y } Td { lv_cap_txt } Tj ET\n|.

        " Aspect ratio scaling: scale to fit within slot
        DATA(lv_avail_w) = lc_w_usable.
        DATA(lv_avail_h) = lc_slot_h - 30.
        DATA(lv_raw_w)   = COND f( WHEN <ls_img>-width > 0 THEN <ls_img>-width ELSE 800 ).
        DATA(lv_raw_h)   = COND f( WHEN <ls_img>-height > 0 THEN <ls_img>-height ELSE 600 ).

        DATA(lv_scale) = nmin( val1 = lv_avail_w / lv_raw_w
                               val2 = lv_avail_h / lv_raw_h ).
        IF lv_scale > 1.
          lv_scale = 1.
        ENDIF.

        DATA(lv_w) = lv_raw_w * lv_scale.
        DATA(lv_h) = lv_raw_h * lv_scale.
        DATA(lv_x) = lc_margin + ( ( lv_avail_w - lv_w ) / 2 ).
        DATA(lv_y) = lv_cap_y - 20 - lv_h + 5.

        " Image draw operator
        lv_page_cs = lv_page_cs && |q { lv_w } 0 0 { lv_h } { lv_x } { lv_y } cm /Im{ lv_k } Do Q\n|.
        lv_k = lv_k + 1.
      ENDWHILE.

      APPEND lv_page_cs TO lt_cstreams.
    ENDDO.

    " Emit Content Stream Objects
    DO lv_num_pages TIMES.
      lv_p = sy-index.
      lv_cs_obj_id = 2 + lv_num_pages + lv_p.
      READ TABLE lt_cstreams INTO lv_page_cs INDEX lv_p.

      append_obj_str( EXPORTING iv_obj_num = lv_cs_obj_id
                                iv_content = |<< /Length { strlen( lv_page_cs ) } >>\nstream\n{ lv_page_cs }\nendstream|
                      CHANGING  cv_pdf     = rv_pdf
                                ct_offsets = lt_offsets ).
    ENDDO.

    " Emit Image XObjects (Binary Embedding)
    LOOP AT it_attachments ASSIGNING <ls_img>.
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

    DATA lv_xref_x TYPE xstring.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING  text   = lv_xref
      IMPORTING  buffer = lv_xref_x
      EXCEPTIONS OTHERS = 1.

    CONCATENATE rv_pdf lv_xref_x INTO rv_pdf IN BYTE MODE.
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

    " 2. GOS images from linked Service Notification (BUS2078/QMEL)
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
    ENDIF.
  ENDMETHOD.

  METHOD get_gos_attachments.
    CLEAR rt_attachments.

    DATA ls_object TYPE sibflporb.
    ls_object-catid  = 'BO'.
    ls_object-typeid = iv_objtype.
    ls_object-instid = iv_objkey.

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

    DATA ls_doc_data    TYPE sofolenti1.
    DATA lt_doc_content TYPE TABLE OF solisti1.
    DATA lt_hex_content TYPE TABLE OF solix.
    DATA lv_content     TYPE xstring.

    LOOP AT lt_links ASSIGNING FIELD-SYMBOL(<ls_link>).
      CLEAR: ls_doc_data,
             lt_doc_content,
             lt_hex_content,
             lv_content.

      DATA(lv_doc_id) = CONV sofolenti1-doc_id( <ls_link>-instid_b ).

      CALL FUNCTION 'SO_DOCUMENT_READ_API1'
        EXPORTING  document_id                = lv_doc_id
        IMPORTING  document_data              = ls_doc_data
        TABLES     object_content             = lt_doc_content
                   contents_hex               = lt_hex_content
        EXCEPTIONS document_id_not_exist      = 1
                   operation_no_authorization = 2
                   x_error                    = 3
                   OTHERS                     = 4.

      IF sy-subrc <> 0.
        /ctdi/cl_print_driver_log=>log_warning(
            |Failed to read SOFM document { lv_doc_id } for { iv_objtype } { iv_objkey }| ).
        CONTINUE.
      ENDIF.

      CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
        EXPORTING  input_length = CONV i( ls_doc_data-doc_size )
        IMPORTING  buffer       = lv_content
        TABLES     binary_tab   = lt_hex_content
        EXCEPTIONS OTHERS       = 1.

      IF lv_content IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_fname) = CONV string( ls_doc_data-obj_descr ).
      DATA(lv_ext)   = to_upper( CONV string( ls_doc_data-obj_type ) ).
      IF lv_ext IS INITIAL OR lv_ext = 'EXT'.
        DATA(lv_dot_pos) = find( val = lv_fname
                                 sub = '.'
                                 occ = -1 ).
        IF lv_dot_pos >= 0.
          lv_ext = to_upper( substring( val = lv_fname
                                        off = lv_dot_pos + 1 ) ).
        ENDIF.
      ENDIF.

      IF is_supported_image_ext( lv_ext ) = abap_true.
        DATA ls_img TYPE ty_image_attachment.
        ls_img-atta_id  = CONV #( lv_doc_id ).
        ls_img-filename = lv_fname.
        ls_img-file_ext = lv_ext.
        ls_img-content  = lv_content.
        ls_img-source   = iv_source.
        ls_img-objkey   = iv_objkey.

        extract_image_dimensions( EXPORTING iv_content = ls_img-content
                                            iv_ext     = ls_img-file_ext
                                  IMPORTING ev_width   = ls_img-width
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
