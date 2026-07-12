# CloudKit 多设备同步配置指南

## 概述

菜搭子使用 SwiftData + CloudKit 实现多设备自动同步。食材、菜谱、分类、标签、扫描记录都会在登录同一 Apple ID 的设备间自动同步。

## 技术架构

```
┌───────────┐    ┌───────────┐    ┌───────────┐
│ iPhone A  │    │  iPad     │    │ iPhone B  │
│ SwiftData │    │ SwiftData │    │ SwiftData │
└─────┬─────┘    └─────┬─────┘    └─────┬─────┘
      │                │                │
      └────────────────┼────────────────┘
                       │
                  ┌────▼────┐
                  │ CloudKit│
                  │ (iCloud)│
                  └─────────┘
```

## 第一步：Apple Developer 配置

### 1.1 在 App Store Connect 创建 App ID

1. 登录 [developer.apple.com](https://developer.apple.com)
2. 进入 **Certificates, Identifiers & Profiles** → **Identifiers**
3. 点击 **+** 新建 App ID
4. 选择 **App IDs**，Bundle ID 填 `com.caidaizi.app`
5. 在 Capabilities 中勾选 **iCloud**
6. 保存

### 1.2 创建 iCloud Container

1. 在同一页面，找到刚创建的 App ID
2. 点击 **iCloud** 能力 → **Configure**
3. 确保容器 `iCloud.com.caidaizi.app` 已关联
4. 保存

### 1.3 更新 Provisioning Profile

1. 进入 **Profiles** 页面
2. 找到项目的 Development/Distribution Profile
3. 点击 **Edit** → 确保 iCloud 能力已包含
4. 重新下载并安装

## 第二步：Xcode 配置

### 2.1 添加 iCloud 能力

1. 打开 `菜搭子.xcodeproj`
2. 选择 target → **Signing & Capabilities**
3. 点击 **+ Capability** → 搜索并添加 **iCloud**
4. 勾选 **CloudKit**
5. 确保容器为 `iCloud.com.caidaizi.app`

### 2.2 验证 Signing

- Team 已选择你的 Apple Developer 账号
- Bundle Identifier 为 `com.caidaizi.app`

### 2.3 测试 CloudKit

在 Xcode 中运行 App 后：

1. 在 iPhone 上添加一些食材和菜谱
2. 在同一 Apple ID 的 iPad 上打开 App
3. 等待几秒 → 数据自动同步
4. 检查 Xcode Console 应有类似输出：
   ```
   CoreData: CloudKit: Setup success
   CoreData: CloudKit: Import success
   ```

## 第三步：调试与监控

### CloudKit Dashboard

1. 打开 [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
2. 选择容器 `iCloud.com.caidaizi.app`
3. 查看 **Records** → 实时查看同步的数据
4. 查看 **Logs** → 调试同步问题

### 常见问题

#### 数据不自动同步？
- 确认两台设备登录同一 Apple ID
- 确认 iCloud Drive 已开启（设置 → Apple ID → iCloud → iCloud Drive）
- 确认 App 有网络权限
- 同步有短暂延迟（通常几秒到几十秒）

#### 首次同步慢？
- 首次同步需要下载所有数据，较大量数据（数百条记录）可能需要十几秒
- 后续同步为增量同步，速度很快

#### 设备离线？
- 离线修改的数据会在恢复网络后自动上传
- SwiftData 自动处理冲突（以最后修改为准）

## 不需要额外的代码

菜搭子已通过以下配置完成 CloudKit 集成：

```swift
// App入口 (菜搭子App.swift)
let configuration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .automatic  // ← 关键：自动使用 CloudKit
)

let modelContainer = try ModelContainer(
    for: schema,
    configurations: configuration
)
```

**无需任何额外代码**。SwiftData 会自动处理：
- 模型 schema 迁移
- CloudKit record 映射
- 增量同步
- 冲突解决
- 离线支持

## 用户可见的同步状态

"我的"页面会显示 iCloud 同步状态：

- 🟢 **已连接 · 自动同步中** — 正常工作
- ⚪ **请在设置中登录 iCloud** — 未登录或未开启
