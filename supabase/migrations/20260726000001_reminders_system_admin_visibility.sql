-- System Admins should see and manage every reminder in the system, not
-- just ones they personally own — the existing "reminders_owner" policy
-- only allows a user to see their own rows.
CREATE POLICY "reminders_system_admin" ON reminders FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND user_type = 'system_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND user_type = 'system_admin'));
