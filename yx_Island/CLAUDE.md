# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# 项目概述

这是一个基于 **FiveM + QBCore** 框架的佩里科岛搜索物资系统脚本。玩家可以报名参加活动,通过空投登岛,在限定时间内搜索物资和武器箱,最后从撤离点返回。支持死亡背包掉落、复活系统等完整游戏循环。

**作者**: 于晓
**版本**: 2.0.1
**框架依赖**: QBCore, qs-inventory, ox_target, ox_lib

**配置文件说明**:
- `config.lua` - 主配置文件,包含所有系统配置
- `config_weapon.lua` - 武器箱专用配置文件(注意: 此文件与 config.lua 中的 Config.WeaponBoxes 重复,实际使用 config.lua)
- `武器箱系统说明.md` - 武器箱系统详细文档

---

# 代码架构

## 文件结构

```
yx_Island/
├── fxmanifest.lua          # FiveM 资源清单
├── config.lua              # 主配置文件 (包含所有系统配置)
├── config_weapon.lua       # 武器箱配置文件 (已过时,使用 config.lua)
├── 武器箱系统说明.md       # 武器箱和复活系统详细文档
├── client/
│   ├── main.lua            # 客户端核心逻辑: 位置检测、系统开关
│   ├── registration.lua    # 报名系统: NPC生成、ox_target交互
│   ├── airdrop.lua         # 空投跳伞系统: 传送到高空、自动开伞
│   ├── evacuation.lua      # 撤离系统: 撤离点标记、玩家撤离交互
│   ├── death.lua           # 死亡背包客户端: 实体管理、菜单显示
│   ├── resources.lua       # 物资刷新客户端: 物资点标记、拾取交互
│   └── weapon_boxes.lua    # 武器箱客户端: 箱子实体、ox_target交互
└── server/
    ├── main.lua            # 服务端核心: 玩家状态管理、系统全局控制
    ├── activity.lua        # 活动管理: 报名、启动、计时器、撤离、武器箱初始化
    ├── inventory.lua       # 背包管理: 保存/恢复非武器物品
    ├── commands.lua        # 控制台命令: island_toggle, island_status
    ├── death.lua           # 死亡背包服务端: 创建背包、物品转移、清理
    ├── resources.lua       # 物资刷新服务端: 物资点生成、物品发放
    └── weapon_boxes.lua    # 武器箱服务端: 箱子生成、锁定机制、物品掉落
```

## 核心逻辑流程

1. **报名阶段** (registration.lua + activity.lua)
   - 管理员执行 `island_toggle` 开启系统
   - NPC 在配置的坐标生成,玩家可通过 ox_target 报名
   - 报名玩家进入 `WaitingList`

2. **活动启动** (activity.lua)
   - 管理员执行 `island_status start` 启动活动
   - 调用 `StorePlayerInventory()` 暂存非武器物品
   - 触发 `yx_island:client:start_airdrop` 将玩家空投到岛上
   - 玩家状态设置为 `on_island = true`,加入 `IslandPlayers` 列表

3. **岛上活动** (client/main.lua)
   - 每隔 `Config.CheckInterval` 毫秒检测玩家是否在岛内
   - 进入/离开岛屿时触发服务端事件更新状态

4. **撤离阶段** (evacuation.lua + activity.lua)
   - 活动开始 `Config.Evacuation.delay_open_time` 秒后开启撤离点
   - 玩家到达撤离点按 E 请求撤离
   - 服务端调用 `RestorePlayerInventory()` 归还物品
   - 传送玩家回集结点,状态重置

5. **活动结束**
   - 到达 `Config.Activity.duration` 时自动强制关闭
   - 调用 `ForceEvacuateIsland()` + `ClearAllPlayerItems()` 清空所有物品
   - 系统关闭,NPC 删除

6. **死亡系统** (death.lua)
   - 客户端通过 `gameEventTriggered` 事件检测玩家死亡
   - 服务端创建死亡背包实体,将玩家物品转移到背包
   - 其他玩家可通过 ox_target 交互拾取物品
   - 玩家被标记为已死亡并退出活动

## 关键全局变量

**server/main.lua**:
- `IslandSystemEnabled`: 系统总开关
- `IslandPlayers`: 当前岛上玩家 `{source = playerName}`
- `WaitingList`: 已报名但未登岛的玩家 `{source = playerName}`

**server/activity.lua**:
- `EvacuatedPlayers`: 已撤离/死亡的玩家 `{source = {name, reason}}` (防止重复报名)
- `EvacuationRequests`: 撤离请求表 `{source = {evac_coords, start_time}}`
- `ActivityTimer`: 活动计时器标记

**server/inventory.lua**:
- `PlayerInventoryBackup`: 背包备份数据 `{source = inventory_data}`

**server/death.lua**:
- `DeathBags`: 死亡背包数据 `{bag_id = bag_data}`

**server/weapon_boxes.lua**:
- `WeaponBoxes`: 武器箱数据 `{box_id = {coords, opened}}`
- `BoxLocks`: 武器箱锁定状态 `{box_id = player_source}`

**server/resources.lua**:
- `ResourcePoints`: 物资点数据 `{point_id = {coords, zone_id, items}}`

## 重要导出函数

**系统管理** (server/main.lua):
- `GetSystemStatus()`: 获取系统开关状态
- `GetIslandPlayerCount()`, `GetIslandPlayerList()`: 岛上玩家信息
- `GetWaitingPlayerCount()`, `GetWaitingPlayerList()`: 等待列表信息

**活动管理** (server/activity.lua):
- `StartIslandActivity()`: 启动活动
- `ResetIslandSystem()`: 重置所有系统状态

**背包管理** (server/inventory.lua):
- `StorePlayerInventory(source)`: 暂存非武器物品
- `RestorePlayerInventory(source)`: 归还玩家物品
- `RestoreAllInventories()`: 批量恢复所有玩家背包
- `ClearAllPlayerItems(source)`: 强制清空所有物品

**武器箱系统** (server/weapon_boxes.lua):
- `InitializeWeaponBoxes()`: 初始化所有武器箱
- `ClearAllWeaponBoxes()`: 清理所有武器箱
- `GetWeaponBoxStatus()`: 获取武器箱状态

**物资系统** (server/resources.lua):
- `InitializeResourcePoints()`: 初始化物资点
- `ClearAllResourcePoints()`: 清理所有物资点

---

# 开发规范

## 1. 代码结构与优化

- 所有功能应 **模块化设计**：每个功能模块单独存放，避免单文件过大。
- 避免重复代码，能复用的逻辑应抽取到公共函数或模块。
- 循环中避免进行大量计算或 I/O 操作，必要时使用缓存。
- 事件监听和 Tick 中的逻辑应尽量精简，减少性能消耗。
- 变量、函数名必须清晰易懂，遵循小写+下划线命名法（例：`vehicle_spawn_config`）。

## 2. 配置文件（Config.lua）

- 所有可调整的 **数据参数** 必须放入 `Config.lua`。
- 功能开关、数值、文字内容、权限设置等均可通过 Config 调整。
- Config 文件应使用表格结构分块注释，方便后续修改和查找。
- 所有脚本应在初始化时优先加载 Config。

## 3. 调试模式（Debug Mode）

- 提供 `Config.Debug` 选项控制调试信息输出。
- `Debug = true` 时，在控制台或游戏中显示详细日志（事件触发、变量值、错误信息等）。
- `Debug = false` 时，禁止输出调试信息，以免影响性能。
- 日志输出函数应封装为 `debug_print(msg)`，自动判断是否输出。

## 4. 事件与安全性

- 所有事件（ServerEvent / ClientEvent）必须有权限和数据验证，防止作弊调用。
- 服务端接收的数据必须经过类型检查和逻辑校验。
- 事件命名遵循：`资源名:功能名`（例：`yx_island:server:register`）。
- 避免使用全局变量，防止变量污染。

## 5. 文档与注释

- 所有模块文件顶部需有功能说明。
- 重要函数、复杂逻辑必须写注释，说明作用、参数和返回值。
- 每个 Config 配置项必须有说明用途的注释。

## 6. 通用设计原则

- **可拓展性**：功能设计时考虑未来可能的扩展（如增加新的玩法、物品、任务）。
- **可移植性**：尽量减少与特定资源的耦合，便于在不同服务器环境中使用。
- **版本控制**：所有脚本应在 GitHub/Git 仓库管理，并有版本号标识。
- **容错处理**：遇到错误时应提示并安全退出，不影响服务器稳定运行。
- **逻辑实现**：代码在保证功能实现的同时，保证代码简洁，避免重复逻辑。
- **脚本优化**：代码要保证优化避免无限循环查询等优化较差的方法，如果一定要有，必须要有检测间隔设置或者其他调节配置项。
- **简洁设计**：避免创建任何文档或者修复说明，除非具有必要性。
- **作者署名**：作者署名为：于晓

---

# 控制台命令

管理员通过 FiveM 服务器控制台执行以下命令（需设置 `Config.Commands.console_only = true`）：

## 系统控制命令
- `island_toggle` - 开启/关闭系统（生成/删除 NPC）
- `island_status` - 查看系统状态
- `island_status start` - 启动活动（将等待列表玩家全部空投到岛上）
- `island_status players` - 查看岛上玩家列表
- `island_status waiting` - 查看报名等待列表

## 调试命令
- `island_bags` - 查看所有死亡背包列表
- `island_clearbags` - 强制清理所有死亡背包
- `island_boxes` - 查看所有武器箱状态
- `island_clearboxes` - 强制清理所有武器箱
- `island_resources` - 查看所有物资点状态
- `island_clearresources` - 强制清理所有物资点

---

# 重要事件列表

## 客户端 → 服务端事件

**核心系统**:
- `yx_island:server:enter_island` - 玩家进入岛屿
- `yx_island:server:leave_island` - 玩家离开岛屿
- `yx_island:server:register` - 玩家报名
- `yx_island:server:cancel_register` - 取消报名

**撤离系统**:
- `yx_island:server:request_evacuation` - 请求撤离（传递撤离点坐标）
- `yx_island:server:cancel_evacuation` - 取消撤离（离开范围时）

**死亡背包**:
- `yx_island:server:player_died` - 玩家死亡通知
- `yx_island:server:open_death_bag` - 打开死亡背包
- `yx_island:server:take_bag_item` - 拾取单个物品
- `yx_island:server:take_all_items` - 拾取全部物品

**武器箱系统**:
- `yx_island:server:open_weapon_box` - 打开武器箱
- `yx_island:server:complete_weapon_box_search` - 完成武器箱搜索
- `yx_island:server:cancel_weapon_box_search` - 取消武器箱搜索

**物资系统**:
- `yx_island:server:pickup_resource` - 拾取物资点物品

## 服务端 → 客户端事件

**核心系统**:
- `yx_island:client:toggle_system` - 系统开关状态变更
- `yx_island:client:start_airdrop` - 开始空投跳伞
- `yx_island:client:teleport_to_safe` - 传送到安全区
- `yx_island:client:teleport_to_return` - 传送到集结点
- `yx_island:client:reset_registration` - 重置报名状态
- `yx_island:client:reset_all_states` - 重置所有状态

**撤离系统**:
- `yx_island:client:open_evacuation` - 开启撤离点
- `yx_island:client:close_evacuation` - 关闭撤离点

**死亡背包**:
- `yx_island:client:spawn_death_bag` - 生成死亡背包
- `yx_island:client:remove_death_bag` - 移除死亡背包
- `yx_island:client:show_bag_menu` - 显示背包菜单
- `yx_island:client:refresh_bag_menu` - 刷新背包菜单

**武器箱系统**:
- `yx_island:client:spawn_weapon_box` - 生成武器箱
- `yx_island:client:remove_weapon_box` - 移除武器箱
- `yx_island:client:start_weapon_box_progress` - 开始搜索进度条

**物资系统**:
- `yx_island:client:initialize_resources` - 初始化物资点
- `yx_island:client:remove_resource_point` - 移除物资点
- `yx_island:client:clear_all_resources` - 清除所有物资点

---

# 核心机制说明

## 死亡背包系统
1. 玩家在岛上死亡时,客户端通过 `gameEventTriggered` 检测死亡事件
2. 服务端创建物理背包实体(prop),将玩家所有物品存储到背包数据中
3. 玩家被强制复活并传送回集结点,退出活动
4. 其他玩家可通过 ox_target 交互背包
5. 触发交互后显示 ox_lib 进度条（默认15秒）
   - 播放搜索动画（翻垃圾桶动作）
   - 禁止移动和其他操作
   - 可以取消搜索
6. 进度条完成后显示 ox_lib 菜单，可选择性拾取物品
7. 背包为空时自动清理,或在系统重置时批量清理

## 活动计时器机制
- 使用 `ActivityTimer` 标记控制计时器状态
- 警告线程和结束线程通过每秒检查 `ActivityTimer` 判断是否继续运行
- 支持随时停止计时器,避免资源泄漏
- 活动结束自动执行强制撤离和系统重置

## 撤离点随机选择机制
- 配置文件定义 `Config.Evacuation.all_points` 包含所有可用撤离点（共5个）
- 每局活动开始时,服务端从中随机选择 `Config.Evacuation.random_count` 个撤离点（默认2个）
- 服务端将选中的撤离点列表同步给所有客户端
- 客户端仅在选中的撤离点显示标记和交互
- 每局撤离点位置随机,增加游戏变化性

## 撤离范围检测机制
- 玩家请求撤离后,必须在 `Config.Evacuation.wait_range` 范围内等待
- 客户端每秒检测玩家位置,离开范围则取消撤离并通知服务端
- 服务端维护 `EvacuationRequests` 表,记录撤离请求和坐标
- 服务端在执行撤离前二次验证玩家是否仍在范围内
- 确保玩家必须真正停留在撤离范围内才能完成撤离

## 撤离延迟开启
- 活动开始后等待 `Config.Evacuation.delay_open_time` 秒才开启撤离点
- 使用独立线程控制,可被活动计时器停止打断
- 撤离点开启后通知所有岛上玩家,并在客户端生成标记

## 已撤离玩家机制
- `EvacuatedPlayers` 列表记录本次活动已成功撤离的玩家
- 防止玩家撤离后重复报名进入同一次活动
- 系统重置或活动结束时清空列表

## 武器箱系统机制
1. 活动开始时,服务端调用 `InitializeWeaponBoxes()` 生成30个武器箱
2. 所有客户端接收 `spawn_weapon_box` 事件,创建武器箱实体并添加 ox_target 交互
3. 玩家交互武器箱时:
   - 服务端检查箱子是否已被锁定(防并发)
   - 锁定成功后触发客户端进度条(默认8秒搜索动画)
   - 进度条完成后,服务端根据权重随机选择物品并给予玩家
   - 武器箱标记为已开启,所有客户端删除该实体
4. 使用 `BoxLocks` 表防止同一箱子被多个玩家同时搜索
5. 活动结束时调用 `ClearAllWeaponBoxes()` 清理所有箱子

**物品掉落**: 使用加权随机算法,权重越高概率越大。每次搜索保证获得一件物品。

## 物资刷新系统机制
1. 活动开始时,服务端为每个区域的每个刷新点生成随机数量的物品
2. 物品从区域的 `loot_table` 中按 `amount` 配置随机抽取
3. 客户端显示红色箭头标记和 ox_target 交互
4. 玩家拾取物品时:
   - 触发15秒拾取进度条(可配置)
   - 播放搜索动画并禁止移动
   - 完成后从物资点随机移除一个物品并给予玩家
5. 物资点物品全部拾取完毕后自动清理标记
6. 不同区域有不同的物品数量范围和物品稀有度

**区域设计**:
- 普通区域: 1-3件物品,低稀有度
- 战斗区域: 1-3件物品,中稀有度
- 险恶区域: 3-6件物品,高稀有度
- 别墅区: 5-10件物品,顶级稀有度

---

# 常见开发任务

## 修改岛屿范围或坐标
编辑 `config.lua:16-19` 中的 `Config.IslandCenter` 和 `Config.IslandRadius`

## 调整活动时长
编辑 `config.lua:117` 中的 `Config.Activity.duration` (单位: 秒)

## 修改撤离点位置
编辑 `config.lua:65-146` 中的 `Config.Evacuation.all_points` 表

## 调整背包规则
修改 `server/inventory.lua:34-46` 中的 `IsAllowedItem()` 函数逻辑

## 添加新的撤离点
在 `config.lua:65-146` 的 `Config.Evacuation.all_points` 表中添加新的撤离点配置

## 调整每局撤离点数量
修改 `config.lua:152` 中的 `Config.Evacuation.random_count`

## 修改死亡背包物品显示
编辑 `client/death.lua:180-236` 中的 `show_bag_menu` 菜单构建逻辑

## 调整复活逻辑
修改 `server/death.lua:85-91` 中的医护脚本调用参数

## 调整背包搜索时间和动作
修改 `config.lua:277-289` 中的 `Config.DeathBag.search_progress` 配置
- `duration`: 搜索时长（毫秒）
- `animation.dict` 和 `animation.clip`: 动画字典和动作名称

## 修改武器箱配置
编辑 `config.lua:568-649` 中的 `Config.WeaponBoxes` 配置
- `enabled`: 总开关
- `spawn_points`: 武器箱刷新点位（共30个）
- `loot_table`: 掉落物品池（加权随机）
- `progress.duration`: 搜索时长（默认8秒）

## 修改物资点配置
编辑 `config.lua:303-554` 中的 `Config.Resources` 配置
- `enabled`: 总开关
- `zones`: 物资区域配置（包含普通/战斗/险恶/别墅四个区域）
- `global.pickup_progress.duration`: 拾取时长（默认15秒）

---

# 调试与开发

## 调试模式

在 `config.lua:8` 设置 `Config.Debug = true` 启用调试模式。调试模式会在服务器控制台输出详细日志:
- 玩家进入/离开岛屿事件
- 背包存储/恢复操作
- 死亡背包创建/清理
- 武器箱生成/开启状态
- 物资点初始化和拾取

**重要**: 生产环境请关闭调试模式以优化性能。

## 测试活动流程

完整测试流程:
1. 启动 FiveM 服务器并加载资源
2. 控制台执行 `island_toggle` 开启系统
3. 玩家前往机场报名点 (-1026, -3018, 14) 与 NPC 交互报名
4. 控制台执行 `island_status start` 启动活动
5. 观察:
   - 玩家被传送到高空并自动开伞
   - 武器箱在30个点位生成
   - 物资点在4个区域生成红色箭头标记
   - 非武器物品被暂存
6. 测试搜索武器箱和拾取物资
7. 等待撤离点开启(默认30分钟后)或使用 Config 调低 `delay_open_time` 快速测试
8. 前往撤离点测试撤离流程
9. 测试死亡背包和复活系统
10. 控制台执行 `island_toggle` 关闭系统

## 常见问题排查

### 武器箱不生成
- 检查 `Config.WeaponBoxes.enabled = true`
- 查看控制台是否有 "武器箱系统已初始化" 消息
- 确认活动已启动 (不仅是系统开启)

### 物资点不显示
- 检查 `Config.Resources.enabled = true`
- 确认客户端收到 `initialize_resources` 事件
- 检查客户端是否在岛屿范围内

### 撤离点不出现
- 确认活动已启动超过 `Config.Evacuation.delay_open_time` 秒
- 检查服务端是否成功随机选择撤离点
- 查看客户端是否收到 `open_evacuation` 事件

### 背包物品丢失
- 检查 `PlayerInventoryBackup` 表是否有玩家数据
- 确认 `StorePlayerInventory()` 在空投前被调用
- 查看 `RestorePlayerInventory()` 是否在撤离时执行

## 性能优化建议

1. **位置检测间隔**: `Config.CheckInterval` 建议设置为 5000ms 或更高
2. **减少物资点数量**: 如服务器性能较差,可减少 `Config.Resources.zones` 中的刷新点
3. **调整进度条时长**: 较长的进度条可减少快速交互导致的网络压力
4. **关闭调试模式**: 生产环境设置 `Config.Debug = false` 以优化性能

## 与其他脚本集成

本脚本依赖以下资源:
- **qb-core**: 玩家管理、物品系统
- **qs-inventory**: 背包操作 (可替换为其他背包系统,需修改 server/inventory.lua)
- **ox_target**: 交互系统
- **ox_lib**: 进度条、菜单系统

如需更换背包系统,重点修改:
- `server/inventory.lua`: 背包存储/恢复逻辑
- `server/death.lua`: 死亡背包物品转移逻辑

## 扩展建议

可扩展功能方向:
- 添加 NPC 敌人巡逻系统
- 实现组队机制和队友标记
- 增加特殊任务和奖励系统
- 添加排行榜和统计功能
- 实现动态难度调整

---

**注意**: 详细的武器箱系统说明请参考 `武器箱系统说明.md` 文件。
