CLASS zcx_ca_status_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_t100_dyn_msg.
    INTERFACES if_t100_message.

    "-- Exception IDs (maintain texts in SE91 / message class ZCASTAT_MSG) --

    CONSTANTS:
      "& Transition blocked by concurrent lock — another user/job is transitioning
      concurrent_lock          TYPE sotr_conc VALUE 'ZCASTAT_CONCURRENT_LOCK'    ##NO_TEXT,
      "& Target status is ambiguous — multiple active actions qualify, supply iv_to_status
      ambiguous_action         TYPE sotr_conc VALUE 'ZCASTAT_AMBIGUOUS_ACTION'   ##NO_TEXT,
      "& No active action found for this from_status + action_code combination
      no_valid_action          TYPE sotr_conc VALUE 'ZCASTAT_NO_VALID_ACTION'    ##NO_TEXT,
      "& Transition from/to combination not found or inactive in ZCASTAT_ACTION
      invalid_transition       TYPE sotr_conc VALUE 'ZCASTAT_INVALID_TRANSITION' ##NO_TEXT,
      "& BAdI implementation blocked transition via VALIDATE_TRANSITION
      custom_validation_failed TYPE sotr_conc VALUE 'ZCASTAT_CUSTOM_VALIDATION' ##NO_TEXT,
      "& Not authorized for this status type / action
      not_authorized           TYPE sotr_conc VALUE 'ZCASTAT_NOT_AUTHORIZED'     ##NO_TEXT,
      "& Configuration error — no initial status defined for type
      no_initial_status        TYPE sotr_conc VALUE 'ZCASTAT_NO_INITIAL_STATUS'  ##NO_TEXT.

    DATA:
      status_type    TYPE ZCA_DE_stat_type    READ-ONLY,
      object_key     TYPE ZCA_DE_stat_obj_key READ-ONLY,
      from_status    TYPE ZCA_DE_stat_code    READ-ONLY,
      to_status      TYPE ZCA_DE_stat_code    READ-ONLY,
      action_code    TYPE ZCA_DE_ACTION_CODE  READ-ONLY,
      locked_by      TYPE syuname             READ-ONLY,
      detail_message TYPE string              READ-ONLY.

    METHODS constructor
      IMPORTING
        !textid        LIKE if_t100_message=>t100key OPTIONAL
        !previous      LIKE previous                 OPTIONAL
        status_type    TYPE ZCA_DE_stat_type          OPTIONAL
        object_key     TYPE ZCA_DE_stat_obj_key       OPTIONAL
        from_status    TYPE ZCA_DE_stat_code          OPTIONAL
        to_status      TYPE ZCA_DE_stat_code          OPTIONAL
        action_code    TYPE ZCA_DE_ACTION_CODE        OPTIONAL
        locked_by      TYPE syuname                   OPTIONAL
        detail_message TYPE string                    OPTIONAL.

ENDCLASS.

CLASS zcx_ca_status_error IMPLEMENTATION.

  METHOD constructor.
    CALL METHOD super->constructor
      EXPORTING
        textid   = textid
        previous = previous.
    me->status_type    = status_type.
    me->object_key     = object_key.
    me->from_status    = from_status.
    me->to_status      = to_status.
    me->action_code    = action_code.
    me->locked_by      = locked_by.
    me->detail_message = detail_message.
  ENDMETHOD.

ENDCLASS.
