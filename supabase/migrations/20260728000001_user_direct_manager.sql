ALTER TABLE users ADD COLUMN IF NOT EXISTS direct_manager_id uuid REFERENCES users(id) ON DELETE SET NULL;

-- Replaced by the system-wide direct-manager concept above: a vehicle no
-- longer has its own manager, notifications instead go to each driver's
-- direct manager (see fleet_notify.dart / execute-reminder's
-- also_notify_managers).
ALTER TABLE fleet_vehicles DROP COLUMN IF EXISTS manager_user_id;
