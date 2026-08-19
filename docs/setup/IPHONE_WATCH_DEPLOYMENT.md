# 推送并安装到 iPhone 与 Apple Watch

更新时间：2026-08-20  
适用项目：DrivingTrainer 个人 MVP  
工程：`DrivingTrainer.xcodeproj`  
iPhone Bundle ID：`com.panwenye.DrivingTrainer`  
Watch Bundle ID：`com.panwenye.DrivingTrainer.watchkitapp`

## 1. 推荐方案

当前阶段使用 Xcode + Personal Team 通过 USB 或受信任的无线连接直装。这条路径无需 App Store、TestFlight 或付费服务器，最适合个人两周 MVP。

Watch App 已嵌入 iPhone App。通常先把 iPhone App 安装到已与 Watch 配对的 iPhone，系统会根据 Watch App 的“自动安装 App”设置同步安装；必要时也可在 Xcode 中单独运行 `DrivingTrainerWatch` scheme。

## 2. 准备条件

### Mac

- macOS 能运行 Xcode 26.6。
- 已安装 iOS 26.5 和 watchOS 26.5 平台组件。
- 已在 Xcode → Settings → Accounts 登录 Apple ID。
- 工程已配置 Personal Team：`7446Z7NZ56`。

### iPhone

- 使用数据线连接 Mac，解锁并选择“信任此电脑”。
- iOS 版本不能高于当前 Xcode 支持范围。
- 预留足够存储空间。
- 首次运行开发 App 时需要开启“开发者模式”。

### Apple Watch

- 已与上述 iPhone 正常配对。
- Watch 已解锁并佩戴，蓝牙/Wi-Fi 正常。
- Watch App → 通用 → 自动安装 App 建议开启。
- watchOS 版本不能高于当前 Xcode 支持范围。

## 3. 第一次安装到 iPhone

1. 在 Finder 中确认 iPhone 已出现并完成信任。
2. 打开 `DrivingTrainer.xcodeproj`。
3. 在 Xcode 顶部选择 scheme：`DrivingTrainerApp`。
4. 在运行设备中选择已连接的真实 iPhone，不要选择模拟器。
5. 打开项目 → Targets → DrivingTrainerApp → Signing & Capabilities。
6. 确认：
   - Automatically manage signing 已开启；
   - Team 为当前 Personal Team；
   - Bundle Identifier 无冲突。
7. 点击 Run，或按 `⌘R`。
8. 如果 iPhone 提示需要开发者模式：
   - 设置 → 隐私与安全性 → 开发者模式；
   - 开启后按系统提示重启；
   - 重启后确认启用，再回到 Xcode 重新 Run。
9. 首次启动允许“使用 App 时定位”。MVP 当前不请求始终定位。

## 4. 安装到 Apple Watch

### 方案 A：随 iPhone App 自动安装（推荐）

1. 保持 Watch 与 iPhone 配对、解锁并在附近。
2. 通过 `DrivingTrainerApp` scheme 安装 iPhone App。
3. 打开 iPhone 的 Watch App。
4. 在“可用 App”或“已安装到 Apple Watch”中查找“驾考训练”。
5. 若未自动安装，点击“安装”。
6. 在 Watch 上启动“驾考训练”，应显示“等待 iPhone 开始训练”。

### 方案 B：Xcode 单独运行 Watch scheme

1. Xcode 顶部切换为 `DrivingTrainerWatch` scheme。
2. 运行设备选择与目标 iPhone 配对的 Apple Watch。
3. 等待 Xcode 完成准备设备和安装。
4. 点击 Run。

首次连接 Watch 时，Xcode 可能需要较长时间下载符号或准备设备。不要在设备仍显示 Preparing 时反复断开连接。

## 5. 真机验收顺序

### iPhone 基础验收

1. 冷启动无崩溃。
2. 训练页显示 1、3、4 号路线。
3. 路线页进入录制，确认定位授权、GPS 精度、时长和轨迹点更新。
4. 步行 5–10 分钟，检查轨迹连续性。
5. 添加节点、保存路线，退出并重启 App，确认数据仍存在。
6. 开始训练，验证完成、有困难、跳过、暂停、继续和结束。
7. 打开记录详情，确认节点结果正确。
8. 从 Apple 地图复制一条真实驾驶路线链接，导入后在地图上核对。

### Watch 联动验收

1. Watch App 初始显示等待状态。
2. iPhone 选择路线，Watch 显示路线名称和下一节点。
3. iPhone 进入节点提醒半径，Watch 文案更新并产生通知触觉。
4. 临时关闭 Watch 蓝牙或离开连接范围，确认 iPhone 训练不崩溃。
5. 恢复连接后开始下一个节点，确认摘要重新同步。

### 安全要求

- 第一次实地验证优先步行完成。
- 道路测试必须由副驾持有和操作手机，驾驶员不得触屏。
- 不在正式考试或复杂道路环境中调试。

## 6. Release 构建方案

个人真机测试通过后，可在 Xcode 中执行：

1. Scheme 选择 `DrivingTrainerApp`。
2. 运行目标选择 Any iOS Device 或已连接 iPhone。
3. Product → Archive。
4. 在 Organizer 中选择 Distribute App。
5. 个人测试继续使用 Development 分发；若以后加入付费 Apple Developer Program，再选择 TestFlight/App Store Connect。

Personal Team 通常不适合长期分发，签名可能需要周期性重新安装。个人 MVP 阶段这是预期限制，不是应用故障。

## 7. 常见问题

### Xcode 看不到 iPhone

- 解锁 iPhone，重新插线并确认信任。
- 更换支持数据传输的数据线或 USB 端口。
- 打开 Xcode → Window → Devices and Simulators 检查状态。

### Signing requires a development team

- 在两个 Targets（DrivingTrainerApp、DrivingTrainerWatch）中选择同一个 Team。
- 保持 Automatically manage signing 开启。

### Bundle identifier 已被占用

- 使用只属于当前 Apple ID 的唯一 Bundle ID。
- 同时更新 Watch Bundle ID 和 companion identifier，保持父子关系一致。

### iPhone 提示无法验证开发者

- 确认设备联网。
- 在设置中的 VPN 与设备管理/开发者 App 项目里信任对应 Apple ID（系统版本不同，入口名称可能不同）。
- 确认开发者模式已经开启。

### Watch App 没有出现

- 确认 Watch 与安装 iPhone App 的同一台 iPhone 配对。
- 检查 Watch App 中是否关闭了自动安装。
- 检查 `WKCompanionAppBundleIdentifier` 是否为 `com.panwenye.DrivingTrainer`。
- 在 Xcode Devices and Simulators 中等待 Watch 完成准备，再单独运行 Watch scheme。

### Watch 没有震动

- 确认 Watch 不处于剧院模式或关闭触觉的状态。
- 保持 Watch 佩戴并解锁。
- 先确认 Watch 文案是否更新；文案更新但无触觉时再检查系统触觉设置。

## 8. 完成判定

同时满足以下条件才可标记为“真机交付完成”：

- iPhone 能安装、冷启动和重新启动。
- 真实 GPS 录制、节点保存和训练提醒通过。
- Watch App 能安装、收到下一节点摘要并震动。
- 断连时 iPhone 主流程不受影响。
- 测试结果已回写集成测试报告。

