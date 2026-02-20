# 紧急职业车载电台系统

这是一个为QBCore框架设计的紧急职业车载电台系统，支持police、lssd、ambulance三个职业。

## 功能特性

### 🚗 车载电台功能
- 自动检测紧急车辆并连接车载电台
- 职业独立的电台频道（police、lssd、ambulance互不干扰）
- 无视距离限制的语音通信

### 📻 调度员系统
- 每个职业只能有一个调度员
- 使用 `/diaodu` 命令注册/注销调度员身份
- 调度员可以使用U键进行全频喊话

### 🎤 语音控制
- 调度员：长按U键进行全频喊话
- 普通警员：长按U键联系调度员
- 与pma-voice完全兼容

## 安装说明

1. 将脚本放入服务器的resources文件夹
2. 在server.cfg中添加：`ensure yx_car_radio`
3. 重启服务器

## 使用方法

### 调度员注册
```
/diaodu - 注册或注销调度员身份
```

### 语音控制
- **调度员**：在紧急车辆中长按U键进行全频喊话
- **普通警员**：在紧急车辆中长按U键联系调度员

### 管理员命令
```
/dispatchers - 查看当前调度员状态（需要管理员权限）
```

## 支持的车辆

### Police
- police, police2, police3, police4
- policeb, policet, sheriff, sheriff2
- ambulance, firetruk, fbi, fbi2
- riot, pranger

### LSSD
- sheriff, sheriff2, sheriff3
- sheriff4, sheriff5, sheriff6

### Ambulance
- ambulance, ambulance2
- firetruk, firetruk2

## 配置说明

在 `config.lua` 中可以修改：
- 支持的车辆类型
- 支持的职业
- 频道前缀
- 按键设置
- 通知消息

## 依赖项

- qb-core
- pma-voice

## 技术特点

- 使用异步线程避免死循环
- 模块化设计，易于维护
- 优化的性能表现
- 完整的错误处理

## 注意事项

1. 确保pma-voice已正确安装和配置
2. 车载电台与对讲机频道完全独立
3. 调度员断开连接时会自动清理状态
4. 支持热重载配置

## 版本信息

- 版本：1.0.0
- 作者：YX
- 框架：QBCore
- 语音系统：pma-voice 