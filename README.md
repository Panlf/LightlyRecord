# 轻记 · LightlyRecord

> 一款 **纯本地、零云端** 的极简 Android 记账 App —— 用 Flutter + SQLite 打造，无账号、无后端、无网络权限，所有数据只存在你自己的手机里。

`轻记` 把所有记账能力收敛到一个清爽的界面里：多账本、自定义分类、预算管理、收支统计、日历视图、6 套主题，以及一个随手就能记一笔的「山峦」悬浮按钮。

---

## 📋 目录

- [功能特性](#功能特性)
- [界面与交互](#界面与交互)
- [技术栈](#技术栈)
- [项目架构](#项目架构)
- [目录结构](#目录结构)
- [环境要求](#环境要求)
- [构建与运行](#构建与运行)
- [设计原则](#设计原则)
- [开源协议](#开源协议)
- [免责声明](#免责声明)

---

## 功能特性

- **📒 多账本管理**：生活账、旅行账、装修账……想开几个开几个，数据互不干扰。
- **🏷 自定义分类**：内置常用收支分类，支持自定义名称、图标与配色；图标自动配浅底，清晰可见。
- **💰 预算管理**：按月设预算，首页预算卡**默认隐藏**，在「我的 → 预算管理」开启后才出现，不打扰极简党。
- **📊 收支统计**：分类占比、收支趋势等图表，按月洞察花在哪、赚多少。
- **🗓 日历视图**：每一天按金额热力着色，点开看当日明细，打卡式回顾一目了然。
- **🎨 6 套主题**：薄荷 / 雾蓝 / 暖沙 / 樱粉 / 薰衣草 / 暗夜，随心情一键切换。
- **📤 数据导出**：一键导出 CSV，通过系统分享面板发给邮箱或表格，方便备份与对账。
- **⚡ 山峦 FAB**：底部悬浮的「山峦」按钮，点一下展开，记一笔快到飞起。

---

## 界面与交互

底部 5 个 Tab 常驻（`IndexedStack`），双击返回键退出：

| Tab | 名称 | 核心内容 |
|-----|------|----------|
| 今日 | 明细 | 问候语 + 当前账本名（标题联动）、本月概览卡（支出 / 收入 / 结余 / 环比 / 日均）、预算卡（可选）、当日明细列表 |
| 图表 | 统计 | 分类占比、收支趋势等可视化图表 |
| 日历 | 日历 | 每日金额热力、选中日明细 |
| 账本 | 账本 | 账本列表、新建 / 重命名 / 删除（默认账本不可删） |
| 我的 | 设置 | 主题切换、预算管理开关、分类管理、数据导出、关于 |

「记一笔 / 交易详情 / 预算 / 主题 / 分类」均以**滑入页**形式从右侧滑出，不打断主流程。

---

## 技术栈

| 类别 | 选型 |
|------|------|
| 框架 | Flutter 3.32.5 / Dart 3.8.1 |
| 本地存储 | SQLite（`sqflite`）+ `path` |
| 状态管理 | `provider`（ChangeNotifier + MultiProvider） |
| 格式化 | `intl`（NumberFormat 千分位 / DateFormat 日期） |
| 文件与系统 | `path_provider`、`package_info_plus`、`share_plus` |
| 本地化 | `flutter_localizations`（中文日期选择器） |

---

## 项目架构

采用**单向分层**架构，依赖方向严格向下，UI 永远不直接碰数据库：

```
pages (UI)  →  state (Controller)  →  repository  →  dao  →  db (SQLite)
```

- **pages**：5 个 Tab + 若干滑入页，遵循 `attach() / detach()` 生命周期与 `context.watch` 订阅。
- **state**：各页 Controller（Home / Stats / Calendar / Book / Me / Theme）与全局 `AppState`，持有派生数据与加载态；经 `dataVersion` 总线在写操作后统一重算。
- **repository**：业务聚合层，唯一定义「本月支出」「日均」「环比」「预算进度」等派生指标口径。
- **dao**：单表 CRUD，参数化 SQL，杜绝注入。
- **db**：`AppDatabase` 单例，负责建库、版本迁移与种子数据。

数据实体（5 类）：`Txn`（交易记录）、`Category`（分类）、`Book`（账本）、`Budget`（预算）、`Pref`（偏好设置）。

---

## 目录结构

```
lib/
├── core/            # 金额 / 日期格式化、全局常量
├── data/
│   ├── dao/         # 各表数据访问对象
│   ├── db/          # AppDatabase 单例、版本迁移、种子数据
│   ├── model/       # Txn / Category / Book / Budget / Pref / TxType
│   └── repository/  # 业务聚合层（6 个 Repository）
├── icons/           # 内置 SVG 分类图标
├── pages/           # 5 Tab + 滑入页
│   ├── add_tx/      # 记一笔（滑入）
│   ├── tx_detail/   # 交易详情（滑入）
│   ├── budget/      # 预算（滑入）
│   ├── theme/       # 主题（滑入）
│   ├── category/    # 分类管理（滑入）
│   ├── books/       # 账本页
│   ├── calendar/    # 日历页
│   ├── home/        # 今日页
│   ├── stats/       # 图表页
│   ├── me/          # 我的页
│   └── shell/       # 底部 5 Tab 主壳
├── painters/        # 自定义绘制（如仪表盘）
├── router/          # 滑入路由 SlideRoute
├── state/           # 各页 Controller + AppState
├── theme/           # AppColors / AppDimens / AppTypography / AppTheme（6 套主题）
├── utils/           # 导出服务等
└── widgets/         # 通用组件（卡片、Toast、对话框、山峦 FAB 等）

docs/                # PRD、架构设计、类图 / 时序图（Mermaid）
test/                # 单元与仓库层测试
android/             # Android 工程（含构建配置）
```

> 想深入了解需求与架构，可阅读 `docs/PRD-轻记.md` 与 `docs/ARCHITECTURE-轻记.md`。

---

## 环境要求

- **Flutter SDK** ≥ 3.32（开发与构建）
- **Android SDK**（构建 APK，建议 API 35 构建工具）
- 一台 Android 设备或模拟器（运行）
- 操作系统：Windows / macOS / Linux 均可开发

---

## 构建与运行

```bash
# 1. 克隆仓库
git clone git@github.com:Panlf/LightlyRecord.git
cd LightlyRecord

# 2. 安装依赖（国内可配置镜像加速）
flutter pub get

# 3. 运行（调试）
flutter run

# 4. 构建发布版 APK
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

> 注：本项目发布构建复用调试签名（`android/app/build.gradle` 中 `signingConfigs.debug`），便于本地自签测试；正式上架前请替换为专属发布密钥。

---

## 设计原则

- **金额以整数「分」存储**：全程禁 `double` 浮点运算，彻底规避 `0.1 + 0.2 ≠ 0.3` 的精度坑；解析入口统一为 `parseYuanToMinor`。
- **纯本地、零云端**：无后端、无账号、无网络权限，数据仅存于本机 SQLite。
- **派生指标单点定义**：所有统计口径集中在一处（`StatsRepository`），避免各页各算各的导致对不上。
- **静态质量门禁**：`flutter analyze` 零 Error 为底线；金额、颜色、命名相关规则额外收紧。

---

## 开源协议

本项目基于 [MIT License](./LICENSE) 开源。可自由使用、修改、分发，但须保留版权声明与许可声明。

---

## 免责声明

- 数据完全存储在本地 SQLite，**卸载 App 将丢失全部记账数据**，请定期使用「数据导出」功能备份。
- 本项目按现状提供，作者不对任何数据丢失或使用后果负责。
- 当前聚焦 Android 平台；iOS / 桌面端未适配。

---

© 2026 panlf · 轻记 LightlyRecord
