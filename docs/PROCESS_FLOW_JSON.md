# ProcessFlow JSON

`ZCL_CA_STATUS_MANAGER->GET_PROCESS_FLOW_JSON` combines the active process-flow
configuration with the status history of one business object.

```abap
DATA(lv_json) = NEW zcl_ca_status_manager( )->get_process_flow_json(
  iv_status_type = 'ZMM_PO_REQUEST'
  iv_object_key  = '4500001234' ).
```

The complete configured graph is returned even when the object has no entries in
`ZCASTAT_LOG`. In that case the active `ZCASTAT_CODE` marked `IS_INITIAL = 'X'`
is shown as the current node and every other node is returned as `Planned`.

## Configuration

Keep the configuration in the existing tables:

1. Define the active statuses in `ZCASTAT_CODE`. Mark exactly one as initial.
2. Define one active row in `ZCASTAT_FLWNODE` for every visual occurrence.
3. Define the arrows in `ZCASTAT_FLWCONN`.

For each flow node:

- `NODE_ID` is the unique visual occurrence, for example `N_REVIEW1`.
- `STATUS_CODE` is the business status represented by the node.
- `NODE_TEXT` becomes the ProcessFlow node title.
- `LANE_ID` becomes the UI5 lane ID and lane text.
- `COLUMN_POSITION` becomes the UI5 lane position.
- Nodes with the same `LANE_ID` must have the same `COLUMN_POSITION`.

This avoids a separate lane table. Use short display-ready values such as
`CREATE`, `REVIEW`, and `COMPLETE` for `LANE_ID`.

Example:

| Node ID | Status | Text | Lane ID | Position |
|---|---|---|---|---:|
| `N_NEW` | `NEW` | New request | `CREATE` | 1 |
| `N_REVIEW` | `PENDING` | Pending approval | `REVIEW` | 2 |
| `N_APPROVED` | `APPROVED` | Approved | `COMPLETE` | 3 |
| `N_REJECTED` | `REJECTED` | Rejected | `COMPLETE` | 3 |

Connections:

| From node | To node |
|---|---|
| `N_NEW` | `N_REVIEW` |
| `N_REVIEW` | `N_APPROVED` |
| `N_REVIEW` | `N_REJECTED` |

The output contains both branches before either branch is taken. Connections are
also converted to the `children` array on each UI5 node.

## Re-entry

If a status can be visited more than once and every occurrence should be visible,
configure several nodes with the same `STATUS_CODE`, ordered by
`COLUMN_POSITION`:

```text
N_REVIEW1 (PENDING) -> N_REJECTED -> N_REVIEW2 (PENDING)
```

The first visit to `PENDING` maps to `N_REVIEW1`; the second maps to `N_REVIEW2`.
If only one node is configured, repeated visits reuse that node.

## Node states

| Situation | JSON state |
|---|---|
| Future configured node | `Planned` |
| Current ordinary status | `Neutral` |
| Completed status | `Positive` |
| Status with criticality `1` | `Negative` |
| Current final status or criticality `3` | `Positive` |

The current node has `focused: true`. The response also contains the ordered
`history` array with action, comments, user, and timestamp.

## Fiori binding

After exposing the method through a RAP function/action or HTTP endpoint, load the
JSON into a `JSONModel` and bind the ProcessFlow aggregations:

```javascript
const oModel = new JSONModel(oProcessFlowData);
this.getView().setModel(oModel, "flow");
```

```xml
<suite:ProcessFlow
  nodes="{flow>/nodes}"
  lanes="{flow>/lanes}">
  <suite:nodes>
    <suite:ProcessFlowNode
      nodeId="{flow>nodeId}"
      laneId="{flow>laneId}"
      title="{flow>title}"
      titleAbbreviation="{flow>titleAbbreviation}"
      children="{flow>children}"
      state="{flow>state}"
      stateText="{flow>stateText}"
      texts="{flow>texts}"
      focused="{flow>focused}" />
  </suite:nodes>
  <suite:lanes>
    <suite:ProcessFlowLaneHeader
      laneId="{flow>laneId}"
      text="{flow>text}"
      position="{flow>position}" />
  </suite:lanes>
</suite:ProcessFlow>
```

The class produces the JSON; publishing it is intentionally left to the service
layer so the same manager can be used from RAP, OData, or a custom HTTP service.
