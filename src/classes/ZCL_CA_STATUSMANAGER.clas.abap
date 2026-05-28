CLASS zcl_ca_statusmanager DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  "--------------------------------------------------------------------
  " Status Framework — Central Status Manager
  "
  " Field name conventions (v12):
  "   status_type  (was status_type_id)
  "   object_key   (was business_obj_key)
  "   log_number   (was log_sequence)
  "   from_status  (was from_status_code)
  "   to_status    (was to_status_code)
  "   created_by   (was created_by_user)
  "   changed_by   (was changed_by_user)
  "
  " Prerequisites before activation:
  "   EZCASTAT_LOCK  — SE11 lock object (fields: STATUS_TYPE + OBJECT_KEY)
  "   ZCASTAT_NR     — SNRO number range (interval 01, buffered size 10)
  "   BADI_ZCASTAT_TRANSITION — SE19 (ESPOT_ZCASTAT, filter ZCA_DE_STAT_TYPE)
  "--------------------------------------------------------------------

  PUBLIC SECTION.

    METHODS change_status
      IMPORTING
        iv_status_type TYPE ZCA_DE_stat_type
        iv_object_key  TYPE ZCA_DE_stat_obj_key
        iv_action_code TYPE char20
        iv_to_status   TYPE ZCA_DE_stat_code OPTIONAL
        iv_from_status TYPE ZCA_DE_stat_code OPTIONAL
        iv_remark      TYPE char255          OPTIONAL
      RAISING
        zcx_ca_status_error.

    METHODS get_current_status
      IMPORTING
        iv_status_type TYPE ZCA_DE_stat_type
        iv_object_key  TYPE ZCA_DE_stat_obj_key
      RETURNING
        VALUE(rv_status) TYPE ZCA_DE_stat_code.

    METHODS get_log
      IMPORTING
        iv_status_type TYPE ZCA_DE_stat_type
        iv_object_key  TYPE ZCA_DE_stat_obj_key
      RETURNING
        VALUE(rt_log)  TYPE STANDARD TABLE OF zcastat_log.

    METHODS get_available_actions
      IMPORTING
        iv_status_type TYPE ZCA_DE_stat_type
        iv_from_status TYPE ZCA_DE_stat_code
      RETURNING
        VALUE(rt_actions) TYPE STANDARD TABLE OF zcastat_action.

    METHODS is_transition_allowed
      IMPORTING
        iv_status_type TYPE ZCA_DE_stat_type
        iv_object_key  TYPE ZCA_DE_stat_obj_key
        iv_action_code TYPE char20
        iv_to_status   TYPE ZCA_DE_stat_code OPTIONAL
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

  PRIVATE SECTION.

    METHODS resolve_current_status
      IMPORTING
        iv_status_type TYPE ZCA_DE_stat_type
        iv_object_key  TYPE ZCA_DE_stat_obj_key
      RETURNING
        VALUE(rv_status) TYPE ZCA_DE_stat_code.

    METHODS resolve_target_status
      IMPORTING
        iv_status_type TYPE ZCA_DE_stat_type
        iv_from_status TYPE ZCA_DE_stat_code
        iv_action_code TYPE char20
      RETURNING
        VALUE(rv_status) TYPE ZCA_DE_stat_code
      RAISING
        zcx_ca_status_error.

    METHODS validate_transition_config
      IMPORTING
        iv_status_type TYPE ZCA_DE_stat_type
        iv_from_status TYPE ZCA_DE_stat_code
        iv_to_status   TYPE ZCA_DE_stat_code
      RAISING
        zcx_ca_status_error.

    METHODS write_log_entry
      IMPORTING
        iv_log_uuid    TYPE sysuuid_16
        iv_status_type TYPE ZCA_DE_stat_type
        iv_object_key  TYPE ZCA_DE_stat_obj_key
        iv_action_code TYPE char20
        iv_from_status TYPE ZCA_DE_stat_code
        iv_to_status   TYPE ZCA_DE_stat_code
        iv_remark      TYPE char255 OPTIONAL.

    METHODS get_next_number
      RETURNING
        VALUE(rv_number) TYPE int8.

ENDCLASS.


CLASS zcl_ca_statusmanager IMPLEMENTATION.

  METHOD change_status.
    "--------------------------------------------------------------------
    " ① ENQUEUE LOCK
    "--------------------------------------------------------------------
    CALL FUNCTION 'ENQUEUE_EZCASTAT_LOCK'
      EXPORTING
        mode_zcastat_log = 'E'
        mandt            = sy-mandt
        status_type      = iv_status_type
        object_key       = iv_object_key
        _scope           = '2'
        _wait            = abap_false
      EXCEPTIONS
        foreign_lock     = 1
        system_failure   = 2
        OTHERS           = 3.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_status_error
        EXPORTING
          textid         = zcx_ca_status_error=>concurrent_lock
          status_type    = iv_status_type
          object_key     = iv_object_key
          locked_by      = sy-msgv1.
    ENDIF.

    "--------------------------------------------------------------------
    " ② RESOLVE CURRENT STATUS
    "--------------------------------------------------------------------
    DATA(lv_from) = COND ZCA_DE_stat_code(
      WHEN iv_from_status IS NOT INITIAL
      THEN iv_from_status
      ELSE me->resolve_current_status(
             iv_status_type = iv_status_type
             iv_object_key  = iv_object_key )
    ).

    "--------------------------------------------------------------------
    " ③ RESOLVE TARGET STATUS
    "--------------------------------------------------------------------
    DATA(lv_to) = COND ZCA_DE_stat_code(
      WHEN iv_to_status IS NOT INITIAL
      THEN iv_to_status
      ELSE me->resolve_target_status(
             iv_status_type = iv_status_type
             iv_from_status = lv_from
             iv_action_code = iv_action_code )
    ).

    "--------------------------------------------------------------------
    " ④ VALIDATE CONFIGURATION
    "--------------------------------------------------------------------
    me->validate_transition_config(
      iv_status_type = iv_status_type
      iv_from_status = lv_from
      iv_to_status   = lv_to ).

    "--------------------------------------------------------------------
    " ⑤ BAdI VALIDATE_TRANSITION (blocking)
    "--------------------------------------------------------------------
    DATA lo_badi TYPE REF TO badi_zcastat_transition.

    GET BADI lo_badi
      FILTERS
        status_type = iv_status_type.

    CALL BADI lo_badi->validate_transition
      EXPORTING
        iv_status_type = iv_status_type
        iv_object_key  = iv_object_key
        iv_from_status = lv_from
        iv_to_status   = lv_to.

    "--------------------------------------------------------------------
    " ⑥ WRITE LOG ENTRY
    "--------------------------------------------------------------------
    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    me->write_log_entry(
      iv_log_uuid    = lv_uuid
      iv_status_type = iv_status_type
      iv_object_key  = iv_object_key
      iv_action_code = iv_action_code
      iv_from_status = lv_from
      iv_to_status   = lv_to
      iv_remark      = iv_remark ).

    "--------------------------------------------------------------------
    " ⑦ BAdI AFTER_TRANSITION (non-blocking)
    "--------------------------------------------------------------------
    TRY.
        CALL BADI lo_badi->after_transition
          EXPORTING
            iv_status_type = iv_status_type
            iv_object_key  = iv_object_key
            iv_from_status = lv_from
            iv_to_status   = lv_to
            iv_log_uuid    = lv_uuid.
      CATCH cx_root INTO DATA(lx_after).
        cl_abap_message_helper=>handle_exception( exception = lx_after ).
    ENDTRY.

    "--------------------------------------------------------------------
    " ⑧ DEQUEUE LOCK
    "--------------------------------------------------------------------
    CALL FUNCTION 'DEQUEUE_EZCASTAT_LOCK'
      EXPORTING
        mode_zcastat_log = 'E'
        mandt            = sy-mandt
        status_type      = iv_status_type
        object_key       = iv_object_key.

  ENDMETHOD.


  METHOD get_current_status.
    rv_status = me->resolve_current_status(
      iv_status_type = iv_status_type
      iv_object_key  = iv_object_key ).
  ENDMETHOD.


  METHOD get_log.
    SELECT *
      FROM zcastat_log
      WHERE status_type = @iv_status_type
        AND object_key  = @iv_object_key
      ORDER BY log_number ASCENDING
               changed_at ASCENDING
      INTO TABLE @rt_log.
  ENDMETHOD.


  METHOD get_available_actions.
    SELECT *
      FROM zcastat_action
      WHERE status_type  = @iv_status_type
        AND from_status  = @iv_from_status
        AND is_active    = @abap_true
      INTO TABLE @rt_actions.
  ENDMETHOD.


  METHOD is_transition_allowed.
    rv_allowed = abap_false.
    TRY.
        DATA(lv_current) = me->get_current_status(
          iv_status_type = iv_status_type
          iv_object_key  = iv_object_key ).

        DATA(lv_target) = COND ZCA_DE_stat_code(
          WHEN iv_to_status IS NOT INITIAL
          THEN iv_to_status
          ELSE me->resolve_target_status(
                 iv_status_type = iv_status_type
                 iv_from_status = lv_current
                 iv_action_code = iv_action_code )
        ).

        me->validate_transition_config(
          iv_status_type = iv_status_type
          iv_from_status = lv_current
          iv_to_status   = lv_target ).

        rv_allowed = abap_true.
      CATCH zcx_ca_status_error.
        rv_allowed = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD resolve_current_status.
    SELECT SINGLE to_status
      FROM zcastat_log
      WHERE status_type = @iv_status_type
        AND object_key  = @iv_object_key
      ORDER BY log_number DESCENDING
               changed_at DESCENDING
      INTO @rv_status.
  ENDMETHOD.


  METHOD resolve_target_status.
    SELECT to_status
      FROM zcastat_action
      WHERE status_type  = @iv_status_type
        AND from_status  = @iv_from_status
        AND action_code  = @iv_action_code
        AND is_active    = @abap_true
      INTO TABLE @DATA(lt_targets).

    CASE lines( lt_targets ).
      WHEN 0.
        RAISE EXCEPTION TYPE zcx_ca_status_error
          EXPORTING
            textid       = zcx_ca_status_error=>no_valid_action
            status_type  = iv_status_type
            action_code  = iv_action_code.
      WHEN 1.
        rv_status = lt_targets[ 1 ]-to_status.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_ca_status_error
          EXPORTING
            textid       = zcx_ca_status_error=>ambiguous_action
            status_type  = iv_status_type
            action_code  = iv_action_code.
    ENDCASE.
  ENDMETHOD.


  METHOD validate_transition_config.
    SELECT SINGLE @abap_true
      FROM zcastat_action
      WHERE status_type = @iv_status_type
        AND from_status = @iv_from_status
        AND to_status   = @iv_to_status
        AND is_active   = @abap_true
      INTO @DATA(lv_exists).

    IF lv_exists IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_status_error
        EXPORTING
          textid       = zcx_ca_status_error=>invalid_transition
          status_type  = iv_status_type
          from_status  = iv_from_status
          to_status    = iv_to_status.
    ENDIF.
  ENDMETHOD.


  METHOD write_log_entry.
    DATA(lv_num) = me->get_next_number( ).

    INSERT zcastat_log FROM VALUE #(
      mandt        = sy-mandt
      log_uuid     = iv_log_uuid
      log_number   = lv_num
      status_type  = iv_status_type
      object_key   = iv_object_key
      from_status  = iv_from_status
      to_status    = iv_to_status
      action_code  = iv_action_code
      remark       = iv_remark
      changed_by   = sy-uname
      changed_at   = cl_abap_context_info=>get_system_date_time( )
      changed_date = sy-datum
      changed_time = sy-uzeit
    ).
  ENDMETHOD.


  METHOD get_next_number.
    DATA lv_number TYPE num10.
    TRY.
        CALL FUNCTION 'NUMBER_GET_NEXT'
          EXPORTING
            nr_range_nr             = '01'
            object                  = 'ZCASTAT_NR'
          IMPORTING
            number                  = lv_number
          EXCEPTIONS
            number_range_not_intern = 1
            object_not_found        = 2
            quantity_is_0           = 3
            quantity_is_not_1       = 4
            interval_not_found      = 5
            period_not_found        = 6
            blocks_not_found        = 7
            no_object_reference     = 8
            OTHERS                  = 9.
        rv_number = COND #( WHEN sy-subrc = 0 THEN lv_number ELSE 0 ).
      CATCH cx_root.
        rv_number = 0.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
