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
is shown as the current node and reachable future occurrences are returned as
`Planned`.
The root `configurationMode` is `DYNAMIC` for the simple model and `OVERRIDE`
when active explicit flow nodes select the complex model.

## Simple configuration

The default mode needs only reusable lanes, statuses, and actions:

1. Define lane labels and positions in `ZCASTAT_LANE`.
2. Define active statuses in `ZCASTAT_CODE`, assign each status its preferred
   `LANE_ID`, and mark exactly one status as initial.
3. Define transitions in `ZCASTAT_ACTION`.
4. Leave `ZCASTAT_FLWNODE` empty or inactive for this status type.

The manager creates a unique node occurrence for every status visit and derives
future arrows from the active actions. If a transition points to a status whose
preferred lane is left of the current lane, the new occurrence stays in the
current lane and is rendered below it. Effective lane positions therefore never
decrease.

Example lanes:

| Lane ID | Text | Position |
|---|---|---:|
| `REQUEST` | Request | 1 |
| `APPROVAL` | Approval | 2 |
| `COMPLETE` | Complete | 3 |

Example preferred status lanes:

| Status | Preferred lane |
|---|---|
| `NEW` | `REQUEST` |
| `REVISED` | `REQUEST` |
| `PENDING` | `APPROVAL` |
| `REJECTED` | `APPROVAL` |
| `APPROVED` | `COMPLETE` |

For history `NEW → PENDING → REJECTED → REVISED → PENDING`, the `REVISED`
and second `PENDING` occurrences stay in `APPROVAL`; the graph never moves left.

Future expansion processes each action once, so cyclic status configurations are
shown without producing an infinite JSON graph. Real repeated visits are always
added from `ZCASTAT_LOG`.

## Complex visual override

If any active `ZCASTAT_FLWNODE` exists for a status type, the manager switches
that entire status type to configured override mode. In this mode:

- `NODE_ID` is the explicit visual occurrence.
- `STATUS_CODE` maps the occurrence to a business status.
- `LANE_ID` and `COLUMN_POSITION` control placement.
- `ZCASTAT_FLWCONN` supplies the explicit forward-only edges.

Use this only for layouts that cannot be derived safely from lanes and actions.

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

## Re-entry in complex mode

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
