# DynAbap — Dynamic ABAP Tools & Utilities

A highly flexible, modern ABAP framework designed to dynamically map, route, and execute standard **Smart Forms** and **Adobe Forms** for Repair Projects and Sales Contracts in SAP under the `/CTDI/` namespace.

By decoupling form execution logic from hardcoded standard print programs, this repository enables SAP developers and consultants to configure customized printing routines and local PDF output control entirely via customizing tables keyed by specific **Contract / Repair Numbers (VBELN)**, **SKZ**, and **AKZ** selectors.

---

## Key Features

* **Dynamic Execution Engine**: Decoupled, highly testable runtime printer orchestrator that dynamically resolves and executes custom print classes inheriting from the base print driver.
* **Separated Customizing Engine**: Extraction of SM30 table maintenance validations, system modifiability checks, and dynamic class skeletons generator into a dedicated static helper class (`/CTDI/CL_PRINT_CUST_ENGINE`) maintaining single-responsibility principle.
* **Standard SLG1 Message Logging**: Integrated application logging class (`/CTDI/CL_PRINT_DRIVER_LOG`) wrapping standard `/HPC/CL_UAPPL_LOG` APIs with object-oriented exception logging under the hood for comprehensive execution visibility.
* **Full Translation Friendliness (L10N)**: Repository-wide L10N audit to ensure all user-facing literal strings, status messages, exception texts, and popup dialogs are fully decoupled from code and represented as standard ABAP text symbols `'text'(id)` for seamless localization.
* **abapGit Standard Compliance**: Cleaned `.clas.xml` definitions (removing invalid `<TPOOL>` / `<I18N_TPOOLS>` tags that cause deserialization failures) and added non-ABAP files (`.gitignore`, `README.md`, `.abaplint.json`, `.abaplintignore`, and `.github/*`) to the `.abapgit.xml` ignore list to guarantee perfect, warning-free package installation.
* **Service Order ID Integration (aufnr)**: Complete migration of print program signatures, print driver inheritance, engine execution, and custom exception classes (`/ctdi/cx_print_error`, `/ctdi/cx_print_driver_error`, `/ctdi/cx_no_config_found`) to use the standard **`aufnr`** type (CHAR12) rather than `vbeln_va` (CHAR10) to fully support PM/CS Service Orders without truncation.
* **Production-Safe Checks**: Auto-generation of SE24 class skeletons is gated by `S_DEVELOP` and client modifiability check (`TR_SYS_PARAMS`), ensuring it bypasses repository generation seamlessly in locked Quality Assurance (QA) and Production (PRD) environments, saving customizing records cleanly.
* **Automated Form Type Detection**: Dynamically detects the form technology (**Smart Forms** vs. **Adobe PDF-based Forms**) at runtime by checking standard SAP metadata (`STXFADM`), eliminating manually-configured technology flags.
* **Dynamic Repair Result Access Sequence**: Implements a highly configurable 11-step fallback access sequence reading from `/CTDI/REP_RESULT` using combinations of Contract, SKZ, AKZ, and Swap Flags to determine exact repair result descriptions dynamically.
* **Robust ABAP Unit Tests**: Covered test classes utilizing SQL double isolation and dynamic mock providers to reach comprehensive statement and branch coverage.

---

## File Structure

All ABAP objects are structured in an **abapGit** compatible format under the `src/` directory:

* **Customizing Table**: [src/#ctdi#rep_forms.tabl.xml](src/%23ctdi%23rep_forms.tabl.xml)
* **Sub-Project Table**: [src/#ctdi#rep_projec.tabl.xml](src/%23ctdi%23rep_projec.tabl.xml)
* **Repair Result Table**: [src/#ctdi#rep_result.tabl.xml](src/%23ctdi%23rep_result.tabl.xml)
* **Base Print Driver Class**: [src/#ctdi#cl_print_driver_base.clas.abap](src/%23ctdi%23cl_print_driver_base.clas.abap)
* **CTDI Print Driver Class**: [src/#ctdi#cl_print_driver_ctdi.clas.abap](src/%23ctdi%23cl_print_driver_ctdi.clas.abap)
* **Legacy Print Driver Class**: [src/#ctdi#cl_print_driver_legacy.clas.abap](src/%23ctdi%23cl_print_driver_legacy.clas.abap)
* **Template/Demo Driver Class**: [src/#ctdi#cl_print_driver_template.clas.abap](src/%23ctdi%23cl_print_driver_template.clas.abap)
* **Customizing Engine Class**: [src/#ctdi#cl_print_cust_engine.clas.abap](src/%23ctdi%23cl_print_cust_engine.clas.abap)
* **Unified Logger Class**: [src/#ctdi#cl_print_driver_log.clas.abap](src/%23ctdi%23cl_print_driver_log.clas.abap)
* **CTDI Print Data Provider Class**: [src/#ctdi#cl_print_data_ctdi.clas.abap](src/%23ctdi%23cl_print_data_ctdi.clas.abap)
* **Legacy Print Data Provider Class**: [src/#ctdi#cl_print_data_legacy.clas.abap](src/%23ctdi%23cl_print_data_legacy.clas.abap)
* **Output Determination Program**: [src/#ctdi#print_repair.prog.abap](src/%23ctdi%23print_repair.prog.abap)
* **Exception Classes**: 
  - `/CTDI/CX_PRINT_ERROR`
  - `/CTDI/CX_PRINT_DRIVER_ERROR`
  - `/CTDI/CX_NO_CONFIG_FOUND`
* **SM30 Event Template**: [src/templates/sm30_event_class_generator.abap](src/templates/sm30_event_class_generator.abap)

---

## Operational Workflow: Adding a New Project & Form

When a new business project category is introduced requiring a new Adobe Form or Smart Form layout, follow these 4 operational steps to integrate it:

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
3. Configure your contract mapping via Transaction `SM30` for table `/CTDI/REP_FORMS`.
4. Attach the event template [sm30_event_class_generator.abap](src/templates/sm30_event_class_generator.abap) to table events:
   - **Event 05 (Creating a new entry):** Attach `on_new_entry`.
   - **Event 01 (Before saving):** Attach `on_before_save`.
5. Wire the program [/CTDI/PRINT_REPAIR](src/%23ctdi%23print_repair.prog.abap) into Transaction `NACE` under your specific Contract/Order Output Type.
