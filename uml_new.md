# Print Driver Architecture - NEW (Simplified)

## Class Diagram

> [!NOTE]
> **UML Visibility Notation Guide (ABAP Equivalents)**
> - `+` **Public** (`PUBLIC SECTION`): Accessible from anywhere.
> - `#` **Protected** (`PROTECTED SECTION`): Accessible within the class and its subclasses.
> - `-` **Private** (`PRIVATE SECTION`): Accessible only within the class itself.
> - `$` **Static** (`CLASS-METHODS` / `CLASS-DATA`): Indicated at the end of the method/attribute.

```mermaid
classDiagram
    class `/CTDI/CL_PRINT_DRIVER_BASE` {
        #mv_repair_order: AUFNR
        #mv_sernr: EQUI-SERNR
        #mv_form_name: FPNAME
        #ms_repair: /CTDI/REPAIR
        #ms_project: /CTDI/REP_PROJEC
        #mt_errors: /CTDI/REPAIR_ERROR_TT
        #mt_comments: STANDARD TABLE OF TLINE
        #mt_custom_form_params: ABAP_FUNC_PARMBIND_TAB
        +factory(iv_repair_id, iv_sernr)$ REF TO /CTDI/CL_PRINT_DRIVER_BASE
        +execute(iv_save_as_pdf, io_data)
        #read_data(io_data)
        #render_form(iv_save_as_pdf)
        #register_custom_parameter(iv_name, ir_data, iv_kind)
        -resolve_contract(iv_repair_id)$
        -get_config_from_db(iv_repair_id)$
        #detect_form_type()
        #execute_smartform(iv_save_as_pdf)
        #execute_adobeform(iv_save_as_pdf)
        #download_pdf(iv_pdf_data)
        #get_user_print_defaults()
    }

    class `/CTDI/CL_PRINT_CUST_ENGINE` {
        +gc_base_class: SEOCLSNAME$
        +on_new_entry(cs_entry)$
        +validate_entry(is_entry)$
        +check_generation_allowed()$
        #validate_form_interface(iv_form_name, iv_class_name, iv_vbeln)$
        -generate_provider_class(iv_class_name, iv_vbeln)$
    }

    class `/CTDI/CL_PRINT_DRIVER_LEGACY` {
        #read_data(io_data)
        #get_user_print_defaults()
    }

    class `/CTDI/CL_PRINT_DRIVER_CTDI` {
        #read_data(io_data)
    }

    class `/CTDI/CL_PRINT_DRIVER_TEMPLATE` {
        #read_data(io_data)
        #render_form(iv_save_as_pdf)
    }

    class `/CTDI/CL_PRINT_DRIVER_FUTURE` {
        #read_data(io_data)
        Note: "Example of a future driver"
    }

    class `/CTDI/CL_PRINT_DATA_LEGACY` {
        +ms_legacy: /CELLAG/ALCAREP
        +mt_legacy_error: STANDARD TABLE
        +mt_comment_lines: STANDARD TABLE
        +read_data(iv_aufnr, iv_sernr)
        #get_repair_result()
        -get_kddata()
        -get_part_data()
        -get_error_description()
        -get_comment()
        -check_sernr_swap()
        -get_astatus_data(iv_objnr)
        -get_rlf_wedate(iv_vbeln_vl)
        -get_retlief()
        -convert_to_timestamp(iv_date, iv_time)
    }

    class `/CTDI/CL_PRINT_DATA_CTDI` {
        +ms_repair: /CTDI/REPAIR
        +mt_repair_error: /CTDI/REPAIR_ERROR_TT
        +read_data(iv_aufnr, iv_sernr)
    }

    class `/CTDI/CL_PRINT_DATA_FUTURE` {
        +ms_custom_future_data: ZFUTURE_STRUCT
        +read_data(iv_aufnr, iv_sernr)
    }

    `/CTDI/CL_PRINT_DRIVER_BASE` <|-- `/CTDI/CL_PRINT_DRIVER_LEGACY` : Inherits
    `/CTDI/CL_PRINT_DRIVER_BASE` <|-- `/CTDI/CL_PRINT_DRIVER_CTDI` : Inherits
    `/CTDI/CL_PRINT_DRIVER_BASE` <|-- `/CTDI/CL_PRINT_DRIVER_TEMPLATE` : Inherits
    `/CTDI/CL_PRINT_DRIVER_BASE` <|-- `/CTDI/CL_PRINT_DRIVER_FUTURE` : Inherits
    
    `/CTDI/CL_PRINT_DATA_LEGACY` <|-- `/CTDI/CL_PRINT_DATA_CTDI` : Inherits
    `/CTDI/CL_PRINT_DATA_LEGACY` <|-- `/CTDI/CL_PRINT_DATA_FUTURE` : Inherits (Crucial for global memory fallback!)

    `/CTDI/CL_PRINT_DRIVER_LEGACY` ..> `/CTDI/CL_PRINT_DATA_LEGACY` : Uses Data Provider
    `/CTDI/CL_PRINT_DRIVER_CTDI` ..> `/CTDI/CL_PRINT_DATA_CTDI` : Uses Data Provider
    `/CTDI/CL_PRINT_DRIVER_FUTURE` ..> `/CTDI/CL_PRINT_DATA_FUTURE` : Uses Data Provider
```

## Sequence Diagram (Execution Flow)

```mermaid
sequenceDiagram
    autonumber
    actor Caller
    participant Base as /CTDI/CL_PRINT_DRIVER_BASE
    participant Subclass as Subclass (CTDI/Legacy)
    participant DataProv as /CTDI/CL_PRINT_DATA_*

    Caller->>Base: factory(iv_repair_id, iv_sernr)
    activate Base

    Base->>Base: get_config_from_db()
    activate Base
    Base->>Base: resolve_contract()
    Base-->>Base: ev_form_name, ev_class_name, es_project
    deactivate Base

    Base->>Subclass: CREATE OBJECT (from config)
    Base-->>Caller: Provider Instance (lo_driver)
    deactivate Base

    Caller->>Base: lo_driver->execute(iv_save_as_pdf)
    activate Base

    Base->>Subclass: read_data()
    activate Subclass
    Subclass->>DataProv: NEW() & read_data()
    activate DataProv
    Note right of DataProv: Populates attributes<br/>(ms_repair, mt_errors, ms_legacy)
    DataProv-->>Subclass: 
    deactivate DataProv
    
    Subclass->>Base: register_custom_parameter()
    Note right of Subclass: Dynamically binds structures<br/>to be injected into form
    
    Subclass-->>Base: return
    deactivate Subclass

    Base->>Subclass: render_form()
    activate Subclass
    Subclass->>Base: super->render_form()
    activate Base
    
    Base->>Base: detect_form_type()
    alt Type = 'S'
        Base->>Base: execute_smartform()
    else Type = 'A'
        Base->>Base: execute_adobeform()
    end
    Note right of Base: Automatically injects any parameters<br/>registered in the previous step

    Base-->>Subclass: return
    deactivate Base
    Subclass-->>Base: return
    deactivate Subclass

    Base-->>Caller: Process Completed
    deactivate Base
```
