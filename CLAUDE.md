# Status Framework — Claude Code Project Memory

## What this is

A custom SAP S/4HANA **state machine framework** — a modern, RAP-native replacement for SAP's classic BS02 User Status solution. It provides a configurable status lifecycle engine for any business object type, fully aligned with CDS view architecture, RAP behavior definitions, and Fiori UX patterns.

**Positioning**: "BS02 reimagined for RAP." Where BS02 is SE-configured and BAPI-driven, this framework is CDS-projected, RAP-managed, and Fiori-ready.

---

## Package & Naming Conventions

### DDIC Tables — prefix `ZCASTAT_*`

> 16-character DDIC limit drove rejection of `ZCA_STATUS_*`

| Table             | Purpose                                            |
| ----------------- | -------------------------------------------------- |
| `ZCASTAT_TYPE`    | Status type header (the state machine definition)  |
| `ZCASTAT_CODE`    | Status codes per type (nodes in the state machine) |
| `ZCASTAT_ACTION`  | Named user actions / allowed transitions           |
| `ZCASTAT_LANE`    | Reusable ProcessFlow lane labels and positions     |
| `ZCASTAT_FLWNODE` | Flow visualization nodes (Fiori ProcessFlow)       |
| `ZCASTAT_FLWCONN` | Flow visualization connections                     |
| `ZCASTAT_LOG`     | Status change audit log                            |

Draft table for flow nodes: `ZCASTAT_FLWNOD_D` (E dropped to hit exactly 16 chars).

### CDS Views — layer prefix before functional area

| Prefix    | Layer                       | Example            |
| --------- | --------------------------- | ------------------ |
| `ZI_CA_*` | Interface (base) views      | `ZI_CA_StatusType` |
| `ZC_CA_*` | Projection (consumer) views | `ZC_CA_StatusType` |

This matches SAP standard naming — layer type (`I`/`C`) comes before functional area (`CA`).

### Core Class

`ZCL_CA_STATUS_MANAGER` — the central business logic engine.

### Example Status Codes

| Code    | Label            | Flag                |
| ------- | ---------------- | ------------------- |
| `SUBM`  | Submitted        | `is_initial = true` |
| `PNDG`  | Pending Approval | —                   |
| `APPR`  | Approved         | —                   |
| `RJCT`  | Rejected         | —                   |
| `REVSN` | In Revision      | —                   |
| `CLOS`  | Closed           | `is_final = true`   |

---

## Key Design Decisions

### Core entity is `StatusType`, not `StatusWorkflow`

"WorkflowType overpromises" — the framework is a state machine, not a workflow engine. This name propagates to all objects: table `ZCASTAT_TYPE`, CDS view `ZI_CA_StatusType`, etc.

### `ZCASTAT_ACTION` rows = named user actions

Rows in the action table represent **named transitions a user can trigger** (e.g. "Submit for Approval"), not abstract graph edges. This distinction matters for UI action binding.

### Simple dynamic flow and complex overrides

The default flow uses `ZCASTAT_LANE`, the preferred `ZCASTAT_CODE-LANE_ID`, active actions, and log history. Each visit becomes a unique visual occurrence. Effective lane position never decreases: a rollback status stays in the current lane and renders below it. Future actions are expanded once to bound cycles.

If any active `ZCASTAT_FLWNODE` exists for a status type, `ZCASTAT_FLWNODE` and `ZCASTAT_FLWCONN` become the explicit complex-layout override. The same `status_code` may then map to multiple configured nodes (`N_PNDG`, `N_PNDG2`).

### `FLW` abbreviation for flow tables

`ZCASTAT_FLWNODE`, `ZCASTAT_FLWCONN` — fits within the 16-character limit.

### MANDT handling

Removed from all CDS view key projections and association ON conditions. CDS runtime handles MANDT filtering transparently — explicit MANDT in keys is redundant and incorrect in CDS.

---

## Timestamp Strategy

### Config tables (`ZCASTAT_TYPE`, `ZCASTAT_CODE`, `ZCASTAT_ACTION`, `ZCASTAT_LANE`, `ZCASTAT_FLWNODE`, `ZCASTAT_FLWCONN`)

Two fields: `created_at UTCLONG`, `changed_at UTCLONG`.

### Log table (`ZCASTAT_LOG`)

Three fields — deliberate decision for SE16N readability:
| Field | Type | Purpose |
|---|---|---|
| `changed_at` | `UTCLONG` | Precision ordering, programmatic use |
| `changed_date` | `DATS` / `SY-DATUM` | Direct SE16N readability |
| `changed_time` | `TIMS` / `SY-UZEIT` | Direct SE16N readability |

> Rationale: Basis teams and support personnel read logs directly in SE16N without timezone conversion tooling. The DATS/TIMS pair eliminates that friction operationally.

---

## Transport & Content Flags

| Object group             | `CONTFLAG` | `TABART` |
| ------------------------ | ---------- | -------- |
| All 6 customizing tables | `C`        | `CUST`   |
| Log table `ZCASTAT_LOG`  | `A`        | `APPL0`  |

---

## `criticality` Field on `ZCASTAT_CODE`

Type `INT1`. Used by RAP/Fiori for **automatic semantic coloring** — no custom UI code needed.

| Value | Meaning            |
| ----- | ------------------ |
| `0`   | Neutral            |
| `1`   | Negative (red)     |
| `2`   | Critical (orange)  |
| `3`   | Positive (green)   |
| `5`   | Information (blue) |

---

## `ZCL_CA_STATUS_MANAGER` — `ChangeStatus` Method

### Signature (smart auto-resolution)

```abap
METHOD ChangeStatus
  IMPORTING
    iv_object_type    TYPE zcast_obj_type
    iv_object_key     TYPE zcast_obj_key
    iv_action_code    TYPE zcast_action_code  " optional
    iv_from_status    TYPE zcast_stat_code    " optional
    iv_to_status      TYPE zcast_stat_code    " optional
  RAISING
    zcx_ca_status_error.
```

### Resolution logic

- `iv_from_status` omitted → reads last `ZCASTAT_LOG` entry for current status
- `iv_to_status` omitted → auto-resolves target when **exactly one** active action exists for the current status
- Two or more valid targets → raises `AMBIGUOUS_ACTION` exception (caller must specify `iv_action_code` or `iv_to_status`)

---

## Fiori ProcessFlow — Swimlane Support

`ZCASTAT_LANE` defines lane IDs, labels, icons, and positions. In simple mode each status selects its preferred lane through `ZCASTAT_CODE-LANE_ID`. Complex override nodes retain their own `lane_id` and `column_position`.

---

## Folder Structure

```
z-status-framework/
├── src/
│   ├── ddic/
│   │   ├── tables/       ← ZCASTAT_TYPE, _CODE, _ACTION, _LANE, _FLWNODE, _FLWCONN, _LOG
│   │   ├── domains/      ← ZCAST_STAT_CODE, ZCAST_OBJ_TYPE, ZCAST_ACTION_CODE
│   │   ├── dtel/         ← reusable data elements
│   │   └── structures/   ← shared ABAP type definitions
│   ├── cds/              ← ZI_CA_* interface views, ZC_CA_* projections
│   ├── bdef/             ← RAP behavior definitions + implementations
│   └── classes/          ← ZCL_CA_STATUS_MANAGER, ZCX_CA_StatusError, helpers
├── test/                 ← ABAP Unit test classes, fixture data
├── transport/            ← Transport request sequence documentation
├── docs/
│   ├── architecture.md
│   ├── decisions.md      ← ADR log (naming rationale, rejected alternatives)
│   └── bs02-comparison.md
├── .github/
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── ISSUE_TEMPLATE/
├── .abapgit.xml          ← abapGit config & package binding
├── CHANGELOG.md
└── CLAUDE.md             ← this file
```

---

## Queued Features

All planned features have been implemented. No pending items.

---

## What NOT to do

- Do not add `MANDT` to CDS view key lists or association ON conditions — the runtime handles it.
- Do not use `StatusWorkflow` anywhere — the correct term is `StatusType`.
- Do not exceed 16 characters on any DDIC object name.
- Do not use `CONTFLAG=C` on the log table — it must be `A` / `APPL0`.
- Do not rely on implicit type conversions for `UTCLONG` fields — always use `CONVERT TIME STAMP` or CDS built-in functions explicitly.

---

## abapGit Workflow

```
# Pull latest from SAP into local files
abapgit pull

# After Claude Code edits — push to SAP DEV
abapgit push

# Activate objects in SAP after push
# Test in DEV → create transport → promote to QA → Production
```

Claude Code edits files locally. abapGit is the bridge to SAP. Never edit directly in SE80/ADT and forget to pull — local files and SAP will diverge.
