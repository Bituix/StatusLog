@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status Framework: ProcessFlow Node Interface View'

define view entity ZI_CA_FlwNode
  as select from zcastat_flwnode as node
  association to parent ZI_CA_StatusType as _StatusType
    on $projection.StatusType = _StatusType.StatusType
  association [1..1] to ZI_CA_StatusCode as _StatusCode
    on  $projection.StatusType = _StatusCode.StatusType
    and $projection.StatusCode = _StatusCode.StatusCode
{
  key node.status_type     as StatusType,
  key node.node_id         as NodeId,
      node.status_code     as StatusCode,
      node.node_text       as NodeText,
      node.column_position as ColumnPosition,
      node.lane_id         as LaneId,
      node.is_active       as IsActive,
      node.created_by      as CreatedBy,
      node.created_at      as CreatedAt,
      node.changed_by      as ChangedBy,
      node.changed_at      as ChangedAt,

      _StatusType,
      _StatusCode
}
