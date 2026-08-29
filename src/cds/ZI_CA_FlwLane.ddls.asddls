@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status Framework: ProcessFlow Lane Interface View'

define view entity ZI_CA_FlwLane
  as select from zcastat_lane as lane
  association to parent ZI_CA_StatusType as _StatusType
    on $projection.StatusType = _StatusType.StatusType
{
  key lane.status_type  as StatusType,
  key lane.lane_id      as LaneId,
      lane.lane_text    as LaneText,
      lane.lane_position as LanePosition,
      lane.icon_src     as IconSrc,
      lane.is_active    as IsActive,
      lane.created_by   as CreatedBy,
      lane.created_at   as CreatedAt,
      lane.changed_by   as ChangedBy,
      lane.changed_at   as ChangedAt,

      _StatusType
}
