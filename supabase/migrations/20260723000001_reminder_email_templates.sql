ALTER TABLE reminders ADD COLUMN IF NOT EXISTS email_template_source TEXT NOT NULL DEFAULT 'main'; -- 'main' | 'custom'
ALTER TABLE reminders ADD COLUMN IF NOT EXISTS email_template_mode TEXT;                            -- 'visual' | 'html', only when source='custom'
ALTER TABLE reminders ADD COLUMN IF NOT EXISTS email_template_blocks JSONB NOT NULL DEFAULT '[]';
ALTER TABLE reminders ADD COLUMN IF NOT EXISTS email_template_html_source TEXT;
