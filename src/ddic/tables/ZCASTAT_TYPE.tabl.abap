@EndUserText.label : 'Status Framework: Status Type Master'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcastat_type {
  key client              : abap.client not null;
  key status_type        : zca_de_stat_type not null;
  status_type_desc       : zca_de_stat_type_desc;
  business_object_type   : abap.char(30);
  cds_view_name          : abap.char(40);
  semantic_object        : abap.char(40);
  semantic_action        : abap.char(40);
  is_active              : abap_boolean;
  created_by             : syuname;
  created_at             : utclong;
  changed_by             : syuname;
  changed_at             : utclong;
}
