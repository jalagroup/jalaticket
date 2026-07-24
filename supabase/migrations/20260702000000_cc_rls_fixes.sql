-- ============================================================
-- CC RLS Fixes:
--   1. Normal users can read their own audience / group-member rows
--      (required by getFormsForCurrentUser service queries)
--   2. Anonymous users can see external submissions they just created
--      (required by cc_sub_values_insert / cc_sub_attachments_insert policy chain)
-- ============================================================

-- Allow any authenticated user to see their own form-audience entries
DO $$ BEGIN
  CREATE POLICY cc_form_audience_select_self ON cc_form_audience
    FOR SELECT USING (user_id = cc_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Allow any authenticated user to see group-member rows they belong to
DO $$ BEGIN
  CREATE POLICY cc_group_members_select_self ON cc_group_members
    FOR SELECT USING (user_id = cc_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Allow (anon + authenticated) to SELECT anonymous external submissions
-- so that the cc_sub_values_insert / cc_sub_attachments_insert WITH CHECK
-- sub-select can verify the submission belongs to an external-enabled form.
DO $$ BEGIN
  CREATE POLICY cc_submissions_select_external ON cc_submissions
    FOR SELECT USING (
      submitted_by_user_id IS NULL
      AND form_id IN (
        SELECT id FROM cc_forms
        WHERE external_apply_enabled = true
          AND is_active = true
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
