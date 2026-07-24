-- ================================================================
-- CC: Storage bucket + policies for submission attachments
-- ================================================================

-- ── 1. Create cc_attachments bucket (public = true so getPublicUrl works) ──
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'cc_attachments',
  'cc_attachments',
  true,
  52428800,   -- 50 MB per file
  NULL        -- allow all mime types
)
ON CONFLICT (id) DO UPDATE SET public = true;

-- ── 2. Anon INSERT: anonymous users may upload under submissions/ ─────────
DO $$ BEGIN
  CREATE POLICY "cc_attachments_anon_insert"
    ON storage.objects FOR INSERT TO anon
    WITH CHECK (
      bucket_id = 'cc_attachments'
      AND (storage.foldername(name))[1] = 'submissions'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 3. Auth INSERT: authenticated users may upload under submissions/ ─────
DO $$ BEGIN
  CREATE POLICY "cc_attachments_auth_insert"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
      bucket_id = 'cc_attachments'
      AND (storage.foldername(name))[1] = 'submissions'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 4. Public SELECT: anyone may read (bucket is public anyway) ───────────
DO $$ BEGIN
  CREATE POLICY "cc_attachments_public_select"
    ON storage.objects FOR SELECT TO public
    USING (bucket_id = 'cc_attachments');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 5. Auth DELETE: authenticated users may delete their own uploads ──────
DO $$ BEGIN
  CREATE POLICY "cc_attachments_auth_delete"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'cc_attachments');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
