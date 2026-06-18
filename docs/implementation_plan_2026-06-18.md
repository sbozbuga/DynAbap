# #5 — Extract Duplicated Driver `read_data` (Action Hooks Pattern)

## Architecture Decision

We need to eliminate the duplicated boilerplate (io_data checking, error handling, logging) from the `read_data` methods in `cl_print_driver_ctdi` and `cl_print_driver_legacy`. 

Instead of forcing the base class to know about specific data provider types (which creates tight coupling), we will implement a **Decoupled Action Hooks** pattern. The base class dictates the *workflow*, but the subclass manages its own *state*.

## Proposed Changes

### 1. Base Class: `/CTDI/CL_PRINT_DRIVER_BASE`
[MODIFY] [cl_print_driver_base.clas.abap](file:///d:/_Repos/DynAbap/src/%23ctdi%23cl_print_driver_base.clas.abap)

Introduce three protected, parameter-less (mostly) hook methods:

```abap
"! Hook: Unpacks a pre-loaded data object (io_data).
"! Subclasses should CAST io_data to their specific provider type.
METHODS unpack_io_data
  IMPORTING !io_data TYPE REF TO object
  RAISING   cx_sy_move_cast_error
            /ctdi/cx_print_driver_error.

"! Hook: Fetches business data directly from the DB.
"! Subclasses instantiate their provider and call read_data, or perform direct SELECTs.
METHODS fetch_data_from_db
  RAISING cx_static_check
          cx_dynamic_check.

"! Hook: Maps loaded data to base attributes and registers form parameters.
METHODS map_and_register_data
  RAISING /ctdi/cx_print_driver_error.
```

Implement the central Template Method in `read_data`:

```abap
METHOD read_data.
  " 1. Initialize data state
  IF io_data IS BOUND.
    TRY.
        unpack_io_data( io_data ).
        /ctdi/cl_print_driver_log=>log_info( |Unpacked io_data for Repair { mv_repair_order }| ).
      CATCH cx_sy_move_cast_error INTO DATA(lx_cast).
        DATA(lv_cast_err) = |Invalid data object passed to Print Driver for { mv_repair_order }|.
        /ctdi/cl_print_driver_log=>log_error( lv_cast_err ).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING message = lv_cast_err previous = lx_cast.
    ENDTRY.
  ELSE.
    TRY.
        fetch_data_from_db( ).
        /ctdi/cl_print_driver_log=>log_info( |Read data from DB for Repair { mv_repair_order }| ).
      CATCH cx_root INTO DATA(lx_root).
        /ctdi/cl_print_driver_log=>log_exception( lx_root ).
        DATA(lv_err) = |Error reading data from DB for { mv_repair_order }|.
        /ctdi/cl_print_driver_log=>log_error( lv_err ).
        RAISE EXCEPTION TYPE /ctdi/cx_print_driver_error
          EXPORTING message = lv_err previous = lx_root.
    ENDTRY.
  ENDIF.

  " 2. Map structures and register
  map_and_register_data( ).
ENDMETHOD.
```

---

### 2. CTDI Driver: `/CTDI/CL_PRINT_DRIVER_CTDI`
[MODIFY] [cl_print_driver_ctdi.clas.abap](file:///d:/_Repos/DynAbap/src/%23ctdi%23cl_print_driver_ctdi.clas.abap)

Replace `read_data` redefinition with private state management and the 3 hooks:

```abap
CLASS /ctdi/cl_print_driver_ctdi DEFINITION ...
  PROTECTED SECTION.
    METHODS unpack_io_data        REDEFINITION.
    METHODS fetch_data_from_db    REDEFINITION.
    METHODS map_and_register_data REDEFINITION.
  PRIVATE SECTION.
    DATA mr_provider TYPE REF TO /ctdi/cl_print_data_ctdi.
ENDCLASS.

CLASS /ctdi/cl_print_driver_ctdi IMPLEMENTATION.
  METHOD unpack_io_data.
    mr_provider = CAST #( io_data ).
  ENDMETHOD.

  METHOD fetch_data_from_db.
    mr_provider = NEW #( ).
    mr_provider->read_data( iv_aufnr = mv_repair_order iv_sernr = mv_sernr ).
  ENDMETHOD.

  METHOD map_and_register_data.
    IF mr_provider IS BOUND.
      ms_repair   = mr_provider->ms_repair.
      mt_errors   = mr_provider->mt_repair_error.
      mt_comments = mr_provider->mt_comments.
    ENDIF.

    register_custom_parameter( iv_name = 'REPAIR'        iv_kind = abap_func_exporting ir_data = REF #( ms_repair ) ).
    register_custom_parameter( iv_name = 'PROJECT'       iv_kind = abap_func_exporting ir_data = REF #( ms_project ) ).
    register_custom_parameter( iv_name = 'REPAIR_ERRORS' iv_kind = abap_func_tables    ir_data = REF #( mt_errors ) ).
    register_custom_parameter( iv_name = 'COMMENT_LINES' iv_kind = abap_func_tables    ir_data = REF #( mt_comments ) ).
  ENDMETHOD.
ENDCLASS.
```

---

### 3. Legacy Driver: `/CTDI/CL_PRINT_DRIVER_LEGACY`
[MODIFY] [cl_print_driver_legacy.clas.abap](file:///d:/_Repos/DynAbap/src/%23ctdi%23cl_print_driver_legacy.clas.abap)

Follow the exact same pattern, but privately store `DATA mr_provider TYPE REF TO /ctdi/cl_print_data_legacy`.

---

### 4. Template Scaffold: `/CTDI/CL_PRINT_DRIVER_TEMPLATE`
[MODIFY] [cl_print_driver_template.clas.abap](file:///d:/_Repos/DynAbap/src/%23ctdi%23cl_print_driver_template.clas.abap)

Update the class definitions to redefine the new hooks instead of `read_data`. The scaffold will demonstrate how a driver can ignore `io_data` completely, execute direct `SELECT` queries in `fetch_data_from_db` without using a provider class, and map results in `map_and_register_data`.

## Verification Plan

### Automated Tests
Run standard linting to verify syntax and structure:
```bash
npx @abaplint/cli
```

### Manual Verification
- Test CTDI Print via `print_repair` — verify success output in log.
- Trigger `cx_sy_move_cast_error` internally and verify it bubbles up to the base class logger correctly.
