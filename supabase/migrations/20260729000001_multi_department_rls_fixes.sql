-- The same bug fixed for tickets_select_department_super_admin turned out to
-- be duplicated across many other policies written before super admins
-- could be assigned to multiple departments (admin_departments): each one
-- independently re-implemented "does this row's department match the
-- current super admin's department" using ONLY the legacy single
-- users.department_id column, which is NULL for a genuinely multi-department
-- super admin. That made chat, chat rooms, ticket attachments, ticket
-- tracking points, and complaint tickets/attachments all invisible to any
-- super admin with more than one department.
--
-- Fix: one shared helper (mirrors fleet_user_can_access's SECURITY DEFINER
-- pattern) returning every department id the current user is scoped to —
-- admin: their single legacy department_id; super_admin: their full
-- admin_departments set, unioned with the legacy field as a safety net. Every
-- affected policy is rewritten to use it instead of its own ad-hoc check,
-- with all of its other conditions left exactly as they were.

CREATE OR REPLACE FUNCTION user_department_ids()
RETURNS TABLE(department_id uuid)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT ad.department_id FROM admin_departments ad
    JOIN users u ON u.id = ad.admin_id
    WHERE u.auth_id = auth.uid() AND u.user_type = 'super_admin'
  UNION
  SELECT users.department_id FROM users
    WHERE users.auth_id = auth.uid()
      AND users.user_type IN ('admin', 'super_admin')
      AND users.department_id IS NOT NULL;
$$;

-- ── chat_rooms ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "chat_rooms_select_policy" ON chat_rooms;
CREATE POLICY "chat_rooms_select_policy" ON chat_rooms FOR SELECT TO authenticated
  USING (
    ticket_id IN (
      SELECT t.id FROM tickets t
      WHERE (
        t.created_by IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
        OR t.assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
        OR t.target_department_id IN (SELECT department_id FROM user_department_ids())
        OR t.place_id IN (SELECT users.place_id FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'super_user' AND users.place_id IS NOT NULL)
        OR t.place_id IN (SELECT bap.place_id FROM branch_admin_places bap JOIN users u ON u.id = bap.admin_id WHERE u.auth_id = auth.uid() AND u.user_type = 'branch_admin')
        OR EXISTS (SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin')
      )
      AND t.status = ANY (ARRAY['inprogress'::ticket_status, 'prefinished'::ticket_status])
    )
  );

-- ── chat_messages ───────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "chat_messages_select_policy" ON chat_messages;
CREATE POLICY "chat_messages_select_policy" ON chat_messages FOR SELECT TO authenticated
  USING (
    chat_room_id IN (
      SELECT cr.id FROM chat_rooms cr
      WHERE EXISTS (
        SELECT 1 FROM tickets t
        WHERE cr.ticket_id = t.id
          AND (
            t.created_by IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
            OR t.assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
            OR t.target_department_id IN (SELECT department_id FROM user_department_ids())
            OR t.place_id IN (SELECT users.place_id FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'super_user' AND users.place_id IS NOT NULL)
            OR t.place_id IN (SELECT bap.place_id FROM branch_admin_places bap JOIN users u ON u.id = bap.admin_id WHERE u.auth_id = auth.uid() AND u.user_type = 'branch_admin')
            OR EXISTS (SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin')
          )
          AND t.status = ANY (ARRAY['inprogress'::ticket_status, 'prefinished'::ticket_status])
      )
    )
  );

DROP POLICY IF EXISTS "chat_messages_insert_policy" ON chat_messages;
CREATE POLICY "chat_messages_insert_policy" ON chat_messages FOR INSERT TO authenticated
  WITH CHECK (
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
            OR t.place_id IN (SELECT users.place_id FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'super_user' AND users.place_id IS NOT NULL)
            OR t.place_id IN (SELECT bap.place_id FROM branch_admin_places bap JOIN users u ON u.id = bap.admin_id WHERE u.auth_id = auth.uid() AND u.user_type = 'branch_admin')
            OR EXISTS (SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin')
          )
          AND t.status = ANY (ARRAY['inprogress'::ticket_status, 'prefinished'::ticket_status])
      )
    )
  );

-- ── ticket_tracking_points ──────────────────────────────────────────────────
DROP POLICY IF EXISTS "tracking_points_select_policy" ON ticket_tracking_points;
CREATE POLICY "tracking_points_select_policy" ON ticket_tracking_points FOR SELECT TO authenticated
  USING (
    ticket_id IN (
      SELECT t.id FROM tickets t
      WHERE t.created_by IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
        OR t.assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
        OR t.target_department_id IN (SELECT department_id FROM user_department_ids())
        OR t.place_id IN (SELECT users.place_id FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'super_user' AND users.place_id IS NOT NULL)
        OR t.place_id IN (SELECT bap.place_id FROM branch_admin_places bap JOIN users u ON u.id = bap.admin_id WHERE u.auth_id = auth.uid() AND u.user_type = 'branch_admin')
        OR EXISTS (SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin')
    )
  );

-- ── ticket_attachments ──────────────────────────────────────────────────────
DROP POLICY IF EXISTS "ticket_attachments_select_policy" ON ticket_attachments;
CREATE POLICY "ticket_attachments_select_policy" ON ticket_attachments FOR SELECT TO authenticated
  USING (
    ticket_id IN (SELECT tickets.id FROM tickets WHERE tickets.created_by IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid()))
    OR ticket_id IN (SELECT tickets.id FROM tickets WHERE tickets.assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid()))
    OR ticket_id IN (SELECT t.id FROM tickets t WHERE t.target_department_id IN (SELECT department_id FROM user_department_ids()))
    OR EXISTS (SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin')
  );

-- ── storage.objects (the 'attachments' bucket) ──────────────────────────────
DROP POLICY IF EXISTS "Users can view attachments they have access to" ON storage.objects;
CREATE POLICY "Users can view attachments they have access to" ON storage.objects FOR SELECT
  USING (
    bucket_id = 'attachments'
    AND auth.role() = 'authenticated'
    AND (
      (name LIKE '%ticket_attachments/%' AND EXISTS (
        SELECT 1 FROM tickets t, ticket_attachments ta
        WHERE ta.file_path::text = objects.name AND t.id = ta.ticket_id
          AND t.created_by IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
      ))
      OR (name LIKE '%ticket_attachments/%' AND EXISTS (
        SELECT 1 FROM tickets t, ticket_attachments ta
        WHERE ta.file_path::text = objects.name AND t.id = ta.ticket_id
          AND t.assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
      ))
      OR (name LIKE '%ticket_attachments/%' AND EXISTS (
        SELECT 1 FROM tickets t, ticket_attachments ta
        WHERE ta.file_path::text = objects.name AND t.id = ta.ticket_id
          AND t.target_department_id IN (SELECT department_id FROM user_department_ids())
      ))
      OR EXISTS (SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin')
    )
  );

-- ── complaint_tickets ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Admins can update complaints" ON complaint_tickets;
CREATE POLICY "Admins can update complaints" ON complaint_tickets FOR UPDATE TO authenticated
  USING (
    assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
    OR department_id IN (
      SELECT udi.department_id FROM user_department_ids() udi
      WHERE EXISTS (
        SELECT 1 FROM department_complaint_permissions dcp
        WHERE dcp.department_id = udi.department_id AND dcp.can_access_complaints = true
      )
    )
  );

DROP POLICY IF EXISTS "Admins can view department complaints" ON complaint_tickets;
CREATE POLICY "Admins can view department complaints" ON complaint_tickets FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin')
    OR EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid() AND u.user_type = 'super_admin'
        AND (
          complaint_tickets.department_id IN (SELECT department_id FROM user_department_ids())
          OR complaint_tickets.department_id IS NULL
          OR complaint_tickets.created_by = u.id
        )
    )
    OR assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
    OR created_by IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
  );

DROP POLICY IF EXISTS "Users can update complaints based on role" ON complaint_tickets;
CREATE POLICY "Users can update complaints based on role" ON complaint_tickets FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin')
    OR EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid() AND u.user_type = 'super_admin'
        AND (
          complaint_tickets.department_id IN (SELECT department_id FROM user_department_ids())
          OR complaint_tickets.department_id IS NULL
        )
    )
    OR assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
    OR (created_by IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid()) AND status = 'pending'::complaint_status)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin')
    OR EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid() AND u.user_type = 'super_admin'
        AND (
          complaint_tickets.department_id IN (SELECT department_id FROM user_department_ids())
          OR complaint_tickets.department_id IS NULL
        )
    )
    OR assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
    OR (created_by IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid()) AND status = 'pending'::complaint_status)
  );

-- ── complaint_attachments ────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can view complaint attachments" ON complaint_attachments;
CREATE POLICY "Users can view complaint attachments" ON complaint_attachments FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin')
    OR EXISTS (
      SELECT 1 FROM users u JOIN complaint_tickets ct ON ct.id = complaint_attachments.complaint_id
      WHERE u.auth_id = auth.uid() AND u.user_type = 'super_admin'
        AND (
          ct.department_id IN (SELECT department_id FROM user_department_ids())
          OR ct.department_id IS NULL
          OR ct.created_by = u.id
        )
    )
    OR EXISTS (SELECT 1 FROM complaint_tickets ct WHERE ct.id = complaint_attachments.complaint_id AND ct.assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid()))
    OR EXISTS (SELECT 1 FROM complaint_tickets ct WHERE ct.id = complaint_attachments.complaint_id AND ct.created_by IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid()))
  );

DROP POLICY IF EXISTS "Users can upload complaint attachments" ON complaint_attachments;
CREATE POLICY "Users can upload complaint attachments" ON complaint_attachments FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin')
    OR EXISTS (
      SELECT 1 FROM users u JOIN complaint_tickets ct ON ct.id = complaint_attachments.complaint_id
      WHERE u.auth_id = auth.uid() AND u.user_type = 'super_admin'
        AND (
          ct.department_id IN (SELECT department_id FROM user_department_ids())
          OR ct.department_id IS NULL
          OR ct.created_by = u.id
        )
    )
    OR EXISTS (SELECT 1 FROM complaint_tickets ct WHERE ct.id = complaint_attachments.complaint_id AND ct.assigned_to IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid()))
    OR EXISTS (SELECT 1 FROM complaint_tickets ct WHERE ct.id = complaint_attachments.complaint_id AND ct.created_by IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid()))
  );
