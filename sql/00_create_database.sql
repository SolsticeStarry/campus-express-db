-- ============================================================
-- 00_create_database.sql
-- 作用：创建数据库 campus_express（如不存在）
-- 执行顺序：00 -> 01 -> 02 -> 03 -> 04 -> 05 -> 06 -> 07
-- 说明：本脚本不删除已有数据库；如需彻底重建，请手动执行：
--       DROP DATABASE IF EXISTS campus_express;
-- ============================================================

CREATE DATABASE IF NOT EXISTS campus_express
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE campus_express;
