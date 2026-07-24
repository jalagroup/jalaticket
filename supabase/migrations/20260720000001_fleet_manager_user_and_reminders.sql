-- Fleet: direct manager becomes a linked system user (mirrors driver_user_id),
-- and a generated service_due flag so the Smart Reminders engine can alert on
-- odometer-based service due without needing to compare two columns.

ALTER TABLE fleet_vehicles
  ADD COLUMN IF NOT EXISTS manager_user_id uuid REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE fleet_vehicles DROP COLUMN IF EXISTS manager_name;
ALTER TABLE fleet_vehicles DROP COLUMN IF EXISTS manager_phone;

ALTER TABLE fleet_vehicles ADD COLUMN IF NOT EXISTS service_due boolean
  GENERATED ALWAYS AS (current_odometer >= (next_service_odometer - service_alert_km)) STORED;

-- Generic addition (benefits every reminder, not just fleet ones): the
-- reminders engine can now write real in-app notification rows, which
-- needs 'reminder' as a valid notification_type value.
DO $$ BEGIN
  ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'reminder';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
