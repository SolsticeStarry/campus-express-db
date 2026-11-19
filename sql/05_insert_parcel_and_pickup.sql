-- ============================================================
-- 05_insert_parcel_and_pickup.sql
-- 作用：插入 60 条运单，并为其中 50 条生成取件记录
-- 依赖：02_insert_base_data.sql、04_create_triggers.sql
-- 说明：
--   1. 必须先执行 04_create_triggers.sql，运单入库与取件才会触发状态联动
--   2. 运单按“奇数走货架位、偶数走柜格口”分配
--   3. 前 50 条为在库后被取件，后 10 条为待取件/滞留
--   4. 使用临时表避免触发器更新 parcel 时与 INSERT ... SELECT 读取 parcel 冲突
-- ============================================================

USE campus_express;
SET NAMES utf8mb4;

-- 1. 插入 60 条运单
INSERT INTO parcel (
    parcel_no, company_id, person_id, station_id, courier_id,
    shelf_id, slot_id,
    category, weight_kg,
    special_req, arrive_time, notify_time, deadline, status, pickup_code
)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 60
)
SELECT
    CONCAT(ELT(1 + MOD(n, 10), 'SF','ZT','YT','ST','YD','JD','YZ','JT','DB','BS'), LPAD(n, 12, '0')),
    1 + MOD(n - 1, 50),
    s.person_id,
    CASE WHEN n <= 50 THEN n ELSE n - 50 END,
    CASE WHEN n <= 50 THEN n ELSE n - 50 END,
    CASE
        WHEN n <= 50 AND MOD(n, 2) = 1 THEN n
        WHEN n > 50 AND MOD(n, 2) = 1 THEN n - 50
        ELSE NULL
    END,
    CASE
        WHEN n <= 50 AND MOD(n, 2) = 0 THEN 2 * n - 1
        WHEN n > 50 AND MOD(n, 2) = 0 THEN 2 * (n - 50)
        ELSE NULL
    END,
    ELT(1 + MOD(n, 6), '文件','衣物','食品','电子产品','日用品','化妆品'),
    ROUND(0.5 + MOD(n, 20) * 0.3, 2),
    IF(MOD(n, 5) = 0, '易碎品，请轻拿轻放', NULL),
    DATE_ADD('2025-10-01 08:00:00', INTERVAL n HOUR),
    DATE_ADD(DATE_ADD('2025-10-01 08:00:00', INTERVAL n HOUR), INTERVAL 30 MINUTE),
    CASE
        WHEN n BETWEEN 54 AND 60 THEN DATE_ADD(DATE_ADD('2025-10-01 08:00:00', INTERVAL n HOUR), INTERVAL 1 DAY)
        ELSE DATE_ADD(DATE_ADD('2025-10-01 08:00:00', INTERVAL n HOUR), INTERVAL 3 DAY)
    END,
    CASE
        WHEN n <= 50 THEN '在库'
        WHEN n BETWEEN 51 AND 53 THEN '已通知'
        ELSE '滞留'
    END,
    LPAD(100000 + MOD(n * 37, 900000), 6, '0')
FROM seq
JOIN person s
  ON s.person_id = CASE
      WHEN n <= 40 THEN CONCAT('2023', LPAD(n, 6, '0'))
      WHEN n <= 52 THEN CONCAT('T2023', LPAD(n - 40, 3, '0'))
      ELSE CONCAT('S2023', LPAD(n - 52, 3, '0'))
  END;

-- 2. 取前 50 条在库运单，生成临时取件数据集
DROP TEMPORARY TABLE IF EXISTS tmp_pickup;
CREATE TEMPORARY TABLE tmp_pickup AS
SELECT
    p.parcel_no,
    p.person_id,
    s.name,
    s.phone,
    p.arrive_time,
    p.station_id,
    ROW_NUMBER() OVER (ORDER BY p.parcel_no) AS rn
FROM parcel p
JOIN person s ON p.person_id = s.person_id
WHERE p.status = '在库';

-- 3. 插入 50 条取件记录，触发器会同步运单状态与柜格/货架状态
INSERT INTO pickup_log (
    parcel_no, person_id, pickup_type, picker_name, picker_phone,
    pickup_time, station_id
)
SELECT
    parcel_no,
    person_id,
    IF(MOD(rn, 3) = 0, '代取', '本人'),
    IF(MOD(rn, 3) = 0, CONCAT('代取人', rn), name),
    IF(MOD(rn, 3) = 0, CONCAT('139', LPAD(100 + rn, 8, '0')), phone),
    DATE_ADD(arrive_time, INTERVAL 1 DAY),
    station_id
FROM tmp_pickup
WHERE rn <= 50
ORDER BY parcel_no;

DROP TEMPORARY TABLE tmp_pickup;
