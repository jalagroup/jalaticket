-- ============================================================================
-- auto-process-tickets schedule
--
-- The existing auto_approve_expired_tickets() Postgres function already
-- handles BOTH regular prefinished tickets AND under-supervision tickets.
-- No extra RPC is needed.
--
-- HOW TO DEPLOY (run once in the Supabase SQL editor):
--   1. Enable pg_cron:  Dashboard → Database → Extensions → pg_cron → Enable
--   2. Enable pg_net:   Dashboard → Database → Extensions → pg_net  → Enable
--   3. Run this file in the SQL editor.
-- ============================================================================

-- Drop the redundant function we created earlier (already handled by the
-- existing auto_approve_expired_tickets which covers both cases).
DROP FUNCTION IF EXISTS public.auto_approve_supervised_tickets();

-- ── pg_cron schedule ────────────────────────────────────────────────────────

-- Remove existing schedule before re-creating it
SELECT cron.unschedule('auto-process-tickets')
WHERE  EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'auto-process-tickets'
);

-- Schedule: every hour at minute 0
-- verify_jwt = false on the function so no Authorization header is needed.
SELECT cron.schedule(
  'auto-process-tickets',
  '0 * * * *',
  $$
    SELECT net.http_post(
      url     := 'https://wxibjgzemtfzkattbpue.supabase.co/functions/v1/auto-process-tickets',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body    := '{}'::jsonb
    );
  $$
);
