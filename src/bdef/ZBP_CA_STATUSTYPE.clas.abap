CLASS zbp_ca_statustype DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zi_ca_statustype.

  PUBLIC SECTION.

    CLASS-METHODS validate_statuscode_no_log_ref
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR StatusCode~validate_no_log_reference.

    CLASS-METHODS validate_flwnode_no_log_ref
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR FlowNode~validate_no_log_reference.

    CLASS-METHODS stamp_audit_fields_type
      FOR DETERMINE ON MODIFY
      IMPORTING keys FOR StatusType~stamp_audit_fields.

    CLASS-METHODS stamp_audit_fields_code
      FOR DETERMINE ON MODIFY
      IMPORTING keys FOR StatusCode~stamp_audit_fields.

    CLASS-METHODS stamp_audit_fields_action
      FOR DETERMINE ON MODIFY
      IMPORTING keys FOR StatusAction~stamp_audit_fields.

ENDCLASS.


CLASS zbp_ca_statustype IMPLEMENTATION.

  METHOD validate_statuscode_no_log_ref.
    READ ENTITIES OF zi_ca_statustype
      ENTITY statuscode
        FIELDS ( status_type status_code )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_codes)
      FAILED DATA(ls_failed_read).

    LOOP AT lt_codes INTO DATA(ls_code).
      SELECT SINGLE @abap_true
        FROM zcastat_log
        WHERE status_type = @ls_code-status_type
          AND ( from_status = @ls_code-status_code
             OR to_status   = @ls_code-status_code )
        INTO @DATA(lv_used).

      IF lv_used = abap_true.
        APPEND VALUE #( %tky = ls_code-%tky ) TO failed-statuscode.
        APPEND VALUE #(
          %tky                 = ls_code-%tky
          %msg                 = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = |Status code '{ ls_code-status_code }' exists in | &&
                                              |ZCASTAT_LOG and cannot be deleted. | &&
                                              |Set IS_ACTIVE = false to deactivate.| )
          %element-status_code = if_abap_behv=>mk-on
        ) TO reported-statuscode.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validate_flwnode_no_log_ref.
    READ ENTITIES OF zi_ca_statustype
      ENTITY flownode
        FIELDS ( status_type node_id status_code )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_nodes)
      FAILED DATA(ls_failed_read).

    LOOP AT lt_nodes INTO DATA(ls_node).
      SELECT SINGLE @abap_true
        FROM zcastat_log
        WHERE status_type = @ls_node-status_type
          AND to_status   = @ls_node-status_code
        INTO @DATA(lv_used).

      IF lv_used = abap_true.
        APPEND VALUE #( %tky = ls_node-%tky ) TO failed-flownode.
        APPEND VALUE #(
          %tky             = ls_node-%tky
          %msg             = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = |Flow node '{ ls_node-node_id }' maps to status | &&
                                          |'{ ls_node-status_code }' referenced in ZCASTAT_LOG. | &&
                                          |Set IS_ACTIVE = false instead.| )
          %element-node_id = if_abap_behv=>mk-on
        ) TO reported-flownode.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD stamp_audit_fields_type.
    READ ENTITIES OF zi_ca_statustype
      ENTITY statustype FIELDS ( status_type )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_types).

    DATA lt_update TYPE TABLE FOR UPDATE zi_ca_statustype\\statustype.
    LOOP AT lt_types INTO DATA(ls_type).
      APPEND VALUE #(
        %tky       = ls_type-%tky
        changed_by = sy-uname
        changed_at = cl_abap_context_info=>get_system_date_time( )
        %control   = VALUE #( changed_by = if_abap_behv=>mk-on
                               changed_at = if_abap_behv=>mk-on )
      ) TO lt_update.
    ENDLOOP.
    MODIFY ENTITIES OF zi_ca_statustype
      ENTITY statustype UPDATE FIELDS ( changed_by changed_at )
      WITH lt_update REPORTED DATA(ls_rep).
  ENDMETHOD.


  METHOD stamp_audit_fields_code.
    READ ENTITIES OF zi_ca_statustype
      ENTITY statuscode FIELDS ( status_type status_code )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_codes).

    DATA lt_update TYPE TABLE FOR UPDATE zi_ca_statustype\\statuscode.
    LOOP AT lt_codes INTO DATA(ls_code).
      APPEND VALUE #(
        %tky       = ls_code-%tky
        changed_by = sy-uname
        changed_at = cl_abap_context_info=>get_system_date_time( )
        %control   = VALUE #( changed_by = if_abap_behv=>mk-on
                               changed_at = if_abap_behv=>mk-on )
      ) TO lt_update.
    ENDLOOP.
    MODIFY ENTITIES OF zi_ca_statustype
      ENTITY statuscode UPDATE FIELDS ( changed_by changed_at )
      WITH lt_update REPORTED DATA(ls_rep).
  ENDMETHOD.


  METHOD stamp_audit_fields_action.
    READ ENTITIES OF zi_ca_statustype
      ENTITY statusaction FIELDS ( status_type from_status to_status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_actions).

    DATA lt_update TYPE TABLE FOR UPDATE zi_ca_statustype\\statusaction.
    LOOP AT lt_actions INTO DATA(ls_action).
      APPEND VALUE #(
        %tky       = ls_action-%tky
        changed_by = sy-uname
        changed_at = cl_abap_context_info=>get_system_date_time( )
        %control   = VALUE #( changed_by = if_abap_behv=>mk-on
                               changed_at = if_abap_behv=>mk-on )
      ) TO lt_update.
    ENDLOOP.
    MODIFY ENTITIES OF zi_ca_statustype
      ENTITY statusaction UPDATE FIELDS ( changed_by changed_at )
      WITH lt_update REPORTED DATA(ls_rep).
  ENDMETHOD.

ENDCLASS.
