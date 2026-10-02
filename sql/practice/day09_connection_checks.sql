-- ============================================================
-- QueryForge
-- Day 09 - PostgreSQL Connection Checks
-- ============================================================

SELECT current_database();

SELECT current_user;

SELECT
    inet_server_addr(),
    inet_server_port();