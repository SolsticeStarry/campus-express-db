-- ============================================================
-- 04_create_triggers.sql
-- 作用：创建 5 个触发器，维护入库、取件、退回时的状态联动
-- 依赖：01_create_tables.sql
-- 说明：脚本使用 DELIMITER；如客户端不支持，请在查询窗口分段执行
-- ============================================================

USE campus_express;
SET NAMES utf8mb4;

DELIMITER //

-- 1. 入库前校验：位置二选一、驿站归属、货架容量、柜格空闲
DROP TRIGGER IF EXISTS trg_parcel_before_insert//
CREATE TRIGGER trg_parcel_before_insert
BEFORE INSERT ON parcel
FOR EACH ROW
BEGIN
    DECLARE v_station_id INT DEFAULT NULL;
    DECLARE v_status VARCHAR(10) DEFAULT NULL;
    DECLARE v_capacity INT DEFAULT NULL;
    DECLARE v_current INT DEFAULT NULL;

    IF NEW.shelf_id IS NOT NULL AND NEW.slot_id IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '货架位与柜格口只能二选一';
    END IF;

    IF NEW.shelf_id IS NULL AND NEW.slot_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '必须选择一个存放位置';
    END IF;

    IF NEW.shelf_id IS NOT NULL THEN
        SET v_station_id = NULL;
        SET v_status = NULL;
        SET v_capacity = NULL;
        SET v_current = NULL;

        SELECT station_id, status, capacity, current_count
          INTO v_station_id, v_status, v_capacity, v_current
          FROM shelf
         WHERE shelf_id = NEW.shelf_id;

        IF v_station_id IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '货架位不存在';
        END IF;
        IF v_station_id <> NEW.station_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '货架位不属于该驿站';
        END IF;
        IF v_status <> '可用' OR v_current >= v_capacity THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '货架位不可用或已满';
        END IF;
    END IF;

    IF NEW.slot_id IS NOT NULL THEN
        SET v_station_id = NULL;
        SET v_status = NULL;

        SELECT l.station_id, sl.status
          INTO v_station_id, v_status
          FROM locker_slot sl
          JOIN locker l ON sl.locker_id = l.locker_id
         WHERE sl.slot_id = NEW.slot_id;

        IF v_station_id IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '柜格口不存在';
        END IF;
        IF v_station_id <> NEW.station_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '柜格口不属于该驿站';
        END IF;
        IF v_status <> '空闲' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '柜格口不是空闲状态';
        END IF;
    END IF;
END//

-- 2. 入库后联动：占用柜格口、增加货架当前数量
DROP TRIGGER IF EXISTS trg_parcel_after_insert//
CREATE TRIGGER trg_parcel_after_insert
AFTER INSERT ON parcel
FOR EACH ROW
BEGIN
    IF NEW.slot_id IS NOT NULL THEN
        UPDATE locker_slot
           SET status = '占用'
         WHERE slot_id = NEW.slot_id;
    END IF;

    IF NEW.shelf_id IS NOT NULL THEN
        UPDATE shelf
           SET status = IF(current_count + 1 >= capacity, '已满', '可用'),
               current_count = current_count + 1
         WHERE shelf_id = NEW.shelf_id;
    END IF;
END//

-- 3. 取件前校验：运单状态、驿站和收件人一致，代取时须填写实际取件人
DROP TRIGGER IF EXISTS trg_pickup_before_insert//
CREATE TRIGGER trg_pickup_before_insert
BEFORE INSERT ON pickup_log
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(10) DEFAULT NULL;
    DECLARE v_person_id VARCHAR(20) DEFAULT NULL;
    DECLARE v_station_id INT DEFAULT NULL;

    SELECT status, person_id, station_id
      INTO v_status, v_person_id, v_station_id
      FROM parcel
     WHERE parcel_no = NEW.parcel_no;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '运单不存在';
    END IF;
    IF v_status = '已取件' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该运单已取件，不能重复取件';
    END IF;
    IF v_status = '退回' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该运单已退回，不能取件';
    END IF;
    IF v_station_id <> NEW.station_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '取件驿站与运单所属驿站不一致';
    END IF;
    IF NOT (NEW.person_id <=> v_person_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '取件记录的收件人员编号与运单不一致';
    END IF;
    IF NEW.pickup_type = '代取' AND (NEW.picker_name IS NULL OR NEW.picker_name = '') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '代取时必须填写代取人姓名';
    END IF;
END//

-- 4. 取件后联动：运单状态改为已取件、释放柜格口、减少货架当前数量
DROP TRIGGER IF EXISTS trg_pickup_after_insert//
CREATE TRIGGER trg_pickup_after_insert
AFTER INSERT ON pickup_log
FOR EACH ROW
BEGIN
    DECLARE v_shelf_id INT DEFAULT NULL;
    DECLARE v_slot_id INT DEFAULT NULL;

    SELECT shelf_id, slot_id
      INTO v_shelf_id, v_slot_id
      FROM parcel
     WHERE parcel_no = NEW.parcel_no;

    UPDATE parcel
       SET status = '已取件'
     WHERE parcel_no = NEW.parcel_no;

    IF v_slot_id IS NOT NULL THEN
        UPDATE locker_slot
           SET status = IF(status = '占用', '空闲', status)
         WHERE slot_id = v_slot_id;
    END IF;

    IF v_shelf_id IS NOT NULL THEN
        UPDATE shelf
           SET status = IF(status = '已满', '可用', status),
               current_count = GREATEST(current_count - 1, 0)
         WHERE shelf_id = v_shelf_id;
    END IF;
END//

-- 5. 退回前联动：拒绝已取件运单直接退回，其他退回释放原库位
DROP TRIGGER IF EXISTS trg_parcel_before_update//
CREATE TRIGGER trg_parcel_before_update
BEFORE UPDATE ON parcel
FOR EACH ROW
BEGIN
    IF OLD.status = '已取件' AND NEW.status = '退回' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '已取件运单不能直接退回';
    END IF;

    IF NEW.status = '退回' AND OLD.status <> '退回' THEN
        IF OLD.slot_id IS NOT NULL THEN
            UPDATE locker_slot
               SET status = IF(status = '占用', '空闲', status)
             WHERE slot_id = OLD.slot_id;
        END IF;

        IF OLD.shelf_id IS NOT NULL THEN
            UPDATE shelf
               SET status = IF(status = '已满', '可用', status),
                   current_count = GREATEST(current_count - 1, 0)
             WHERE shelf_id = OLD.shelf_id;
        END IF;
    ELSEIF NEW.status <> '退回' AND OLD.status = '退回' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '已退回运单不能直接恢复，请重新入库';
    END IF;
END//

DELIMITER ;
