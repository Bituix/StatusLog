@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status Framework: Status Log Interface View (Read-Only)'
@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #XL, dataClass: #TRANSACTIONAL }

define view entity ZI_CA_StatusLog
  as select from zcastat_log as log
  association [1..1] to ZI_CA_StatusType as _StatusType
    on $projection.StatusType = _StatusType.StatusType
  association [0..1] to ZI_CA_StatusCode as _FromStatus
    on  $projection.StatusType  = _FromStatus.StatusType
    and $projection.FromStatus  = _FromStatus.StatusCode
  association [1..1] to ZI_CA_StatusCode as _ToStatus
    on  $projection.StatusType  = _ToStatus.StatusType
    and $projection.ToStatus    = _ToStatus.StatusCode
{
  key log.log_uuid     as LogUuid,
      log.log_number   as LogNumber,
      log.status_type  as StatusType,
      log.object_key   as ObjectKey,
      log.from_status  as FromStatus,
      log.to_status    as ToStatus,
      log.action_code  as ActionCode,
      log.comments     as Comments,
      log.changed_by   as ChangedBy,
      log.changed_at   as ChangedAt,
      log.changed_date as ChangedDate,
      log.changed_time as ChangedTime,

      _StatusType.CdsViewName    as CdsViewName,
      _StatusType.SemanticObject as SemanticObject,
      _StatusType.SemanticAction as SemanticAction,

      _ToStatus.Criticality      as Criticality,
      _ToStatus.StatusText       as ToStatusText,
      _FromStatus.StatusText     as FromStatusText,

      _StatusType,
      _FromStatus,
      _ToStatus
}
