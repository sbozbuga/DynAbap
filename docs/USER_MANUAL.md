# /CTDI/ Repair Print Framework — End-User Manual & Operational Guide

---

> **Document Version:** 2.1  
> **Target Audience:** Workshop Technicians, Dispatchers, Warehouse Clerks, Repair Administrators, Key Users & Service Managers  
> **System Namespace:** `/CTDI/`  
> **Compatible SAP Releases:** SAP ERP 6.0 (EHP7/EHP8), SAP S/4HANA (On-Premise 1809+)

---

## Quick Navigation & Table of Contents

- [1. Framework Overview & Value Proposition](#1-framework-overview--value-proposition)
- [2. User Roles & Transaction Overview](#2-user-roles--transaction-overview)
- [3. Single Repair Order Printing (`/CTDI/PRINT_REPAIR`)](#3-single-repair-order-printing-ctdiprint_repair)
  - [3.1 Selection Screen & Parameters](#31-selection-screen--parameters)
  - [3.2 Step-by-Step: Printing a Single Order to Paper](#32-step-by-step-printing-a-single-order-to-paper)
  - [3.3 Step-by-Step: Generating & Saving a PDF with Inspection Photos](#33-step-by-step-generating--saving-a-pdf-with-inspection-photos)
  - [3.4 Quick-Access Customizing Toolbar](#34-quick-access-customizing-toolbar)
- [4. Mass Printing & Processing Workplace (`/CTDI/PRINT_REPAIR_MASS`)](#4-mass-printing--processing-workplace-ctdiprint_repair_mass)
  - [4.1 Selection Screen & Filtering Orders](#41-selection-screen--filtering-orders)
  - [4.2 The Interactive ALV Workplace Grid](#42-the-interactive-alv-workplace-grid)
  - [4.3 Understanding Attachment & Status Indicators](#43-understanding-attachment--status-indicators)
  - [4.4 1-Click Drilldown Navigation](#44-1-click-drilldown-navigation)
  - [4.5 Spool Printing Modes (Individual, Bundled, Merged)](#45-spool-printing-modes-individual-bundled-merged)
  - [4.6 PDF Export Modes (Batch Download vs. Merged PDF)](#46-pdf-export-modes-batch-download-vs-merged-pdf)
  - [4.7 On-Screen Print Preview](#47-on-screen-print-preview)
- [5. Inspection Photos & GOS Image Attachment Guide](#5-inspection-photos--gos-image-attachment-guide)
  - [5.1 Where Images Come From](#51-where-images-come-from)
  - [5.2 Supported Image Formats](#52-supported-image-formats)
  - [5.3 Automatic Page Layout & Aspect Ratio Preservation](#53-automatic-page-layout--aspect-ratio-preservation)
  - [5.4 Rendering Engines: Adobe ADS vs. Built-in Raw PDF](#54-rendering-engines-adobe-ads-vs-built-in-raw-pdf)
- [6. Key User & Supervisor Customizing Guide](#6-key-user--supervisor-customizing-guide)
  - [6.1 Form Routing Hierarchy (`/CTDI/REP_FORMS`)](#61-form-routing-hierarchy-ctdirep_forms)
  - [6.2 Repair Outcome Text Resolution (`/CTDI/REP_RESULT`)](#62-repair-outcome-text-resolution-ctdirep_result)
  - [6.3 Project Definitions (`/CTDI/REP_PROJEC`)](#63-project-definitions-ctdirep_projec)
- [7. Troubleshooting, Diagnostics & FAQ](#7-troubleshooting-diagnostics--faq)
  - [7.1 Spool Jobs in `SP01`](#71-spool-jobs-in-sp01)
  - [7.2 Application Logs in `SLG1`](#72-application-logs-in-slg1)
  - [7.3 Frequently Encountered Issues & Instant Fixes](#73-frequently-encountered-issues--instant-fixes)
- [8. Quick Reference Cheat Sheet](#8-quick-reference-cheat-sheet)

---

## 1. Framework Overview & Value Proposition

The **/CTDI/ Dynamic Repair Print Framework** is SAP-native software designed to handle all printing and PDF export requirements for customer repair orders, service notifications, and warranties.

![Repair Workshop Life Cycle](images/workshop_lifecycle.svg)

### Key Advantages for the Daily Operation

1. **Automatic Form Layout Detection:** You do not need to choose whether a customer uses **SmartForms** or modern **Adobe Interactive Forms (ADS)**. The system identifies the layout and renders it automatically.
2. **Integrated Inspection & Defect Photos:** Any photos attached via SAP GOS (Generic Object Services) or Content Server / ArchiveLink are automatically scaled to DIN A4 and appended to the PDF output.
3. **Flexible Spool Bundling:** Instead of flooding the printer with hundreds of 1-page spool requests, you can bundle an entire shift's batch into a single spool job.
4. **Smart Folder PDF Downloads:** When downloading PDFs for multiple orders, the system prompts you for the destination directory once and saves all files quietly in the background without repeated dialogs.
5. **Direct Master Data Drilldown:** Double-click on any order, notification, or contract in the mass screen to jump straight to standard transactions (`IW33`, `IW53`, `VA43`, `VA03`).

---

## 2. User Roles & Transaction Overview

| Role | Main Transactions | Primary Tasks |
|---|---|---|
| **Workshop Technician / Operator** | `/CTDI/PRINT_REPAIR` | Print single repair slip, preview output, check inspection photos. |
| **Dispatcher / Shipping Clerk** | `/CTDI/PRINT_REPAIR_MASS` | Review ready orders, print batch spools, export merged customer dossiers. |
| **Key User / Repair Supervisor** | `SM30` (`/CTDI/REP_FORMS`, `/CTDI/REP_RESULT`) | Configure customer layouts, maintain repair outcome texts, adjust image rules. |
| **IT & Spool Administrator** | `SP01`, `SLG1`, `NACE` | Spool queue management, application log analysis, output condition records. |

---

## 3. Single Repair Order Printing (`/CTDI/PRINT_REPAIR`)

Use **`/CTDI/PRINT_REPAIR`** when working on an individual repair order at the service desk, packing station, or technician workbench.

### 3.1 Selection Screen & Parameters

![Single Repair Order Printout Selection Screen](images/ui_single_selection.svg)

#### Field Explanations

| Field | Description | Mandatory? | Notes / Recommendation |
|---|---|:---:|---|
| **Repair / Order ID** (`p_aufnr`) | The SAP PM/CS Service Order number (e.g., `4001234`). | **Yes** | Leading zeros are added automatically by SAP. |
| **Serial Number** (`p_sernr`) | Specific equipment serial number. | No | Leave blank if printing for the primary order equipment. |
| **Append attached images** (`p_images`) | Appends defect/inspection photos to the PDF. | No | Check this if the customer requires photographic evidence. |

> [!NOTE]
> When executing from standard transaction **`IW42`** (Overall Completion Confirmation), the system defaults directly to printer spool mode. When executing manually from the selection screen, the system defaults to generating a **local PDF file**.

---

### 3.2 Step-by-Step: Printing a Single Order to Paper

1. Enter Transaction code **`/CTDI/PRINT_REPAIR`** in the SAP command field.
2. Enter the **Repair Order ID** in `p_aufnr`.
3. If paper printout is required, ensure the output device configured in your SAP User Profile (`SU3` &rarr; *Defaults* &rarr; *Output Device*) is set to your physical workstation printer.
4. Press **`F8`** (Execute).
5. The system resolves the layout and dispatches the document directly to the printer spool. A status message appears in the bottom status bar:
   > `✔ Print driver completed successfully for Repair 4001234`

---

### 3.3 Step-by-Step: Generating & Saving a PDF with Inspection Photos

1. Launch **`/CTDI/PRINT_REPAIR`**.
2. Enter the **Repair Order ID** (e.g., `4001234`).
3. Check the box **[X] Append attached images to PDF**.
4. Press **`F8`** (Execute).
5. A Windows **File Save Dialog** opens automatically:
   - File Name suggestion: `Repair_4001234_<Timestamp>.pdf`
   - Choose your target local folder (e.g., `C:\Repairs\Reports\`) and click **Save**.
6. The resulting PDF document contains:
   - **Page 1..N:** The official Repair Delivery Note / Certificate (Adobe Form or SmartForm).
   - **Page N+1..:** All attached inspection and damage photos, scaled to A4 with aspect ratio preservation and timestamp captions.

---

### 3.4 Quick-Access Customizing Toolbar

At the top of the selection screen, authorized Key Users and Supervisors have direct access to system customizing tables without leaving the transaction:

![Quick-Access Customizing Toolbar](images/ui_customizing_toolbar.svg)

- **`[Project]` (FC02):** Opens Table Maintenance for `/CTDI/REP_PROJEC` (Contract-to-project mappings).
- **`[Forms]` (FC03):** Opens Table Maintenance for `/CTDI/REP_FORMS` (Contract-to-form & driver assignments).
- **`[Results]` (FC04):** Opens Table Maintenance for `/CTDI/REP_RESULT` (11-step repair outcome text mappings).
- **`[Mass Printing]` (FC05):** Instantly launches the Mass Processing Workplace (`/CTDI/PRINT_REPAIR_MASS`).

> [!IMPORTANT]
> The customizing buttons `[Project]`, `[Forms]`, and `[Results]` are only visible if your SAP user ID is granted maintenance authorization in table `ZSM30_USER`. Regular operators will only see the `[Mass Printing]` shortcut.

---

## 4. Mass Printing & Processing Workplace (`/CTDI/PRINT_REPAIR_MASS`)

**`/CTDI/PRINT_REPAIR_MASS`** is the primary operational dashboard for dispatchers, shipping clerks, and repair supervisors. It displays an interactive ALV grid containing all ready repair orders and allows bulk execution.

### 4.1 Selection Screen & Filtering Orders

![Mass Print Selection Screen](images/ui_mass_selection.svg)

1. Enter your search criteria (Order range, Plant, or Date range).
2. If you want inspection photos included in PDF exports, select **[X] Append attached images to PDF**.
3. Press **`F8`** (Execute).

---

### 4.2 The Interactive ALV Workplace Grid

The program retrieves all matching orders, deduplicates records to guarantee **strictly one row per repair order**, pre-evaluates form layouts, and renders the interactive ALV Workplace:

![Interactive ALV Workplace Grid](images/ui_alv_grid.svg)

---

### 4.3 Understanding Attachment & Status Indicators

#### Column: `Att.` (`ICON_IMG`) — Attachment Status

| Icon | SAP Symbol | Meaning | What it means for you |
|:---:|---|---|---|
| 🖼️ | `@9T@` (`icon_bmp`) | **Confirmed Image Attachments** | High-resolution photos exist in the Content Server / ArchiveLink (`ZRS_JPG`). These will be appended. |
| 📎 | `@1S@` (`icon_attachment`) | **Standard GOS Attachments** | Office/GOS attachments exist on the order or linked notification. Image formats (`JPG`, `PNG`, etc.) will be appended. |
| *Blank* | *Empty* | **No Attachments Found** | Order has no linked photos or files. Standard form output only. |

#### Column: `Stat` (`ICON`) — Execution Result

| Icon | SAP Symbol | State | Explanation |
|:---:|---|---|---|
| ⚪ | `@BZ@` (`icon_led_inactive`) | **Ready / Untouched** | Order has been loaded but not yet printed in this session. |
| 🟢 | `@5B@` (`icon_led_green`) | **Success** | Document printed to spool or successfully downloaded as PDF. |
| 🟡 | `@5D@` (`icon_led_yellow`) | **Warning / Fallback** | Processed with warnings, or non-critical fallback configuration used. |
| 🔴 | `@5C@` (`icon_led_red`) | **Error** | Execution failed. See the `Message` column for root-cause details. |

---

### 4.4 1-Click Drilldown Navigation

You can double-click directly on specific cell values in the ALV to open the corresponding SAP master transaction in a new session:

| Column Clicked | Target Transaction | Description |
|---|:---:|---|
| **Order ID** (`AUFNR`) | **`IW33`** | Display PM/CS Repair Order (operations, components, costs). |
| **Z2 Notif.** (`QMNUM`) | **`IW53`** | Display Service Notification (reported defect, customer remarks). |
| **Contract** (`CONTRACT_ID`) | **`VA43`** | Display Service / Sales Contract (SLA conditions, validity). |
| **Sales Order** (`KDAUF`) | **`VA03`** | Display Sales Order details. |

---

### 4.5 Spool Printing Modes (Individual, Bundled, Merged)

When clicking **`[Print Selected]`** (`PRINT_SEL`), the framework routes documents according to the currently active **Spool Mode**. You can switch the mode at any time by clicking the **`[Spool Mode]`** button in the ALV toolbar.

![Comparison of Spool Modes](images/spool_modes.svg)

1. **Individual Mode (`INDIVIDUAL`)**:
   - Creates a distinct spool job for every order.
   - **Best for:** When printed paper must be immediately separated into 100 physical technician trays by different workers.
2. **Bundled Mode (`BUNDLED`) — RECOMMENDED**:
   - Uses high-speed SAP spool bundling (`FP_JOB_OPEN` / `SSF_OPEN` simple bundling).
   - Generates only 1 or 2 large spool jobs (e.g., `Mass Print Adobe 21.09.2026_14:30`).
   - **Best for:** Maximum printing speed. Eliminates printer pauses between single jobs.
3. **Merged Mode (`MERGED`)**:
   - Converts all documents into PDF and merges them into one single spool document via `CL_RSPO_PDF_MERGE`.
   - **Best for:** When inspection photos must be included directly in the paper spool output.

---

### 4.6 PDF Export Modes (Batch Download vs. Merged PDF)

The ALV toolbar provides two distinct options for creating PDF files on your computer:

#### Option A: `[Save as PDF]` (`PDF_SEL`) — Individual File Batch

- **What it does:** Generates a separate `.pdf` file for each selected order.
- **Smart Directory Memory:**
  1. On the first order, SAP asks you where to save the files (e.g., `D:\Shift_Export\`).
  2. For all remaining selected orders, the system automatically saves into that same directory without prompting again!
  3. File naming format: `Repair_<OrderNumber>_<Timestamp>.pdf`.

#### Option B: `[PDF Merge]` (`PDF_MERGE`) — Single Combined Document

- **What it does:** Renders all selected repair certificates, appends all corresponding inspection photos, and stitches everything into **one single master PDF dossier**.
- Prompts you once for the output file name (e.g., `Repair-Merged-25-Orders-20260921.pdf`).
- **Best for:** Sending a complete bulk repair dossier to an external customer or archiving team via email.

---

### 4.7 On-Screen Print Preview

To visually inspect a document layout before sending it to the printer:
1. Select a single row in the ALV table.
2. Click **`[Preview]`** (`PREVIEW`).
3. The SAP Print Preview window opens immediately, showing the exact rendered form with live database values.
4. Close the preview window to return to the ALV grid without generating a spool job.

---

## 5. Inspection Photos & GOS Image Attachment Guide

The `/CTDI/` Print Framework features an automated photo append pipeline managed by `/CTDI/CL_PRINT_GOS_IMAGES`.

### 5.1 Where Images Come From

The system queries two standard SAP attachment locations:

1. **Generic Object Services (GOS / SOFFICE):**
   - Attachments stored directly on the Service Order (`BUS2007`) via the standard GOS paperclip icon.
   - Attachments stored on the linked Service Notification (`QMEL` / `BUS2078`).
2. **SAP Content Server / ArchiveLink (`TOA01`):**
   - Professional defect inspection images archived under document type `ZRS_JPG`.

---

### 5.2 Supported Image Formats

| File Extension | Format | Support Status | Notes |
|:---:|:---:|:---:|---|
| `.JPG` / `.JPEG` | JPEG | ✅ Full Native | Full EXIF orientation support, auto-scaled. |
| `.PNG` | Portable Network Graphics | ✅ Full Native | Transparency preserved against white background. |
| `.BMP` | Windows Bitmap | ✅ Full Native | Converted and scaled. |
| `.TIF` / `.TIFF` | Tagged Image File | ✅ Full Native | Standard single-page inspection TIFFs supported. |
| `.PDF` / `.DOCX` | Non-Image Documents | ℹ️ Preserved | Filtered out from image pipeline (not converted to photos). |

---

### 5.3 Automatic Page Layout & Aspect Ratio Preservation

Attached photos are never stretched or distorted. The engine calculates the optimal bounding box and packs **up to 2 photos per DIN A4 page** vertically:

![Inspection Photo Layout](images/image_layout.svg)

- If an order has **1 image**: It is centered gracefully on the page.
- If an order has **2 images**: Both are stacked vertically on Page 1.
- If an order has **3+ images**: A new A4 page is opened automatically for images 3 & 4.

---

### 5.4 Rendering Engines: Adobe ADS vs. Built-in Raw PDF

In the ALV Toolbar, you can toggle the image rendering method using **`[Img Render]`** (`IMG_RENDER`):

| Mode | Technology | When to use |
|---|---|---|
| **Raw PDF** (`R`) | Built-in Lightweight Vector Engine | **Default & Recommended.** Fastest execution, zero server overhead, works even if Adobe Document Services (ADS) is temporarily offline. |
| **ADS Form** (`A`) | Adobe Document Services (`/CTDI/REPAIR_IMG`) | Uses SAP standard ADS template rendering. Ideal for high-end color profile matching. |

---

## 6. Key User & Supervisor Customizing Guide

Key users can maintain customer form routing and repair texts via Transaction **`SM30`** (or by clicking the quick-access buttons on the `/CTDI/PRINT_REPAIR` selection screen).

### 6.1 Form Routing Hierarchy (`/CTDI/REP_FORMS`)

When a repair order is processed, the framework evaluates table **`/CTDI/REP_FORMS`** using an **8-step priority fallback sequence**:

![Form Routing Priority Hierarchy](images/access_sequence.svg)

#### Table Columns in `/CTDI/REP_FORMS`

| Column | Key? | Description | Example |
|---|:---:|---|---|
| `VBELN` | **Key** | Sales Contract / Customer Project Number | `40000010` (or blank for global) |
| `SKZ` | **Key** | Confirmation Reason (`AFRU-BEMOT`) | `10` (Standard Repair) |
| `AKZ` | **Key** | Defect / Reason Code (`QMEL-QMCOD`) | `SCRP` (Scrap) |
| `FORM_NAME` | | SmartForm or Adobe Form layout name | `/CTDI/REPAIR_D` |
| `CLASS_NAME` | | Driver class inheriting from `/CTDI/CL_PRINT_DRIVER_BASE` | Leave blank for auto-generation! |
| `APPEND_IMAGES` | | Default rule for attaching inspection photos | `X` = Always attach, ` ` = Do not attach |

> [!TIP]
> **Automatic Class Generator:** When creating a new contract entry in SM30 for `/CTDI/REP_FORMS`, you can leave `CLASS_NAME` empty. The system will automatically detect this and ask:
> *"Do you want to generate a new driver class /CTDI/CL_PRINT_DRIVER_<Contract>?"*
> Clicking **Yes** automatically creates and activates a clean ABAP class ready for custom logic!

---

### 6.2 Repair Outcome Text Resolution (`/CTDI/REP_RESULT`)

Table **`/CTDI/REP_RESULT`** controls the customer-facing outcome text printed on the certificate (e.g., *"Replaced main board and recalibrated antenna"*). It uses an **11-step rule access sequence** evaluating Contract, SKZ, AKZ, and whether a device exchange (Tauschfall) took place.

---

### 6.3 Project Definitions (`/CTDI/REP_PROJEC`)

Table **`/CTDI/REP_PROJEC`** maps the high-level business project name and customer identifier to the SAP Sales Contract number.

---

## 7. Troubleshooting, Diagnostics & FAQ

### 7.1 Spool Jobs in `SP01`

To check the status of physical print jobs:
1. Open Transaction **`SP01`**.
2. Filter by your User Name (`sy-uname`) and Date.
3. Look for the standardized Job Titles:
   - `Mass Print Adobe <Date>_<Time>` &rarr; Bundled Adobe PDF job.
   - `Mass Print SmartForms <Date>_<Time>` &rarr; Bundled SmartForms job.
   - `Mass Print Merged <Date>_<Time>` &rarr; Unified merged spool job.
4. Status `COMPLETED` indicates the document reached the physical printer.

---

### 7.2 Application Logs in `SLG1`

If an order fails with a red LED in the ALV:
1. Open Transaction **`SLG1`**.
2. Enter Object: **`/CTDI/PRINT_REPAIR`**.
3. Press **`F8`** (Execute).
4. Full diagnostic call stacks, parameter dumps, and root exceptions are logged for IT review.

---

### 7.3 Frequently Encountered Issues & Instant Fixes

#### Issue 1: ALV row turns Yellow with message *"No configuration found in /CTDI/REP_FORMS"*
- **Cause:** No active entry in `/CTDI/REP_FORMS` matches the Contract, SKZ, or AKZ of this order, and no Global Fallback (blank contract entry) is defined.
- **Solution:** Click the `[Forms]` button on the selection screen, add an entry for the contract (or a global blank entry), and enter the desired form name.

#### Issue 2: Spool error *"Printer destination invalid or USR01 default missing"*
- **Cause:** Your user profile has no default printer configured.
- **Solution:** Go to Transaction **`SU3`** &rarr; Tab **`Defaults`** &rarr; Set **Output Device** (e.g. `LOCL` or your network printer) &rarr; Check **Output Immediately** &rarr; Save (`Ctrl+S`).

#### Issue 3: Error *"PDF merge initialization failed (ADS connection error)"*
- **Cause:** The SAP Adobe Document Services RFC connection (`ADS`) is temporarily down.
- **Solution:** In the ALV toolbar, click **`[Img Render]`** and switch to **Raw PDF** mode. Raw PDF does not require ADS and runs completely independently.

#### Issue 4: Photos attached in GOS do not appear in the PDF
- **Cause:** The checkbox *Append attached images* was unchecked, or the attached files are non-image formats (e.g., Word `.docx` or Excel `.xlsx`).
- **Solution:** Verify the attachment is a valid image (`.jpg`, `.png`, `.bmp`, `.tif`) and ensure the attachment toggle is active (`[Attach: ON]`).

---

## 8. Quick Reference Cheat Sheet

| I want to... | Action to take |
|---|---|
| **Print 1 order immediately** | Run `/CTDI/PRINT_REPAIR`, enter Order ID, hit `F8`. |
| **Print 50 orders to paper without stopping** | Run `/CTDI/PRINT_REPAIR_MASS`, select rows, click `[Print Selected]` with Spool Mode set to **Bundled**. |
| **Send 1 combined PDF of 20 orders to a customer** | Run `/CTDI/PRINT_REPAIR_MASS`, select rows, click `[PDF Merge]`. |
| **Export 100 individual PDFs into a folder** | Run `/CTDI/PRINT_REPAIR_MASS`, select rows, click `[Save as PDF]`. Choose the folder once; rest is automatic. |
| **Inspect an order before printing** | Double-click the Order ID in the ALV to open `IW33`, or click `[Preview]`. |
| **Check if an order has photos** | Look at the `Att.` column: 🖼️ = Content Server photos, 📎 = GOS files. |
| **Switch Spool Mode** | Click `[Spool Mode]` on the ALV toolbar (choose Individual, Bundled, or Merged). |
| **Add a new customer form** | Open `/CTDI/REP_FORMS` via `SM30`, add the Contract number and Form Name, leave Class blank to auto-generate. |

---

*/CTDI/ Repair Print Framework — Built with Precision for SAP Service Operations.*
