# DynAbap — Dynamic ABAP Tools & Utilities

A highly flexible, modern ABAP framework designed to dynamically map, route, and execute standard **Smart Forms** and **Adobe Forms** for Repair Orders, Service Notifications, and Sales Contracts in SAP under the `/CTDI/` namespace.

By decoupling form execution logic from hardcoded standard print programs, this repository enables SAP developers and consultants to configure customized printing routines, spool bundling, and local PDF output control entirely via customizing tables keyed by specific **Contract / Repair Numbers (VBELN)**, **SKZ**, and **AKZ** selectors.

---

## Key Features

* **Dynamic Execution Engine**: Decoupled, highly testable runtime printer orchestrator that dynamically resolves and executes custom print classes inheriting from the base print driver via the Template Method pattern.
* **Separated Customizing Engine**: Extraction of SM30 table maintenance validations, in-memory RTTI inheritance verification, system modifiability checks, and dynamic class skeleton generation into a dedicated static helper class ([`/CTDI/CL_PRINT_CUST_ENGINE`](src/%23ctdi%23cl_print_cust_engine.clas.abap)).
* **Centralized Selection Screen Lifecycle**: Single-method toolbar setup (`init_toolbar( )`) and FCODE dispatching (`handle_selection_screen_fcode( )`) for quick SM30 Customizing navigation across all print programs.
* **GOS Image Attachment & PDF Merging**: Automated retrieval of image attachments (GOS `/ SOFFICE` and Content Server / ArchiveLink `ZRS_JPG`) from orders and linked notifications via [`/CTDI/CL_PRINT_GOS_IMAGES`](src/%23ctdi%23cl_print_gos_images.clas.abap), scaling images to A4 with aspect ratio preservation and merging directly into the PDF output stream.
* **Mass Printing & Spool Bundling**: High-performance ALV processing ([`/CTDI/PRINT_REPAIR_MASS`](src/%23ctdi%23print_repair_mass.prog.abap)) with flexible spool modes (individual spool per order, bundled multi-order spool job, or client-side merged PDF).
* **Parallel RFC Mass Execution**: High-throughput distributed printing ([`/CTDI/PRINT_REPAIR_MASS_PRLL`](src/%23ctdi%23print_repair_mass_prll.prog.abap)) running across multiple dialog work processes.
* **Standard SLG1 Message Logging**: Integrated application logging class ([`/CTDI/CL_PRINT_DRIVER_LOG`](src/%23ctdi%23cl_print_driver_log.clas.abap)) with object-oriented exception logging and runtime log level filtering (`I`, `W`, `E`).
* **Full Translation Friendliness (L10N)**: Multilingual support across English and German text pools, data elements, table definitions, and message classes.
* **abapGit Standard Compliance**: Cleaned XML serializers and standard 7-bit ASCII encoding, fully validated with `abaplint` (0 errors / 0 warnings).
* **Automated Form Type Detection**: Dynamically detects the form technology (**Smart Forms** vs. **Adobe PDF-based Forms**) at runtime by querying SAP metadata (`STXFADM`), eliminating manually-configured technology flags.
* **Dynamic Repair Result Access Sequence**: Implements a configurable 11-step fallback access sequence reading from `/CTDI/REP_RESULT` using combinations of Contract, SKZ, AKZ, and Swap Flags.

---

## File Structure

All ABAP objects are structured in an **abapGit** compatible format under the `src/` directory:

### Customizing & DDIC
* **Forms Customizing Table**: [src/#ctdi#rep_forms.tabl.xml](src/%23ctdi%23rep_forms.tabl.xml)
* **Project Customizing Table**: [src/#ctdi#rep_projec.tabl.xml](src/%23ctdi%23rep_projec.tabl.xml)
* **Repair Result Table**: [src/#ctdi#rep_result.tabl.xml](src/%23ctdi%23rep_result.tabl.xml)
* **Repair Structure**: [src/#ctdi#repair.tabl.xml](src/%23ctdi%23repair.tabl.xml)
* **Repair Error Table Type**: [src/#ctdi#repair_error_tt.ttyp.xml](src/%23ctdi%23repair_error_tt.ttyp.xml)

### Classes & Engines
* **Base Print Driver Class**: [src/#ctdi#cl_print_driver_base.clas.abap](src/%23ctdi%23cl_print_driver_base.clas.abap)
* **CTDI Print Driver Class**: [src/#ctdi#cl_print_driver_ctdi.clas.abap](src/%23ctdi%23cl_print_driver_ctdi.clas.abap)
* **Legacy Print Driver Class**: [src/#ctdi#cl_print_driver_legacy.clas.abap](src/%23ctdi%23cl_print_driver_legacy.clas.abap)
* **Template/Demo Driver Class**: [src/#ctdi#cl_print_driver_template.clas.abap](src/%23ctdi%23cl_print_driver_template.clas.abap)
* **Customizing Engine Class**: [src/#ctdi#cl_print_cust_engine.clas.abap](src/%23ctdi%23cl_print_cust_engine.clas.abap)
* **GOS Image Attachment & Merger**: [src/#ctdi#cl_print_gos_images.clas.abap](src/%23ctdi%23cl_print_gos_images.clas.abap)
* **Unified Logger Class**: [src/#ctdi#cl_print_driver_log.clas.abap](src/%23ctdi%23cl_print_driver_log.clas.abap)
* **CTDI Print Data Provider Class**: [src/#ctdi#cl_print_data_ctdi.clas.abap](src/%23ctdi%23cl_print_data_ctdi.clas.abap)
* **Legacy Print Data Provider Class**: [src/#ctdi#cl_print_data_legacy.clas.abap](src/%23ctdi%23cl_print_data_legacy.clas.abap)

### Reports & Output Programs
* **Single Interactive Print Program**: [src/#ctdi#print_repair.prog.abap](src/%23ctdi%23print_repair.prog.abap)
* **Mass ALV Processing Program**: [src/#ctdi#print_repair_mass.prog.abap](src/%23ctdi%23print_repair_mass.prog.abap)
* **Parallel RFC Mass Print Program**: [src/#ctdi#print_repair_mass_prll.prog.abap](src/%23ctdi%23print_repair_mass_prll.prog.abap)

### Exception & Messages
* **Customizing Validation Exception**: [src/#ctdi#cx_cust_error.clas.abap](src/%23ctdi%23cx_cust_error.clas.abap)
* **Driver Execution Exception**: [src/#ctdi#cx_print_driver_error.clas.abap](src/%23ctdi%23cx_print_driver_error.clas.abap)
* **Configuration Not Found Exception**: [src/#ctdi#cx_no_config_found.clas.abap](src/%23ctdi%23cx_no_config_found.clas.abap)
* **Message Class**: [src/#ctdi#print_repair.msag.xml](src/%23ctdi%23print_repair.msag.xml)

---

## Operational Workflow: Adding a New Project & Form

When a new business project category is introduced requiring a new Adobe Form or Smart Form layout, follow these 4 operational steps:

### 1. Define the Print Layout
Create the form layout in SAP:
* For **Adobe PDF-Based Forms**: Use Transaction **`SFP`** to design the Interface and Form.
* For **Smart Forms**: Use Transaction **`SMARTFORMS`** to build the layout.

### 2. Register the Customizing Entry in DEV
Link the specific Contract/Repair ID to your form and print class using Transaction **`SM30`** (table **`/CTDI/REP_FORMS`**):
* **Contract/Repair Number**: The contract `VBELN` associated with the repair project.
* **Form Name**: The name of the SFP Form or Smart Form created in Step 1.
* **Class Name**: Leave blank. The SM30 validation event will automatically offer to generate a new SE24 class inheriting from base class `/CTDI/CL_PRINT_DRIVER_BASE` (named `/CTDI/CL_PRINT_DRIVER_{vbeln}`).

### 3. Implement Custom Logic in the Generated Class
In transaction **`SE24`**, locate your newly generated class `/CTDI/CL_PRINT_DRIVER_{vbeln}`:
* Redefine the action hook methods:
  - `unpack_io_data`: Extract parameters.
  - `fetch_data_from_db`: Select data.
  - `map_and_register_data`: Map fields and register parameters via `register_custom_parameter`.

### 4. Transport and Wire Triggering (NACE)
Go to Transaction **`NACE`** and map the print output routine for your Output Type to the print program [/CTDI/PRINT_REPAIR](src/%23ctdi%23print_repair.prog.abap). Once tested, release and transport the configuration and generated classes to QA/PRD.

---

## Installation & Configuration

1. **Import the package** into your SAP system using [abapGit](https://abapgit.org/).
2. **Activate** all imported objects.
3. Configure your contract mapping via Transaction `SM30` for table `/CTDI/REP_FORMS` and project defaults in `/CTDI/REP_PROJEC`.
4. Attach the event template [sm30_event_class_generator.abap](src/templates/sm30_event_class_generator.abap) to table maintenance events:
   - **Event 05 (Creating a new entry):** Attach `on_new_entry`.
   - **Event 01 (Before saving):** Attach `validate_entry`.
5. Wire the program [/CTDI/PRINT_REPAIR](src/%23ctdi%23print_repair.prog.abap) into Transaction `NACE` under your specific Contract/Order Output Type.
