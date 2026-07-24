-- Add notification preference columns to cc_forms
ALTER TABLE cc_forms
  ADD COLUMN IF NOT EXISTS notify_creator_on_submit BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS notify_email TEXT;
