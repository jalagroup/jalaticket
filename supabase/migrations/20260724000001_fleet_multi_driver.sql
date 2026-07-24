CREATE TABLE fleet_vehicle_drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES fleet_vehicles(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(vehicle_id, user_id)
);

-- Backfill existing single-driver assignments before dropping the old column.
INSERT INTO fleet_vehicle_drivers (vehicle_id, user_id, is_primary)
  SELECT id, driver_user_id, true FROM fleet_vehicles WHERE driver_user_id IS NOT NULL;

ALTER TABLE fleet_vehicles DROP COLUMN IF EXISTS driver_user_id;

ALTER TABLE fleet_vehicle_drivers ENABLE ROW LEVEL SECURITY;

-- fleet-access admins manage all rows for vehicles in their department(s)
CREATE POLICY "fleet_drivers_manage" ON fleet_vehicle_drivers FOR ALL
  USING (EXISTS (SELECT 1 FROM fleet_vehicles v WHERE v.id = vehicle_id AND fleet_user_can_access(v.department_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM fleet_vehicles v WHERE v.id = vehicle_id AND fleet_user_can_access(v.department_id)));

-- any user can see their own driver assignments (for "My Vehicles")
CREATE POLICY "fleet_drivers_self_select" ON fleet_vehicle_drivers FOR SELECT
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Assigned drivers can also read the vehicle itself (not just fleet-access admins)
CREATE POLICY "fleet_vehicles_driver_select" ON fleet_vehicles FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM fleet_vehicle_drivers d
    JOIN users u ON u.id = d.user_id
    WHERE d.vehicle_id = fleet_vehicles.id AND u.auth_id = auth.uid()
  ));
