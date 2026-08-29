
sap.ui.define([
    "sap/base/Log"
    // ... your other dependencies
], function (Log) {
    "use strict";

    return {
        onNavToDisplayApp: async function (sDocNumber) {
            try {
                var oCrossAppNav = await sap.ushell.Container.getServiceAsync("CrossApplicationNavigation");
                oCrossAppNav.toExternal({
                    target: {
                        semanticObject: "InboundDelivery",
                        action: "display"
                    },
                    params: {
                        "DeliveryDocument": sDocNumber
                    }
                });
            } catch (oError) {
                Log.error("CrossApplicationNavigation failed", oError);
            }
        }
    };
});

# Status Framework — abapgit Repository (v12)

SAP S/4HANA · ABAP RESTful Application Programming Model

---

## Naming conventions (v12)

| Object type                         | Prefix                                             |
| ----------------------------------- | -------------------------------------------------- |
| Domains                             | `ZCA_DO_*`                                         |
| Data elements                       | `ZCA_DE_*`                                         |
| Tables / Classes / Interfaces / CDS | `ZCASTAT_*` / `ZCL_CA_*` / `ZIFI_CA_*` / `ZI_CA_*` |

### Field name changes from previous versions

| Old name           | New name      |
| ------------------ | ------------- |
| `status_type_id`   | `status_type` |
| `business_obj_key` | `object_key`  |
| `log_sequence`     | `log_number`  |
| `from_status_code` | `from_status` |
| `to_status_code`   | `to_status`   |
| `created_by_user`  | `created_by`  |
| `changed_by_user`  | `changed_by`  |

---

## Repository manifest — 37 objects

| Category                | Objects                                                                           | Count |
| ----------------------- | --------------------------------------------------------------------------------- | ----- |
| Domains                 | ZCA_DO_STAT_TYPE · ZCA_DO_STAT_CODE · ZCA_DO_STAT_OBJ_KEY                         | 3     |
| Data elements           | ZCA_DE_STAT_TYPE · STAT_CODE · STAT_TYPE_DESC · STAT_OBJ_KEY · ACTION_CODE · COMMENTS · STAT_NEW | 7 |
| Tables                  | ZCASTAT_TYPE · CODE · ACTION · LANE · FLWNODE · FLWCONN · LOG                     | 7     |
| Draft stubs             | ZCASTAT_TYPE_D · CODE_D · ACTION_D · LANE_D · FLWNOD_D · FLWCN_D                  | 6     |
| CDS views               | ZI_CA_StatusType · Code · Action · FlwLane · FlwNode · FlwConn · StatusLog · ZC_CA_StatusCode | 8 |
| Behavior definitions    | ZBD_CA_StatusType · ZBD_CA_StatusAction                                           | 2     |
| Behavior implementation | ZBP_CA_STATUSTYPE                                                                 | 1     |
| BAdI interface          | ZIFI_CA_STAT_TRANSITION                                                           | 1     |
| Classes                 | ZCL_CA_STATUS_MANAGER · ZCX_CA_STATUS_ERROR                                       | 2     |

---

## Activation sequence

### 1. Domains → Data elements (SE11, mass activate)

`ZCA_DO_STAT_TYPE` → `ZCA_DO_STAT_CODE` → `ZCA_DO_STAT_OBJ_KEY`
`ZCA_DE_STAT_TYPE` → `ZCA_DE_STAT_CODE` → `ZCA_DE_STAT_TYPE_DESC` → `ZCA_DE_STAT_OBJ_KEY`

### 2. Tables (SE11)

ZCASTAT_TYPE → ZCASTAT_LANE → ZCASTAT_CODE → ZCASTAT_ACTION → ZCASTAT_FLWNODE → ZCASTAT_FLWCONN → ZCASTAT_LOG

| Table                                    | Delivery class | Table type |
| ---------------------------------------- | -------------- | ---------- |
| ZCASTAT_TYPE/CODE/ACTION/LANE/FLWNODE/FLWCONN | C          | CUST       |
| ZCASTAT_LOG                              | A              | APPL0      |

### 3. Manual prerequisites (SE11 / SNRO / SE19 / SE91)

#### Lock object — SE11: `EZCASTAT_LOCK`

- Table: ZCASTAT_LOG · Mode: E (exclusive, non-cumulative)
- Lock fields: `STATUS_TYPE` (ZCA_DE_STAT_TYPE) + `OBJECT_KEY` (ZCA_DE_STAT_OBJ_KEY)

#### Number range — SNRO: `ZCASTAT_NR`

- Interval 01 · Range 0000000001–9999999999 · Buffered size 10

#### BAdI — SE19: `ESPOT_ZCASTAT` / `BADI_ZCASTAT_TRANSITION`

- Interface: ZIFI_CA_STAT_TRANSITION
- Filter: `STATUS_TYPE` typed with **ZCA_DE_STAT_TYPE (CHAR 40)** ← must not use shorter type
- Multiple use: Yes · Default implementation: No

#### Message class — SE91: `ZCASTAT_MSG`

Six texts: CONCURRENT_LOCK · AMBIGUOUS_ACTION · NO_VALID_ACTION · INVALID_TRANSITION · CUSTOM_VALIDATION · NOT_AUTHORIZED

### 4. ABAP objects

`ZCX_CA_STATUS_ERROR` → `ZIFI_CA_STAT_TRANSITION` → `ZBP_CA_STATUSTYPE`

### 5. CDS views (ADT)

Mass-activate `ZI_CA_FlwLane`, `ZI_CA_StatusCode`, `ZI_CA_FlwNode`, `ZI_CA_FlwConn`, `ZI_CA_StatusType`, `ZI_CA_StatusAction`, `ZI_CA_StatusLog`, and `ZC_CA_StatusCode`.

### 6. Behavior definitions (ADT — generates draft tables)

`ZBD_CA_StatusType` → `ZBD_CA_StatusAction`

### 7. Manager class (last)

`ZCL_CA_STATUS_MANAGER`

---

## Usage

```abap
TRY.
  NEW ZCL_CA_STATUS_MANAGER( )->change_status(
    iv_status_type = 'ZMM_PO_REQUEST'
    iv_object_key  = ls_po-ebeln
    iv_action_code = 'APPROVE'
    iv_remark      = 'Approved after review' ).
  COMMIT WORK AND WAIT.
CATCH zcx_ca_status_error INTO DATA(lx).
  ROLLBACK WORK.
  MESSAGE lx->get_text( ) TYPE 'E'.
ENDTRY.
```

## Extending for a new object type (Clean Core)

1. SE19 → `ESPOT_ZCASTAT` → new BAdI implementation for `BADI_ZCASTAT_TRANSITION`
2. Set filter `STATUS_TYPE` = your type (e.g. `ZWM_DELIVERY`)
3. Implement `validate_transition` and `after_transition`
4. Transport in your functional team's own request

## Post-UAT backlog

| Item                                                                                     | Trigger                                    |
| ---------------------------------------------------------------------------------------- | ------------------------------------------ |
| CDS metadata cache in ZCL_CA_STATUS_MANAGER                                              | Load test with 100+ objects in list report |
| ILM archiving object for ZCASTAT_LOG (add ARCHIVED + ARCHIVED_AT columns before go-live) | First production volume data               |
| Auth object ZCASTAT_A + AUTHORITY-CHECK                                                  | Security workshop                          |
