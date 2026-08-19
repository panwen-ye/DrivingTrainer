# 地图接入与坐标链路

## 结论

应用只接入 Apple 原生 `MapKit` 和 `CoreLocation`，没有引入高德、百度、Google 或网页地图 SDK。地图底图使用 `Map` 的 `.standard` 样式；设备位置和录制轨迹来自 `CLLocationManager`。因此，定位坐标从采集到展示始终处于同一套 Apple 原生框架链路内，没有在应用层混用不同地图坐标。

这里的“正确地图”有两层含义：

1. SDK 接入正确：由 MapKit 显示 Apple 针对设备所在地区提供的地图数据。
2. 路线内容正确：训练路线来自用户实际录制的 GPS 点和手工标记的考试节点，不是根据道路名称猜测，也不由地图自动规划。

应用可以保证第一层代码链路和第二层数据来源，但不能替地图数据供应方保证道路更新时效，也不能自动证明某条路线仍是考场最新官方考试路线。正式训练前仍应由用户对照考场现场信息确认。

## 数据流

```text
iPhone GPS
  → CLLocationManager / CLLocation
  → TrackPointFilter 过滤低精度点和异常跳点
  → TrackPoint(Coordinate: latitude + longitude)
  → 本地 JSON 路线文件
  → CLLocationCoordinate2D
  → MapPolyline / Marker
  → Apple MapKit 标准地图
```

`Coordinate` 只保存经纬度数值，不执行 GCJ-02、BD-09 等第三方坐标转换。当前路线全部来自 `CoreLocation`，并直接交回 `MapKit` 渲染。以后如果支持导入高德、百度或其他来源的坐标，必须同时记录坐标系并在导入边界做显式转换；不能直接混入当前路线数据。

## 录制地图

`RecordingView` 使用绑定的 `MapCameraPosition`：

- 初始相机优先跟随用户位置；定位尚未取得时由 MapKit 自动选择视野。
- `interactionModes: [.pan, .zoom]` 明确允许拖动和双指缩放。
- `MapUserLocationButton`、`MapCompass` 和 `MapScaleView` 分别提供回到当前位置、方向和比例尺。
- 自定义 `MapZoomButtons` 提供始终可见的加/减按钮。点击后按 0.5 或 2 倍调整相机距离，并限制在 40 米至 20,000 公里，避免相机距离无效。
- 实时轨迹点转换为 `CLLocationCoordinate2D`，两个点以上时由 `MapPolyline` 连成蓝色轨迹。

## 训练地图

`TrainingPreviewView` 使用相同的地图控件和缩放逻辑。进入页面时，代码把轨迹点与考试节点转换为 `MKMapPoint`，求出包围全部点的 `MKMapRect`，再增加 15%（且最少 500 MapKit 点）的边距。这样训练页首次显示时会尽量完整呈现整条路线，而不是停留在全国视野或只显示单个节点。

空路线没有可框选坐标时，初始相机回退到用户位置；用户随后仍可通过手势、加减按钮或定位按钮改变视野。

## 距离提醒与地图的关系

节点提醒不依赖地图画面上的道路或屏幕像素。`GeoDistance` 根据两个经纬度点计算球面距离，`ReminderEngine` 再将距离与节点提醒半径比较。即使用户缩放或拖动地图，提醒距离也不会改变。

## 验证清单

- iPhone 目标使用 iOS 26.5 SDK 编译成功。
- 自动化 Domain、Persistence、Integration 测试 21 项全部通过。
- iPhone 17 模拟器中放大、缩小按钮均可访问。
- 点击放大后地图比例尺从约 36 米变化为约 15 米。
- 训练节点标记、当前位置按钮和 Apple 地图法律信息正常显示。

