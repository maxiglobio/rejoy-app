-- Enable Realtime for active_tracking_state so clients receive INSERT/DELETE events.
-- Run in Supabase Dashboard → SQL Editor (or Database → Publications → supabase_realtime).
-- If the table is already in the publication, this will error; that's fine.
alter publication supabase_realtime add table public.active_tracking_state;
