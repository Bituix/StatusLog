@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status Framework: Status Type Interface View'
@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #S, dataClass: #MASTER }

define root view entity ZI_CA_StatusType
  as select from zcastat_type as type
  composition [0..*] of ZI_CA_StatusCode as _StatusCode
  composition [0..*] of ZI_CA_FlwNode   as _FlwNode
  composition [0..*] of ZI_CA_FlwConn   as _FlwConn
{
  key type.status_type      as StatusType,
      type.status_type_desc as StatusTypeDesc,
      type.business_object_type as BusinessObjectType,
      type.cds_view_name    as CdsViewName,
      type.semantic_object  as SemanticObject,
      type.semantic_action  as SemanticAction,
      type.is_active        as IsActive,
      type.created_by       as CreatedBy,
      type.created_at       as CreatedAt,
      type.changed_by       as ChangedBy,
      type.changed_at       as ChangedAt,

      _StatusCode,
      _FlwNode,
      _FlwConn
}
