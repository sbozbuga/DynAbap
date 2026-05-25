# DynAbap — Dynamic ABAP Tools & Utilities

A highly flexible, modern ABAP framework designed to dynamically map, route, and execute standard **Smart Forms** and **Adobe Forms** for Repair Projects and Sales Contracts in SAP under the `/CTDI/` namespace.

By decoupling form execution logic from hardcoded standard print programs, this repository enables SAP developers and consultants to configure customized printing routines and local PDF output control entirely via customizing tables keyed by specific **Contract / Repair Numbers (VBELN)**, **SKZ**, and **AKZ** selectors.

---

## Key Features

* **Dynamic Execution Engine**: Decoupled, highly testable runtime printer orchestrator that dynamically casts and executes custom print classes implementing the provider interface.
* **Separated Customizing Engine**: Extraction of SM30 table maintenance validations, system modifiability checks, and dynamic class skeletons generator into a dedicated static helper class (`/CTDI/CL_REPAIR_CUST_ENGINE`) maintaining single-responsibility principle.
* **Standard SLG1 Message Logging**: Integrated dynamic application logging class (`/CTDI/CL_REPAIR_LOG`) utilizing SAP's standard Application Log APIs (`BAL_LOG_CREATE`, `BAL_LOG_MSG_ADD`, and `BAL_DB_SAVE`) with chunked text parsing supporting standard message `00 398` (`&1&2&3&4`) for comprehensive execution visibility.
* **Full Translation Friendliness (L10N)**: Repository-wide L10N audit to ensure all user-facing literal strings, status messages, exception texts, and popup dialogs are fully decoupled from code and represented as standard ABAP text symbols `'text'(id)` for seamless localization.
* **abapGit Standard Compliance**: Cleaned `.clas.xml` definitions (removing invalid `<TPOOL>` / `<I18N_TPOOLS>` tags that cause deserialization failures) and added non-ABAP files (`.gitignore`, `README.md`, `.abaplint.json`, `.abaplintignore`, and `.github/*`) to the `.abapgit.xml` ignore list to guarantee perfect, warning-free package installation.
* **Service Order ID Integration (aufnr)**: Complete migration of print program signatures, print provider interface, engine execution, and custom exception classes (`/ctdi/cx_print_error`, `/ctdi/cx_form_error`, `/ctdi/cx_repair_not_found`) to use the standard **`aufnr`** type (CHAR12) rather than `vbeln_va` (CHAR10) to fully support PM/CS Service Orders without truncation.
* **Production-Safe Checks**: Auto-generation of SE24 class skeletons is gated by `S_DEVELOP` and client modifiability check (`TR_SYS_PARAMS`), ensuring it bypasses repository generation seamlessly in locked Quality Assurance (QA) and Production (PRD) environments, saving customizing records cleanly.
* **Automated Form Type Detection**: Dynamically detects the form technology (**Smart Forms** vs. **Adobe PDF-based Forms**) at runtime by checking standard SAP metadata (`STXFADM`), eliminating manually-configured technology flags.
* **Robust ABAP Unit Tests**: Covered test classes utilizing SQL double isolation and dynamic mock providers to reach comprehensive statement and branch coverage.

---

## File Structure

All ABAP objects are structured in an **abapGit** compatible format under the `src/` directory:

* **Customizing Table**: [src/#ctdi#rep_forms.tabl.xml](src/%23ctdi%23rep_forms.tabl.xml)
* **Contract/Project Table**: [src/#ctdi#rep_project.tabl.xml](src/%23ctdi%23rep_project.tabl.xml)
* **Repair Result Table**: [src/#ctdi#rep_result.tabl.xml](src/%23ctdi%23rep_result.tabl.xml)
* **Print Provider Interface**: [src/#ctdi#if_repair_print_provider.intf.abap](src/%23ctdi%23if_repair_print_provider.intf.abap)
* **Dynamic Engine Class**: [src/#ctdi#cl_repair_print_engine.clas.abap](src/%23ctdi%23cl_repair_print_engine.clas.abap)
* **Customizing Engine Class**: [src/#ctdi#cl_repair_cust_engine.clas.abap](src/%23ctdi%23cl_repair_cust_engine.clas.abap)
* **Dynamic Logger Class**: [src/#ctdi#cl_repair_log.clas.abap](src/%23ctdi%23cl_repair_log.clas.abap)
* **Sample Print Class**: [src/#ctdi#cl_repair_print_sample.clas.abap](src/%23ctdi%23cl_repair_print_sample.clas.abap)
* **Output Determination Wrapper**: [src/#ctdi#sd_repair_print_program.prog.abap](src/%23ctdi%23sd_repair_print_program.prog.abap)
* **ABAP Unit Tests**: [src/#ctdi#cl_repair_print_engine.clas.testclasses.abap](src/%23ctdi%23cl_repair_print_engine.clas.testclasses.abap)
* **Exception Classes**: 
  - `/CTDI/CX_PRINT_ERROR`
  - `/CTDI/CX_REPAIR_NOT_FOUND`
  - `/CTDI/CX_FORM_ERROR`
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
* **Class Name**: Leave blank. The SM30 validation event will automatically offer to generate a new SE24 class implementing `/CTDI/IF_REPAIR_PRINT_PROVIDER` (named `/CTDI/CL_REPAIR_PRINT_{vbeln}`).
* **Method Name**: Defaults to `PRINT`.

### 3. Implement Custom Logic in the Generated Class
In transaction **`SE24`**, locate your newly generated class `/CTDI/CL_REPAIR_PRINT_{vbeln}`:
* Define your data collection logic inside the `read_data` stub.
* Implement parameter binding or custom formatting in the `print` stub.

### 4. Transport and Wire Triggering (NACE)
Go to Transaction **`NACE`** and map the print output routine for your Output Type to the wrapper program [sd_repair_print_program](src/%23ctdi%23sd_repair_print_program.prog.abap) with form routine **`ENTRY`**. Once tested, release and transport the configuration and generated classes to QA/PRD.

---

## Installation & Configuration

1. **Import the package** into your SAP system using [abapGit](https://abapgit.org/).
2. **Activate** all imported objects.
3. Configure your contract mapping via Transaction `SM30` for table `/CTDI/REP_FORMS`.
4. Attach the event template [sm30_event_class_generator.abap](src/templates/sm30_event_class_generator.abap) to table events:
   - **Event 05 (Creating a new entry):** Attach `on_new_entry`.
   - **Event 01 (Before saving):** Attach `on_before_save`.
5. Wire the wrapper [sd_repair_print_program](src/%23ctdi%23sd_repair_print_program.prog.abap) into Transaction `NACE` under your specific Contract/Order Output Type with form routine `ENTRY`.
