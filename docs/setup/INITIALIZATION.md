# 初始化与上机方案

## 1. 建议工程形态

编码阶段创建一个 Xcode workspace：

```text
DrivingTrainer.xcworkspace
├── DrivingTrainerApp       (iOS App target)
├── DrivingTrainerWatch     (watchOS App target)
├── DrivingTrainerWidgets   (远期可选，不在 MVP)
└── Local Swift Packages
    ├── Domain
    ├── Persistence         (MVP 为 JSON Store)
    ├── LocationKit
    └── DesignSystem
```

最低系统版本在首次编码时根据实机版本确定。由于 MVP 不依赖 SwiftData，可减少系统版本约束。

## 2. 初始化顺序

1. 确认 Mac、Xcode、iPhone、Watch 系统版本和开发者登录状态。
2. 在 Xcode 创建 iOS App，并勾选配套 watchOS App。
3. 设置唯一 Bundle ID、Team、自动签名和本地开发配置。
4. 先建立 Domain 与 LocationKit 两个本地模块；其他模块只有在代码增长后再拆分。
5. 配置定位、后台定位和 Watch 通信能力及权限文案。
6. 第一天先做空壳真机安装，再实现数据层和功能。
7. 加入单元测试、隐私清单和基本诊断日志。

## 3. 如何在 iPhone 上运行

开发期不需要先发布 App Store：

1. 用数据线或同一网络连接 iPhone 与 Mac，并在 iPhone 开启“开发者模式”。
2. 在 Xcode 登录 Apple ID，选择个人团队或付费开发者团队进行签名。
3. 选择真实 iPhone 为运行设备，点击 Run，Xcode 会安装开发版 App。
4. 首次运行按提示授予定位、通知等权限。
5. Watch App 可由配对 iPhone 安装；Xcode 也可选择配对的 Watch 进行调试。

免费 Apple ID 适合短期真机验证，但签名有效期和部分能力受限；如果要长期稳定自用、TestFlight 分发或使用完整能力，建议加入 Apple Developer Program。具体限制在实施时以 Apple 当前规则为准。

两周 MVP 的最短路径是个人 iPhone 通过 Xcode 直接安装。TestFlight 和 App Store 审核不作为前置条件。

## 4. 配置环境

- `Debug`：本地开发，允许详细诊断。
- `Release`：自用/TestFlight，关闭敏感日志。
- 密钥和 Team 信息不提交到版本库。
- MVP 不设置后端环境变量；未来服务端接入时再增加配置文件模板。

## 5. 第一轮工程验收

- iOS 空壳能安装并启动。
- Watch 空壳能安装，双方可发送 ping/pong。
- 权限拒绝时有清晰降级说明。
- 单元测试可一键运行。
- 仓库不包含个人签名、定位记录或私密照片。

## 6. Agent 编程工作流

每个功能按小任务交给 Agent：读取规划与当前代码 → 实现单一验收目标 → 运行测试/构建 → 汇报改动与风险。禁止一次生成整个 App 后再集中排错。

建议任务粒度：工程与真机空壳、模型与 JSON Store、路线页面、定位轨迹、提醒状态机、训练报告、Watch 摘要与震动。

每次合入前必须满足：项目可构建、相关测试通过、不新增无理由依赖、关键路径有真机验收记录。涉及定位权限、后台模式或签名的改动必须在真机验证。
