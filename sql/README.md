# SQL 脚本说明

本目录存放“校园快递驿站与快递柜一体化管理系统”的 MySQL 8.0 脚本，按步骤分文件编写。

## 1. 文件与执行顺序

| 顺序 | 文件 | 作用 |
| --- | --- | --- |
| 00 | `00_create_database.sql` | 创建数据库 `campus_express` |
| 01 | `01_create_tables.sql` | 创建 9 张表、索引、外键、CHECK 约束 |
| 02 | `02_insert_base_data.sql` | 插入基础数据（校内人员、公司、驿站、货架、快递柜、格口、派送员） |
| 03 | `03_create_views.sql` | 创建 6 个视图 |
| 04 | `04_create_triggers.sql` | 创建 5 个触发器 |
| 05 | `05_insert_parcel_and_pickup.sql` | 插入运单与取件记录（触发器生效） |

**初始化必须按 00 → 01 → 02 → 03 → 04 → 05 顺序执行。** 选中 `campus_express` 后，可按需执行 [`数据操作代码/`](数据操作代码/)中的 10 项报告示例。原查询脚本中其余 11 项只读查询见 [`补充查询/`](数据操作代码/补充查询/)。

特别注意：

- `05` 必须在 `04` 之后执行，否则运单入库、取件时不会触发状态联动。
- `05` 使用固定运单号，**不要重复执行**；如需重跑，先重新执行 `01`（会清空并重建表）。
- 数据操作示例省略事务语句。开启自动提交时，写操作会直接修改数据，请在实验数据副本上运行。

## 2. 数据库与数据量

- 数据库名：`campus_express`
- 字符集：`utf8mb4`
- 排序规则：`utf8mb4_0900_ai_ci`
- 存储引擎：`InnoDB`

各表数据量：

| 表 | 行数 |
| --- | --- |
| person | 60 |
| courier_company | 50 |
| station | 50 |
| shelf | 50 |
| locker | 50 |
| locker_slot | 100 |
| courier | 50 |
| parcel | 60 |
| pickup_log | 50 |

满足实验 10“每张表数据不少于 50 条”的要求。

## 3. 9 张表

| 序号 | 表名 | 中文名 | 主键 |
| --- | --- | --- | --- |
| 1 | person | 校内人员 | person_id |
| 2 | courier_company | 快递公司 | company_id |
| 3 | station | 驿站 | station_id |
| 4 | shelf | 货架位 | shelf_id |
| 5 | locker | 快递柜 | locker_id |
| 6 | locker_slot | 柜格口 | slot_id |
| 7 | courier | 派送员 | courier_id |
| 8 | parcel | 运单（核心） | parcel_no |
| 9 | pickup_log | 取件记录 | log_id |

## 4. 视图

| 视图 | 用途 |
| --- | --- |
| view_parcel_detail | 运单完整详情（校内人员、公司、驿站、货架/柜格） |
| view_pending_pickup | 待取件包裹（在库、已通知、滞留） |
| view_locker_slot_status | 柜格口状态与当前运单 |
| view_courier_workload | 派送员认领量、取件量、完成率 |
| view_station_summary | 驿站到件量、取件量、滞留率 |
| view_pickup_log_detail | 取件记录详情（本人/代取） |

## 5. 触发器

| 触发器 | 时机 | 作用 |
| --- | --- | --- |
| trg_parcel_before_insert | parcel BEFORE INSERT | 校验货架/柜格二选一、驿站归属、货架容量、柜格空闲 |
| trg_parcel_after_insert | parcel AFTER INSERT | 柜格置为占用、货架当前数量 +1 |
| trg_pickup_before_insert | pickup_log BEFORE INSERT | 本人和代取均校验运单状态、驿站及收件人编号；代取还须填写实际取件人姓名 |
| trg_pickup_after_insert | pickup_log AFTER INSERT | 运单置为已取件、释放柜格、货架当前数量 -1 |
| trg_parcel_before_update | parcel BEFORE UPDATE | 拒绝已取件运单直接退回；正常退回时释放原柜格或货架 |

## 6. 关键约束

- `chk_parcel_location`：`shelf_id` 与 `slot_id` 有且仅有一个非空，实现“货架位 / 柜格口二选一”。
- `chk_parcel_weight`：重量必须大于 0（允许为空）。
- `chk_pickup_agent`：代取时必须填写取件人姓名。
- 外键：驿站 → 货架 / 快递柜，快递柜 → 柜格口，校内人员 / 公司 / 驿站 / 派送员 → 运单，运单 → 取件记录。
- MySQL 8.0 限制：CHECK 约束列不能参与 `ON UPDATE CASCADE` 等外键引用动作，因此 `fk_parcel_shelf`、`fk_parcel_slot` 使用 `ON UPDATE RESTRICT`；货架/柜格主键为自增代理键，不需要级联更新。
- `parcel` 精简：收件人姓名、电话、地址由 `person` 表关联获取；不再保存长宽高、备注、创建/更新时间，运单表只保留核心业务字段。
- 整体字段精简：`person` 只保留人员编号/姓名/人员类型/电话/联系地址；`courier_company` 只保留名称/联系电话；`station` 只保留名称/地址/电话；`shelf` 只保留编码/容量/当前数量/状态；`locker` 只保留所属驿站/编码；`courier` 只保留公司/驿站/姓名/电话；`pickup_log` 不再记录经办人和备注。

## 7. 客户端注意事项

- 脚本使用 `DELIMITER` 定义触发器，推荐在 MySQL 命令行或 Navicat 查询窗口执行。
- 如果客户端不支持 `DELIMITER`，请把 `04_create_triggers.sql` 中的每个 `CREATE TRIGGER ... END` 单独执行。
- 脚本未使用 `COMMENT` 元数据，全部中文说明均以 `--` 注释形式书写。
- 表名、字段名均为英文；视图和查询结果使用 `AS` 中文别名。

## 8. 快速验证

执行完 00–05 后，可运行：

```sql
USE campus_express;

SELECT COUNT(*) AS 校内人员数 FROM person;
SELECT COUNT(*) AS 运单数 FROM parcel;
SELECT COUNT(*) AS 取件记录数 FROM pickup_log;

SELECT 状态, COUNT(*) AS 数量
FROM parcel
GROUP BY 状态;

SELECT 状态, COUNT(*) AS 数量
FROM locker_slot
GROUP BY 状态;

SELECT *
FROM view_station_summary
ORDER BY 到件量 DESC;
```

实测结果（2026-11-12）：

- `person` = 60
- `parcel` = 60
- `pickup_log` = 50
- 运单状态：已取件 50、已通知 3、滞留 7
- 柜格口状态：占用 5、故障 2、空闲 93
- 有货货架数：5（S001、S003、S005、S007、S009）
- 以上统计以初始化数据为准。

## 9. 与实验报告的对应

| 报告章节 | 使用文件 |
| --- | --- |
| 3.2 关系模型 | `01_create_tables.sql` 中各表结构 |
| 3.3 视图设计 | `03_create_views.sql` |
| 3.4 编程性结构 | `04_create_triggers.sql` |
| 3.5 数据操作 | [`数据操作代码/`](数据操作代码/) |
| 数据库实现 | `00`–`05` 全部脚本 |
