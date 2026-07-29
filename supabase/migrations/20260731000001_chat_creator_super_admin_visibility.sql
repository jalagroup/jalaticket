-- Chat room access currently lets in: the ticket creator, the assignee,
-- any super admin scoped to the ticket's TARGET department, the place's
-- super_user, branch admins for the place, and system admins. Missing: the
-- super admin of the CREATOR's own department, for the case where an admin
-- creates a ticket targeting a different department than their own — that
-- admin's own super admin should also be able to see/join the chat.
DROP POLICY IF EXISTS "chat_rooms_select_policy" ON chat_rooms;
CREATE POLICY "chat_rooms_select_policy" ON chat_rooms
FOR SELECT USING (
  ticket_id IN (
    SELECT t.id FROM tickets t
    WHERE (
      t.created_by IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
      OR t.assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
      OR t.target_department_id IN (SELECT department_id FROM user_department_ids())
      OR EXISTS (
        SELECT 1 FROM users creator
        WHERE creator.id = t.created_by
          AND creator.department_id IN (SELECT department_id FROM user_department_ids())
      )
      OR t.place_id IN (
        SELECT users.place_id FROM users
        WHERE users.auth_id = auth.uid() AND users.user_type = 'super_user'::user_type AND users.place_id IS NOT NULL
      )
      OR t.place_id IN (
        SELECT bap.place_id FROM branch_admin_places bap
        JOIN users u ON u.id = bap.admin_id
        WHERE u.auth_id = auth.uid() AND u.user_type = 'branch_admin'::user_type
      )
      OR EXISTS (
        SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin'::user_type
      )
    )
    AND t.status = ANY (ARRAY['inprogress'::ticket_status, 'prefinished'::ticket_status])
  )
);

DROP POLICY IF EXISTS "chat_messages_select_policy" ON chat_messages;
CREATE POLICY "chat_messages_select_policy" ON chat_messages
FOR SELECT USING (
  chat_room_id IN (
    SELECT cr.id FROM chat_rooms cr
    WHERE EXISTS (
      SELECT 1 FROM tickets t
      WHERE cr.ticket_id = t.id
        AND (
          t.created_by IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
          OR t.assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
          OR t.target_department_id IN (SELECT department_id FROM user_department_ids())
          OR EXISTS (
            SELECT 1 FROM users creator
            WHERE creator.id = t.created_by
              AND creator.department_id IN (SELECT department_id FROM user_department_ids())
          )
          OR t.place_id IN (
            SELECT users.place_id FROM users
            WHERE users.auth_id = auth.uid() AND users.user_type = 'super_user'::user_type AND users.place_id IS NOT NULL
          )
          OR t.place_id IN (
            SELECT bap.place_id FROM branch_admin_places bap
            JOIN users u ON u.id = bap.admin_id
            WHERE u.auth_id = auth.uid() AND u.user_type = 'branch_admin'::user_type
          )
          OR EXISTS (
            SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin'::user_type
          )
        )
        AND t.status = ANY (ARRAY['inprogress'::ticket_status, 'prefinished'::ticket_status])
    )
  )
);

DROP POLICY IF EXISTS "chat_messages_insert_policy" ON chat_messages;
CREATE POLICY "chat_messages_insert_policy" ON chat_messages
FOR INSERT WITH CHECK (
  sender_id IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
  AND chat_room_id IN (
    SELECT cr.id FROM chat_rooms cr
    WHERE EXISTS (
      SELECT 1 FROM tickets t
      WHERE cr.ticket_id = t.id
        AND (
          t.created_by IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
          OR t.assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
          OR t.target_department_id IN (SELECT department_id FROM user_department_ids())
          OR EXISTS (
            SELECT 1 FROM users creator
            WHERE creator.id = t.created_by
              AND creator.department_id IN (SELECT department_id FROM user_department_ids())
          )
          OR t.place_id IN (
            SELECT users.place_id FROM users
            WHERE users.auth_id = auth.uid() AND users.user_type = 'super_user'::user_type AND users.place_id IS NOT NULL
          )
          OR t.place_id IN (
            SELECT bap.place_id FROM branch_admin_places bap
            JOIN users u ON u.id = bap.admin_id
            WHERE u.auth_id = auth.uid() AND u.user_type = 'branch_admin'::user_type
          )
          OR EXISTS (
            SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin'::user_type
          )
        )
        AND t.status = ANY (ARRAY['inprogress'::ticket_status, 'prefinished'::ticket_status])
    )
  )
);
