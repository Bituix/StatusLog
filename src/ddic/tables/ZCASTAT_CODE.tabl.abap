@EndUserText.label : 'Status Framework: Status Code'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcastat_code {
  key client       : abap.client not null;
  key status_type : zca_de_stat_type not null;
  key status_code : zca_de_stat_code not null;
  status_text     : abap.char(60);
  criticality     : abap.int1;
  is_initial      : abap_boolean;
  is_final        : abap_boolean;
  is_active       : abap_boolean;
  created_by      : syuname;
  created_at      : utclong;
  changed_by      : syuname;
  changed_at      : utclong;
}
