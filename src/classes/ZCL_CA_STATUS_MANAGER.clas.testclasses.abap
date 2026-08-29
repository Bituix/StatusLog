"! @testing ZCL_CA_STATUS_MANAGER
CLASS ltc_status_manager DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_type    TYPE ZCA_DE_stat_type    VALUE 'INVOICE',
      gc_key     TYPE ZCA_DE_stat_obj_key VALUE 'INV-001',
      gc_approve TYPE ZCA_DE_ACTION_CODE  VALUE 'APPROVE',
      gc_subm    TYPE ZCA_DE_stat_code    VALUE 'SUBM',
      gc_appr    TYPE ZCA_DE_stat_code    VALUE 'APPR',
      gc_rjct    TYPE ZCA_DE_stat_code    VALUE 'RJCT'.

    CLASS-DATA env TYPE REF TO if_osql_test_environment.
    DATA cut TYPE REF TO zcl_ca_status_manager.

    CLASS-METHODS class_setup  RAISING cx_static_check.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    METHODS insert_action
      IMPORTING
        iv_from   TYPE ZCA_DE_stat_code
        iv_to     TYPE ZCA_DE_stat_code
        iv_code   TYPE ZCA_DE_ACTION_CODE DEFAULT space
        iv_active TYPE abap_boolean       DEFAULT abap_true.

    METHODS insert_log
      IMPORTING
        iv_number TYPE int8
        iv_from   TYPE ZCA_DE_stat_code DEFAULT space
        iv_to     TYPE ZCA_DE_stat_code.

    METHODS insert_status_code
      IMPORTING
        iv_code        TYPE ZCA_DE_stat_code
        iv_text        TYPE string
        iv_initial     TYPE abap_boolean DEFAULT abap_false
        iv_final       TYPE abap_boolean DEFAULT abap_false
        iv_criticality TYPE int1         DEFAULT 0.

    METHODS insert_flow_node
      IMPORTING
        iv_node     TYPE string
        iv_status   TYPE ZCA_DE_stat_code
        iv_text     TYPE string
        iv_position TYPE int2
        iv_lane     TYPE string.

    METHODS insert_flow_connection
      IMPORTING
        iv_from TYPE string
        iv_to   TYPE string.

    METHODS no_log_returns_initial      FOR TESTING.
    METHODS log_returns_latest_status   FOR TESTING.
    METHODS get_log_empty               FOR TESTING.
    METHODS get_log_sorted_ascending    FOR TESTING.
    METHODS actions_active_only         FOR TESTING.
    METHODS actions_empty_for_status    FOR TESTING.
    METHODS transition_allowed_valid    FOR TESTING.
    METHODS transition_blocked_no_row   FOR TESTING.
    METHODS transition_blocked_inactive FOR TESTING.
    METHODS change_status_happy_path    FOR TESTING RAISING cx_static_check.
    METHODS change_status_lock_conflict FOR TESTING RAISING cx_static_check.
    METHODS change_status_no_transition FOR TESTING RAISING cx_static_check.
    METHODS change_status_no_action     FOR TESTING RAISING cx_static_check.
    METHODS change_status_ambiguous     FOR TESTING RAISING cx_static_check.
    METHODS change_status_auto_resolve  FOR TESTING RAISING cx_static_check.
    METHODS flow_before_history         FOR TESTING.
    METHODS flow_history_states         FOR TESTING.
    METHODS flow_reentry_uses_next_node FOR TESTING.

ENDCLASS.


CLASS ltc_status_manager IMPLEMENTATION.

  METHOD class_setup.
    env = cl_osql_test_environment=>create(
      i_select_from_entities = VALUE #(
        ( 'ZI_CA_STATUSLOG'    )
        ( 'ZI_CA_STATUSACTION' )
        ( 'ZI_CA_FLWNODE'      )
        ( 'ZI_CA_FLWCONN'      )
        ( 'ZI_CA_STATUSCODE'   )
      )
    ).
  ENDMETHOD.

  METHOD class_teardown.
    env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    env->clear_doubles( ).
    cut = NEW zcl_ca_status_manager( ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK WORK.
  ENDMETHOD.


  "-- helpers ---------------------------------------------------------------

  METHOD insert_action.
    DATA lt TYPE TABLE OF zcastat_action.
    INSERT VALUE #(
      status_type = gc_type
      from_status = iv_from
      to_status   = iv_to
      action_code = iv_code
      is_active   = iv_active
    ) INTO TABLE lt.
    env->insert_test_data( lt ).
  ENDMETHOD.

  METHOD insert_log.
    DATA lt TYPE TABLE OF zcastat_log.
    INSERT VALUE #(
      log_uuid    = cl_system_uuid=>create_uuid_x16_static( )
      log_number  = iv_number
      status_type = gc_type
      object_key  = gc_key
      from_status = iv_from
      to_status   = iv_to
      changed_by  = 'TESTER'
      changed_at  = cl_abap_context_info=>get_system_date_time( )
    ) INTO TABLE lt.
    env->insert_test_data( lt ).
  ENDMETHOD.

  METHOD insert_status_code.
    DATA lt TYPE TABLE OF zcastat_code.
    INSERT VALUE #(
      status_type = gc_type
      status_code = iv_code
      status_text = iv_text
      criticality = iv_criticality
      is_initial  = iv_initial
      is_final    = iv_final
      is_active   = abap_true
    ) INTO TABLE lt.
    env->insert_test_data( lt ).
  ENDMETHOD.

  METHOD insert_flow_node.
    DATA lt TYPE TABLE OF zcastat_flwnode.
    INSERT VALUE #(
      status_type     = gc_type
      node_id         = iv_node
      status_code     = iv_status
      node_text       = iv_text
      column_position = iv_position
      lane_id         = iv_lane
      is_active       = abap_true
    ) INTO TABLE lt.
    env->insert_test_data( lt ).
  ENDMETHOD.

  METHOD insert_flow_connection.
    DATA lt TYPE TABLE OF zcastat_flwconn.
    INSERT VALUE #(
      status_type  = gc_type
      from_node_id = iv_from
      to_node_id   = iv_to
      is_active    = abap_true
    ) INTO TABLE lt.
    env->insert_test_data( lt ).
  ENDMETHOD.


  "-- get_current_status ----------------------------------------------------

  METHOD no_log_returns_initial.
    DATA(lv_status) = cut->get_current_status(
      iv_status_type = gc_type
      iv_object_key  = gc_key ).

    cl_abap_unit_assert=>assert_initial(
      act = lv_status
      msg = 'No log entries — current status must be initial' ).
  ENDMETHOD.

  METHOD log_returns_latest_status.
    insert_log( iv_number = 1  iv_to = gc_subm ).
    insert_log( iv_number = 2  iv_to = gc_appr ).

    DATA(lv_status) = cut->get_current_status(
      iv_status_type = gc_type
      iv_object_key  = gc_key ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_status
      exp = gc_appr
      msg = 'Must return to_status from the highest log_number entry' ).
  ENDMETHOD.


  "-- get_log ---------------------------------------------------------------

  METHOD get_log_empty.
    DATA(lt_log) = cut->get_log(
      iv_status_type = gc_type
      iv_object_key  = gc_key ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_log )
      exp = 0
      msg = 'No log entries — result must be empty' ).
  ENDMETHOD.

  METHOD get_log_sorted_ascending.
    insert_log( iv_number = 2  iv_to = gc_appr ).
    insert_log( iv_number = 1  iv_to = gc_subm ).

    DATA(lt_log) = cut->get_log(
      iv_status_type = gc_type
      iv_object_key  = gc_key ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_log )
      exp = 2
      msg = 'Must return both log entries' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_log[ 1 ]-to_status
      exp = gc_subm
      msg = 'First row must be log_number 1 (SUBM)' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_log[ 2 ]-to_status
      exp = gc_appr
      msg = 'Second row must be log_number 2 (APPR)' ).
  ENDMETHOD.


  "-- get_available_actions -------------------------------------------------

  METHOD actions_active_only.
    insert_action( iv_from = gc_subm  iv_to = gc_appr  iv_code = gc_approve  iv_active = abap_true  ).
    insert_action( iv_from = gc_subm  iv_to = gc_rjct  iv_code = 'REJECT'    iv_active = abap_false ).

    DATA(lt_act) = cut->get_available_actions(
      iv_status_type = gc_type
      iv_from_status = gc_subm ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_act )
      exp = 1
      msg = 'Inactive actions must be filtered out' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_act[ 1 ]-to_status
      exp = gc_appr
      msg = 'The active action must target APPR' ).
  ENDMETHOD.

  METHOD actions_empty_for_status.
    insert_action( iv_from = gc_appr  iv_to = gc_rjct  iv_code = 'REJECT' ).

    DATA(lt_act) = cut->get_available_actions(
      iv_status_type = gc_type
      iv_from_status = gc_subm ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_act )
      exp = 0
      msg = 'No actions configured for SUBM — result must be empty' ).
  ENDMETHOD.


  "-- is_transition_allowed -------------------------------------------------

  METHOD transition_allowed_valid.
    insert_log( iv_number = 1  iv_to = gc_subm ).
    insert_action( iv_from = gc_subm  iv_to = gc_appr  iv_code = gc_approve ).

    DATA(lv_ok) = cut->is_transition_allowed(
      iv_status_type = gc_type
      iv_object_key  = gc_key
      iv_action_code = gc_approve
      iv_to_status   = gc_appr ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_ok
      exp = abap_true
      msg = 'Configured active transition must be allowed' ).
  ENDMETHOD.

  METHOD transition_blocked_no_row.
    insert_log( iv_number = 1  iv_to = gc_subm ).
    " no action configured for SUBM → APPR

    DATA(lv_ok) = cut->is_transition_allowed(
      iv_status_type = gc_type
      iv_object_key  = gc_key
      iv_action_code = gc_approve
      iv_to_status   = gc_appr ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_ok
      exp = abap_false
      msg = 'Unconfigured transition must not be allowed' ).
  ENDMETHOD.

  METHOD transition_blocked_inactive.
    insert_log( iv_number = 1  iv_to = gc_subm ).
    insert_action( iv_from = gc_subm  iv_to = gc_appr  iv_code = gc_approve  iv_active = abap_false ).

    DATA(lv_ok) = cut->is_transition_allowed(
      iv_status_type = gc_type
      iv_object_key  = gc_key
      iv_action_code = gc_approve
      iv_to_status   = gc_appr ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_ok
      exp = abap_false
      msg = 'Inactive transition must not be allowed' ).
  ENDMETHOD.


  "-- change_status ---------------------------------------------------------

  METHOD change_status_happy_path.
    insert_action( iv_from = gc_subm  iv_to = gc_appr  iv_code = gc_approve ).

    INJECT lock_enqueue IN CLASS zcl_ca_status_manager.
    END-INJECT.
    INJECT nr_get_next IN CLASS zcl_ca_status_manager.
      lv_number = 1.
    END-INJECT.
    INJECT db_insert_log IN CLASS zcl_ca_status_manager.
    END-INJECT.
    INJECT lock_dequeue IN CLASS zcl_ca_status_manager.
    END-INJECT.

    TRY.
        cut->change_status(
          iv_status_type = gc_type
          iv_object_key  = gc_key
          iv_action_code = gc_approve
          iv_from_status = gc_subm
          iv_to_status   = gc_appr ).
      CATCH zcx_ca_status_error INTO DATA(lx).
        cl_abap_unit_assert=>fail( |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD change_status_lock_conflict.
    INJECT lock_enqueue IN CLASS zcl_ca_status_manager.
      RAISE EXCEPTION TYPE zcx_ca_status_error
        EXPORTING
          textid      = zcx_ca_status_error=>concurrent_lock
          status_type = iv_status_type
          object_key  = iv_object_key
          locked_by   = 'CONCURRENT'.
    END-INJECT.

    TRY.
        cut->change_status(
          iv_status_type = gc_type
          iv_object_key  = gc_key
          iv_from_status = gc_subm
          iv_to_status   = gc_appr ).
        cl_abap_unit_assert=>fail( 'Expected concurrent_lock exception' ).
      CATCH zcx_ca_status_error INTO DATA(lx).
        cl_abap_unit_assert=>assert_equals(
          act = lx->textid
          exp = zcx_ca_status_error=>concurrent_lock ).
        cl_abap_unit_assert=>assert_equals(
          act = lx->locked_by
          exp = 'CONCURRENT' ).
    ENDTRY.
  ENDMETHOD.

  METHOD change_status_no_transition.
    " No action configured for the given from/to → validate raises invalid_transition
    INJECT lock_enqueue IN CLASS zcl_ca_status_manager.
    END-INJECT.

    TRY.
        cut->change_status(
          iv_status_type = gc_type
          iv_object_key  = gc_key
          iv_from_status = gc_subm
          iv_to_status   = gc_appr ).
        cl_abap_unit_assert=>fail( 'Expected invalid_transition exception' ).
      CATCH zcx_ca_status_error INTO DATA(lx).
        cl_abap_unit_assert=>assert_equals(
          act = lx->textid
          exp = zcx_ca_status_error=>invalid_transition ).
        cl_abap_unit_assert=>assert_equals( act = lx->from_status  exp = gc_subm ).
        cl_abap_unit_assert=>assert_equals( act = lx->to_status    exp = gc_appr ).
    ENDTRY.
  ENDMETHOD.

  METHOD change_status_no_action.
    " action_code given but no matching row in action table → no_valid_action
    INJECT lock_enqueue IN CLASS zcl_ca_status_manager.
    END-INJECT.

    TRY.
        cut->change_status(
          iv_status_type = gc_type
          iv_object_key  = gc_key
          iv_from_status = gc_subm
          iv_action_code = gc_approve ).
        cl_abap_unit_assert=>fail( 'Expected no_valid_action exception' ).
      CATCH zcx_ca_status_error INTO DATA(lx).
        cl_abap_unit_assert=>assert_equals(
          act = lx->textid
          exp = zcx_ca_status_error=>no_valid_action ).
        cl_abap_unit_assert=>assert_equals( act = lx->action_code  exp = gc_approve ).
    ENDTRY.
  ENDMETHOD.

  METHOD change_status_ambiguous.
    " No action_code, multiple active targets → ambiguous_action
    insert_action( iv_from = gc_subm  iv_to = gc_appr  iv_code = gc_approve ).
    insert_action( iv_from = gc_subm  iv_to = gc_rjct  iv_code = 'REJECT'   ).

    INJECT lock_enqueue IN CLASS zcl_ca_status_manager.
    END-INJECT.

    TRY.
        cut->change_status(
          iv_status_type = gc_type
          iv_object_key  = gc_key
          iv_from_status = gc_subm ).
        cl_abap_unit_assert=>fail( 'Expected ambiguous_action exception' ).
      CATCH zcx_ca_status_error INTO DATA(lx).
        cl_abap_unit_assert=>assert_equals(
          act = lx->textid
          exp = zcx_ca_status_error=>ambiguous_action ).
    ENDTRY.
  ENDMETHOD.

  METHOD change_status_auto_resolve.
    " No action_code, exactly one active target → resolves automatically, no exception
    insert_action( iv_from = gc_subm  iv_to = gc_appr  iv_code = gc_approve ).

    INJECT lock_enqueue IN CLASS zcl_ca_status_manager.
    END-INJECT.
    INJECT nr_get_next IN CLASS zcl_ca_status_manager.
      lv_number = 1.
    END-INJECT.
    INJECT db_insert_log IN CLASS zcl_ca_status_manager.
    END-INJECT.
    INJECT lock_dequeue IN CLASS zcl_ca_status_manager.
    END-INJECT.

    TRY.
        cut->change_status(
          iv_status_type = gc_type
          iv_object_key  = gc_key
          iv_from_status = gc_subm ).
      CATCH zcx_ca_status_error INTO DATA(lx).
        cl_abap_unit_assert=>fail( |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  "-- get_process_flow_json -------------------------------------------------

  METHOD flow_before_history.
    insert_status_code( iv_code = 'NEW'  iv_text = 'New'  iv_initial = abap_true ).
    insert_status_code( iv_code = gc_subm iv_text = 'Submitted' ).
    insert_flow_node( iv_node = 'N_NEW'  iv_status = 'NEW'
      iv_text = 'New' iv_position = 1 iv_lane = 'CREATE' ).
    insert_flow_node( iv_node = 'N_SUBM' iv_status = gc_subm
      iv_text = 'Submitted' iv_position = 2 iv_lane = 'REVIEW' ).
    insert_flow_connection( iv_from = 'N_NEW' iv_to = 'N_SUBM' ).

    DATA(lv_json) = cut->get_process_flow_json(
      iv_status_type = gc_type
      iv_object_key  = gc_key ).
    DATA ls_flow TYPE zcl_ca_status_manager=>ty_process_flow.
    /ui2/cl_json=>deserialize(
      EXPORTING
        json        = lv_json
        pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING
        data        = ls_flow ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_flow-nodes ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_flow-lanes ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_flow-current_status exp = 'NEW' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_flow-nodes[ node_id = 'N_NEW' ]-state exp = 'Neutral' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_flow-nodes[ node_id = 'N_SUBM' ]-state exp = 'Planned' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_flow-nodes[ node_id = 'N_NEW' ]-children[ 1 ] exp = 'N_SUBM' ).
    cl_abap_unit_assert=>assert_initial( act = ls_flow-history ).
  ENDMETHOD.

  METHOD flow_history_states.
    insert_status_code( iv_code = 'NEW' iv_text = 'New' iv_initial = abap_true ).
    insert_status_code( iv_code = gc_subm iv_text = 'Submitted' ).
    insert_status_code( iv_code = gc_appr iv_text = 'Approved'
      iv_final = abap_true iv_criticality = 3 ).
    insert_flow_node( iv_node = 'N_NEW' iv_status = 'NEW'
      iv_text = 'New' iv_position = 1 iv_lane = 'CREATE' ).
    insert_flow_node( iv_node = 'N_SUBM' iv_status = gc_subm
      iv_text = 'Submitted' iv_position = 2 iv_lane = 'REVIEW' ).
    insert_flow_node( iv_node = 'N_APPR' iv_status = gc_appr
      iv_text = 'Approved' iv_position = 3 iv_lane = 'DONE' ).
    insert_log( iv_number = 1 iv_from = 'NEW' iv_to = gc_subm ).

    DATA(lv_json) = cut->get_process_flow_json(
      iv_status_type = gc_type
      iv_object_key  = gc_key ).
    DATA ls_flow TYPE zcl_ca_status_manager=>ty_process_flow.
    /ui2/cl_json=>deserialize(
      EXPORTING json = lv_json pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING data = ls_flow ).

    cl_abap_unit_assert=>assert_equals( act = ls_flow-current_status exp = gc_subm ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_flow-nodes[ node_id = 'N_NEW' ]-state exp = 'Positive' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_flow-nodes[ node_id = 'N_SUBM' ]-state exp = 'Neutral' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_flow-nodes[ node_id = 'N_APPR' ]-state exp = 'Planned' ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_flow-history ) exp = 1 ).
  ENDMETHOD.

  METHOD flow_reentry_uses_next_node.
    insert_status_code( iv_code = gc_subm iv_text = 'Submitted' iv_initial = abap_true ).
    insert_status_code( iv_code = gc_rjct iv_text = 'Rejected' iv_criticality = 1 ).
    insert_flow_node( iv_node = 'N_SUBM1' iv_status = gc_subm
      iv_text = 'First review' iv_position = 1 iv_lane = 'REVIEW1' ).
    insert_flow_node( iv_node = 'N_RJCT' iv_status = gc_rjct
      iv_text = 'Rejected' iv_position = 2 iv_lane = 'REWORK' ).
    insert_flow_node( iv_node = 'N_SUBM2' iv_status = gc_subm
      iv_text = 'Second review' iv_position = 3 iv_lane = 'REVIEW2' ).
    insert_log( iv_number = 1 iv_from = gc_subm iv_to = gc_rjct ).
    insert_log( iv_number = 2 iv_from = gc_rjct iv_to = gc_subm ).

    DATA(lv_json) = cut->get_process_flow_json(
      iv_status_type = gc_type
      iv_object_key  = gc_key ).
    DATA ls_flow TYPE zcl_ca_status_manager=>ty_process_flow.
    /ui2/cl_json=>deserialize(
      EXPORTING json = lv_json pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING data = ls_flow ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_flow-nodes[ node_id = 'N_SUBM1' ]-state exp = 'Positive' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_flow-nodes[ node_id = 'N_RJCT' ]-state exp = 'Negative' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_flow-nodes[ node_id = 'N_SUBM2' ]-state exp = 'Neutral' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_flow-nodes[ node_id = 'N_SUBM2' ]-visit_number exp = 2 ).
  ENDMETHOD.

ENDCLASS.
