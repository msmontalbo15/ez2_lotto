-- =============================================================================
-- cron_setup.sql
-- EZ2 Lotto - fetch-today cron jobs setup
-- =============================================================================
-- Schedule: Fire every 5 minutes during each draw window (2PM / 5PM / 9PM PHT)
-- PHT (Philippine Time) = UTC+8, so subtract 8 hours for UTC cron times
-- Draw window: draw time → +35 min (sites publish within 5–30 min)
-- Combo fetch: 20, 25, 30 minutes after draw (3 jobs per draw)
-- Winners fetch: Only at end of day (after 9:35 PM PHT) - handled by edge function
-- =============================================================================

BEGIN;

-- =============================================================================
-- STEP 1: Create helper function to reduce code duplication
-- =============================================================================
CREATE OR REPLACE FUNCTION ez2_fetch_today()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_url TEXT;
    v_headers JSONB;
    v_body JSONB := '{}'::jsonb;
    v_response RECORD;
BEGIN
    -- Build URL and headers once
    v_url := current_setting('app.supabase_url', true) || '/functions/v1/fetch-today';
    v_headers := (
        'Authorization'::TEXT,
        'Bearer ' || current_setting('app.service_role_key', true)
    )::JSONB;

    -- Execute HTTP POST with error handling
    PERFORM net.http_post(
        url := v_url,
        headers := v_headers,
        body := v_body
    );

    RAISE NOTICE 'EZ2 fetch-today executed successfully at %', now();

EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the cron job
        RAISE WARNING 'EZ2 fetch-today failed: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END;
$;

-- =============================================================================
-- STEP 2: Helper function to unschedule job safely (idempotent)
-- =============================================================================
CREATE OR REPLACE FUNCTION safe_unschedule(job_name TEXT)
RETURNS void
LANGUAGE plpgsql
AS $
BEGIN
    -- Try to unschedule - will silently fail if job doesn't exist
    PERFORM cron.unschedule(job_name);
EXCEPTION
    WHEN OTHERS THEN
        -- Ignore errors - job might not exist
        NULL;
END;
$;

COMMIT;

-- =============================================================================
-- STEP 3: Clean up old jobs (using safe unschedule for idempotency)
-- =============================================================================
SELECT safe_unschedule('ez2-fetch-2pm-1');
SELECT safe_unschedule('ez2-fetch-2pm-2');
SELECT safe_unschedule('ez2-fetch-2pm-3');
SELECT safe_unschedule('ez2-fetch-2pm-4');
SELECT safe_unschedule('ez2-fetch-5pm-1');
SELECT safe_unschedule('ez2-fetch-5pm-2');
SELECT safe_unschedule('ez2-fetch-5pm-3');
SELECT safe_unschedule('ez2-fetch-5pm-4');
SELECT safe_unschedule('ez2-fetch-9pm-1');
SELECT safe_unschedule('ez2-fetch-9pm-2');
SELECT safe_unschedule('ez2-fetch-9pm-3');
SELECT safe_unschedule('ez2-fetch-9pm-4');

-- =============================================================================
-- STEP 4: Schedule cron jobs (3 jobs per draw at 20, 25, 30 minutes after draw)
-- =============================================================================
-- 2PM PHT draw (6:00 UTC) 
-- +20-30 min for combo → fire at 6:20, 6:25, 6:30 UTC
SELECT cron.schedule('ez2-fetch-2pm-1', '20 6 * * *',  'SELECT ez2_fetch_today()');
SELECT cron.schedule('ez2-fetch-2pm-2', '25 6 * * *',  'SELECT ez2_fetch_today()');
SELECT cron.schedule('ez2-fetch-2pm-3', '30 6 * * *', 'SELECT ez2_fetch_today()');

-- 5PM PHT draw (9:00 UTC)
-- +20-30 min for combo → fire at 9:20, 9:25, 9:30 UTC
SELECT cron.schedule('ez2-fetch-5pm-1', '20 9 * * *',  'SELECT ez2_fetch_today()');
SELECT cron.schedule('ez2-fetch-5pm-2', '25 9 * * *',  'SELECT ez2_fetch_today()');
SELECT cron.schedule('ez2-fetch-5pm-3', '30 9 * * *', 'SELECT ez2_fetch_today()');

-- 9PM PHT draw (13:00 UTC)
-- +20-30 min for combo → fire at 13:20, 13:25, 13:30 UTC
-- Winners will be fetched by edge function after 9:35 PM (1295 min) automatically
SELECT cron.schedule('ez2-fetch-9pm-1', '20 13 * * *', 'SELECT ez2_fetch_today()');
SELECT cron.schedule('ez2-fetch-9pm-2', '25 13 * * *', 'SELECT ez2_fetch_today()');
SELECT cron.schedule('ez2-fetch-9pm-3', '30 13 * * *','SELECT ez2_fetch_today()');
