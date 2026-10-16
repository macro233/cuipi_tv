# 脆皮tv (Crispy TV)

<p align="center">
  <img src="logo.png" width="160" height="160" alt="脆皮tv Logo" />
</p>

<p align="center">
  <b>全平台沉浸式影视流媒体播放器 · 支持 TVBox / LibreTV 多仓聚合 · 4K 极清电视直播 · 本地硬盘智能网络海报刮削</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue.svg?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Windows-brightgreen.svg" alt="Platform" />
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License" />
</p>

---

## ✨ 核心特性

- **🎬 影视点播聚合**
  - 内置 89 条高可用秒播直连 CDN 专线与 GitHub TVBox（肥猫 / 饭太硬 / 优质多仓）全网精选源。
  - 支持多源自动降级熔断切换与智能线路探测。
  - 提供年份、豆瓣高分、画质标签等多维筛选与极速流式搜索。

- **📺 4K 极清电视直播**
  - 央视全套、各省卫视、高清影视与轮播频道。
  - 支持 IPv4 / IPv6 双栈自适应解析与全屏沉浸换台交互。

- **💾 本地硬盘资源库（智能海报刮削）**
  - 完美支持本地硬盘 4K / HDR / IMAX 蓝光视频零缓冲本地硬解。
  - 智能网络海报刮削引擎：根据文件名联网检索 AppleCMS 与网络影视数据库，自动匹配高清海报封面、豆瓣评分与剧情梗概。
  - 支持自定义导入本地视频路径与全量封面一键重新搜刮。

- **🎨 包豪斯风格与五大背景主题**
  - 经典包豪斯工控美学弧形仪表盘与沉浸控制台。
  - 支持 5 大全局渐变主题底色一键热切换：
    - 🌿 **松石墨绿**（经典包豪斯，护眼低眩光）
    - 🌌 **曜石极夜**（OLED 纯黑极致省电）
    - 🌊 **浩瀚星海**（深空科技冷蓝）
    - ☕ **暖冬焦糖**（复古胶片老影院质感）
    - 🔮 **幻境星云**（神秘赛博深紫光影）

- **📱 多模式小窗口与系统级画中画 (PiP)**
  - iOS 原生 `AVPictureInPictureController` 画中画支持，上滑返回主屏幕自动小窗后台播放。
  - YouTube 样式底部悬浮迷你播控条（左侧小窗实时播放，右侧播控，返回主页边搜边看）。
  - 应用内全平台可拖拽自由悬浮小窗。

- **⚡ 实时缓冲吞吐测速监控**
  - 去除冗杂源标签，缓冲卡顿阶段动态计算网络传输吞吐速度（如 `⚡ 正在缓冲 · 3.8 MB/s · 4K 极清`）。

- **📡 局域网服务与手机扫码遥控**
  - 内置轻量 Python / Dart 局域网服务，同一 Wi-Fi 下手机浏览器扫码即用，支持跨设备点播投屏与自定义源配置。

---

## 🚀 快速开始

### 运行环境
- Flutter SDK >= 3.22.0
- Dart SDK >= 3.4.0
- Xcode 15+ (iOS / macOS 开发)
- Android Studio / Android SDK (Android 开发)

### 编译与运行
```bash
# 克隆仓库
git clone https://github.com/macro233/cuipi_tv.git
cd cuipi_tv/cuipi_tv

# 安装依赖
flutter pub get

# 运行 macOS 客户端
flutter run -d macos

# 运行 iOS 真机 (确保设备已配对并信任)
flutter run -d iphone

# 编译 iOS Release 包
flutter build ios --release
```

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源发布。
