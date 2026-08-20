# 奔跑的阿旭1.0 APP

面向 iPhone + Apple Watch 的科目三个人训练工具。项目已进入 MVP 开发，核心业务模块、iPhone 工程、路线录制和训练闭环均已落地。

## 当前产品定位

- iPhone 是主设备：路线录制、Apple 地图共享链接导入、地图查看、训练提示点与独立考核项目编辑、训练和复盘。
- Apple Watch 是辅助设备：快捷标记、震动提示、训练状态查看。
- MVP 优先本地运行、离线可用，不依赖自建服务器。
- 第一目标是在 2026 年 8 月 23 日交付可安装到个人 iPhone 的轻量 MVP，支持武汉同心考场 1、3、4 号路线训练。
- 全程采用 Agent 辅助开发，但每个阶段必须经过自动测试和真机验收。

## 文档入口

- [产品范围与页面原型](docs/product/PRODUCT_AND_PROTOTYPE.md)
- [模拟考试考核项目播报设计](docs/product/EXAM_ANNOUNCEMENT_MODE.md)
- [技术与服务架构](docs/architecture/ARCHITECTURE.md)
- [地图接入与坐标链路](docs/architecture/MAP_INTEGRATION.md)
- [初始化与上机方案](docs/setup/INITIALIZATION.md)
- [资源与应用清单](docs/setup/RESOURCES.md)
- [分阶段开发计划](docs/planning/ROADMAP.md)
- [当前开发状态](docs/planning/STATUS.md)
- [需求与进度总览](docs/PROJECT_REQUIREMENTS_AND_PROGRESS.md)
- [推送并安装到 iPhone 与 Apple Watch](docs/setup/IPHONE_WATCH_DEPLOYMENT.md)
- [数据模型草案](docs/architecture/DATA_MODEL.md)
- [决策记录](docs/decisions/0001-native-apple-stack.md)

## 目录结构

```text
DrivingTrainer/
├── apps/
│   ├── iOS/                 # 后续生成 iPhone App target
│   └── watchOS/             # 后续生成 Watch App target
├── packages/
│   ├── Domain/              # 路线、节点、训练记录等纯业务模型
│   ├── Persistence/         # MVP JSON 存储；未来可迁移 SwiftData
│   ├── LocationKit/         # 定位、轨迹过滤与后台记录
│   └── DesignSystem/        # 共用颜色、组件和图标规范
├── services/
│   └── backend-placeholder/ # 云同步/AI 的远期占位，不在 MVP 启用
├── resources/
│   ├── route-seeds/         # 可导入的路线种子数据
│   └── media/               # 自有或已授权的图片/音频
├── docs/                    # 产品、架构、计划和决策文档
├── tests/
│   ├── unit/
│   └── fixtures/
└── tools/                   # 后续放数据校验、导入等辅助工具
```

现有根目录 `tongxin-kemu3-routes.html` 作为路线资料参考，保持原样，不纳入 App 运行依赖。

## MVP 技术结论

- 语言：Swift，不使用 Java。
- UI：SwiftUI。
- 地图与定位：MapKit + Core Location；支持通过 Apple 地图路线共享链接导入轨迹。
- 存储：首版使用轻量 JSON/Codable 文件存储；达到真实数据量后再决定是否迁移 SwiftData。
- Watch：两周 MVP 只做震动提醒和下一节点摘要；复杂通信与手表录制后移。
- 服务端：无；首版完全本地运行。
- 第三方依赖：默认 0 个。

## 当前验证状态

- 30 项 Swift 自动化测试全部通过，其中包含 7 项跨模块集成测试。
- Xcode 工程可由 `xcodegen generate` 稳定生成。
- iPhone 与嵌入 Watch App 已通过模拟器目标构建和安装。
- Personal Team 已配置；真机安装等待连接、解锁并信任用户 iPhone。
- 三条同心考场路线可实地录制，也可从 Apple 地图路线共享链接导入后人工校准。
