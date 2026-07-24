-- ================================================================
-- CC: External anonymous submissions + targeted-user visibility
-- ================================================================

-- ── Helper: SECURITY DEFINER so anon role can check form status ──
CREATE OR REPLACE FUNCTION cc_form_is_external(fid uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM cc_forms
    WHERE id = fid
      AND external_apply_enabled = true
      AND is_active = true
  );
$$;
GRANT EXECUTE ON FUNCTION cc_form_is_external(uuid) TO anon;
GRANT EXECUTE ON FUNCTION cc_form_is_external(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION cc_submission_is_anon_external(sid uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM cc_submissions s
    WHERE s.id = sid
      AND s.submitted_by_user_id IS NULL
      AND cc_form_is_external(s.form_id)
  );
$$;
GRANT EXECUTE ON FUNCTION cc_submission_is_anon_external(uuid) TO anon;
GRANT EXECUTE ON FUNCTION cc_submission_is_anon_external(uuid) TO authenticated;

-- ── 1. Allow anon to read externally-accessible forms ─────────────
DO $$ BEGIN
  CREATE POLICY cc_forms_select_external ON cc_forms
    FOR SELECT TO anon
    USING (external_apply_enabled = true AND is_active = true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 2. Allow anon to read form steps/sections/fields ──────────────
DO $$ BEGIN
  CREATE POLICY cc_form_steps_select_external ON cc_form_steps
    FOR SELECT TO anon
    USING (cc_form_is_external(form_id));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY cc_form_sections_select_external ON cc_form_sections
    FOR SELECT TO anon
    USING (step_id IN (
      SELECT id FROM cc_form_steps WHERE cc_form_is_external(form_id)
    ));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY cc_form_fields_select_external ON cc_form_fields
    FOR SELECT TO anon
    USING (section_id IN (
      SELECT id FROM cc_form_sections
      WHERE step_id IN (
        SELECT id FROM cc_form_steps WHERE cc_form_is_external(form_id)
      )
    ));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 3. Allow anon to INSERT submissions for external forms ─────────
DO $$ BEGIN
  CREATE POLICY cc_submissions_insert_anon ON cc_submissions
    FOR INSERT TO anon
    WITH CHECK (
      submitted_by_user_id IS NULL
      AND cc_form_is_external(form_id)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 4. Allow anon to SELECT their own submission (for value insert) ─
DO $$ BEGIN
  CREATE POLICY cc_submissions_select_anon_own ON cc_submissions
    FOR SELECT TO anon
    USING (
      submitted_by_user_id IS NULL
      AND cc_form_is_external(form_id)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 5. Allow anon to INSERT submission_values for their submission ──
DO $$ BEGIN
  CREATE POLICY cc_submission_values_insert_anon ON cc_submission_values
    FOR INSERT TO anon
    WITH CHECK (cc_submission_is_anon_external(submission_id));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 6. Allow anon to INSERT submission_attachments for their submission
DO $$ BEGIN
  CREATE POLICY cc_submission_attachments_insert_anon ON cc_submission_attachments
    FOR INSERT TO anon
    WITH CHECK (cc_submission_is_anon_external(submission_id));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 7. Allow audience/group members to see their assigned forms ────
DO $$ BEGIN
  CREATE POLICY cc_forms_select_audience ON cc_forms
    FOR SELECT TO authenticated
    USING (
      -- directly in audience
      id IN (
        SELECT form_id FROM cc_form_audience
        WHERE user_id = cc_current_user_id()
      )
      OR
      -- in a group that has access
      id IN (
        SELECT fa.form_id FROM cc_form_audience fa
        JOIN cc_group_members gm ON gm.group_id = fa.group_id
        WHERE gm.user_id = cc_current_user_id()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 8. Allow audience members to see form structure ────────────────
DO $$ BEGIN
  CREATE POLICY cc_form_steps_select_auth ON cc_form_steps
    FOR SELECT TO authenticated
    USING (
      form_id IN (
        SELECT id FROM cc_forms
        WHERE
          owner_user_id = cc_current_user_id()
          OR id IN (SELECT form_id FROM cc_form_audience WHERE user_id = cc_current_user_id())
          OR id IN (
            SELECT fa.form_id FROM cc_form_audience fa
            JOIN cc_group_members gm ON gm.group_id = fa.group_id
            WHERE gm.user_id = cc_current_user_id()
          )
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 9. Self-select on cc_form_audience and cc_group_members ────────
DO $$ BEGIN
  CREATE POLICY cc_form_audience_select_self ON cc_form_audience
    FOR SELECT USING (user_id = cc_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY cc_group_members_select_self ON cc_group_members
    FOR SELECT USING (user_id = cc_current_user_id());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 10. Allow anon to read the form's logo from storage (if needed) -
-- Storage policies must be set separately in the Supabase dashboard
-- under Storage > Policies for the "cc-form-logos" bucket.
-- Grant READ access to public/anon for that bucket.
