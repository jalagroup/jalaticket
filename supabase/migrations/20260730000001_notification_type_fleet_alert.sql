-- 'fleet_alert' is used as the notifications.type value for fleet vehicle
-- warning notifications (lib/fleet/fleet_notify.dart) but was never added to
-- the notification_type enum, so every fleet alert insert was silently
-- failing (22P02) — push/email still went out (they don't depend on this
-- insert succeeding), but no in-app notification row was ever created.
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'fleet_alert';
