@EndUserText.label : 'Status Framework: ProcessFlow Node (Visual)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcastat_flwnode {
  key client       : abap.client not null;
  key status_type : zca_de_stat_type not null;
  key node_id     : abap.char(10) not null;
  status_code     : zca_de_stat_code;
  node_text       : abap.char(60);
  column_position : abap.int2;
  lane_id         : abap.char(10);
  is_active       : abap_boolean;
  created_by      : syuname;
  created_at      : utclong;
  changed_by      : syuname;
  changed_at      : utclong;
}
