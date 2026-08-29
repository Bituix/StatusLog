@EndUserText.label : 'Status Framework: ProcessFlow Lane'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcastat_lane {
  key client       : abap.client not null;
  key status_type : zca_de_stat_type not null;
  key lane_id     : abap.char(10) not null;
  lane_text       : abap.char(60);
  lane_position   : abap.int2;
  icon_src        : abap.char(255);
  is_active       : abap_boolean;
  created_by      : syuname;
  created_at      : utclong;
  changed_by      : syuname;
  changed_at      : utclong;
}
