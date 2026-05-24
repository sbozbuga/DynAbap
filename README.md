# DynAbap — Dynamic ABAP Tools & Utilities

A highly flexible, modern ABAP framework to dynamically map, route, and execute standard **Smart Forms** and **Adobe Forms** for Repair Projects and Sales Contracts in SAP under the `/CTDI/` namespace.

By decoupling form execution logic from hardcoded standard print programs, this repository enables SAP developers and consultants to configure customized printing routines and local PDF output control entirely via customizing tables keyed by specific **Contract / Repair Numbers (VBELN)**.

---

## Key Features

* **Dynamic Execution Engine**: Orchestrates execution dynamically at runtime. Decoupled into a clean, testable design using a 3-line orchestrator and focused private helper methods (`resolve_contract`, `get_config`, `execute_provider`).
* **Contract-Based Customizing**: Keyed by specific Sales Contract / Repair numbers (`VBELN`) rather than document types (`AUART`), allowing high granularity where each repair project can have its own form and execution logic.
* **Auto-Generating SM30 Developer Events**: Includes an SM30 table maintenance template that programmatically generates SE24 class skeletons implementing the provider interface upon saving new entries.
* **Production-Safe Checks**: The SM30 auto-generation is gated by:
  - `S_DEVELOP` authorization check.
  - Client modifiability check (`TR_SYS_PARAMS`), ensuring it bypasses repository generation seamlessly in locked Quality Assurance (QA) and Production (PRD) environments, saving entries as direct customizing records.
* **Automated Form Type Detection**: Dynamically detects the form type (**Smart Forms** vs. **Adobe PDF-based Forms**) at runtime by checking standard SAP metadata (`STXFADM`), eliminating the need for a manually-configured form type field.
* **Domain Exception Hierarchy**: Utilizes custom class-based exceptions (`/ctdi/cx_print_error`, `/ctdi/cx_repair_not_found`, `/ctdi/cx_form_error`) to capture specific error contexts and captured `SY-SUBRC` codes instead of raising generic system exceptions.
* **PM/CS Trigger Integration (IW42)**: Detects standard PM/CS Overall Completion Confirmations triggered from **IW42**, navigating through direct `AFIH` contract linkages or indirect `AUFK-KDAUF` pipelines to resolve correct configurations.
* **Robust ABAP Unit Tests**: Fully covered test classes reaching **100% statement and branch coverage** using dynamic mock providers, local legacy test classes, and SQL double isolation test environments.

---

## File Structure

All ABAP objects are structured in an **abapGit** compatible format under the `src/` directory:

* **Customizing Table**: [#ctdi#sd_repair_form.tabl.xml](file:///home/sb/GitRepos/DynAbap/src/#ctdi#sd_repair_form.tabl.xml)
* **Print Provider Interface**: [#ctdi#if_repair_print_provider.intf.abap](file:///home/sb/GitRepos/DynAbap/src/#ctdi#if_repair_print_provider.intf.abap)
* **Dynamic Engine Class**: [#ctdi#cl_repair_print_engine.clas.abap](file:///home/sb/GitRepos/DynAbap/src/#ctdi#cl_repair_print_engine.clas.abap)
* **Sample Print Class**: [#ctdi#cl_repair_print_sample.clas.abap](file:///home/sb/GitRepos/DynAbap/src/#ctdi#cl_repair_print_sample.clas.abap)
* **Output Determination Wrapper**: [#ctdi#sd_repair_print_program.prog.abap](file:///home/sb/GitRepos/DynAbap/src/#ctdi#sd_repair_print_program.prog.abap)
* **ABAP Unit Tests**: [#ctdi#cl_repair_print_engine.clas.testclasses.abap](file:///home/sb/GitRepos/DynAbap/src/#ctdi#cl_repair_print_engine.clas.testclasses.abap)
* **Exception Classes**: 
  - `/ctdi/cx_print_error`
  - `/ctdi/cx_repair_not_found`
  - `/ctdi/cx_form_error`
  - `/ctdi/cx_no_config_found`
* **SM30 Event Template**: [src/templates/sm30_event_class_generator.abap](file:///home/sb/GitRepos/DynAbap/src/templates/sm30_event_class_generator.abap)

---

## Operational Workflow: Adding a New Project & Form

When a new business project category is introduced requiring a new Adobe Form or Smart Form layout, follow these 4 operational steps to integrate it:

### 1. Define the Print Layout
Create the form layout in SAP:
* For **Adobe PDF-Based Forms**: Use Transaction **`SFP`** to design the Interface and Form.
* For **Smart Forms**: Use Transaction **`SMARTFORMS`** to build the layout.

### 2. Register the Customizing Entry in DEV
Link the specific Contract VBELN to your form and print class using Transaction **`SM30`** (table **`/CTDI/SD_REPAIR_FORM`**):
* **Contract/Repair Number**: The contract `VBELN` associated with the repair project.
* **Form Name**: The name of the SFP Form or Smart Form created in Step 1.
* **Class Name**: Leave blank. The SM30 auto-generation event will automatically generate a new SE24 class implementing `/CTDI/IF_REPAIR_PRINT_PROVIDER` (named `/CTDI/CL_REPAIR_PRINT_{vbeln}`).
* **Method Name**: Defaults to `PRINT`.

### 3. Implement Custom Logic in the Generated Class
In transaction **`SE24`**, locate your newly generated class `/CTDI/CL_REPAIR_PRINT_{vbeln}`:
* Define your data collection logic inside the `read_data` stub.
* Implement parameter binding or custom formatting in the `print` stub.

### 4. Transport and Wire Triggering (NACE)
Go to Transaction **`NACE`** and map the print output routine for your Output Type to the wrapper program [#ctdi#sd_repair_print_program](file:///home/sb/GitRepos/DynAbap/src/#ctdi#sd_repair_print_program.prog.abap) with form routine **`ENTRY`**. Once tested, release and transport the configuration and generated classes to QA/PRD.

---

## Installation & Configuration

1. **Import the package** into your SAP system using [abapGit](https://abapgit.org/).
2. **Activate** all imported objects.
3. Configure your contract mapping via Transaction `SM30` for table `/CTDI/SD_REPAIR_FORM`.
4. Attach the event template [sm30_event_class_generator.abap](file:///home/sb/GitRepos/DynAbap/src/templates/sm30_event_class_generator.abap) to table events:
   - **Event 05 (Creating a new entry):** Attach `on_new_entry`.
   - **Event 01 (Before saving):** Attach `on_before_save`.
5. Wire the wrapper [#ctdi#sd_repair_print_program](file:///home/sb/GitRepos/DynAbap/src/#ctdi#sd_repair_print_program.prog.abap) into Transaction `NACE` under your specific Contract/Order Output Type with form routine `ENTRY`.
