-- Personal file library: every user gets their own library of uploaded
-- files, shareable via a public link (no login) that stays live until the
-- owner revokes/regenerates it, and attachable to any ticket they can see.

-- ── 1. Storage bucket (public = true so shared links need no auth) ────────
-- 200MB per file — raised specifically for this bucket (not project-wide)
-- since large design/media files are the whole point of a library.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'file_library',
  'file_library',
  true,
  209715200,  -- 200 MB per file
  NULL        -- allow all mime types
)
ON CONFLICT (id) DO UPDATE SET public = true, file_size_limit = 209715200;

-- Files are stored at library/{owner_user_id}/{random-uuid}_{filename} —
-- only the owner (matched via the first path segment) may write/delete.
DO $$ BEGIN
  CREATE POLICY "file_library_owner_insert"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
      bucket_id = 'file_library'
      AND (storage.foldername(name))[1] IN (SELECT users.id::text FROM users WHERE users.auth_id = auth.uid())
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "file_library_owner_delete"
    ON storage.objects FOR DELETE TO authenticated
    USING (
      bucket_id = 'file_library'
      AND (storage.foldername(name))[1] IN (SELECT users.id::text FROM users WHERE users.auth_id = auth.uid())
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "file_library_public_select"
    ON storage.objects FOR SELECT TO public
    USING (bucket_id = 'file_library');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 2. library_files: metadata + ownership, drives the UI list ────────────
CREATE TABLE IF NOT EXISTS library_files (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  file_path text NOT NULL,
  file_size bigint,
  mime_type text,
  is_shared boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE library_files ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own library files"
ON library_files FOR ALL USING (
  owner_user_id IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
);
