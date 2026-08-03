-- Folders inside the personal file library — lets a user organize files
-- into a nested tree (create/rename/move), instead of one flat file list.

CREATE TABLE IF NOT EXISTS library_folders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parent_folder_id uuid REFERENCES library_folders(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE library_folders ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Users manage their own library folders"
  ON library_folders FOR ALL USING (
    owner_user_id IN (SELECT users.id FROM users WHERE users.auth_id = auth.uid())
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_library_folders_parent ON library_folders(parent_folder_id);
CREATE INDEX IF NOT EXISTS idx_library_folders_owner ON library_folders(owner_user_id);

-- Files can now optionally live inside a folder — NULL means the library root.
ALTER TABLE library_files ADD COLUMN IF NOT EXISTS folder_id uuid REFERENCES library_folders(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_library_files_folder ON library_files(folder_id);
