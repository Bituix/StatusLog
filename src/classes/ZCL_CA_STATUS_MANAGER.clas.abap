CLASS ZCL_CA_STATUS_MANAGER DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  "--------------------------------------------------------------------
  " Prerequisites before activation:
  "   EZCASTAT_LOCK  — SE11 lock object (fields: STATUS_TYPE + OBJECT_KEY)
  "   ZCASTAT_NR     — SNRO number range (interval 01, buffered size 10)
  "   BADI_ZCASTAT_TRANSITION — SE19 (ESPOT_ZCASTAT, filter ZCA_DE_STAT_TYPE)
  "--------------------------------------------------------------------

  PUBLIC SECTION.

    TYPES ty_string_table TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_process_flow_lane,
        lane_id  TYPE string,
        icon_src TYPE string,
        text     TYPE string,
        position TYPE i,
      END OF ty_process_flow_lane,
      ty_process_flow_lanes TYPE STANDARD TABLE OF ty_process_flow_lane WITH EMPTY KEY,

      BEGIN OF ty_process_flow_node,
        node_id            TYPE string,
        lane_id            TYPE string,
        title              TYPE string,
        title_abbreviation TYPE string,
        children           TYPE ty_string_table,
        state              TYPE string,
        state_text         TYPE string,
        texts              TYPE ty_string_table,
        highlighted        TYPE abap_bool,
        focused            TYPE abap_bool,
        status_code        TYPE string,
        visit_number       TYPE i,
        log_number         TYPE int8,
      END OF ty_process_flow_node,
      ty_process_flow_nodes TYPE STANDARD TABLE OF ty_process_flow_node WITH EMPTY KEY,

      BEGIN OF ty_process_flow_connection,
        from_node_id TYPE string,
        to_node_id   TYPE string,
      END OF ty_process_flow_connection,
      ty_process_flow_connections TYPE STANDARD TABLE OF ty_process_flow_connection WITH EMPTY KEY,

      BEGIN OF ty_process_flow_history,
        log_number  TYPE int8,
        from_status TYPE string,
        to_status   TYPE string,
        action_code TYPE string,
        comments    TYPE string,
        changed_by  TYPE string,
        changed_at  TYPE string,
      END OF ty_process_flow_history,
      ty_process_flow_histories TYPE STANDARD TABLE OF ty_process_flow_history WITH EMPTY KEY,

      BEGIN OF ty_process_flow,
        status_type    TYPE string,
        object_key     TYPE string,
        current_status TYPE string,
        lanes          TYPE ty_process_flow_lanes,
        nodes          TYPE ty_process_flow_nodes,
        connections    TYPE ty_process_flow_connections,
        history        TYPE ty_process_flow_histories,
      END OF ty_process_flow.

    METHODS change_status
      IMPORTING
        iv_status_type TYPE ZCA_DE_stat_type
        iv_object_key  TYPE ZCA_DE_stat_obj_key
        iv_action_code TYPE ZCA_DE_ACTION_CODE OPTIONAL
        iv_to_status   TYPE ZCA_DE_stat_code   OPTIONAL
        iv_from_status TYPE ZCA_DE_stat_code   OPTIONAL
        iv_comments    TYPE string            OPTIONAL
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

    METHODS get_process_flow_json
      IMPORTING
        iv_status_type TYPE ZCA_DE_stat_type
        iv_object_key  TYPE ZCA_DE_stat_obj_key
      RETURNING
        VALUE(rv_json) TYPE string.

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
        iv_action_code TYPE ZCA_DE_ACTION_CODE
        iv_to_status   TYPE ZCA_DE_stat_code OPTIONAL
      RETURNING
        VALUE(rv_allowed) TYPE abap_boolean.

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
        iv_action_code TYPE ZCA_DE_ACTION_CODE
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

    METHODS validate_comment_required
      IMPORTING
        iv_status_type TYPE ZCA_DE_stat_type
        iv_from_status TYPE ZCA_DE_stat_code
        iv_to_status   TYPE ZCA_DE_stat_code
        iv_comments    TYPE string OPTIONAL
      RAISING
        zcx_ca_status_error.

    METHODS write_log_entry
      IMPORTING
        iv_log_uuid    TYPE sysuuid_x16
        iv_status_type TYPE ZCA_DE_stat_type
        iv_object_key  TYPE ZCA_DE_stat_obj_key
        iv_action_code TYPE ZCA_DE_ACTION_CODE
        iv_from_status TYPE ZCA_DE_stat_code
        iv_to_status   TYPE ZCA_DE_stat_code
        iv_comments    TYPE string OPTIONAL
      RAISING
        zcx_ca_status_error.

    METHODS get_next_number
      RETURNING
        VALUE(rv_number) TYPE int8
      RAISING
        zcx_ca_status_error.

ENDCLASS.


CLASS ZCL_CA_STATUS_MANAGER IMPLEMENTATION.

  METHOD change_status.
    " ① lock
    TEST-SEAM lock_enqueue.
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
            textid      = zcx_ca_status_error=>concurrent_lock
            status_type = iv_status_type
            object_key  = iv_object_key
            locked_by   = sy-msgv1.
      ENDIF.
    END-TEST-SEAM.

    " ② resolve current status
    DATA(lv_from) = COND ZCA_DE_stat_code(
      WHEN iv_from_status IS NOT INITIAL
      THEN iv_from_status
      ELSE resolve_current_status(
             iv_status_type = iv_status_type
             iv_object_key  = iv_object_key )
    ).

    " ③ resolve target status
    DATA(lv_to) = COND ZCA_DE_stat_code(
      WHEN iv_to_status IS NOT INITIAL
      THEN iv_to_status
      ELSE resolve_target_status(
             iv_status_type = iv_status_type
             iv_from_status = lv_from
             iv_action_code = iv_action_code )
    ).

    " ④ validate configuration
    validate_transition_config(
      iv_status_type = iv_status_type
      iv_from_status = lv_from
      iv_to_status   = lv_to ).

    validate_comment_required(
      iv_status_type = iv_status_type
      iv_from_status = lv_from
      iv_to_status   = lv_to
      iv_comments    = iv_comments ).

    " ⑤ BAdI: blocking pre-check
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

    " ⑥ write log
    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    write_log_entry(
      iv_log_uuid    = lv_uuid
      iv_status_type = iv_status_type
      iv_object_key  = iv_object_key
      iv_action_code = iv_action_code
      iv_from_status = lv_from
      iv_to_status   = lv_to
      iv_comments    = iv_comments ).

    " ⑦ BAdI: non-blocking post-hook
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

    " ⑧ unlock
    TEST-SEAM lock_dequeue.
      CALL FUNCTION 'DEQUEUE_EZCASTAT_LOCK'
        EXPORTING
          mode_zcastat_log = 'E'
          mandt            = sy-mandt
          status_type      = iv_status_type
          object_key       = iv_object_key.
    END-TEST-SEAM.

  ENDMETHOD.


  METHOD get_current_status.
    rv_status = resolve_current_status(
      iv_status_type = iv_status_type
      iv_object_key  = iv_object_key ).
  ENDMETHOD.


  METHOD get_log.
    SELECT LogUuid     AS log_uuid,
           LogNumber   AS log_number,
           StatusType  AS status_type,
           ObjectKey   AS object_key,
           FromStatus  AS from_status,
           ToStatus    AS to_status,
           ActionCode  AS action_code,
           Comments    AS comments,
           ChangedBy   AS changed_by,
           ChangedAt   AS changed_at,
           ChangedDate AS changed_date,
           ChangedTime AS changed_time
      FROM ZI_CA_StatusLog
      WHERE StatusType = @iv_status_type
        AND ObjectKey  = @iv_object_key
      ORDER BY LogNumber ASCENDING,
               ChangedAt ASCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt_log.
  ENDMETHOD.


  METHOD get_process_flow_json.
    TYPES:
      BEGIN OF ty_visit,
        status_code  TYPE ZCA_DE_stat_code,
        log_number   TYPE int8,
        changed_by   TYPE syuname,
        changed_at   TYPE utclong,
        visit_number TYPE i,
      END OF ty_visit,
      ty_visits TYPE STANDARD TABLE OF ty_visit WITH EMPTY KEY,

      BEGIN OF ty_visit_count,
        status_code TYPE ZCA_DE_stat_code,
        count       TYPE i,
      END OF ty_visit_count,
      ty_visit_counts TYPE HASHED TABLE OF ty_visit_count
        WITH UNIQUE KEY status_code.

    DATA ls_flow TYPE ty_process_flow.
    DATA lt_nodes TYPE STANDARD TABLE OF zcastat_flwnode WITH EMPTY KEY.
    DATA lt_connections TYPE STANDARD TABLE OF zcastat_flwconn WITH EMPTY KEY.
    DATA lt_status_codes TYPE STANDARD TABLE OF zcastat_code WITH EMPTY KEY.
    DATA lt_visits TYPE ty_visits.
    DATA lt_visit_counts TYPE ty_visit_counts.

    ls_flow-status_type = iv_status_type.
    ls_flow-object_key = iv_object_key.

    "The complete active configuration is returned, including future nodes.
    SELECT StatusType     AS status_type,
           NodeId         AS node_id,
           StatusCode     AS status_code,
           NodeText       AS node_text,
           ColumnPosition AS column_position,
           LaneId         AS lane_id,
           IsActive       AS is_active
      FROM ZI_CA_FlwNode
      WHERE StatusType = @iv_status_type
        AND IsActive   = @abap_true
      ORDER BY ColumnPosition ASCENDING,
               NodeId ASCENDING
      INTO CORRESPONDING FIELDS OF TABLE @lt_nodes.

    SELECT StatusType AS status_type,
           FromNodeId AS from_node_id,
           ToNodeId   AS to_node_id,
           IsActive   AS is_active
      FROM ZI_CA_FlwConn
      WHERE StatusType = @iv_status_type
        AND IsActive   = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @lt_connections.

    SELECT StatusType  AS status_type,
           StatusCode  AS status_code,
           StatusText  AS status_text,
           Criticality AS criticality,
           IsInitial   AS is_initial,
           IsFinal     AS is_final,
           IsActive    AS is_active
      FROM ZI_CA_StatusCode
      WHERE StatusType = @iv_status_type
        AND IsActive   = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @lt_status_codes.

    "A lane is inferred from the node configuration. All nodes sharing a
    "LANE_ID must use the same COLUMN_POSITION.
    LOOP AT lt_nodes INTO DATA(ls_config_node).
      DATA(lv_lane_id) = COND string(
        WHEN ls_config_node-lane_id IS NOT INITIAL
        THEN ls_config_node-lane_id
        ELSE |COL_{ ls_config_node-column_position }| ).

      IF NOT line_exists( ls_flow-lanes[ lane_id = lv_lane_id ] ).
        APPEND VALUE #(
          lane_id  = lv_lane_id
          text     = lv_lane_id
          position = ls_config_node-column_position
        ) TO ls_flow-lanes.
      ENDIF.

      DATA(lt_children) = VALUE ty_string_table( ).
      LOOP AT lt_connections INTO DATA(ls_connection)
        WHERE from_node_id = ls_config_node-node_id.
        IF line_exists( lt_nodes[ node_id = ls_connection-to_node_id ] ).
          APPEND CONV string( ls_connection-to_node_id ) TO lt_children.
          APPEND VALUE #(
            from_node_id = ls_connection-from_node_id
            to_node_id   = ls_connection-to_node_id
          ) TO ls_flow-connections.
        ENDIF.
      ENDLOOP.

      APPEND VALUE #(
        node_id            = ls_config_node-node_id
        lane_id            = lv_lane_id
        title              = ls_config_node-node_text
        title_abbreviation = ls_config_node-status_code
        children           = lt_children
        state              = 'Planned'
        state_text         = 'Planned'
        texts              = VALUE #( ( CONV string( ls_config_node-status_code ) ) )
        highlighted        = abap_false
        focused            = abap_false
        status_code        = ls_config_node-status_code
      ) TO ls_flow-nodes.
    ENDLOOP.

    SORT ls_flow-lanes BY position lane_id.

    DATA(lt_log) = get_log(
      iv_status_type = iv_status_type
      iv_object_key  = iv_object_key ).

    LOOP AT lt_log INTO DATA(ls_log).
      APPEND VALUE #(
        log_number  = ls_log-log_number
        from_status = ls_log-from_status
        to_status   = ls_log-to_status
        action_code = ls_log-action_code
        comments    = ls_log-comments
        changed_by  = ls_log-changed_by
        changed_at  = |{ ls_log-changed_at }|
      ) TO ls_flow-history.
    ENDLOOP.

    "The first FROM_STATUS is also a visited node. Every TO_STATUS is a new
    "visit, which supports re-entry when a status has several visual nodes.
    IF lt_log IS NOT INITIAL.
      DATA(ls_first_log) = lt_log[ 1 ].
      IF ls_first_log-from_status IS NOT INITIAL.
        APPEND VALUE #(
          status_code = ls_first_log-from_status
        ) TO lt_visits.
      ENDIF.

      LOOP AT lt_log INTO ls_log.
        APPEND VALUE #(
          status_code = ls_log-to_status
          log_number  = ls_log-log_number
          changed_by  = ls_log-changed_by
          changed_at  = ls_log-changed_at
        ) TO lt_visits.
      ENDLOOP.
    ELSE.
      "Before the first transition, show the configured initial status as
      "current and keep the remaining configured graph visible as planned.
      READ TABLE lt_status_codes INTO DATA(ls_initial_code)
        WITH KEY is_initial = abap_true.
      IF sy-subrc = 0.
        APPEND VALUE #( status_code = ls_initial_code-status_code ) TO lt_visits.
      ENDIF.
    ENDIF.

    LOOP AT lt_visits ASSIGNING FIELD-SYMBOL(<ls_visit>).
      ASSIGN lt_visit_counts[ status_code = <ls_visit>-status_code ]
        TO FIELD-SYMBOL(<ls_count>).
      IF sy-subrc <> 0.
        INSERT VALUE #(
          status_code = <ls_visit>-status_code
          count       = 0
        ) INTO TABLE lt_visit_counts ASSIGNING <ls_count>.
      ENDIF.
      <ls_count>-count = <ls_count>-count + 1.
      <ls_visit>-visit_number = <ls_count>-count.
    ENDLOOP.

    DATA(lv_current_visit_index) = lines( lt_visits ).
    LOOP AT lt_visits INTO DATA(ls_visit).
      DATA(lv_visit_index) = sy-tabix.
      DATA(lv_matching_node_count) = 0.
      DATA(lv_selected_node_index) = 0.
      DATA(lv_last_matching_index) = 0.

      LOOP AT ls_flow-nodes ASSIGNING FIELD-SYMBOL(<ls_candidate_node>).
        IF <ls_candidate_node>-status_code = ls_visit-status_code.
          lv_matching_node_count = lv_matching_node_count + 1.
          lv_last_matching_index = sy-tabix.
          IF lv_matching_node_count = ls_visit-visit_number.
            lv_selected_node_index = sy-tabix.
            EXIT.
          ENDIF.
        ENDIF.
      ENDLOOP.

      "A single visual node can still represent repeated visits. Configure
      "multiple nodes only when each occurrence must appear separately.
      IF lv_selected_node_index = 0.
        lv_selected_node_index = lv_last_matching_index.
      ENDIF.
      IF lv_selected_node_index = 0.
        CONTINUE.
      ENDIF.

      ASSIGN ls_flow-nodes[ lv_selected_node_index ]
        TO FIELD-SYMBOL(<ls_selected_node>).
      READ TABLE lt_status_codes INTO DATA(ls_status_code)
        WITH KEY status_code = ls_visit-status_code.

      DATA(lv_is_current) = xsdbool( lv_visit_index = lv_current_visit_index ).
      IF lv_is_current = abap_true.
        ls_flow-current_status = ls_visit-status_code.
        <ls_selected_node>-focused = abap_true.
        <ls_selected_node>-state_text = 'Current'.
        <ls_selected_node>-state = COND #(
          WHEN ls_status_code-criticality = 1 THEN 'Negative'
          WHEN ls_status_code-criticality = 3
            OR ls_status_code-is_final = abap_true THEN 'Positive'
          ELSE 'Neutral' ).
      ELSE.
        <ls_selected_node>-state_text = 'Completed'.
        <ls_selected_node>-state = COND #(
          WHEN ls_status_code-criticality = 1 THEN 'Negative'
          ELSE 'Positive' ).
      ENDIF.

      <ls_selected_node>-visit_number = ls_visit-visit_number.
      <ls_selected_node>-log_number = ls_visit-log_number.
      IF ls_visit-changed_by IS NOT INITIAL.
        <ls_selected_node>-texts = VALUE #(
          ( CONV string( ls_visit-status_code ) )
          ( |Changed by { ls_visit-changed_by }| )
        ).
      ENDIF.
    ENDLOOP.

    rv_json = /ui2/cl_json=>serialize(
      data        = ls_flow
      compress    = abap_true
      pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
  ENDMETHOD.


  METHOD get_available_actions.
    SELECT StatusType,
           FromStatus,
           ToStatus,
           ActionCode,
           ActionName,
           RequiresComment,
           AuthorizationObject,
           IsActive,
           CreatedBy,
           CreatedAt,
           ChangedBy,
           ChangedAt
      FROM ZI_CA_StatusAction
      WHERE StatusType = @iv_status_type
        AND FromStatus = @iv_from_status
        AND IsActive   = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @rt_actions.
  ENDMETHOD.


  METHOD is_transition_allowed.
    rv_allowed = abap_false.
    TRY.
        DATA(lv_current) = get_current_status(
          iv_status_type = iv_status_type
          iv_object_key  = iv_object_key ).

        DATA(lv_target) = COND ZCA_DE_stat_code(
          WHEN iv_to_status IS NOT INITIAL
          THEN iv_to_status
          ELSE resolve_target_status(
                 iv_status_type = iv_status_type
                 iv_from_status = lv_current
                 iv_action_code = iv_action_code )
        ).

        validate_transition_config(
          iv_status_type = iv_status_type
          iv_from_status = lv_current
          iv_to_status   = lv_target ).

        rv_allowed = abap_true.
      CATCH zcx_ca_status_error.
        rv_allowed = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD resolve_current_status.
    SELECT ToStatus
      FROM ZI_CA_StatusLog
      WHERE StatusType = @iv_status_type
        AND ObjectKey  = @iv_object_key
      ORDER BY LogNumber DESCENDING,
               ChangedAt DESCENDING
      INTO @rv_status
      UP TO 1 ROWS.
  ENDMETHOD.


  METHOD resolve_target_status.
    DATA lt_targets TYPE TABLE OF ZCA_DE_stat_code WITH EMPTY KEY.

    IF iv_action_code IS NOT INITIAL.
      SELECT ToStatus
        FROM ZI_CA_StatusAction
        WHERE StatusType = @iv_status_type
          AND FromStatus = @iv_from_status
          AND ActionCode = @iv_action_code
          AND IsActive   = @abap_true
        INTO TABLE @lt_targets.
    ELSE.
      " auto-resolution: caller expects exactly one valid action from this status
      SELECT ToStatus
        FROM ZI_CA_StatusAction
        WHERE StatusType = @iv_status_type
          AND FromStatus = @iv_from_status
          AND IsActive   = @abap_true
        INTO TABLE @lt_targets.
    ENDIF.

    CASE lines( lt_targets ).
      WHEN 0.
        RAISE EXCEPTION TYPE zcx_ca_status_error
          EXPORTING
            textid      = zcx_ca_status_error=>no_valid_action
            status_type = iv_status_type
            action_code = iv_action_code.
      WHEN 1.
        rv_status = lt_targets[ 1 ].
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_ca_status_error
          EXPORTING
            textid      = zcx_ca_status_error=>ambiguous_action
            status_type = iv_status_type
            action_code = iv_action_code.
    ENDCASE.
  ENDMETHOD.


  METHOD validate_transition_config.
    SELECT SINGLE @abap_true
      FROM ZI_CA_StatusAction
      WHERE StatusType = @iv_status_type
        AND FromStatus = @iv_from_status
        AND ToStatus   = @iv_to_status
        AND IsActive   = @abap_true
      INTO @DATA(lv_exists).

    IF lv_exists IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_status_error
        EXPORTING
          textid      = zcx_ca_status_error=>invalid_transition
          status_type = iv_status_type
          from_status = iv_from_status
          to_status   = iv_to_status.
    ENDIF.
  ENDMETHOD.


  METHOD write_log_entry.
    DATA(lv_num) = get_next_number( ).

    TEST-SEAM db_insert_log.
      INSERT zcastat_log FROM VALUE #(
        mandt        = sy-mandt
        log_uuid     = iv_log_uuid
        log_number   = lv_num
        status_type  = iv_status_type
        object_key   = iv_object_key
        from_status  = iv_from_status
        to_status    = iv_to_status
        action_code  = iv_action_code
        comments     = iv_comments
        changed_by   = sy-uname
        changed_at   = cl_abap_context_info=>get_system_date_time( )
        changed_date = sy-datum
        changed_time = sy-uzeit
      ).
    END-TEST-SEAM.
  ENDMETHOD.


  METHOD validate_comment_required.
    SELECT SINGLE RequiresComment
      FROM ZI_CA_StatusAction
      WHERE StatusType = @iv_status_type
        AND FromStatus = @iv_from_status
        AND ToStatus   = @iv_to_status
        AND IsActive   = @abap_true
      INTO @DATA(lv_requires).

    IF lv_requires = abap_true AND iv_comments IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_status_error
        EXPORTING
          textid      = zcx_ca_status_error=>comment_required
          status_type = iv_status_type
          from_status = iv_from_status
          to_status   = iv_to_status.
    ENDIF.
  ENDMETHOD.


  METHOD get_next_number.
    DATA lv_number TYPE num10.

    TEST-SEAM nr_get_next.
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

      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_ca_status_error.
      ENDIF.
    END-TEST-SEAM.

    rv_number = lv_number.
  ENDMETHOD.

ENDCLASS.
