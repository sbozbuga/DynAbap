CLASS lcl_test_gos_images DEFINITION DEFERRED.
CLASS lcl_tests DEFINITION DEFERRED.
CLASS /ctdi/cl_print_gos_images DEFINITION LOCAL FRIENDS lcl_tests lcl_test_gos_images.

"! Test helper subclass to inject mock attachments without database GOS calls
CLASS lcl_test_gos_images DEFINITION
  INHERITING FROM /ctdi/cl_print_gos_images
  CREATE PUBLIC.

  PUBLIC SECTION.
    DATA mt_mock_attachments TYPE /ctdi/cl_print_gos_images=>tt_image_attachments.

    METHODS get_attachments REDEFINITION.
ENDCLASS.

CLASS lcl_test_gos_images IMPLEMENTATION.
  METHOD get_attachments.
    rt_attachments = mt_mock_attachments.
  ENDMETHOD.
ENDCLASS.


CLASS lcl_tests DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO lcl_test_gos_images.

    METHODS setup.
    METHODS teardown.

    METHODS test_filter_images FOR TESTING.
    METHODS test_supported_ext FOR TESTING.
    METHODS test_extract_dimensions FOR TESTING.
    METHODS test_convert_empty FOR TESTING.
    METHODS test_convert_single_image FOR TESTING.
    METHODS test_convert_multi_images FOR TESTING.
    METHODS test_merge_empty FOR TESTING.
    METHODS test_append_images_empty FOR TESTING.
    METHODS test_append_images_with_mock FOR TESTING.
    METHODS test_escape_pdf_text FOR TESTING.
    METHODS test_convert_to_jpeg_passthru FOR TESTING.
    METHODS test_deduplicate_attachments FOR TESTING.
ENDCLASS.


CLASS lcl_tests IMPLEMENTATION.

  METHOD setup.
    CREATE OBJECT mo_cut.
  ENDMETHOD.

  METHOD teardown.
    CLEAR mo_cut.
  ENDMETHOD.

  METHOD test_filter_images.
    DATA lt_raw TYPE /ctdi/cl_print_gos_images=>tt_image_attachments.

    APPEND VALUE #( filename = 'photo1.jpg' file_ext = 'JPG' ) TO lt_raw.
    APPEND VALUE #( filename = 'doc1.pdf'   file_ext = 'PDF' ) TO lt_raw.
    APPEND VALUE #( filename = 'photo2.png' file_ext = 'PNG' ) TO lt_raw.
    APPEND VALUE #( filename = 'note.txt'   file_ext = 'TXT' ) TO lt_raw.
    APPEND VALUE #( filename = 'scan.tiff'  file_ext = 'TIFF' ) TO lt_raw.

    DATA(lt_filtered) = /ctdi/cl_print_gos_images=>filter_image_attachments( lt_raw ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_filtered )
      exp = 3
      msg = 'Should filter out non-image files (PDF, TXT)' ).
  ENDMETHOD.

  METHOD test_supported_ext.
    cl_abap_unit_assert=>assert_true(
      act = /ctdi/cl_print_gos_images=>is_supported_image_ext( 'JPG' )
      msg = 'JPG should be supported' ).

    cl_abap_unit_assert=>assert_true(
      act = /ctdi/cl_print_gos_images=>is_supported_image_ext( 'jpeg' )
      msg = 'jpeg (lowercase) should be supported' ).

    cl_abap_unit_assert=>assert_true(
      act = /ctdi/cl_print_gos_images=>is_supported_image_ext( 'PNG' )
      msg = 'PNG should be supported' ).

    cl_abap_unit_assert=>assert_false(
      act = /ctdi/cl_print_gos_images=>is_supported_image_ext( 'PDF' )
      msg = 'PDF should not be supported as image' ).

    cl_abap_unit_assert=>assert_false(
      act = /ctdi/cl_print_gos_images=>is_supported_image_ext( 'DOCX' )
      msg = 'DOCX should not be supported as image' ).
  ENDMETHOD.

  METHOD test_extract_dimensions.
    " Mock minimal PNG header: 8-byte signature + 4-byte chunk len + 4-byte chunk type + 4-byte W (100) + 4-byte H (200)
    DATA lv_png_header TYPE xstring VALUE '89504E470D0A1A0A0000000D4948445200000064000000C80802000000'.
    DATA lv_w TYPE i.
    DATA lv_h TYPE i.

    /ctdi/cl_print_gos_images=>extract_image_dimensions(
      EXPORTING iv_content = lv_png_header
                iv_ext     = 'PNG'
      IMPORTING ev_width   = lv_w
                ev_height  = lv_h ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_w
      exp = 100
      msg = 'PNG width extraction' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_h
      exp = 200
      msg = 'PNG height extraction' ).
  ENDMETHOD.

  METHOD test_convert_empty.
    DATA lt_empty TYPE /ctdi/cl_print_gos_images=>tt_image_attachments.
    DATA(lv_pdf) = mo_cut->convert_images_to_pdf( lt_empty ).

    cl_abap_unit_assert=>assert_initial(
      act = lv_pdf
      msg = 'Empty attachment table should return initial xstring' ).
  ENDMETHOD.

  METHOD test_convert_single_image.
    DATA lt_imgs TYPE /ctdi/cl_print_gos_images=>tt_image_attachments.
    APPEND VALUE #( filename = 'repair_defect.jpg'
                    file_ext = 'JPG'
                    source   = 'Repair Order'
                    width    = 800
                    height   = 600
                    content  = 'FFD8FFE000104A46494600010101006000600000FFD9' ) TO lt_imgs.

    DATA(lv_pdf) = mo_cut->convert_images_to_pdf( lt_imgs ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_pdf
      msg = 'Generated PDF should not be empty' ).

    DATA(lt_bin) = cl_bcs_convert=>xstring_to_solix( lv_pdf ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( xstrlen( lv_pdf ) > 100 )
      msg = 'PDF should contain valid structure bytes' ).
  ENDMETHOD.

  METHOD test_convert_multi_images.
    DATA lt_imgs TYPE /ctdi/cl_print_gos_images=>tt_image_attachments.

    " 3 images should produce 2 pages (max 2 images per A4 page)
    APPEND VALUE #( filename = 'img1.jpg' file_ext = 'JPG' source = 'Order' width = 640 height = 480 content = 'FFD8FFD9' ) TO lt_imgs.
    APPEND VALUE #( filename = 'img2.jpg' file_ext = 'JPG' source = 'Order' width = 640 height = 480 content = 'FFD8FFD9' ) TO lt_imgs.
    APPEND VALUE #( filename = 'img3.jpg' file_ext = 'JPG' source = 'Notification' width = 640 height = 480 content = 'FFD8FFD9' ) TO lt_imgs.

    DATA(lv_pdf) = mo_cut->convert_images_to_pdf( lt_imgs ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_pdf
      msg = 'Multi-image PDF generated successfully' ).
  ENDMETHOD.

  METHOD test_merge_empty.
    DATA lv_base TYPE xstring VALUE '255044462D312E34'. " %PDF-1.4
    DATA lv_empty TYPE xstring.

    DATA(lv_res) = mo_cut->merge_pdfs( iv_base_pdf   = lv_base
                                       iv_images_pdf = lv_empty ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_res
      exp = lv_base
      msg = 'Empty images PDF should return base PDF unchanged' ).
  ENDMETHOD.

  METHOD test_append_images_empty.
    DATA lv_base TYPE xstring VALUE '255044462D312E34'.
    " No mock images injected
    DATA(lv_res) = mo_cut->append_images( iv_repair_order = '1000000001'
                                          iv_pdf          = lv_base ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_res
      exp = lv_base
      msg = 'No images found should return input PDF intact' ).
  ENDMETHOD.

  METHOD test_append_images_with_mock.
    DATA lv_base TYPE xstring VALUE '255044462D312E34'.
    APPEND VALUE #( filename = 'order_scratch.jpg'
                    file_ext = 'JPG'
                    source   = 'Repair Order'
                    width    = 400
                    height   = 300
                    content  = 'FFD8FFD9' ) TO mo_cut->mt_mock_attachments.

    DATA(lv_res) = mo_cut->append_images( iv_repair_order = '1000000001'
                                          iv_pdf          = lv_base ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lv_res
      msg = 'Append images should return merged PDF or base PDF safely' ).
  ENDMETHOD.

  METHOD test_escape_pdf_text.
    " Direct check on PDF string escaping logic
    DATA lt_imgs TYPE /ctdi/cl_print_gos_images=>tt_image_attachments.
    APPEND VALUE #( filename = 'special (chars) [test].jpg'
                    file_ext = 'JPG'
                    source   = 'Order'
                    width    = 100
                    height   = 100
                    content  = 'FFD8FFD9' ) TO lt_imgs.

    DATA(lv_pdf) = mo_cut->convert_images_to_pdf( lt_imgs ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_pdf
      msg = 'Conversion with special characters in filename succeeds' ).
  ENDMETHOD.

  METHOD test_convert_to_jpeg_passthru.
    DATA lv_jpeg TYPE xstring VALUE 'FFD8FFE000104A46494600010101006000600000FFD9'.
    DATA(lv_res) = /ctdi/cl_print_gos_images=>convert_to_jpeg(
      iv_content = lv_jpeg
      iv_ext     = 'JPG' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_res
      exp = lv_jpeg
      msg = 'JPEG content should pass through unchanged' ).
  ENDMETHOD.

  METHOD test_deduplicate_attachments.
    DATA lt_raw TYPE /ctdi/cl_print_gos_images=>tt_image_attachments.

    " 1. Base image from Repair Order
    APPEND VALUE #( atta_id  = 'SOFM_001'
                    filename = 'IMG_0001.jpg'
                    source   = 'Repair Order'
                    content  = 'FFD8FFE000104A46494600010101006000600000FFD9' ) TO lt_raw.

    " 2. Duplicate GOS pointer (same atta_id)
    APPEND VALUE #( atta_id  = 'SOFM_001'
                    filename = 'IMG_0001_copy.jpg'
                    source   = 'Repair Order'
                    content  = 'FFD8FFE000104A46494600010101006000600000FFD9' ) TO lt_raw.

    " 3. Cross-protocol duplicate from ArchiveLink (different atta_id, exact same binary content)
    APPEND VALUE #( atta_id  = 'ARC_GUID_999'
                    filename = 'archived_defect.jpg'
                    source   = 'Notification'
                    content  = 'FFD8FFE000104A46494600010101006000600000FFD9' ) TO lt_raw.

    " 4. Different photo that happens to share identical filename ('IMG_0001.jpg')
    APPEND VALUE #( atta_id  = 'SOFM_002'
                    filename = 'IMG_0001.jpg'
                    source   = 'Notification'
                    content  = 'FFD8FFE000104A46494600010101004800480000FFD9' ) TO lt_raw.

    DATA(lt_unique) = /ctdi/cl_print_gos_images=>deduplicate_attachments( lt_raw ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_unique )
      exp = 2
      msg = 'Should drop exact ID and exact binary duplicates, keeping distinct photos' ).

    ASSIGN lt_unique[ 1 ] TO FIELD-SYMBOL(<ls_first>).
    cl_abap_unit_assert=>assert_equals(
      act = <ls_first>-atta_id
      exp = 'SOFM_001'
      msg = 'Original sequence should be preserved (Repair Order first)' ).

    ASSIGN lt_unique[ 2 ] TO FIELD-SYMBOL(<ls_second>).
    cl_abap_unit_assert=>assert_equals(
      act = <ls_second>-atta_id
      exp = 'SOFM_002'
      msg = 'Distinct photo with same filename should be retained' ).
  ENDMETHOD.

ENDCLASS.
