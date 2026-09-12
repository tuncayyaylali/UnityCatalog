-- 1. Create Analytics Schema in Unity Catalog (Iceberg on MinIO)
CREATE SCHEMA IF NOT EXISTS unity.analytics_schema
WITH (location = 's3://warehouse/analytics_schema');

-- 2. Create Clickstream Table in Unity Catalog
CREATE TABLE IF NOT EXISTS unity.analytics_schema.clickstream (
    event_id VARCHAR,
    user_id VARCHAR,
    event_type VARCHAR,
    page_url VARCHAR,
    event_timestamp TIMESTAMP(3) WITH TIME ZONE
);

-- 3. Seed Clickstream Data
INSERT INTO unity.analytics_schema.clickstream VALUES
('evt_001', 'usr_001', 'page_view', '/home', TIMESTAMP '2026-09-12 10:15:00 UTC'),
('evt_002', 'usr_001', 'click', '/products', TIMESTAMP '2026-09-12 10:18:22 UTC'),
('evt_003', 'usr_001', 'click', '/cart', TIMESTAMP '2026-09-12 10:20:05 UTC'),
('evt_004', 'usr_002', 'page_view', '/home', TIMESTAMP '2026-09-12 11:00:10 UTC'),
('evt_005', 'usr_002', 'click', '/pricing', TIMESTAMP '2026-09-12 11:05:40 UTC'),
('evt_006', 'usr_003', 'page_view', '/blog', TIMESTAMP '2026-09-12 12:30:15 UTC'),
('evt_007', 'usr_004', 'page_view', '/login', TIMESTAMP '2026-09-12 13:00:00 UTC'),
('evt_008', 'usr_005', 'page_view', '/products', TIMESTAMP '2026-09-12 14:10:00 UTC'),
('evt_009', 'usr_005', 'click', '/checkout', TIMESTAMP '2026-09-12 14:15:30 UTC'),
('evt_010', 'usr_001', 'purchase', '/thank-you', TIMESTAMP '2026-09-12 10:25:00 UTC');

-- 4. AGENTS.md Production SQL Federation Query
SELECT 
    u.user_id,
    u.first_name,
    u.last_name,
    COUNT(c.event_id) AS total_clicks,
    MAX(c.event_timestamp) AS last_seen_date
FROM 
    postgresql.public.users u
JOIN 
    unity.analytics_schema.clickstream c ON u.user_id = c.user_id
WHERE 
    u.status = 'ACTIVE'
GROUP BY 
    u.user_id, 
    u.first_name, 
    u.last_name
ORDER BY 
    total_clicks DESC
LIMIT 10;

