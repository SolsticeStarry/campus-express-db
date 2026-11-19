-- ============================================================
-- 03_create_views.sql
-- 作用：创建 6 个查询视图
-- 依赖：01_create_tables.sql（表已存在即可）
-- 说明：视图列使用中文别名，便于报告展示与后续查询
-- ============================================================

USE campus_express;
SET NAMES utf8mb4;

-- 1. 运单详情视图
CREATE OR REPLACE VIEW view_parcel_detail AS
SELECT
    p.parcel_no        AS 运单号,
    cc.company_name    AS 快递公司,
    p.person_id        AS 人员编号,
    s.name             AS 收件人,
    s.person_type      AS 人员类型,
    s.phone            AS 收件人电话,
    st.station_name    AS 驿站,
    IFNULL(sh.shelf_code, '')                          AS 货架位,
    IFNULL(CONCAT(l.locker_code, '-', sl.slot_code), '') AS 柜格口,
    s.address          AS 送达地址,
    p.category         AS 物品类别,
    p.weight_kg        AS 重量千克,
    p.arrive_time      AS 到站时间,
    p.notify_time      AS 通知时间,
    p.deadline         AS 取件期限,
    p.status           AS 状态,
    p.pickup_code      AS 取件码
FROM parcel p
JOIN courier_company cc ON p.company_id = cc.company_id
JOIN person s           ON p.person_id = s.person_id
JOIN station st         ON p.station_id = st.station_id
LEFT JOIN shelf sh      ON p.shelf_id = sh.shelf_id
LEFT JOIN locker_slot sl ON p.slot_id = sl.slot_id
LEFT JOIN locker l      ON sl.locker_id = l.locker_id;

-- 2. 待取件包裹视图
CREATE OR REPLACE VIEW view_pending_pickup AS
SELECT
    p.parcel_no        AS 运单号,
    cc.company_name    AS 快递公司,
    p.person_id        AS 人员编号,
    s.name             AS 收件人,
    st.station_name    AS 驿站,
    IFNULL(sh.shelf_code, '')                          AS 货架位,
    IFNULL(CONCAT(l.locker_code, '-', sl.slot_code), '') AS 柜格口,
    p.arrive_time      AS 到站时间,
    p.deadline         AS 取件期限,
    p.status           AS 状态,
    DATEDIFF(NOW(), p.arrive_time) AS 在站天数
FROM parcel p
JOIN courier_company cc ON p.company_id = cc.company_id
JOIN person s           ON p.person_id = s.person_id
JOIN station st         ON p.station_id = st.station_id
LEFT JOIN shelf sh      ON p.shelf_id = sh.shelf_id
LEFT JOIN locker_slot sl ON p.slot_id = sl.slot_id
LEFT JOIN locker l      ON sl.locker_id = l.locker_id
WHERE p.status IN ('在库', '已通知', '滞留');

-- 3. 快递柜格口状态视图
CREATE OR REPLACE VIEW view_locker_slot_status AS
SELECT
    st.station_name    AS 驿站,
    l.locker_code      AS 快递柜,
    sl.slot_code       AS 柜格口,
    sl.status          AS 状态,
    p.parcel_no        AS 当前运单,
    s.name             AS 当前收件人
FROM locker_slot sl
JOIN locker l   ON sl.locker_id = l.locker_id
JOIN station st ON l.station_id = st.station_id
LEFT JOIN parcel p
    ON p.slot_id = sl.slot_id
   AND p.status IN ('在库', '已通知', '滞留')
LEFT JOIN person s ON p.person_id = s.person_id;

-- 4. 派送员工作量视图
CREATE OR REPLACE VIEW view_courier_workload AS
SELECT
    c.courier_id       AS 派送员编号,
    c.name             AS 派送员,
    cc.company_name    AS 快递公司,
    st.station_name    AS 驿站,
    COUNT(p.parcel_no) AS 认领运单数,
    SUM(CASE WHEN p.status = '已取件' THEN 1 ELSE 0 END) AS 已取件数,
    SUM(CASE WHEN p.status IN ('在库', '已通知', '滞留') THEN 1 ELSE 0 END) AS 待处理数,
    IFNULL(ROUND(
        SUM(CASE WHEN p.status = '已取件' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(p.parcel_no), 0) * 100,
        2
    ), 0) AS 完成率百分比
FROM courier c
JOIN courier_company cc ON c.company_id = cc.company_id
JOIN station st         ON c.station_id = st.station_id
LEFT JOIN parcel p      ON p.courier_id = c.courier_id
GROUP BY c.courier_id, c.name, cc.company_name, st.station_name;

-- 5. 驿站到件与滞留统计视图
CREATE OR REPLACE VIEW view_station_summary AS
SELECT
    st.station_id      AS 驿站编号,
    st.station_name    AS 驿站,
    COUNT(p.parcel_no) AS 到件量,
    SUM(CASE WHEN p.status = '已取件' THEN 1 ELSE 0 END) AS 已取件量,
    SUM(CASE WHEN p.status IN ('在库', '已通知', '滞留') THEN 1 ELSE 0 END) AS 待取件量,
    SUM(CASE WHEN p.status = '滞留' THEN 1 ELSE 0 END) AS 滞留量,
    IFNULL(ROUND(
        SUM(CASE WHEN p.status = '滞留' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(p.parcel_no), 0) * 100,
        2
    ), 0) AS 滞留率百分比
FROM station st
LEFT JOIN parcel p ON p.station_id = st.station_id
GROUP BY st.station_id, st.station_name;

-- 6. 取件记录详情视图
CREATE OR REPLACE VIEW view_pickup_log_detail AS
SELECT
    pl.log_id          AS 记录编号,
    pl.parcel_no       AS 运单号,
    pl.person_id       AS 人员编号,
    s.name             AS 收件人,
    s.person_type      AS 人员类型,
    pl.pickup_type     AS 取件方式,
    pl.picker_name     AS 取件人,
    pl.picker_phone    AS 取件人电话,
    pl.pickup_time     AS 取件时间,
    st.station_name    AS 驿站
FROM pickup_log pl
JOIN person s   ON pl.person_id = s.person_id
JOIN station st ON pl.station_id = st.station_id;
