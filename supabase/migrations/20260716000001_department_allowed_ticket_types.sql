ALTER TABLE departments
  ADD COLUMN IF NOT EXISTS allowed_ticket_types JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS allowed_department_ids JSONB NOT NULL DEFAULT '[]'::jsonb;
