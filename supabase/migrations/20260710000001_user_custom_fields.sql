CREATE TABLE IF NOT EXISTS user_field_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label TEXT NOT NULL,
  label_ar TEXT,
  field_type TEXT NOT NULL DEFAULT 'text',
  field_options JSONB DEFAULT '[]',
  fill_mode TEXT NOT NULL DEFAULT 'optional',
  blocks_user_until_filled BOOLEAN NOT NULL DEFAULT FALSE,
  is_shown_in_profile BOOLEAN NOT NULL DEFAULT TRUE,
  order_index INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_field_values (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  field_id UUID NOT NULL REFERENCES user_field_definitions(id) ON DELETE CASCADE,
  value JSONB,
  filled_by_user_id UUID REFERENCES users(id),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, field_id)
);

ALTER TABLE user_field_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_field_values ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated_read_field_defs"
  ON user_field_definitions FOR SELECT TO authenticated USING (true);

CREATE POLICY "system_admin_manage_field_defs"
  ON user_field_definitions FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND user_type = 'system_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND user_type = 'system_admin'));

CREATE POLICY "admin_read_all_field_values"
  ON user_field_values FOR SELECT TO authenticated
  USING (
    user_id IN (SELECT id FROM users WHERE auth_id = auth.uid())
    OR EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND user_type IN ('system_admin','super_admin','super_user'))
  );

CREATE POLICY "admin_write_field_values"
  ON user_field_values FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND user_type IN ('system_admin','super_admin','super_user')));

CREATE POLICY "admin_update_field_values"
  ON user_field_values FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND user_type IN ('system_admin','super_admin','super_user')));

CREATE POLICY "user_write_own_field_values"
  ON user_field_values FOR INSERT TO authenticated
  WITH CHECK (
    user_id IN (SELECT id FROM users WHERE auth_id = auth.uid())
    AND EXISTS (
      SELECT 1 FROM user_field_definitions ufd
      WHERE ufd.id = field_id AND ufd.fill_mode IN ('user_only','both')
    )
  );

CREATE POLICY "user_update_own_field_values"
  ON user_field_values FOR UPDATE TO authenticated
  USING (
    user_id IN (SELECT id FROM users WHERE auth_id = auth.uid())
  );
