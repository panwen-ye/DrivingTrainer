# 开发状态

更新时间：2026-08-20

## 已完成

- Swift Package 工程基线。
- Route、RouteNode、TrackPoint、PracticeSession、NodeAttempt 核心模型。
- Codable JSON 原子化本地存储。
- 模型与存储测试用例。
- 生产模块通过 `swift build`。
- Xcode 26.6、iOS 26.5 与 watchOS 26.5 开发环境完成。
- iPhone + Apple Watch 联合工程构建成功；两个 target 使用独立内部产物名，中文显示名称保持一致。
- 30 项自动化测试全部通过，其中包含 7 项跨模块集成测试。
- iPhone 17 模拟器完成清洁安装与录制、节点、训练、复盘闭环验收。
- Personal Team 已绑定到工程，代码持续同步 GitHub `master`。
- 路线页支持粘贴 Apple 地图分享链接，通过 `MKDirections` 导入驾驶轨迹到指定考试路线，并保留已有训练提示点和考核项目。
- 路线录制显示距离、有效时长、GPS 精度、轨迹点和节点数。
- 训练支持完成、有困难、跳过、暂停、继续和暂停后结束。
- 路线详情增加轨迹地图；训练记录增加具体节点复盘。
- 增加独立考核播报点与模拟考试模式；只朗读预设考核项目，不混入训练口诀。
- iPhone 17 模拟器完成考核项目创建、保存、模式切换、自动触发及 0/1 → 1/1 进度验收。
- 路线详情支持点击地图选点，导入轨迹后可补充训练提示点和考核项目；数据保存/重载集成测试通过。
- Debug 模拟器联合构建与无签名 Release 真机架构联合构建均成功。

## 当前待办

- 连接、解锁并信任用户 iPhone，完成自动签名与安装。
- 在真机开启开发者模式并验证 GPS。
- 在已配对 Apple Watch 上验证摘要与震动。
- 按安全要求完成短距离实地测试。

## 测试资料

- [集成测试用例](../testing/INTEGRATION_TEST_PLAN.md)
- [2026-08-19 集成测试报告](../testing/INTEGRATION_TEST_REPORT_2026-08-19.md)
- [2026-08-20 完整回归报告](../testing/INTEGRATION_TEST_REPORT_2026-08-20.md)
- [需求与进度总览](../PROJECT_REQUIREMENTS_AND_PROGRESS.md)
- [iPhone 与 Apple Watch 安装方案](../setup/IPHONE_WATCH_DEPLOYMENT.md)
