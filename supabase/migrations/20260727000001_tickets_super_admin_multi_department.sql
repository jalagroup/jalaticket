-- A super admin can be assigned to multiple departments via admin_departments,
-- but the tickets SELECT policy only ever checked the legacy single
-- users.department_id column (NULL for multi-department admins, since their
-- real assignments live in admin_departments) — so a super admin with more
-- than one department saw zero department-targeted tickets. Single-department
-- admins were unaffected because department_id was still populated for them.
DROP POLICY IF EXISTS "tickets_select_department_super_admin" ON tickets;
CREATE POLICY "tickets_select_department_super_admin" ON tickets FOR SELECT
  USING (
    target_department_id IN (
      SELECT ad.department_id FROM admin_departments ad
      JOIN users u ON u.id = ad.admin_id
      WHERE u.auth_id = auth.uid() AND u.user_type = 'super_admin'
    )
    OR target_department_id IN (
      SELECT users.department_id FROM users
      WHERE users.auth_id = auth.uid() AND users.user_type = 'super_admin' AND users.department_id IS NOT NULL
    )
  );
