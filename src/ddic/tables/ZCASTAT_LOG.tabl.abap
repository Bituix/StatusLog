@EndUserText.label : 'Status Framework: Status Transition Log (Append-Only)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #LIMITED
define table zcastat_log {
  key client      : abap.client not null;
  key log_uuid   : abap.raw(16) not null;
  log_number     : abap.int8;
  status_type    : zca_de_stat_type not null;
  object_key     : zca_de_stat_obj_key not null;
  from_status    : zca_de_stat_code;
  to_status      : zca_de_stat_code not null;
  action_code    : zca_de_action_code;
  comments       : abap.char(255);
  changed_by     : syuname;
  changed_at     : utclong;
  changed_date   : sydatum;
  changed_time   : syuzeit;
}
