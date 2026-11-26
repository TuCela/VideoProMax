# 开发说明

面向接手开发者：环境、构建、代码地图与已知技术债。这里只写与代码有关的内容，个人环境与历史交接记录不入库。

## 环境

| 项 | 要求 |
| --- | --- |
| Flutter | Dart SDK `^3.14.0`，本项目在 Flutter 3.50.1 上验证 |
| 系统 | Windows 10 / 11 x64 |
| 工具链 | Visual Studio 2022，勾选「使用 C++ 的桌面开发」（含 CMake） |

## 构建与验证

```bash
flutter pub get
flutter analyze --no-fatal-infos lib test
flutter test
flutter build windows --release
```

产物在 `build/windows/x64/runner/Release/`。下载合并功能需要 ffmpeg，见下文。

## 四个真实踩过的坑

1. **构建前先结束同名的正在运行进程**，否则 INSTALL 阶段会报 `MSB3073`。
2. **不要随手 `flutter clean`**：会删掉 media_kit 的预编译依赖（`mpv-dev-*.7z`、`ANGLE.7z`），之后构建会重新下载，网络不稳时直接失败。
3. **`windows/CMakeLists.txt` 里安装前缀的兜底不要删**：CMake 3.31 下 `CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT` 不生效，会尝试装到 `Program Files` 导致无权限失败。
4. **`windows/runner/*.cpp` 里不要写中文注释**：MSVC 按系统代码页读文件，中文会触发 `C4819`，本项目把警告当错误（`/WX`），会连带报一串「非法 case」。

## ffmpeg

下载功能靠 ffmpeg 合并 DASH 音视频。仓库不带二进制，用脚本取：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/fetch-ffmpeg.ps1
```

脚本把 `ffmpeg.exe` 放进 `windows/tools/`，`windows/CMakeLists.txt` 的 install 规则会在下次构建时自动装到 exe 同级。也可以手动放到 Release 目录，代码会按 exe 同级 → `tools/` → `bin/` → `%LOCALAPPDATA%\VideoHub\` → `PATH` 的顺序查找。

## 无交互自检

```bash
VIDEOHUB_SMOKE=BV1xx411c7m9 ./build/windows/x64/runner/Release/VideoProMax.exe
```

日志写到 `%TEMP%\videohub-smoke.log`，每秒一行。关注 `pos`（进度）、`ao`（音频输出，应为 `wasapi`，为空即没声音）、`aPts`（音频时钟应逐秒推进）、`dm`（弹幕条数）。

## 代码地图

| 路径 | 职责 |
| --- | --- |
| `lib/bili/` | 数据与协议层：`client.dart`（全部接口 + WBI 签名）、`auth.dart`（扫码登录）、`download_service.dart`（分片下载 + ffmpeg 合并） |
| `lib/ui/` | 界面层：`home_page.dart` 仍是状态中枢（约 2900 行），`player_controls.dart` 是播放器控制栏，`danmaku_bridge.dart` 负责窗口与全屏共享状态 |
| `lib/core/`、`lib/player/`、`lib/sources/` | 平台抽象：`VideoRef`、`VideoSource`、`PlaybackPlan`、B 站实现 |
| `windows/runner/` | 无边框窗口：`WM_NCCALCSIZE` 去边框、`WM_GETMINMAXINFO` 锁最大化尺寸；Flutter 子窗口用 `SetWindowSubclass` 把 6px 边框命中转成 `HTTRANSPARENT`，交给顶层做原生缩放 |

## 数据目录

`%APPDATA%\com.videohub\VideoProMax\`：`prefs.json`、`bilibili-auth.json`、`history.json`、下载记录。这些文件包含登录态，**不要提交、不要打进分发包**。

## 已知技术债

- `home_page.dart` 承担状态与布局编排，建议按播放器 / 详情区 / 列表拆开。
- 测试只有 6 个（历史兼容、平台抽象），UI 层没有 widget test。
- `flutter analyze` 仍有约 78 条 info（`material.dart` deprecation、下划线参数命名），不影响构建。