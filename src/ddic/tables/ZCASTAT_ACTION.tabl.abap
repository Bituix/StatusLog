@EndUserText.label : 'Status Framework: Status Transition Action'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcastat_action {
  key client            : abap.client not null;
  key status_type      : zca_de_stat_type not null;
  key from_status      : zca_de_stat_code not null;
  key to_status        : zca_de_stat_code not null;
  action_code          : zca_de_action_code not null;
  action_name          : abap.char(60);
  requires_comment     : abap_boolean;
  authorization_object : abap.char(10);
  is_active            : abap_boolean;
  created_by           : syuname;
  created_at           : utclong;
  changed_by           : syuname;
  changed_at           : utclong;
}
