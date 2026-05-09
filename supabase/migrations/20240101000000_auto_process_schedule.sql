-- ============================================================================
-- auto_approve_supervised_tickets
-- Closes prefinished tickets that also carry under_supervision = true
-- once they exceed the configured timeout (uses `auto_approval_minutes`
-- from app_settings, or falls back to 1440 minutes / 24 hours).
-- Returns JSON: { approved_count, ticket_ids, ticket_numbers }
-- ============================================================================
CREATE OR REPLACE FUNCTION auto_approve_supervised_tickets()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_approval_minutes integer := 1440; -- default 24 h
  v_setting          text;
  v_cutoff           timestamptz;
  v_approved_count   integer := 0;
  v_ticket_ids       uuid[]  := '{}';
  v_ticket_numbers   text[]  := '{}';
  v_ticket           RECORD;
BEGIN
  -- Read configured timeout (shared with standard auto-approval)
  SELECT setting_value INTO v_setting
  FROM   app_settings
  WHERE  setting_key = 'auto_approval_minutes'
  LIMIT  1;

  IF v_setting IS NOT NULL AND v_setting ~ '^\d+$' THEN
    v_approval_minutes := v_setting::integer;
  END IF;

  v_cutoff := NOW() - (v_approval_minutes || ' minutes')::interval;

  FOR v_ticket IN
    SELECT id, ticket_number, created_by
    FROM   tickets
    WHERE  status            = 'prefinished'
      AND  under_supervision = true
      AND  updated_at       <= v_cutoff
  LOOP
    -- Close the ticket
    UPDATE tickets
    SET    status            = 'closed',
           under_supervision = false,
           updated_at        = NOW()
    WHERE  id = v_ticket.id;

    -- Record auto-approval
    INSERT INTO ticket_approvals (ticket_id, approved_by, is_approved)
    VALUES (v_ticket.id, v_ticket.created_by, true)
    ON CONFLICT DO NOTHING;

    v_ticket_ids     := array_append(v_ticket_ids,     v_ticket.id);
    v_ticket_numbers := array_append(v_ticket_numbers, v_ticket.ticket_number::text);
    v_approved_count := v_approved_count + 1;
  END LOOP;

  RETURN json_build_object(
    'approved_count',   v_approved_count,
    'ticket_ids',       to_json(v_ticket_ids),
    'ticket_numbers',   to_json(v_ticket_numbers)
  );
END;
$$;


-- ============================================================================
-- pg_cron schedule
-- Calls the Edge Function every hour so auto-approval runs independently
-- of whether anyone has the app open.
--
-- HOW TO DEPLOY:
--   1. Enable pg_cron in your Supabase project:
--      Dashboard → Database → Extensions → pg_cron → Enable
--   2. Enable pg_net (for HTTP calls from SQL):
--      Dashboard → Database → Extensions → pg_net → Enable
--   3. Run this entire file in the Supabase SQL editor.
--
-- Replace <YOUR_PROJECT_REF> with your Supabase project reference
-- (found in Project Settings → General → Reference ID).
-- ============================================================================

-- Remove existing schedule if re-running this migration
SELECT cron.unschedule('auto-process-tickets')
WHERE  EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'auto-process-tickets'
);

-- Schedule: every hour at minute 0
-- No Authorization header needed because verify_jwt = false on the function
SELECT cron.schedule(
  'auto-process-tickets',       -- job name
  '0 * * * *',                  -- cron expression: every hour
  $$
    SELECT net.http_post(
      url     := 'https://wxibjgzemtfzkattbpue.supabase.co/functions/v1/auto-process-tickets',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body    := '{}'::jsonb
    );
  $$
);
