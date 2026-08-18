# 资源与需要安装的应用

## 必需硬件

- 一台可运行当前 Xcode 的 Mac。
- iPhone 与 Apple Watch，且二者已配对。
- 数据线（首次配对、真机部署和排障更稳定）。
- 车载安全支架与充电设备；驾驶时不手持操作。

## 必需软件与账号

| 项目 | 用途 | 当前是否安装需确认 |
|---|---|---|
| Xcode | 创建、签名、调试 iOS/watchOS App | 是 |
| Apple ID | 本地开发签名 | 是 |
| Apple Developer Program | 长期安装、TestFlight/商店分发，MVP 可稍后决定 | 否/可选 |
| Git | 版本管理，Xcode 随附工具通常可用 | 是 |

不要求安装 Java/JDK、Android Studio、Node.js、Docker、数据库客户端或第三方地图工具。Xcode 自带 Swift 工具链即可完成 MVP。

## Apple 开发资源

- Bundle ID 与签名 Team。
- App 图标、启动视觉和隐私说明。
- 定位用途文案：前台与后台用途必须清晰区分。
- Background Modes / Location updates entitlement。
- WatchConnectivity 配套 target。
- 若后续同步：iCloud + CloudKit capability，不在两周 MVP 启用。

## 路线内容资源

- 1、3、4 号线的确认版 GPS 坐标或实车录制轨迹。
- 每条路线的节点顺序、项目类型、提醒距离和操作口诀。
- 经授权的节点照片、图标和提示音。
- 路线版本日期和来源说明。

当前根目录 HTML 可用于人工核对路线和口诀，但其中引用了本机绝对路径的百度地图图片，不能直接打包，也不能替代可授权的 App 地图数据。

## 测试资源

- 室外步行测试路线，用于先验证定位和提醒，避免一开始就上车调试。
- 至少一次副驾驶采集，由非驾驶员操作设备。
- GPS 弱、断网、锁屏、低电量、Watch 断连等测试场景。
- 脱敏的 GPX 测试轨迹，支持模拟器重复回放。
