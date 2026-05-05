# HolidaySettings

原生 SwiftUI iPhone App，用于设置闹钟，并自动跳过中国法定节假日。项目目标为 iOS 26.1，闹钟调度使用 Apple `AlarmKit`。

## 功能

- 添加、编辑、删除闹钟。
- 支持选择重复星期。
- 使用 iOS 26.1 `AlarmKit` 调度系统级闹钟。
- 按国务院办公厅通知内置 2025-2026 年官方放假安排和补班日期。
- 只保留全体公民放假的节日：元旦、春节、清明节、劳动节、端午节、中秋节、国庆节。
- 元宵节、七夕节、重阳节、腊八节等不放假的传统节日不再作为内置免闹钟节日。
- 补班日自动覆盖假期跳过规则，无需手动添加调休日。
- 支持添加、编辑、删除自定义免闹钟节日。
- 闹钟和节日设置自动保存到 `UserDefaults`。
- 支持从 App 内导出节日 JSON 配置。

## 闹钟实现

iOS 26.1 的 `AlarmKit` 支持真正的系统闹钟。为了让节日当天不响，App 不使用一条简单的每周重复闹钟，而是为每个启用的闹钟预排未来 90 天内的固定日期闹钟：

- 符合重复星期的日期会被纳入计划。
- 如果当天在官方放假区间内，则跳过。
- 如果当天是官方补班日，则正常响铃。
- 每个闹钟最多预排 64 个未来响铃点。
- 修改闹钟或节日后，App 会取消旧计划并重新同步。

## 官方假期数据

当前内置官方数据覆盖：

- 2025 年：元旦、春节、清明节、劳动节、端午节、国庆节/中秋节，以及 5 个补班日。
- 2026 年：元旦、春节、清明节、劳动节、端午节、中秋节、国庆节，以及 6 个补班日。

数据来源：

- 《全国年节及纪念日放假办法》。
- 国务院办公厅关于 2025 年部分节假日安排的通知。
- 国务院办公厅关于 2026 年部分节假日安排的通知。

## 数据位置

`UserDefaults` key:

```text
cn.holiday.settings.configuration.v1
cn.holiday.settings.alarms.v1
```

保存内容为 `HolidayConfiguration` 的 JSON 编码数据：

```json
{
  "customHolidays": [],
  "selectedHolidayIDs": [
    "dragon-boat",
    "labor-day",
    "mid-autumn",
    "national-day",
    "new-year",
    "qingming",
    "spring-festival"
  ],
  "updatedAt": "2026-05-04T12:00:00Z"
}
```

## 打开方式

用 Xcode 26 打开：

```text
HolidaySettings.xcodeproj
```

当前工程只面向 iPhone：

```text
IPHONEOS_DEPLOYMENT_TARGET = 26.1
TARGETED_DEVICE_FAMILY = 1
```
