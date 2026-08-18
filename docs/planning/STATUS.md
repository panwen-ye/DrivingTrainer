# 开发状态

更新时间：2026-08-18

## 已完成

- Swift Package 工程基线。
- Route、RouteNode、TrackPoint、PracticeSession、NodeAttempt 核心模型。
- Codable JSON 原子化本地存储。
- 模型与存储测试用例。
- 生产模块通过 `swift build`。

## 当前环境阻塞

本机未发现完整 Xcode，当前激活路径为 Command Line Tools。现有命令行 SDK 还缺少 XCTest，因此测试用例已创建但需安装完整 Xcode 后运行。iOS/watchOS App target、模拟器构建、签名和真机安装同样需要完整 Xcode。

## 恢复后的下一步

1. 安装 Xcode，并首次启动完成组件安装。
2. 将开发者目录切换到 Xcode。
3. 运行 `swift test` 验证现有 5 个测试。
4. 创建 iOS/watchOS target 并接入本地 Package。
5. 完成首个 iPhone 空壳安装，再继续路线列表界面。
