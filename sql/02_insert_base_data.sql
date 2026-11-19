-- ============================================================
-- 02_insert_base_data.sql
-- 作用：插入基础数据（学生、快递公司、驿站、货架位、快递柜、柜格口、派送员）
-- 依赖：01_create_tables.sql
-- 说明：每张表均不少于 50 条，使用递归 CTE 生成模拟数据
-- ============================================================

USE campus_express;
SET NAMES utf8mb4;

-- 1. 校内人员表：60 条（40 学生、12 教师、8 教工）
INSERT INTO person (person_id, name, person_type, phone, address)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 60
)
SELECT
    CASE
        WHEN n <= 40 THEN CONCAT('2023', LPAD(n, 6, '0'))
        WHEN n <= 52 THEN CONCAT('T2023', LPAD(n - 40, 3, '0'))
        ELSE CONCAT('S2023', LPAD(n - 52, 3, '0'))
    END,
    CONCAT(
        ELT(1 + MOD(n, 20), '张','王','李','赵','刘','陈','杨','黄','周','吴','徐','孙','胡','朱','高','林','何','郭','马','罗'),
        ELT(1 + MOD(n * 7, 20), '伟','芳','娜','敏','静','丽','强','磊','军','洋','勇','艳','杰','娟','涛','明','超','秀英','霞','平')
    ),
    CASE
        WHEN n <= 40 THEN '学生'
        WHEN n <= 52 THEN '教师'
        ELSE '教工'
    END,
    CONCAT('138', LPAD(n, 8, '0')),
    CASE
        WHEN n <= 40 THEN CONCAT('华南农业大学', ELT(1 + MOD(n, 5), '华山','泰山','启林','燕山','六一'), '区', 1 + MOD(n, 20), '栋', 101 + MOD(n, 50), '房')
        WHEN n <= 52 THEN CONCAT('华南农业大学', ELT(1 + MOD(n, 5), '华山','泰山','启林','燕山','六一'), '学院办公楼', 201 + MOD(n, 30), '室')
        ELSE CONCAT('华南农业大学后勤楼', 101 + MOD(n, 20), '室')
    END
FROM seq;

-- 2. 快递公司表：50 条
INSERT INTO courier_company (company_id, company_name, contact_phone)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 50
)
SELECT
    n,
    CONCAT(ELT(1 + MOD(n, 10), '顺丰','中通','圆通','申通','韵达','京东','邮政','极兔','德邦','百世'), '快递', n, '分公司'),
    CONCAT('020-', LPAD(n, 8, '0'))
FROM seq;

-- 3. 驿站表：50 条
INSERT INTO station (station_id, station_name, address, phone)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 50
)
SELECT
    n,
    CONCAT('华南农业大学', ELT(1 + MOD(n, 5), '华山','泰山','启林','燕山','六一'), '区快递驿站', n),
    CONCAT('华南农业大学', ELT(1 + MOD(n, 5), '华山','泰山','启林','燕山','六一'), '区', 1 + MOD(n, 20), '栋一楼'),
    CONCAT('020-', LPAD(80000000 + n, 8, '0'))
FROM seq;

-- 4. 货架位表：50 条
INSERT INTO shelf (shelf_id, station_id, shelf_code, capacity, current_count, status)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 50
)
SELECT
    n,
    n,
    CONCAT('S', LPAD(n, 3, '0')),
    50,
    0,
    '可用'
FROM seq;

-- 5. 快递柜表：50 条
INSERT INTO locker (locker_id, station_id, locker_code)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 50
)
SELECT
    n,
    n,
    CONCAT('L', LPAD(n, 3, '0'))
FROM seq;

-- 6. 柜格口表：100 条（每个快递柜 2 个格口）
INSERT INTO locker_slot (slot_id, locker_id, slot_code, status)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 100
)
SELECT
    n,
    1 + FLOOR((n - 1) / 2),
    LPAD(1 + MOD(n - 1, 2), 2, '0'),
    '空闲'
FROM seq;

-- 预留 2 个故障格口，用于状态演示
UPDATE locker_slot SET status = '故障' WHERE slot_id IN (98, 100);

-- 7. 派送员表：50 条
INSERT INTO courier (courier_id, company_id, station_id, name, phone)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 50
)
SELECT
    n,
    n,
    n,
    CONCAT('派送员', n),
    CONCAT('139', LPAD(n, 8, '0'))
FROM seq;
