@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status Framework: ProcessFlow Connection Interface View'

define view entity ZI_CA_FlwConn
  as select from zcastat_flwconn as conn
  association to parent ZI_CA_StatusType as _StatusType
    on $projection.StatusType = _StatusType.StatusType
  association [1..1] to ZI_CA_FlwNode as _FromNode
    on  $projection.StatusType = _FromNode.StatusType
    and $projection.FromNodeId = _FromNode.NodeId
  association [1..1] to ZI_CA_FlwNode as _ToNode
    on  $projection.StatusType = _ToNode.StatusType
    and $projection.ToNodeId   = _ToNode.NodeId
{
  key conn.status_type  as StatusType,
  key conn.from_node_id as FromNodeId,
  key conn.to_node_id   as ToNodeId,
      conn.is_active    as IsActive,
      conn.created_by   as CreatedBy,
      conn.created_at   as CreatedAt,
      conn.changed_by   as ChangedBy,
      conn.changed_at   as ChangedAt,

      _StatusType,
      _FromNode,
      _ToNode
}
