@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status Framework: Status Action Interface View'
@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #S, dataClass: #MASTER }

define root view entity ZI_CA_StatusAction
  as select from zcastat_action as action
  association [1..1] to ZI_CA_StatusType as _StatusType
    on $projection.StatusType = _StatusType.StatusType
  association [1..1] to ZI_CA_StatusCode as _FromStatus
    on  $projection.StatusType  = _FromStatus.StatusType
    and $projection.FromStatus  = _FromStatus.StatusCode
  association [1..1] to ZI_CA_StatusCode as _ToStatus
    on  $projection.StatusType  = _ToStatus.StatusType
    and $projection.ToStatus    = _ToStatus.StatusCode
{
  key action.status_type           as StatusType,
  key action.from_status           as FromStatus,
  key action.to_status             as ToStatus,
      action.action_code           as ActionCode,
      action.action_name           as ActionName,
      action.requires_comment      as RequiresComment,
      action.authorization_object  as AuthorizationObject,
      action.is_active             as IsActive,
      action.created_by            as CreatedBy,
      action.created_at            as CreatedAt,
      action.changed_by            as ChangedBy,
      action.changed_at            as ChangedAt,

      _StatusType,
      _FromStatus,
      _ToStatus
}
