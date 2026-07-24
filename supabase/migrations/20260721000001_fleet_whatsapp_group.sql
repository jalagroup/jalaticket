-- Lets a fleet manager route WhatsApp alerts for a vehicle to a group/dispatch
-- number instead of the driver directly. When set, openFleetVehicleWhatsApp
-- (lib/fleet/fleet_whatsapp.dart) sends there instead, with driver + vehicle
-- details folded into the message body so recipients still have context.
ALTER TABLE fleet_vehicles ADD COLUMN IF NOT EXISTS whatsapp_group_number text;
