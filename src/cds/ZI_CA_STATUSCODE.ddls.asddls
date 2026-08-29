@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status Framework: Status Code Interface View'

define view entity ZI_CA_StatusCode
  as select from zcastat_code as code
  association to parent ZI_CA_StatusType as _StatusType
    on $projection.StatusType = _StatusType.StatusType
  association [1..1] to ZI_CA_FlwLane as _FlwLane
    on  $projection.StatusType = _FlwLane.StatusType
    and $projection.LaneId     = _FlwLane.LaneId
{
  key code.status_type  as StatusType,
  key code.status_code  as StatusCode,
      code.status_text as StatusText,
      code.lane_id      as LaneId,
      code.criticality  as Criticality,
      code.is_initial   as IsInitial,
      code.is_final     as IsFinal,
      code.is_active    as IsActive,
      code.created_by   as CreatedBy,
      code.created_at   as CreatedAt,
      code.changed_by   as ChangedBy,
      code.changed_at   as ChangedAt,

      _StatusType,
      _FlwLane
}
