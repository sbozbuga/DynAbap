*&---------------------------------------------------------------------*
*& Include          /CTDI/PRINT_PROCESS_FLOW
*&---------------------------------------------------------------------*
* # Print Process Flow Documentation
* 
* This document describes the step-by-step execution flow of the unified `/CTDI/PRINT_DRIVER` engine and programs. The flow is documented below using visual architecture diagrams and structured ABAP-style comment blocks.
* 
* ---
* 
* ## 🗺️ Architectural Flow Overview
* 
* ```mermaid
* graph TD
*     A[Trigger: /CTDI/PRINT_DRIVER_PROGRAM or NACE] --> B[Call Engine: /CTDI/CL_PRINT_DRIVER_ENGINE=>EXECUTE]
*     B --> C[Contract Resolution: AUFK/AFIH -> VBAK]
*     C --> D[Access Sequence Search: /CTDI/REP_FORMS]
*     D --> E{Config Cached?}
*     E -- Yes --> F[Read Hashed Buffer]
*     E -- No --> G[Query DB + Cache Entry]
*     F & G --> H[Instantiate Class]
*     H --> I{Custom Class Configured?}
*     I -- Yes --> J[Dynamic Instantiation + Cast to /CTDI/IF_PRINT_DRIVER]
*     I -- No --> K[Fallback to /CTDI/CL_PRINT_DRIVER_BASE]
*     J & K --> L[Call IF_PRINT_DRIVER~EXECUTE]
*     L --> M[Base / Custom Provider: EXECUTE]
*     M --> N[read_data: Load DB fields, defects, comments]
*     N --> O[render_form: Detect Form Tech]
*     O --> P{Smart Form or Adobe Form?}
*     P -- Smart Form --> Q[execute_smartform: Call SSF FM + Intercept OTF]
*     P -- Adobe Form --> R[execute_adobeform: Call FP API + Intercept PDF]
*     Q & R --> S{iv_save_as_pdf = abap_true?}
*     S -- Yes --> T[download_pdf: Save locally via Presentation GUI]
*     S -- No --> U[Direct Printer Output / Spool Job]
* ```
* 
* ```text
* +--------------------------------------------------------------------+
* | 1. TRIGGER: /CTDI/PRINT_DRIVER_PROGRAM / /CTDI/PRINT_DRIVER_ALL    |
* +---------------------------------+----------------------------------+
*                                   |
*                                   v
* +--------------------------------------------------------------------+
* | 2. ENGINE ENTRY: /CTDI/CL_PRINT_DRIVER_ENGINE=>EXECUTE             |
* +---------------------------------+----------------------------------+
*                                   |
*                                   v
* +--------------------------------------------------------------------+
* | 3. CONTRACT RESOLUTION: AUFK / AFIH -> VBAK (Order Context)        |
* +---------------------------------+----------------------------------+
*                                   |
*                                   v
* +--------------------------------------------------------------------+
* | 4. HIERARCHICAL LOOKUP: /CTDI/REP_FORMS (7-Level Access Sequence)  |
* +---------------------------------+----------------------------------+
*                                   |
*                                   +--------------> [ CACHE HIT? ]
*                                   |                     |
*                                   | No                  | Yes
*                                   v                     v
*                          [ Query Database ]      [ Read Hashed Cache ]
*                                   |                     |
*                                   +----------+----------+
*                                              |
*                                              v
* +--------------------------------------------------------------------+
* | 5. INSTANTIATION & STRICT INTERFACE CAST TO /CTDI/IF_PRINT_DRIVER  |
* +---------------------------------+----------------------------------+
*                                   |
*          +------------------------+------------------------+
*          |                                                 |
*          | Custom Provider Configured                      | Standard Fallback
*          v                                                 v
*   [ Dynamic Object Instantiation ]               [ /CTDI/CL_PRINT_DRIVER_BASE ]
*          |                                                 |
*          +------------------------+------------------------+
*                                   |
*                                   v
* +--------------------------------------------------------------------+
* | 6. TARGET EXECUTION: provider->execute( ... )                      |
* +---------------------------------+----------------------------------+
*                                   |
*             +---------------------+---------------------+
*             | read_data( )                              | render_form( )
*             v                                           v
*      [ Fetch order, defects,                     [ Detect Form Tech:   ]
*        serial numbers & lines ]                  [ SmartForm/AdobeForm ]
*             |                                           |
*             |                                           v
*             |                                    [ Execute Form Tech ]
*             |                                    [ (intercept PDF if   ]
*             |                                    [ requested)          ]
*             |                                           |
*             +---------------------+---------------------+
*                                   |
*                                   v
* +--------------------------------------------------------------------+
* | 7. PDF DOWNLOAD (Optional): download_pdf( ) via Presentation Layer |
* +--------------------------------------------------------------------+
* ```
* 
* ---
* 
* ## 📝 Print Process Flow (ABAP-Style Comment Block)
* 
* ```abap
* ======================================================================*
*       _/_/_/    _/      _/  _/_/_/_/_/  _/_/_/      _/_/_/           *
*      _/    _/    _/  _/        _/      _/    _/  _/                  *
*     _/_/_/        _/          _/      _/    _/  _/                   *
*    _/            _/          _/      _/    _/  _/                    *
*   _/            _/      _/_/_/_/_/  _/_/_/      _/_/_/               *
*                                                                      *
*----------------------------------------------------------------------*
* UNIFIED PRINT PROCESS FLOW SPECIFICATION                              *
*----------------------------------------------------------------------*
*                                                                      *
* 1. TRIGGER LAYER                                                     *
*    - Executed via Print Driver Program /CTDI/PRINT_DRIVER_PROGRAM    *
*      or standard NACE output trigger context.                        *
*    - Supplies inputs: iv_repair_id, iv_form_name, iv_save_as_pdf,    *
*      and optional iv_class_name (for explicit driver overrides).     *
*                                                                      *
* 2. INITIALIZATION & CONTRACT RESOLUTION (ENGINE LAYER)                *
*    - Engine '/CTDI/CL_PRINT_DRIVER_ENGINE' takes control.            *
*    - Checks table AUFK & AFIH to see if 'iv_repair_id' is a Service   *
*      Order. If so, resolves the corresponding customer and sales      *
*      order header data from table VBAK.                              *
*    - If not a Service Order, resolves sales order parameters         *
*      directly from VBAK.                                             *
*                                                                      *
* 3. ACCESS SEQUENCE CUSTOMIZING RESOLUTION                             *
*    - The Engine checks for matching configurations in customizing    *
*      table '/CTDI/REP_FORMS' using a strict 7-level fallback hierarchy: *
*      - Level 1: Specific Customer + Service Order Type + Sales Order *
*      - Level 2: Specific Customer + Service Order Type + Any Sales    *
*      - Level 3: Specific Customer + Any Service Order + Sales Order   *
*      - Level 4: Specific Customer + Any Service Order + Any Sales     *
*      - Level 5: Any Customer + Service Order Type + Sales Order Type *
*      - Level 6: Any Customer + Service Order Type + Any Sales Order   *
*      - Level 7: Fallback Default (No Customer, Service, or Sales Key) *
*                                                                      *
* 4. HASHED BUFFER CACHING                                             *
*    - Results of the Access Sequence lookup are saved in an internal  *
*      hashed cache (mt_config_cache) within the Engine instance.       *
*    - Subsequent print executions for identical parameters are        *
*      served instantly from memory, avoiding redundant DB queries.    *
*                                                                      *
* 5. PROVIDER INSTANTIATION & CASTING                                  *
*    - The Engine dynamically instantiates the custom ClassName        *
*      configured in /CTDI/REP_FORMS (e.g. ZCL_PRINT_MYPROVIDER).      *
*    - Performs automatic namespace normalization (e.g., matching 'Z'   *
*      classes into '/CTDI/' custom packages if appropriate).          *
*    - Verifies class compatibility and strictly casts the instance to *
*      the unified single interface: '/CTDI/IF_PRINT_DRIVER'.          *
*    - Fallback: If no provider is configured, the Engine            *
*      instantiates the default base class '/CTDI/CL_PRINT_DRIVER_BASE'.*
*                                                                      *
* 6. EXECUTION LAYER (BASE / CUSTOM PROVIDER CLASS)                    *
*    - Engine invokes: o_provider->execute( ... )                      *
*    - Step A (read_data): Fetches the business data, serial numbers,  *
*      defects (from /CTDI/REPAIR_ERROR) & tdline comment tables.      *
*    - Step B (render_form): Identifies Form Technology (Smart Form vs.*
*      Adobe Form) by checking table STXFADM:                          *
*      - [Smart Form Flow]:                                            *
*        - Resolves generated Function Module name dynamically.        *
*        - Applies user printer defaults (printer, immed, delete spool).*
*        - Triggers Form. If PDF is requested, intercepts OTF stream.   *
*      - [Adobe Form Flow]:                                            *
*        - Prepares FP document parameter options (/1BCDWB/DOCPARAMS). *
*        - Executes Form and retrieves PDF output stream if requested. *
*    - Step C (download_pdf): If 'iv_save_as_pdf' is active, downloads *
*      the PDF stream directly to the local presentation layer.        *
*                                                                      *
*======================================================================*
* ```
* 
* ---
* 
* ## 🛠️ Unified Class Interface Reference
* 
* ### `Interface: /CTDI/IF_PRINT_DRIVER`
* The sole unified printing interface. All custom print providers must implement this interface:
* ```abap
* interface /CTDI/IF_PRINT_DRIVER public.
*   methods EXECUTE
*     importing
*       !IV_REPAIR_ID type AUFNR
*       !IV_FORM_NAME type FPNAME
*       !IV_SAVE_AS_PDF type ABAP_BOOL default ABAP_FALSE
*     changing
*       !CS_REPAIR type /CTDI/REPAIR
*       !CT_ERRORS type /CTDI/REPAIR_ERROR_T
*       !CT_COMMENTS type TLINE_T
*     raising
*       /CTDI/CX_PRINT_DRIVER_ERROR.
* endinterface.
* ```
* 
* ### `Base Class: /CTDI/CL_PRINT_DRIVER_BASE`
* Provides standard out-of-the-box form processing. Custom classes should inherit from `/CTDI/CL_PRINT_DRIVER_BASE` and selectively redefine methods (like `read_data`) to supply specialized business logic.
