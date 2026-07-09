ALTER TABLE cc_forms
  ADD COLUMN IF NOT EXISTS notify_additional_emails   TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS notify_additional_user_ids TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS notify_custom_message      TEXT;
