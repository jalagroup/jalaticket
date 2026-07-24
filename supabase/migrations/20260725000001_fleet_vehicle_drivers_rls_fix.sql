-- Fixes "infinite recursion detected in policy for relation
-- fleet_vehicle_drivers" (42P17): the SELECT policy added on fleet_vehicles
-- for assigned drivers queried fleet_vehicle_drivers directly, and the
-- manage policy on fleet_vehicle_drivers queried fleet_vehicles directly —
-- each table's RLS check triggered the other table's RLS check, forever.
--
-- Fix: move each cross-table lookup into its own SECURITY DEFINER function
-- (same pattern as the existing fleet_user_can_access), so a policy on one
-- table never causes Postgres to re-evaluate RLS on the other table.

CREATE OR REPLACE FUNCTION fleet_vehicle_department(p_vehicle_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT department_id FROM fleet_vehicles WHERE id = p_vehicle_id;
$$;

CREATE OR REPLACE FUNCTION fleet_is_driver_of_vehicle(p_vehicle_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM fleet_vehicle_drivers d
    JOIN users u ON u.id = d.user_id
    WHERE d.vehicle_id = p_vehicle_id AND u.auth_id = auth.uid()
  );
$$;

DROP POLICY IF EXISTS "fleet_drivers_manage" ON fleet_vehicle_drivers;
CREATE POLICY "fleet_drivers_manage" ON fleet_vehicle_drivers FOR ALL
  USING (fleet_user_can_access(fleet_vehicle_department(vehicle_id)))
  WITH CHECK (fleet_user_can_access(fleet_vehicle_department(vehicle_id)));

DROP POLICY IF EXISTS "fleet_vehicles_driver_select" ON fleet_vehicles;
CREATE POLICY "fleet_vehicles_driver_select" ON fleet_vehicles FOR SELECT
  USING (fleet_is_driver_of_vehicle(id));

DROP POLICY IF EXISTS "fleet_checkins_driver_insert" ON fleet_vehicle_checkins;
CREATE POLICY "fleet_checkins_driver_insert" ON fleet_vehicle_checkins FOR INSERT
  WITH CHECK (fleet_is_driver_of_vehicle(vehicle_id));

DROP POLICY IF EXISTS "fleet_checkins_driver_select" ON fleet_vehicle_checkins;
CREATE POLICY "fleet_checkins_driver_select" ON fleet_vehicle_checkins FOR SELECT
  USING (fleet_is_driver_of_vehicle(vehicle_id));
