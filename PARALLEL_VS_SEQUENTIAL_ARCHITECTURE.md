# Architecture Comparison: Parallel Processing vs. Simplified Sequential

---

## 1. Option A: Architecture WITH Parallel Processing (Current State)

```mermaid
graph TD
    UI["ALV User Command<br>(PRINT / PDF_SEL / PDF_MERGE)"] --> Check{"Threshold Check<br>&gt; 50 Orders?"}

    subgraph Parallel_Branch ["Parallel Branch (&gt; 50 Orders)"]
        Marshal["1. Marshal Data<br>(EXPORT TO BUFFER)"]
        Mgr["2. CL_ABAP_PARALLEL Engine<br>(p_num_tasks = 10)"]
        
        subgraph RFC_Tasks ["Multiple Asynchronous RFC Tasks"]
            WP1["Task 1: lcl_parallel_print=&gt;do"]
            WP2["Task 2: lcl_parallel_print=&gt;do"]
            WP3["Task N: lcl_parallel_print=&gt;do"]
        end
        
        Unmarshal["3. Collect &amp; Unmarshal<br>(IMPORT FROM BUFFER)"]
        ClientMerge["4. Client-side PDF Merger<br>(CL_RSPO_PDF_MERGE)"]
        
        Marshal --> Mgr
        Mgr --> WP1 & WP2 & WP3
        WP1 & WP2 & WP3 --> Unmarshal
        Unmarshal --> ClientMerge
    end

    subgraph Sequential_Branch ["Sequential Branch (&lt; 50 Orders or Bundled Spool)"]
        SeqLoop["Sequential Loop<br>(Main Process Session)"]
        SeqDrv["/CTDI/CL_PRINT_DRIVER_BASE"]
        SpoolBund["Single Spool Bundler<br>(FP_JOB_OPEN / SSF_OPEN)"]
        SeqLoop --> SeqDrv --> SpoolBund
    end

    Check -- "Yes (PDF Mode)" --> Marshal
    Check -- "No / Spool Bundled" --> SeqLoop
```

### Key Characteristics:
- **Dual Pipeline:** Conditional bifurcation based on order count and execution mode.
- **Inter-Process Marshaling:** Uses `EXPORT ... TO DATA BUFFER` and `IMPORT ... FROM DATA BUFFER`.
- **Spool Limitation:** Parallel tasks **cannot share an open spool** (`FP_JOB_OPEN`/`SSF_OPEN`), requiring separate sequential fallback for bundled printing.

---

## 2. Option B: Architecture WITHOUT Parallel Processing (Simplified Sequential)

```mermaid
graph TD
    UI["ALV User Command<br>(PRINT / PDF_SEL / PDF_MERGE)"] --> Loop["Single Unified Loop<br>(with cl_progress_indicator)"]

    subgraph Direct_Engine ["Direct Object Pipeline (Single Session)"]
        Fact["/CTDI/CL_PRINT_DRIVER_BASE=&gt;factory( aufnr )"]
        Exec["lr_driver-&gt;execute( )"]
        
        subgraph Output_Strategies ["Direct Output Strategies"]
            Spool["1. Single Spool Bundler<br>(FP_JOB_OPEN / SSF_OPEN)"]
            PDFDir["2. Local Directory Download<br>(CL_GUI_FRONTEND_SERVICES)"]
            PDFMerge["3. Single Merged PDF<br>(ADS bumode='M' / CL_RSPO_PDF_MERGE)"]
        end
    end

    Loop --> Fact --> Exec
    Exec --> Spool
    Exec --> PDFDir
    Exec --> PDFMerge
    Loop --> GridUpdate["Direct ALV Status Update<br>(LED &amp; Message)"]
```

### Key Characteristics:
- **Single Linear Pipeline:** 100% deterministic and transparent.
- **Direct Memory Access:** Eliminates buffer serialization entirely.
- **Spool Native:** Native single-spool bundling for all orders.
- **Progress Tracking:** Real-time percentage update per order via `cl_progress_indicator`.

---

## 3. Side-by-Side Architectural Matrix

| Metric | With Parallel (`cl_abap_parallel`) | Without Parallel (Simplified) |
|---|:---:|:---:|
| **Code Size** | ~1,036 lines | **~860 lines** ($-170$ lines) |
| **Execution Paths** | Dual (Parallel + Sequential) | **Single unified engine** |
| **Data Flow** | Binary Buffer Serialization | **Direct in-memory objects** |
| **Debugging** | Complex (Requires RFC/SM50 debugging) | **Trivial (Standard breakpoints)** |
| **Spool Bundling** | Incompatible across parallel tasks | **100% Native single spool** |
| **Server Resource Safety** | Consumes up to 10 dialog work processes | **1 session process only** |
| **Batch Compatibility** | Complex background RFC handling | **Rock-solid in SM36 / SM37** |
| **Throughput (200 Orders)** | ~15–20 seconds | **~30–45 seconds** |

---

## 4. Architectural Verdict

> [!TIP]
> **Maintainability & Reliability Recommendation:**
> Unless you have strict SLA requirements demanding sub-20-second exports for $>500$ individual PDFs in interactive dialog mode, **Option B (Simplified Sequential)** is strongly recommended. It eliminates ~170 lines of boilerplate, eliminates RFC concurrency failures, and ensures single-session spool bundling works seamlessly.
