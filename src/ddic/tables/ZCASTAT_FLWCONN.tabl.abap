@EndUserText.label : 'Status Framework: ProcessFlow Connection (Edge)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcastat_flwconn {
  key client        : abap.client not null;
  key status_type  : zca_de_stat_type not null;
  key from_node_id : abap.char(10) not null;
  key to_node_id   : abap.char(10) not null;
  is_active        : abap_boolean;
  created_by       : syuname;
  created_at       : utclong;
  changed_by       : syuname;
  changed_at       : utclong;
}
