# 校园快递驿站与快递柜一体化管理系统（MySQL）

数据库系统课程「实验 10 · 综合性实验（设计性实验）」项目。面向校园快递代收场景，覆盖「驿站货架 + 快递柜格口」两种存放模式，是一套完整的 MySQL 8.0 数据库设计。

## 数据库设计

- **9 张表**：含主键、外键、索引与 CHECK 约束
- **6 个视图**：面向统计与查询场景
- **5 个触发器**：处理状态流转、柜口占用与释放等业务约束
- **数据操作**：演示入库、取件、退回、删除和统计查询

## 目录结构

```
sql/                 按执行顺序编号的 MySQL 脚本
  00_create_database.sql
  01_create_tables.sql
  02_insert_base_data.sql
  03_create_views.sql
  04_create_triggers.sql
  05_insert_parcel_and_pickup.sql
  数据操作代码/        报告 3.5 的 10 项操作（每项一个 .txt）
    补充查询/          原查询脚本中另外 11 项查询
  README.md          脚本执行顺序与说明
assets/              E-R 图
逻辑结构图.png        Navicat 反向工程截图
实验总体决策总结.md   选题、系统定位与关键设计决策
```

## 交付物

- `assets/er_complete_colored.png`：彩色 Chen 风格 E-R 图
- `逻辑结构图.png`：Navicat 生成的数据库逻辑结构图

## 运行方式

使用 MySQL 8.0，按 `sql/README.md` 的顺序执行 `00` 至 `05` 初始化数据库。选中 `campus_express` 后，可从 `sql/数据操作代码/` 按需执行数据操作示例。

## 说明

仓库只发布 SQL 脚本、设计图和设计说明。实验报告、模板、教材、连接信息和本地辅助工具不纳入版本控制。
