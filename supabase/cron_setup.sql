-- cron_setup.sql
-- EZ2 fetch-today cron jobs
-- Fire every 5 minutes during each draw window (2PM / 5PM / 9PM PHT)
-- PHT = UTC+8, so subtract 8 hours for UTC cron times
-- Draw window: draw time → +35 min (sites publish within 5–30 min)

-- Remove old jobs first
SELECT cron.unschedule('ez2-fetch-2pm-1');
SELECT cron.unschedule('ez2-fetch-2pm-2');
SELECT cron.unschedule('ez2-fetch-2pm-3');
SELECT cron.unschedule('ez2-fetch-2pm-4');
SELECT cron.unschedule('ez2-fetch-2pm-5');
SELECT cron.unschedule('ez2-fetch-2pm-6');
SELECT cron.unschedule('ez2-fetch-2pm-7');
SELECT cron.unschedule('ez2-fetch-5pm-1');
SELECT cron.unschedule('ez2-fetch-5pm-2');
SELECT cron.unschedule('ez2-fetch-5pm-3');
SELECT cron.unschedule('ez2-fetch-5pm-4');
SELECT cron.unschedule('ez2-fetch-5pm-5');
SELECT cron.unschedule('ez2-fetch-5pm-6');
SELECT cron.unschedule('ez2-fetch-5pm-7');
SELECT cron.unschedule('ez2-fetch-9pm-1');
SELECT cron.unschedule('ez2-fetch-9pm-2');
SELECT cron.unschedule('ez2-fetch-9pm-3');
SELECT cron.unschedule('ez2-fetch-9pm-4');
SELECT cron.unschedule('ez2-fetch-9pm-5');
SELECT cron.unschedule('ez2-fetch-9pm-6');
SELECT cron.unschedule('ez2-fetch-9pm-7');

-- ── 2PM PHT draw (6:00 UTC) — fire at :00, :05, :10, :15, :20, :25, :30, :35 ──
SELECT cron.schedule('ez2-fetch-2pm-1', '0 6 * * *',    $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-2pm-2', '5 6 * * *',    $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-2pm-3', '10 6 * * *',   $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-2pm-4', '15 6 * * *',   $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-2pm-5', '20 6 * * *',   $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-2pm-6', '25 6 * * *',   $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-2pm-7', '30 6 * * *',   $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);

-- ── 5PM PHT draw (9:00 UTC) — fire at :00, :05, :10, :15, :20, :25, :30, :35 ──
SELECT cron.schedule('ez2-fetch-5pm-1', '0 9 * * *',    $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-5pm-2', '5 9 * * *',    $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-5pm-3', '10 9 * * *',   $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-5pm-4', '15 9 * * *',   $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-5pm-5', '20 9 * * *',   $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-5pm-6', '25 9 * * *',   $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-5pm-7', '30 9 * * *',   $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);

-- ── 9PM PHT draw (13:00 UTC) — fire at :00, :05, :10, :15, :20, :25, :30, :35 ──
SELECT cron.schedule('ez2-fetch-9pm-1', '0 13 * * *',   $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-9pm-2', '5 13 * * *',   $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-9pm-3', '10 13 * * *',  $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-9pm-4', '15 13 * * *',  $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-9pm-5', '20 13 * * *',  $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-9pm-6', '25 13 * * *',  $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);
SELECT cron.schedule('ez2-fetch-9pm-7', '30 13 * * *',  $$SELECT net.http_post(url:=current_setting('app.supabase_url') || '/functions/v1/fetch-today', headers:='{"Authorization":"Bearer " || current_setting(''app.service_role_key'')}'::jsonb, body:='{}'::jsonb)$$);