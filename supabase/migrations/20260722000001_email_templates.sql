CREATE TABLE IF NOT EXISTS email_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mode TEXT NOT NULL DEFAULT 'visual',       -- 'visual' | 'html'
  blocks JSONB NOT NULL DEFAULT '[]',        -- ordered list of visual blocks, used when mode='visual'
  html_source TEXT,                          -- raw HTML with {{tokens}}, used when mode='html'
  updated_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "system_admin_manage_email_templates"
  ON email_templates FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND user_type = 'system_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND user_type = 'system_admin'));
