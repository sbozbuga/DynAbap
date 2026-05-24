# DynAbap — Dynamic ABAP Tools & Utilities

A highly flexible, premium ABAP framework to dynamically map, route, and execute standard **Smart Forms** and **Adobe Forms** for Sales Contracts (Customer Projects & Repairs) in SAP. 

By decoupling form execution logic from hardcoded standard print programs, this repository enables SAP developers and consultants to configure customized printing routines and local PDF output control entirely via customizing tables.

---

## Key Features

* **Dynamic Execution Engine**: Instantiates configured classes and invokes execution methods (`PRINT`) dynamically at runtime using custom database mapping definitions.
* **Dual Form Support**: Transparently branches between **Adobe PDF-Based Print Forms** (`FP_JOB_OPEN`, `FP_FUNCTION_MODULE_NAME`) and **Smart Forms** (`SSF_FUNCTION_MODULE_NAME`) using a single parameter.
* **Interactive PDF Saving**: Detects foreground dialog mode (`ent_screen = 'X'`) and prompts the user via a popup dialog to either print to a spool or save locally as a PDF file utilizing Frontend Services (`gui_download`).
* **Smart Forms OTF-to-PDF Conversion**: Automatically captures OTF spool outputs and executes dynamic PDF rendering (`CONVERT_OTF`) for local downloads when requested.
* **Customer Project & Repair Mapping**: Dynamically resolves WBS Element details (`PRPS-POSID` / `PRPS-POST1`) linked at the contract item level, falling back to the Customer PO Reference (`VBAK-BSTNK`) to identify and display project names (e.g. *"Deutsche Telekom 5G Base Station Repair"*).
* **NACE Integration ready**: Seamlessly integrates into SAP standard Output Determination (Message Control) via the [ZSD_CONTRACT_PRINT_PROGRAM](file:///home/sb/GitRepos/DynAbap/src/zsd_contract_print_program.prog.abap) wrapper.

---

## File Structure

All ABAP objects are structured in an **abapGit** compatible format under the `src/` directory:

* **Customizing Table**: [zsd_contr_form.tabl.xml](file:///home/sb/GitRepos/DynAbap/src/zsd_contr_form.tabl.xml)
* **Print Provider Interface**: [zif_contract_print_provider.intf.abap](file:///home/sb/GitRepos/DynAbap/src/zif_contract_print_provider.intf.abap)
* **Dynamic Engine Class**: [zcl_contract_print_engine.clas.abap](file:///home/sb/GitRepos/DynAbap/src/zcl_contract_print_engine.clas.abap)
* **Sample Print Class**: [zcl_contract_print_sample.clas.abap](file:///home/sb/GitRepos/DynAbap/src/zcl_contract_print_sample.clas.abap)
* **Output Determination Wrapper**: [zsd_contract_print_program.prog.abap](file:///home/sb/GitRepos/DynAbap/src/zsd_contract_print_program.prog.abap)
* **ABAP Unit Tests**: [zcl_contract_print_engine.clas.testclasses.abap](file:///home/sb/GitRepos/DynAbap/src/zcl_contract_print_engine.clas.testclasses.abap)

---

## Quick Configuration Steps

1. **Import the package** into your SAP system using [abapGit](https://abapgit.org/).
2. **Activate** all imported objects.
3. Configure your contract mapping via Transaction `SM30` for table `ZSD_CONTR_FORM`:
   * **Sales Doc Type**: `G2` (or your contract type)
   * **Form Name**: Name of your target Adobe Form or Smart Form
   * **Form Type**: `S` (Smart Form) or `A` (Adobe Form)
   * **Class Name**: `ZCL_CONTRACT_PRINT_SAMPLE` (or your custom class)
   * **Method Name**: `PRINT`
4. Wire the wrapper [ZSD_CONTRACT_PRINT_PROGRAM](file:///home/sb/GitRepos/DynAbap/src/zsd_contract_print_program.prog.abap) into Transaction `NACE` under your specific Contract Output Type with form routine `ENTRY`.
