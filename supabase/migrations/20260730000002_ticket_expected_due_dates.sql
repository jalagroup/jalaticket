-- Expected due date: the creator sets one when creating a ticket, and the
-- admin working on it can separately set/update their own — both shown in
-- ticket info.
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS creator_due_date timestamptz;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS assignee_due_date timestamptz;
