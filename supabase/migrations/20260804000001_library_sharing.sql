-- Library sharing: a folder or file owner can share it with another user
-- at 'view' (read-only) or 'edit' (can rename/add files, not delete) level.
-- Sharing a folder implicitly shares everything nested inside it — the two
-- helper functions below walk the folder's ancestor chain so a file/folder
-- deep inside a shared tree is reachable without being individually shared.

CREATE TABLE IF NOT EXISTS library_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  file_id uuid REFERENCES library_files(id) ON DELETE CASCADE,
  folder_id uuid REFERENCES library_folders(id) ON DELETE CASCADE,
  shared_by_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  shared_with_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  permission text NOT NULL DEFAULT 'view' CHECK (permission IN ('view', 'edit')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT library_shares_one_resource CHECK (
    (file_id IS NOT NULL AND folder_id IS NULL) OR (file_id IS NULL AND folder_id IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_library_shares_file_unique
  ON library_shares(file_id, shared_with_user_id) WHERE file_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_library_shares_folder_unique
  ON library_shares(folder_id, shared_with_user_id) WHERE folder_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_library_shares_shared_with ON library_shares(shared_with_user_id);

ALTER TABLE library_shares ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Owners manage shares they created"
  ON library_shares FOR ALL USING (
    shared_by_user_id IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Recipients can see shares made to them"
  ON library_shares FOR SELECT USING (
    shared_with_user_id IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Highest permission ('edit' beats 'view') granted to p_user_id via a share
-- on p_folder_id or ANY of its ancestors. Null p_folder_id (root) -> null.
CREATE OR REPLACE FUNCTION library_folder_chain_permission(p_folder_id uuid, p_user_id uuid)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  WITH RECURSIVE chain AS (
    SELECT id, parent_folder_id FROM library_folders WHERE id = p_folder_id
    UNION ALL
    SELECT f.id, f.parent_folder_id
    FROM library_folders f
    INNER JOIN chain c ON f.id = c.parent_folder_id
  )
  SELECT CASE
    WHEN EXISTS (
      SELECT 1 FROM library_shares s
      WHERE s.folder_id IN (SELECT id FROM chain) AND s.shared_with_user_id = p_user_id AND s.permission = 'edit'
    ) THEN 'edit'
    WHEN EXISTS (
      SELECT 1 FROM library_shares s
      WHERE s.folder_id IN (SELECT id FROM chain) AND s.shared_with_user_id = p_user_id
    ) THEN 'view'
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION library_file_permission(p_file_id uuid, p_user_id uuid)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT permission FROM library_shares
  WHERE file_id = p_file_id AND shared_with_user_id = p_user_id
  ORDER BY (permission = 'edit') DESC
  LIMIT 1;
$$;

-- ── library_folders: shared access on top of the existing owner-only policy ──
DO $$ BEGIN
  CREATE POLICY "Shared users can view shared library folders"
  ON library_folders FOR SELECT USING (
    library_folder_chain_permission(id, (SELECT users.id FROM users WHERE users.auth_id = auth.uid())) IS NOT NULL
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Shared editors can update shared library folders"
  ON library_folders FOR UPDATE USING (
    library_folder_chain_permission(id, (SELECT users.id FROM users WHERE users.auth_id = auth.uid())) = 'edit'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Shared editors can create subfolders in shared library folders"
  ON library_folders FOR INSERT WITH CHECK (
    parent_folder_id IS NOT NULL
    AND library_folder_chain_permission(parent_folder_id, (SELECT users.id FROM users WHERE users.auth_id = auth.uid())) = 'edit'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── library_files: shared access on top of the existing owner-only policy ────
DO $$ BEGIN
  CREATE POLICY "Shared users can view shared library files"
  ON library_files FOR SELECT USING (
    library_file_permission(id, (SELECT users.id FROM users WHERE users.auth_id = auth.uid())) IS NOT NULL
    OR library_folder_chain_permission(folder_id, (SELECT users.id FROM users WHERE users.auth_id = auth.uid())) IS NOT NULL
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Shared editors can update shared library files"
  ON library_files FOR UPDATE USING (
    library_file_permission(id, (SELECT users.id FROM users WHERE users.auth_id = auth.uid())) = 'edit'
    OR library_folder_chain_permission(folder_id, (SELECT users.id FROM users WHERE users.auth_id = auth.uid())) = 'edit'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Shared editors can add files to shared library folders"
  ON library_files FOR INSERT WITH CHECK (
    folder_id IS NOT NULL
    AND library_folder_chain_permission(folder_id, (SELECT users.id FROM users WHERE users.auth_id = auth.uid())) = 'edit'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Marks a ticket attachment as sourced from a library file, so the ticket
-- can show "attached from library, shared with: ..." — the actual share
-- records live in library_shares (queried by library_file_id).
ALTER TABLE ticket_attachments ADD COLUMN IF NOT EXISTS library_file_id uuid REFERENCES library_files(id) ON DELETE SET NULL;
