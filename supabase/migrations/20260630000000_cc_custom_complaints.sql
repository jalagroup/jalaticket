-- ============================================================
-- Custom Complaints Module (cc_) migration
-- All tables are prefixed cc_ to avoid collision with the
-- existing quality-complaints system.
-- ============================================================

-- ── Helper functions ──────────────────────────────────────

CREATE OR REPLACE FUNCTION cc_current_user_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT id FROM users WHERE auth_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION cc_is_creator()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE auth_id = auth.uid()
      AND user_type IN ('system_admin','super_admin','super_user','branch_admin')
  );
$$;

-- ── Tables ────────────────────────────────────────────────

-- Groups (reusable audience buckets per creator)
CREATE TABLE IF NOT EXISTS cc_groups (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name          text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS cc_groups_owner_idx ON cc_groups(owner_user_id);

-- Group members
CREATE TABLE IF NOT EXISTS cc_group_members (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id   uuid NOT NULL REFERENCES cc_groups(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(group_id, user_id)
);

CREATE INDEX IF NOT EXISTS cc_group_members_group_idx ON cc_group_members(group_id);
CREATE INDEX IF NOT EXISTS cc_group_members_user_idx  ON cc_group_members(user_id);

-- Forms / templates
CREATE TABLE IF NOT EXISTS cc_forms (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title                 text NOT NULL DEFAULT '',
  logo_url              text,                        -- null = use system default
  theme_color           text NOT NULL DEFAULT '#f16936',
  identity_mode         text NOT NULL DEFAULT 'identified'
                          CHECK (identity_mode IN ('identified','anonymous','choice')),
  external_apply_enabled boolean NOT NULL DEFAULT false,
  show_onboarding       boolean NOT NULL DEFAULT false,
  onboarding_config     jsonb,                       -- designer canvas state
  show_closing          boolean NOT NULL DEFAULT false,
  closing_config        jsonb,                       -- designer canvas state
  progress_style        text NOT NULL DEFAULT 'numbered'
                          CHECK (progress_style IN ('numbered','percentage','dotted')),
  is_active             boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS cc_forms_owner_idx  ON cc_forms(owner_user_id);
CREATE INDEX IF NOT EXISTS cc_forms_active_idx ON cc_forms(is_active);

-- Audience: who can see/submit a form (user or group, not both null)
CREATE TABLE IF NOT EXISTS cc_form_audience (
  id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id  uuid NOT NULL REFERENCES cc_forms(id) ON DELETE CASCADE,
  user_id  uuid REFERENCES users(id) ON DELETE CASCADE,
  group_id uuid REFERENCES cc_groups(id) ON DELETE CASCADE,
  CHECK (user_id IS NOT NULL OR group_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS cc_form_audience_form_idx  ON cc_form_audience(form_id);
CREATE INDEX IF NOT EXISTS cc_form_audience_user_idx  ON cc_form_audience(user_id);
CREATE INDEX IF NOT EXISTS cc_form_audience_group_idx ON cc_form_audience(group_id);

-- Steps within a form
CREATE TABLE IF NOT EXISTS cc_form_steps (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id     uuid NOT NULL REFERENCES cc_forms(id) ON DELETE CASCADE,
  order_index integer NOT NULL DEFAULT 0,
  title       text NOT NULL DEFAULT 'Step'
);

CREATE INDEX IF NOT EXISTS cc_form_steps_form_idx ON cc_form_steps(form_id, order_index);

-- Sections within a step
CREATE TABLE IF NOT EXISTS cc_form_sections (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  step_id     uuid NOT NULL REFERENCES cc_form_steps(id) ON DELETE CASCADE,
  order_index integer NOT NULL DEFAULT 0,
  title       text NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS cc_form_sections_step_idx ON cc_form_sections(step_id, order_index);

-- Fields within a section
-- config jsonb holds: grid_col_width(int), grid_row_height(int),
--   validation{required,min,max,...}, conditional_logic[],
--   options[], styling{}, placeholder, subtype, etc.
CREATE TABLE IF NOT EXISTS cc_form_fields (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  section_id  uuid NOT NULL REFERENCES cc_form_sections(id) ON DELETE CASCADE,
  field_type  text NOT NULL,
  order_index integer NOT NULL DEFAULT 0,
  label       text NOT NULL DEFAULT '',
  config      jsonb NOT NULL DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS cc_form_fields_section_idx ON cc_form_fields(section_id, order_index);

-- Submissions (one row per form submission)
-- submitted_by_user_id is always stored (even for anonymous) — hidden from app
CREATE TABLE IF NOT EXISTS cc_submissions (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id               uuid NOT NULL REFERENCES cc_forms(id) ON DELETE CASCADE,
  submitted_by_user_id  uuid REFERENCES users(id) ON DELETE SET NULL,  -- always stored
  is_anonymous          boolean NOT NULL DEFAULT false,
  device_mac            text,
  device_type           text,    -- 'mobile'|'tablet'|'desktop'|null
  status                text NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','resolved','misleading')),
  created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS cc_submissions_form_idx   ON cc_submissions(form_id, created_at DESC);
CREATE INDEX IF NOT EXISTS cc_submissions_user_idx   ON cc_submissions(submitted_by_user_id);
CREATE INDEX IF NOT EXISTS cc_submissions_status_idx ON cc_submissions(status);

-- Submission field values
CREATE TABLE IF NOT EXISTS cc_submission_values (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL REFERENCES cc_submissions(id) ON DELETE CASCADE,
  field_id      uuid NOT NULL REFERENCES cc_form_fields(id) ON DELETE CASCADE,
  value         jsonb
);

CREATE INDEX IF NOT EXISTS cc_sub_values_submission_idx ON cc_submission_values(submission_id);

-- Submission attachments
CREATE TABLE IF NOT EXISTS cc_submission_attachments (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL REFERENCES cc_submissions(id) ON DELETE CASCADE,
  field_id      uuid REFERENCES cc_form_fields(id) ON DELETE SET NULL,
  file_url      text NOT NULL,
  file_name     text NOT NULL,
  file_type     text,
  file_size     bigint,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS cc_sub_attachments_submission_idx ON cc_submission_attachments(submission_id);

-- Internal notes on a submission (creator-only, not visible to submitter)
CREATE TABLE IF NOT EXISTS cc_submission_notes (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL REFERENCES cc_submissions(id) ON DELETE CASCADE,
  author_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  note          text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS cc_sub_notes_submission_idx ON cc_submission_notes(submission_id);

-- ── Helper function that depends on tables ────────────────
-- Defined here (after cc_form_audience + cc_group_members exist) because
-- Postgres validates LANGUAGE sql bodies against live tables at CREATE time.

-- Returns true if the current authenticated user can access the given form
-- (directly in audience OR via a group they belong to)
CREATE OR REPLACE FUNCTION cc_user_can_access_form(p_form_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM cc_form_audience fa
    WHERE fa.form_id = p_form_id
      AND (
        fa.user_id = cc_current_user_id()
        OR fa.group_id IN (
          SELECT gm.group_id FROM cc_group_members gm
          WHERE gm.user_id = cc_current_user_id()
        )
      )
  );
$$;

-- ── updated_at trigger for cc_forms ──────────────────────

CREATE OR REPLACE FUNCTION cc_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS cc_forms_updated_at ON cc_forms;
CREATE TRIGGER cc_forms_updated_at
  BEFORE UPDATE ON cc_forms
  FOR EACH ROW EXECUTE FUNCTION cc_set_updated_at();

-- ── Row Level Security ─────────────────────────────────────

ALTER TABLE cc_groups             ENABLE ROW LEVEL SECURITY;
ALTER TABLE cc_group_members      ENABLE ROW LEVEL SECURITY;
ALTER TABLE cc_forms              ENABLE ROW LEVEL SECURITY;
ALTER TABLE cc_form_audience      ENABLE ROW LEVEL SECURITY;
ALTER TABLE cc_form_steps         ENABLE ROW LEVEL SECURITY;
ALTER TABLE cc_form_sections      ENABLE ROW LEVEL SECURITY;
ALTER TABLE cc_form_fields        ENABLE ROW LEVEL SECURITY;
ALTER TABLE cc_submissions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE cc_submission_values  ENABLE ROW LEVEL SECURITY;
ALTER TABLE cc_submission_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE cc_submission_notes   ENABLE ROW LEVEL SECURITY;

-- ── cc_groups policies ─────────────────────────────────────

CREATE POLICY cc_groups_select ON cc_groups FOR SELECT
  USING (owner_user_id = cc_current_user_id());

CREATE POLICY cc_groups_insert ON cc_groups FOR INSERT
  WITH CHECK (cc_is_creator() AND owner_user_id = cc_current_user_id());

CREATE POLICY cc_groups_update ON cc_groups FOR UPDATE
  USING (owner_user_id = cc_current_user_id());

CREATE POLICY cc_groups_delete ON cc_groups FOR DELETE
  USING (owner_user_id = cc_current_user_id());

-- ── cc_group_members policies ──────────────────────────────

CREATE POLICY cc_group_members_select ON cc_group_members FOR SELECT
  USING (group_id IN (SELECT id FROM cc_groups WHERE owner_user_id = cc_current_user_id()));

CREATE POLICY cc_group_members_insert ON cc_group_members FOR INSERT
  WITH CHECK (group_id IN (SELECT id FROM cc_groups WHERE owner_user_id = cc_current_user_id()));

CREATE POLICY cc_group_members_delete ON cc_group_members FOR DELETE
  USING (group_id IN (SELECT id FROM cc_groups WHERE owner_user_id = cc_current_user_id()));

-- ── cc_forms policies ─────────────────────────────────────

-- Creators see their own forms
CREATE POLICY cc_forms_select_owner ON cc_forms FOR SELECT
  USING (owner_user_id = cc_current_user_id());

-- Assigned users see forms they have access to
CREATE POLICY cc_forms_select_audience ON cc_forms FOR SELECT
  USING (is_active = true AND cc_user_can_access_form(id));

-- External: anyone can read a form with external_apply_enabled (needed for public URL)
CREATE POLICY cc_forms_select_external ON cc_forms FOR SELECT
  USING (is_active = true AND external_apply_enabled = true);

CREATE POLICY cc_forms_insert ON cc_forms FOR INSERT
  WITH CHECK (cc_is_creator() AND owner_user_id = cc_current_user_id());

CREATE POLICY cc_forms_update ON cc_forms FOR UPDATE
  USING (owner_user_id = cc_current_user_id());

CREATE POLICY cc_forms_delete ON cc_forms FOR DELETE
  USING (owner_user_id = cc_current_user_id());

-- ── cc_form_audience policies ─────────────────────────────

CREATE POLICY cc_form_audience_select ON cc_form_audience FOR SELECT
  USING (form_id IN (SELECT id FROM cc_forms WHERE owner_user_id = cc_current_user_id()));

CREATE POLICY cc_form_audience_insert ON cc_form_audience FOR INSERT
  WITH CHECK (form_id IN (SELECT id FROM cc_forms WHERE owner_user_id = cc_current_user_id()));

CREATE POLICY cc_form_audience_delete ON cc_form_audience FOR DELETE
  USING (form_id IN (SELECT id FROM cc_forms WHERE owner_user_id = cc_current_user_id()));

-- ── cc_form_steps policies ────────────────────────────────

CREATE POLICY cc_form_steps_select_owner ON cc_form_steps FOR SELECT
  USING (form_id IN (SELECT id FROM cc_forms WHERE owner_user_id = cc_current_user_id()));

CREATE POLICY cc_form_steps_select_audience ON cc_form_steps FOR SELECT
  USING (form_id IN (SELECT id FROM cc_forms WHERE is_active = true
    AND (cc_user_can_access_form(id) OR external_apply_enabled = true)));

CREATE POLICY cc_form_steps_insert ON cc_form_steps FOR INSERT
  WITH CHECK (form_id IN (SELECT id FROM cc_forms WHERE owner_user_id = cc_current_user_id()));

CREATE POLICY cc_form_steps_update ON cc_form_steps FOR UPDATE
  USING (form_id IN (SELECT id FROM cc_forms WHERE owner_user_id = cc_current_user_id()));

CREATE POLICY cc_form_steps_delete ON cc_form_steps FOR DELETE
  USING (form_id IN (SELECT id FROM cc_forms WHERE owner_user_id = cc_current_user_id()));

-- ── cc_form_sections policies ─────────────────────────────

CREATE POLICY cc_form_sections_select_owner ON cc_form_sections FOR SELECT
  USING (step_id IN (
    SELECT s.id FROM cc_form_steps s
    JOIN cc_forms f ON f.id = s.form_id
    WHERE f.owner_user_id = cc_current_user_id()
  ));

CREATE POLICY cc_form_sections_select_audience ON cc_form_sections FOR SELECT
  USING (step_id IN (
    SELECT s.id FROM cc_form_steps s
    JOIN cc_forms f ON f.id = s.form_id
    WHERE f.is_active = true
      AND (cc_user_can_access_form(f.id) OR f.external_apply_enabled = true)
  ));

CREATE POLICY cc_form_sections_insert ON cc_form_sections FOR INSERT
  WITH CHECK (step_id IN (
    SELECT s.id FROM cc_form_steps s
    JOIN cc_forms f ON f.id = s.form_id
    WHERE f.owner_user_id = cc_current_user_id()
  ));

CREATE POLICY cc_form_sections_update ON cc_form_sections FOR UPDATE
  USING (step_id IN (
    SELECT s.id FROM cc_form_steps s
    JOIN cc_forms f ON f.id = s.form_id
    WHERE f.owner_user_id = cc_current_user_id()
  ));

CREATE POLICY cc_form_sections_delete ON cc_form_sections FOR DELETE
  USING (step_id IN (
    SELECT s.id FROM cc_form_steps s
    JOIN cc_forms f ON f.id = s.form_id
    WHERE f.owner_user_id = cc_current_user_id()
  ));

-- ── cc_form_fields policies ───────────────────────────────

CREATE POLICY cc_form_fields_select_owner ON cc_form_fields FOR SELECT
  USING (section_id IN (
    SELECT sc.id FROM cc_form_sections sc
    JOIN cc_form_steps st ON st.id = sc.step_id
    JOIN cc_forms f ON f.id = st.form_id
    WHERE f.owner_user_id = cc_current_user_id()
  ));

CREATE POLICY cc_form_fields_select_audience ON cc_form_fields FOR SELECT
  USING (section_id IN (
    SELECT sc.id FROM cc_form_sections sc
    JOIN cc_form_steps st ON st.id = sc.step_id
    JOIN cc_forms f ON f.id = st.form_id
    WHERE f.is_active = true
      AND (cc_user_can_access_form(f.id) OR f.external_apply_enabled = true)
  ));

CREATE POLICY cc_form_fields_insert ON cc_form_fields FOR INSERT
  WITH CHECK (section_id IN (
    SELECT sc.id FROM cc_form_sections sc
    JOIN cc_form_steps st ON st.id = sc.step_id
    JOIN cc_forms f ON f.id = st.form_id
    WHERE f.owner_user_id = cc_current_user_id()
  ));

CREATE POLICY cc_form_fields_update ON cc_form_fields FOR UPDATE
  USING (section_id IN (
    SELECT sc.id FROM cc_form_sections sc
    JOIN cc_form_steps st ON st.id = sc.step_id
    JOIN cc_forms f ON f.id = st.form_id
    WHERE f.owner_user_id = cc_current_user_id()
  ));

CREATE POLICY cc_form_fields_delete ON cc_form_fields FOR DELETE
  USING (section_id IN (
    SELECT sc.id FROM cc_form_sections sc
    JOIN cc_form_steps st ON st.id = sc.step_id
    JOIN cc_forms f ON f.id = st.form_id
    WHERE f.owner_user_id = cc_current_user_id()
  ));

-- ── cc_submissions policies ───────────────────────────────

-- Form owner sees all submissions for their forms
CREATE POLICY cc_submissions_select_owner ON cc_submissions FOR SELECT
  USING (form_id IN (SELECT id FROM cc_forms WHERE owner_user_id = cc_current_user_id()));

-- Submitter sees their own submission
CREATE POLICY cc_submissions_select_self ON cc_submissions FOR SELECT
  USING (submitted_by_user_id = cc_current_user_id());

-- Insert: user must have form access OR form has external_apply_enabled
CREATE POLICY cc_submissions_insert ON cc_submissions FOR INSERT
  WITH CHECK (
    form_id IN (
      SELECT id FROM cc_forms
      WHERE is_active = true
        AND (external_apply_enabled = true OR cc_user_can_access_form(id))
    )
  );

-- Only owner can update submission status
CREATE POLICY cc_submissions_update ON cc_submissions FOR UPDATE
  USING (form_id IN (SELECT id FROM cc_forms WHERE owner_user_id = cc_current_user_id()));

-- ── cc_submission_values policies ─────────────────────────

CREATE POLICY cc_sub_values_select ON cc_submission_values FOR SELECT
  USING (
    submission_id IN (
      SELECT id FROM cc_submissions
      WHERE form_id IN (SELECT id FROM cc_forms WHERE owner_user_id = cc_current_user_id())
         OR submitted_by_user_id = cc_current_user_id()
    )
  );

CREATE POLICY cc_sub_values_insert ON cc_submission_values FOR INSERT
  WITH CHECK (
    submission_id IN (
      SELECT id FROM cc_submissions WHERE submitted_by_user_id = cc_current_user_id()
    )
    -- allow anonymous/external (submitted_by_user_id is null for external)
    OR submission_id IN (
      SELECT s.id FROM cc_submissions s
      JOIN cc_forms f ON f.id = s.form_id
      WHERE f.external_apply_enabled = true AND s.submitted_by_user_id IS NULL
    )
  );

-- ── cc_submission_attachments policies ────────────────────

CREATE POLICY cc_sub_attachments_select ON cc_submission_attachments FOR SELECT
  USING (
    submission_id IN (
      SELECT id FROM cc_submissions
      WHERE form_id IN (SELECT id FROM cc_forms WHERE owner_user_id = cc_current_user_id())
         OR submitted_by_user_id = cc_current_user_id()
    )
  );

CREATE POLICY cc_sub_attachments_insert ON cc_submission_attachments FOR INSERT
  WITH CHECK (
    submission_id IN (
      SELECT id FROM cc_submissions WHERE submitted_by_user_id = cc_current_user_id()
    )
    OR submission_id IN (
      SELECT s.id FROM cc_submissions s
      JOIN cc_forms f ON f.id = s.form_id
      WHERE f.external_apply_enabled = true AND s.submitted_by_user_id IS NULL
    )
  );

-- ── cc_submission_notes policies ─────────────────────────

CREATE POLICY cc_sub_notes_select ON cc_submission_notes FOR SELECT
  USING (
    submission_id IN (
      SELECT id FROM cc_submissions
      WHERE form_id IN (SELECT id FROM cc_forms WHERE owner_user_id = cc_current_user_id())
    )
  );

CREATE POLICY cc_sub_notes_insert ON cc_submission_notes FOR INSERT
  WITH CHECK (
    author_user_id = cc_current_user_id()
    AND submission_id IN (
      SELECT id FROM cc_submissions
      WHERE form_id IN (SELECT id FROM cc_forms WHERE owner_user_id = cc_current_user_id())
    )
  );

CREATE POLICY cc_sub_notes_update ON cc_submission_notes FOR UPDATE
  USING (author_user_id = cc_current_user_id());

CREATE POLICY cc_sub_notes_delete ON cc_submission_notes FOR DELETE
  USING (author_user_id = cc_current_user_id());

-- ── Storage buckets ───────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
  VALUES ('cc_logos', 'cc_logos', true),
         ('cc_attachments', 'cc_attachments', false)
ON CONFLICT DO NOTHING;

-- ── Storage RLS policies ───────────────────────────────────
-- cc_logos (public bucket): reads are open; only creators may write.
-- Paths: logos/{formId}/... and screens/{formId}/...

CREATE POLICY "cc_logos_select" ON storage.objects FOR SELECT
  USING (bucket_id = 'cc_logos');

CREATE POLICY "cc_logos_insert" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'cc_logos' AND cc_is_creator());

-- upsert requires an UPDATE policy as well as INSERT
CREATE POLICY "cc_logos_update" ON storage.objects FOR UPDATE
  USING (bucket_id = 'cc_logos' AND cc_is_creator());

CREATE POLICY "cc_logos_delete" ON storage.objects FOR DELETE
  USING (bucket_id = 'cc_logos' AND cc_is_creator());

-- cc_attachments (private bucket): authenticated users and anon (external
-- submissions) may write; only authenticated users may read.
-- Paths: submissions/{submissionId}/{fieldId}/...

CREATE POLICY "cc_attachments_select" ON storage.objects FOR SELECT
  USING (bucket_id = 'cc_attachments' AND auth.role() = 'authenticated');

CREATE POLICY "cc_attachments_insert" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'cc_attachments' AND auth.role() IN ('authenticated', 'anon'));

CREATE POLICY "cc_attachments_update" ON storage.objects FOR UPDATE
  USING (bucket_id = 'cc_attachments' AND auth.role() IN ('authenticated', 'anon'));
