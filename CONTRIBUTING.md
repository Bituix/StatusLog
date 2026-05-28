# Contributing to Status Framework

## About this project

Status Framework is a personal open-source project. It is a generic, reusable SAP S/4HANA state machine framework — not tied to any specific company, business domain, or proprietary configuration.

---

## Personal vs. company use

This repository is maintained as a **generic framework core**. It contains:

- Framework infrastructure (tables, CDS views, RAP behaviors, business logic engine)
- Generic example status codes and configurations
- Architecture documentation and design decisions

It does **not** contain, and should never contain:

- Company-specific business object types or status configurations
- Real transport request numbers or system IDs
- Proprietary business logic specific to any employer or client
- Any data or configuration belonging to a company's SAP landscape

### Using this at a company

The recommended approach is to **fork this repository** into your company's GitHub Organization and maintain it as a downstream instance. Company-specific configuration, object type registrations, and business rules live in the fork — not here.

Improvements to the generic framework core can be contributed back via pull request to this repository.

---

## Branching strategy

| Branch      | Purpose                                            |
| ----------- | -------------------------------------------------- |
| `main`      | Stable — reflects production-ready framework state |
| `develop`   | Integration — active development target            |
| `feature/*` | One branch per feature or queued item              |
| `release/*` | Cut when preparing a transport request group       |

All changes go through pull requests into `develop`. Only `develop` merges into `main`, and only when the corresponding SAP transport is production-ready.

**Branch naming examples:**

```
feature/criticality-field
feature/status-type-rename
feature/change-status-auto-resolution
release/1.0
```

---

## Commit message convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add criticality field to ZCASTAT_CODE
fix: remove MANDT from CDS association ON conditions
docs: update decisions.md with timestamp strategy rationale
chore: update CLAUDE.md with queued features
refactor: rename StatusWorkflow to StatusType across all objects
test: add ABAP Unit coverage for ChangeStatus ambiguous action
```

---

## Adding a new feature

1. Open a GitHub Issue with the label `status: design` before writing any code
2. Document the decision in `docs/decisions.md` (naming rationale, rejected alternatives)
3. Create a `feature/*` branch from `develop`
4. Implement across the full stack: DDIC → CDS → BDEF → class → test
5. Update `CLAUDE.md` if any conventions or queued items change
6. Open a PR into `develop` with a reference to the issue

---

## What belongs in `docs/`

| File                 | Purpose                                                                                                  |
| -------------------- | -------------------------------------------------------------------------------------------------------- |
| `architecture.md`    | Full framework design — tables, CDS layers, RAP model, Fiori integration                                 |
| `decisions.md`       | ADR log — one entry per resolved naming or structural decision, with rationale and rejected alternatives |
| `bs02-comparison.md` | Explicit positioning against SAP standard BS02 User Status                                               |

Keep all documentation generic. No company names, no real system landscapes, no proprietary object types.

---

## Transport sequence

When promoting to a SAP system, DDIC objects must land before CDS views, which must land before behavior definitions and classes. The required sequence is documented in `transport/sequence.md`.

Never skip the sequence — activation errors from missing dependencies are painful to untangle in production systems.
