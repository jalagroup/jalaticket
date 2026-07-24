CREATE TABLE fleet_vehicle_checkins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES fleet_vehicles(id) ON DELETE CASCADE,
  driver_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  type TEXT NOT NULL, -- 'check_in' | 'check_out'
  odometer INTEGER NOT NULL,
  photo_url TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE fleet_vehicle_checkins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fleet_checkins_manage" ON fleet_vehicle_checkins FOR ALL
  USING (EXISTS (SELECT 1 FROM fleet_vehicles v WHERE v.id = vehicle_id AND fleet_user_can_access(v.department_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM fleet_vehicles v WHERE v.id = vehicle_id AND fleet_user_can_access(v.department_id)));

CREATE POLICY "fleet_checkins_driver_insert" ON fleet_vehicle_checkins FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM fleet_vehicle_drivers d JOIN users u ON u.id = d.user_id
    WHERE d.vehicle_id = fleet_vehicle_checkins.vehicle_id AND u.auth_id = auth.uid()
  ));

CREATE POLICY "fleet_checkins_driver_select" ON fleet_vehicle_checkins FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM fleet_vehicle_drivers d JOIN users u ON u.id = d.user_id
    WHERE d.vehicle_id = fleet_vehicle_checkins.vehicle_id AND u.auth_id = auth.uid()
  ));

-- Keep current_odometer (and therefore the service_due generated column) fresh
-- from the latest check-in/out, satisfying "must update العداد every day".
CREATE OR REPLACE FUNCTION sync_vehicle_odometer_from_checkin() RETURNS TRIGGER AS $$
BEGIN
  UPDATE fleet_vehicles SET current_odometer = NEW.odometer, updated_at = NOW() WHERE id = NEW.vehicle_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_sync_vehicle_odometer AFTER INSERT ON fleet_vehicle_checkins
  FOR EACH ROW EXECUTE FUNCTION sync_vehicle_odometer_from_checkin();

INSERT INTO storage.buckets (id, name, public, file_size_limit)
  VALUES ('fleet_checkin_photos', 'fleet_checkin_photos', true, 20971520)
  ON CONFLICT (id) DO UPDATE SET public = true;

CREATE POLICY "fleet_checkin_photos_select" ON storage.objects FOR SELECT
  USING (bucket_id = 'fleet_checkin_photos');

CREATE POLICY "fleet_checkin_photos_insert" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'fleet_checkin_photos');
