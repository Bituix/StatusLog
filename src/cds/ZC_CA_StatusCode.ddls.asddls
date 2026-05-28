@EndUserText.label: 'Status Code — Value Help'
@Search.searchable: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory:   #S,
  dataClass:      #MASTER
}

define view entity ZC_CA_StatusCode
  as select from ZI_CA_StatusCode
{
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
  key StatusType,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
  key StatusCode,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      StatusText,

      @UI.hidden: true
      Criticality,

      IsInitial,
      IsFinal,
      IsActive
}

/*
  Usage in consuming CDS views:
  ─────────────────────────────
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZC_CA_StatusCode', element: 'StatusCode' },
    additionalBinding: [{ localElement: 'StatusType', element: 'StatusType' }]
  }]
  status_code : zca_de_stat_code;
*/
