-- Smart Reminders Engine tables

CREATE TABLE IF NOT EXISTS reminders (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title                 TEXT NOT NULL,
  description           TEXT,
  is_active             BOOLEAN NOT NULL DEFAULT TRUE,

  -- Data source
  data_source_type      TEXT NOT NULL DEFAULT 'api',   -- 'api' | 'internal' | 'excel'
  data_source_config    JSONB NOT NULL DEFAULT '{}',

  -- Schedule
  schedule_type         TEXT NOT NULL DEFAULT 'interval', -- 'interval' | 'daily' | 'weekly' | 'custom'
  schedule_config       JSONB NOT NULL DEFAULT '{}',

  -- Conditions (optional)
  has_condition         BOOLEAN NOT NULL DEFAULT FALSE,
  condition_operator    TEXT NOT NULL DEFAULT 'and',
  conditions            JSONB NOT NULL DEFAULT '[]',

  -- Message
  channels              TEXT[] NOT NULL DEFAULT '{app}',
  msg_title_template    TEXT NOT NULL DEFAULT '',
  msg_body_template     TEXT NOT NULL DEFAULT '',

  -- Recipients
  recipient_config      JSONB NOT NULL DEFAULT '{"type":"creator"}',

  -- Runtime
  last_run_at           TIMESTAMPTZ,
  next_run_at           TIMESTAMPTZ,
  run_count             INTEGER NOT NULL DEFAULT 0,

  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS reminders_owner_idx ON reminders(owner_user_id);
CREATE INDEX IF NOT EXISTS reminders_active_next_idx ON reminders(is_active, next_run_at);

CREATE TABLE IF NOT EXISTS reminder_runs (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reminder_id         UUID NOT NULL REFERENCES reminders(id) ON DELETE CASCADE,
  started_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at        TIMESTAMPTZ,
  status              TEXT NOT NULL DEFAULT 'running',  -- 'running'|'success'|'failed'|'skipped'
  records_fetched     INTEGER NOT NULL DEFAULT 0,
  notifications_sent  INTEGER NOT NULL DEFAULT 0,
  error_message       TEXT,
  run_log             JSONB DEFAULT '[]'
);

CREATE INDEX IF NOT EXISTS reminder_runs_reminder_idx ON reminder_runs(reminder_id, started_at DESC);

-- RLS
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminder_runs ENABLE ROW LEVEL SECURITY;

-- Owner can manage their own reminders
CREATE POLICY reminders_owner ON reminders
  USING (owner_user_id = (
    SELECT id FROM users WHERE auth_id = auth.uid() LIMIT 1
  ));

-- Runs visible to reminder owner
CREATE POLICY reminder_runs_owner ON reminder_runs
  USING (reminder_id IN (
    SELECT id FROM reminders
    WHERE owner_user_id = (SELECT id FROM users WHERE auth_id = auth.uid() LIMIT 1)
  ));

-- Service role (edge functions) can read/write all
CREATE POLICY reminders_service ON reminders FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY reminder_runs_service ON reminder_runs FOR ALL
  USING (auth.role() = 'service_role');

-- Helper RPC to list public tables (used by the Flutter data source picker)
CREATE OR REPLACE FUNCTION get_public_tables()
RETURNS TABLE(table_name text) AS $$
  SELECT table_name::text FROM information_schema.tables
  WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
  ORDER BY table_name;
$$ LANGUAGE sql SECURITY DEFINER;

-- pg_cron: process due reminders every 5 minutes
SELECT cron.unschedule('process-due-reminders')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-due-reminders');

SELECT cron.schedule(
  'process-due-reminders',
  '*/5 * * * *',
  $$
    SELECT net.http_post(
      url     := 'https://wxibjgzemtfzkattbpue.supabase.co/functions/v1/process-due-reminders',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body    := '{}'::jsonb
    );
  $$
);
