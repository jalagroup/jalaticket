-- ================================================================
-- Fleet Vehicle Management module
-- ================================================================
-- New module: vehicles + parts with mileage/date-based maintenance
-- alerts. Access is department-gated: a system_admin flips
-- departments.fleet_access_enabled on for specific departments, and
-- a super_admin can only see/manage vehicles for a department if
-- they're assigned to it (admin_departments) AND that department has
-- fleet access enabled.

CREATE TABLE IF NOT EXISTS fleet_vehicles (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_number          text NOT NULL,
  vehicle_type            text DEFAULT '',
  manufacturer            text DEFAULT '',
  current_odometer        int NOT NULL DEFAULT 0,
  next_service_odometer   int NOT NULL DEFAULT 10000,
  service_alert_km        int NOT NULL DEFAULT 8000,
  license_expiry          date,
  insurance_expiry        date,
  insurance_start         date,
  tachograph_expiry       date,
  winter_inspection_date  date,
  driver_user_id          uuid REFERENCES users(id) ON DELETE SET NULL,
  manager_name            text DEFAULT '',
  manager_phone           text DEFAULT '',
  work_area               text DEFAULT '',
  department_id           uuid NOT NULL REFERENCES departments(id) ON DELETE RESTRICT,
  created_by              uuid REFERENCES users(id),
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS fleet_vehicles_department_idx ON fleet_vehicles(department_id);
CREATE INDEX IF NOT EXISTS fleet_vehicles_driver_idx ON fleet_vehicles(driver_user_id);

CREATE TABLE IF NOT EXISTS fleet_vehicle_parts (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id              uuid NOT NULL REFERENCES fleet_vehicles(id) ON DELETE CASCADE,
  part_name               text NOT NULL,
  installed_at_odometer   int NOT NULL DEFAULT 0,
  alert_km                int NOT NULL DEFAULT 10000,
  last_checked_odometer   int NOT NULL DEFAULT 0,
  status                  text NOT NULL DEFAULT 'good',
  notes                   text DEFAULT '',
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS fleet_vehicle_parts_vehicle_idx ON fleet_vehicle_parts(vehicle_id);

ALTER TABLE departments ADD COLUMN IF NOT EXISTS fleet_access_enabled boolean NOT NULL DEFAULT false;

-- Helper: can the current caller manage fleet vehicles for this department?
CREATE OR REPLACE FUNCTION fleet_user_can_access(dept_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE auth_id = auth.uid() AND user_type = 'system_admin'
  ) OR EXISTS (
    SELECT 1 FROM admin_departments ad
    JOIN users u ON u.id = ad.admin_id
    JOIN departments d ON d.id = ad.department_id
    WHERE u.auth_id = auth.uid()
      AND ad.department_id = dept_id
      AND d.fleet_access_enabled = true
  );
$$;

ALTER TABLE fleet_vehicles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY fleet_vehicles_select ON fleet_vehicles FOR SELECT TO authenticated
    USING (fleet_user_can_access(department_id));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY fleet_vehicles_insert ON fleet_vehicles FOR INSERT TO authenticated
    WITH CHECK (fleet_user_can_access(department_id));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY fleet_vehicles_update ON fleet_vehicles FOR UPDATE TO authenticated
    USING (fleet_user_can_access(department_id))
    WITH CHECK (fleet_user_can_access(department_id));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY fleet_vehicles_delete ON fleet_vehicles FOR DELETE TO authenticated
    USING (fleet_user_can_access(department_id));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE fleet_vehicle_parts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY fleet_vehicle_parts_select ON fleet_vehicle_parts FOR SELECT TO authenticated
    USING (EXISTS (
      SELECT 1 FROM fleet_vehicles v WHERE v.id = vehicle_id AND fleet_user_can_access(v.department_id)
    ));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY fleet_vehicle_parts_insert ON fleet_vehicle_parts FOR INSERT TO authenticated
    WITH CHECK (EXISTS (
      SELECT 1 FROM fleet_vehicles v WHERE v.id = vehicle_id AND fleet_user_can_access(v.department_id)
    ));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY fleet_vehicle_parts_update ON fleet_vehicle_parts FOR UPDATE TO authenticated
    USING (EXISTS (
      SELECT 1 FROM fleet_vehicles v WHERE v.id = vehicle_id AND fleet_user_can_access(v.department_id)
    ))
    WITH CHECK (EXISTS (
      SELECT 1 FROM fleet_vehicles v WHERE v.id = vehicle_id AND fleet_user_can_access(v.department_id)
    ));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY fleet_vehicle_parts_delete ON fleet_vehicle_parts FOR DELETE TO authenticated
    USING (EXISTS (
      SELECT 1 FROM fleet_vehicles v WHERE v.id = vehicle_id AND fleet_user_can_access(v.department_id)
    ));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
