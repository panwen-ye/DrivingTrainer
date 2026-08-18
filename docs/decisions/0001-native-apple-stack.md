# ADR-0001：采用 Apple 原生、本地优先技术栈

- 状态：拟定，编码前确认
- 日期：2026-08-18

## 决策

使用 Swift、SwiftUI、MapKit、Core Location、Codable JSON 存储和 WatchConnectivity。iPhone 为主应用，Apple Watch 为轻量辅助端；两周 MVP 不建设自有后端，不引入第三方依赖。

## 原因

目标设备均为 Apple 平台，核心能力高度依赖定位、地图、语音和手表通信。原生方案能减少跨平台桥接、包体和服务运维，更适合两周内完成可靠个人版。Java 不是 iOS 原生开发语言，在本项目中只会增加桥接和部署成本。

## 代价

首版不能直接覆盖 Android；部分模块依赖较新的系统版本；需要 Mac、Xcode 和 Apple 签名体系。

## 复审条件

出现明确 Android 用户需求、多人协作路线库、跨平台同步或服务端分析需求时，重新评估客户端和后端边界。
