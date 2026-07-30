-- Lets a system admin grant a specific user the ability to directly pick
-- a target admin within a specific department when creating a ticket
-- (skipping pending/auto-assignment), instead of only ever landing in the
-- normal pending queue for that department's super admin to assign.
CREATE TABLE IF NOT EXISTS ticket_assignment_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  department_id uuid NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  granted_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, department_id)
);

ALTER TABLE ticket_assignment_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own assignment permissions"
ON ticket_assignment_permissions FOR SELECT USING (
  user_id IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
);

CREATE POLICY "System admins can manage assignment permissions"
ON ticket_assignment_permissions FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.user_type = 'system_admin'::user_type)
);
