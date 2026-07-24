-- ================================================================
-- Multi-department Super Admins
-- ================================================================
-- Lets a super_admin be assigned to more than one department, so they
-- can see and act on tickets targeting any of their departments.
-- Mirrors the existing branch_admin_places pattern (same RLS shape).

CREATE TABLE IF NOT EXISTS admin_departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  department_id uuid NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(admin_id, department_id)
);
CREATE INDEX IF NOT EXISTS admin_departments_admin_idx ON admin_departments(admin_id);

ALTER TABLE admin_departments ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Admins can view their assigned departments" ON admin_departments
    FOR SELECT TO authenticated
    USING (admin_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "System admins can manage admin departments" ON admin_departments
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND user_type = 'system_admin'::user_type));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Backfill: existing super admins' single department carries over so
-- nobody loses ticket visibility on upgrade.
INSERT INTO admin_departments (admin_id, department_id)
SELECT id, department_id FROM users
WHERE user_type = 'super_admin' AND department_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Departments get an admin-configurable color for ticket tags.
ALTER TABLE departments ADD COLUMN IF NOT EXISTS color text;
