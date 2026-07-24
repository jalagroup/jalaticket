-- ================================================================
-- Fix: authenticated users submitting an EXTERNAL form anonymously
-- (submitted_by_user_id IS NULL) could not read back their own row
-- after INSERT, because cc_submissions_select_anon_own was scoped
-- TO anon only. The app's createSubmission() does
-- .insert(...).select().single(), which requires Postgres to be
-- able to SELECT the row it just inserted (RETURNING) — with no
-- matching SELECT policy, this failed with:
--   "new row violates row-level security policy for table cc_submissions"
-- (PostgrestException code 42501), even though the INSERT itself
-- was permitted by cc_submissions_insert.
--
-- This hits real users specifically when they open a public/external
-- form link (e.g. /c/submit/{formId}) while already having a live
-- authenticated app session in the same browser — the request is
-- sent as `authenticated`, not `anon`, so the anon-only policy never
-- applied even though the submission itself is legitimately anonymous.
--
-- Fix: an anonymous submission on an externally-enabled form carries
-- no identifying data by design, so allowing any role (not just anon)
-- to read it back is safe and matches the anonymous-submission intent.
-- ================================================================

DROP POLICY IF EXISTS cc_submissions_select_anon_own ON cc_submissions;

CREATE POLICY cc_submissions_select_anon_own ON cc_submissions
  FOR SELECT
  USING (submitted_by_user_id IS NULL AND cc_form_is_external(form_id));
