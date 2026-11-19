-- ============================================================
-- 01_create_tables.sql
-- 作用：创建 9 张表、索引、外键与 CHECK 约束
-- 依赖：00_create_database.sql
-- 说明：按外键依赖逆序删除旧表，方便重复执行
-- ============================================================

USE campus_express;
SET NAMES utf8mb4;

-- 重建前先删除依赖表的视图
DROP VIEW IF EXISTS view_pickup_log_detail, view_station_summary, view_courier_workload,
    view_locker_slot_status, view_pending_pickup, view_parcel_detail;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS pickup_log;
DROP TABLE IF EXISTS parcel;
DROP TABLE IF EXISTS courier;
DROP TABLE IF EXISTS locker_slot;
DROP TABLE IF EXISTS locker;
DROP TABLE IF EXISTS shelf;
DROP TABLE IF EXISTS station;
DROP TABLE IF EXISTS courier_company;
DROP TABLE IF EXISTS person;
DROP TABLE IF EXISTS student;
SET FOREIGN_KEY_CHECKS = 1;

-- 1. 校内人员表
CREATE TABLE person (
    person_id       VARCHAR(20)  NOT NULL,              -- 校内人员编号（学号/工号）
    name            VARCHAR(50)  NOT NULL,              -- 姓名
    person_type     ENUM('学生','教师','教工') NOT NULL, -- 人员类型
    phone           VARCHAR(20)  NOT NULL,              -- 手机号
    address         VARCHAR(200) NOT NULL,              -- 联系地址（宿舍/办公室）
    PRIMARY KEY (person_id),
    KEY idx_person_phone (phone),
    KEY idx_person_type (person_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 2. 快递公司表
CREATE TABLE courier_company (
    company_id      INT          NOT NULL AUTO_INCREMENT, -- 快递公司编号
    company_name    VARCHAR(100) NOT NULL,                -- 快递公司名称
    contact_phone   VARCHAR(20)  NULL,                    -- 联系电话
    PRIMARY KEY (company_id),
    UNIQUE KEY uk_company_name (company_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 3. 驿站表
CREATE TABLE station (
    station_id      INT          NOT NULL AUTO_INCREMENT, -- 驿站编号
    station_name    VARCHAR(100) NOT NULL,                -- 驿站名称
    address         VARCHAR(200) NOT NULL,                -- 驿站地址
    phone           VARCHAR(20)  NULL,                    -- 驿站电话
    PRIMARY KEY (station_id),
    UNIQUE KEY uk_station_name (station_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 4. 货架位表
CREATE TABLE shelf (
    shelf_id        INT          NOT NULL AUTO_INCREMENT, -- 货架位编号
    station_id      INT          NOT NULL,                -- 所属驿站编号
    shelf_code      VARCHAR(20)  NOT NULL,                -- 货架位编码
    capacity        INT          NOT NULL DEFAULT 50,     -- 货架容量
    current_count   INT          NOT NULL DEFAULT 0,      -- 当前存放数量
    status          ENUM('可用','已满','停用') NOT NULL DEFAULT '可用', -- 状态
    PRIMARY KEY (shelf_id),
    UNIQUE KEY uk_shelf_station_code (station_id, shelf_code),
    KEY idx_shelf_station (station_id),
    KEY idx_shelf_status (status),
    CONSTRAINT fk_shelf_station FOREIGN KEY (station_id) REFERENCES station (station_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 5. 快递柜表
CREATE TABLE locker (
    locker_id       INT          NOT NULL AUTO_INCREMENT, -- 快递柜编号
    station_id      INT          NOT NULL,                -- 所属驿站编号
    locker_code     VARCHAR(20)  NOT NULL,                -- 快递柜编码
    PRIMARY KEY (locker_id),
    UNIQUE KEY uk_locker_station_code (station_id, locker_code),
    KEY idx_locker_station (station_id),
    CONSTRAINT fk_locker_station FOREIGN KEY (station_id) REFERENCES station (station_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 6. 柜格口表
CREATE TABLE locker_slot (
    slot_id         INT          NOT NULL AUTO_INCREMENT, -- 柜格口编号
    locker_id       INT          NOT NULL,                -- 所属快递柜编号
    slot_code       VARCHAR(20)  NOT NULL,                -- 格口编码
    status          ENUM('空闲','占用','故障') NOT NULL DEFAULT '空闲', -- 状态
    PRIMARY KEY (slot_id),
    UNIQUE KEY uk_slot_locker_code (locker_id, slot_code),
    KEY idx_slot_locker (locker_id),
    KEY idx_slot_status (status),
    CONSTRAINT fk_slot_locker FOREIGN KEY (locker_id) REFERENCES locker (locker_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 7. 派送员表
CREATE TABLE courier (
    courier_id      INT          NOT NULL AUTO_INCREMENT, -- 派送员编号
    company_id      INT          NOT NULL,                -- 所属快递公司编号
    station_id      INT          NOT NULL,                -- 所属驿站编号
    name            VARCHAR(50)  NOT NULL,                -- 姓名
    phone           VARCHAR(20)  NOT NULL,                -- 手机号
    PRIMARY KEY (courier_id),
    UNIQUE KEY uk_courier_phone (phone),
    KEY idx_courier_company (company_id),
    KEY idx_courier_station (station_id),
    CONSTRAINT fk_courier_company FOREIGN KEY (company_id) REFERENCES courier_company (company_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_courier_station FOREIGN KEY (station_id) REFERENCES station (station_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 8. 运单表（核心）
CREATE TABLE parcel (
    parcel_no       VARCHAR(30)  NOT NULL,                -- 运单号
    company_id      INT          NOT NULL,                -- 快递公司编号
    person_id       VARCHAR(20)  NOT NULL,                -- 收件人员编号
    station_id      INT          NOT NULL,                -- 到达驿站编号
    courier_id      INT          NULL,                    -- 派送员编号
    shelf_id        INT          NULL,                    -- 货架位编号
    slot_id         INT          NULL,                    -- 柜格口编号
    category        VARCHAR(50)  NULL,                    -- 递送物类别
    weight_kg       DECIMAL(8,2) NULL,                    -- 重量（千克）
    special_req     VARCHAR(200) NULL,                    -- 特殊要求
    arrive_time     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP, -- 到站时间
    notify_time     DATETIME     NULL,                    -- 通知取件时间
    deadline        DATETIME     NULL,                    -- 取件期限
    status          ENUM('在库','已通知','已取件','滞留','退回') NOT NULL DEFAULT '在库', -- 状态
    pickup_code     VARCHAR(10)  NULL,                    -- 取件码
    PRIMARY KEY (parcel_no),
    KEY idx_parcel_person (person_id),
    KEY idx_parcel_company (company_id),
    KEY idx_parcel_station (station_id),
    KEY idx_parcel_courier (courier_id),
    KEY idx_parcel_shelf (shelf_id),
    KEY idx_parcel_slot (slot_id),
    KEY idx_parcel_status (status),
    KEY idx_parcel_arrive (arrive_time),
    CONSTRAINT chk_parcel_location CHECK (
        (shelf_id IS NOT NULL AND slot_id IS NULL)
        OR (shelf_id IS NULL AND slot_id IS NOT NULL)
    ),
    CONSTRAINT chk_parcel_weight CHECK (weight_kg IS NULL OR weight_kg > 0),
    CONSTRAINT fk_parcel_company FOREIGN KEY (company_id) REFERENCES courier_company (company_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_parcel_person FOREIGN KEY (person_id) REFERENCES person (person_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_parcel_station FOREIGN KEY (station_id) REFERENCES station (station_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_parcel_courier FOREIGN KEY (courier_id) REFERENCES courier (courier_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_parcel_shelf FOREIGN KEY (shelf_id) REFERENCES shelf (shelf_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_parcel_slot FOREIGN KEY (slot_id) REFERENCES locker_slot (slot_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 9. 取件记录表
CREATE TABLE pickup_log (
    log_id          BIGINT       NOT NULL AUTO_INCREMENT, -- 取件记录编号
    parcel_no       VARCHAR(30)  NOT NULL,                -- 运单号
    person_id       VARCHAR(20)  NOT NULL,                -- 收件人员编号
    pickup_type     ENUM('本人','代取') NOT NULL DEFAULT '本人', -- 取件方式
    picker_name     VARCHAR(50)  NOT NULL,                -- 取件人姓名
    picker_phone    VARCHAR(20)  NULL,                    -- 取件人电话
    pickup_time     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP, -- 取件时间
    station_id      INT          NOT NULL,                -- 取件驿站编号
    PRIMARY KEY (log_id),
    UNIQUE KEY uk_pickup_parcel (parcel_no),
    KEY idx_pickup_person (person_id),
    KEY idx_pickup_station (station_id),
    KEY idx_pickup_time (pickup_time),
    CONSTRAINT chk_pickup_agent CHECK (
        pickup_type = '本人'
        OR (pickup_type = '代取' AND picker_name IS NOT NULL)
    ),
    CONSTRAINT fk_pickup_parcel FOREIGN KEY (parcel_no) REFERENCES parcel (parcel_no)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_pickup_person FOREIGN KEY (person_id) REFERENCES person (person_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_pickup_station FOREIGN KEY (station_id) REFERENCES station (station_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
