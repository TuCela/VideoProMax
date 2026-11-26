# Video Pro Max

基于 Flutter 的哔哩哔哩桌面客户端，目前适配 Windows。

> **非官方项目**：与哔哩哔哩无任何关联，仅供学习 Flutter 桌面开发与网络协议分析使用。

> **官方仓库**：本项目唯一的官方代码托管地址即 https://github.com/TuCela/VideoProMax 。其他网站、账号或平台下的同名项目均为非官方复制，与本项目及作者无关；官方编译产物只在 GitHub Releases 发布。

## 功能

**浏览与搜索**
- 首页推荐、分区浏览，滚动自动续页
- 关键词搜索，支持排序与时间范围筛选
- 分区栏收起态强制单行，放不下的分区收进「更多」
- 搜索结果栏可左右收起，把宽度让给播放器；分栏分隔条可拖动

**播放**
- DASH 音视频流播放，默认自动选择当前视频的最高画质
- 倍速、清晰度、音量、铺满（播放器占满窗口）、窗口全屏切换
- 弹幕渲染，支持透明度、字号、速度、显示区域调整
- 选集：分 P、合集、版权剧集三种形态；右侧常驻栏 + 播放器内浮层
- 画中画（PiP）独立窗口

**内容**
- 评论区含楼中楼，正文可选中复制，支持评论点赞
- UP 主空间：头像 / 简介 / 关注与粉丝数，投稿、动态、合集三个标签页
- 「UP首页」会记住最后一次点开的 UP 主，跨页面切换后仍可返回

**其他**
- 视频下载：音视频分离下载后由 ffmpeg 合并为 mp4，支持暂停 / 继续 / 取消
- 观看历史、扫码登录、全局字号调节

## 环境要求

| 项 | 要求 |
| --- | --- |
| Flutter | Dart SDK `^3.14.0`，本项目在 Flutter 3.50.1 上验证 |
| 系统 | Windows 10 / 11 x64 |
| ffmpeg | 仅下载合并功能需要，可用 `scripts/fetch-ffmpeg.ps1` 自动获取 |

## 构建

```bash
flutter pub get
flutter build windows --release
```

产物位于 `build/windows/x64/runner/Release/`。

下载合并功能需要 ffmpeg。仓库不带二进制，运行 `powershell -ExecutionPolicy Bypass -File scripts/fetch-ffmpeg.ps1` 会把它下载到 `windows/tools/`，下次构建自动装到 exe 同级；也可以手动放进 `Release` 目录。不放也能正常播放，只是下载时会提示找不到 ffmpeg。

已构建过的可以直接双击根目录的 `start-flutter-videohub.bat` 启动（要求 `flutter` 已在 `PATH` 中）。

## 使用

1. 启动后点右上角登录，用哔哩哔哩手机客户端扫码。
2. 登录态只保存在本机，不上传任何第三方服务器：
   `%APPDATA%\com.videohub\VideoProMax\`
3. 部分接口（如 UP 主空间）必须带登录 Cookie，未登录时 B 站会返回 `-352` 风控，界面会提示先登录。

## 项目结构

```
lib/
├── main.dart              # 入口
├── bili/                  # 数据层
│   ├── client.dart        # B 站 API 客户端（含 WBI 签名）
│   ├── auth.dart          # 扫码登录与登录态
│   ├── models.dart        # 数据模型
│   ├── download_service.dart  # 下载与 ffmpeg 合并
│   ├── download_store.dart    # 下载记录持久化
│   ├── history.dart       # 观看历史
│   └── prefs.dart         # 本地偏好
└── ui/                    # 界面层
    ├── home_page.dart     # 主页面（推荐 / 分区 / 搜索 / 播放 / 下载）
    ├── space_page.dart    # UP 主空间
    ├── comments_panel.dart# 评论区
    ├── danmaku_*.dart     # 弹幕渲染与设置
    ├── download_page.dart # 下载管理
    └── ...
windows/                   # Windows runner
```

接口实测结论与 WBI 签名步骤见 [`SPEC.md`](./SPEC.md)；
接手开发（构建坑、代码地图、验证流程）见 [`docs/DEVELOPMENT.md`](./docs/DEVELOPMENT.md)；
第三方组件与许可证见 [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md)，版本记录见 [`CHANGELOG.md`](./CHANGELOG.md)。

## 已知限制

- 只适配 Windows 桌面，其他平台未测试
- 依赖 B 站非公开接口，平台改动随时可能导致功能失效
- 写操作仅实现观看进度上报与评论点赞，暂不支持投币、收藏、发弹幕
- `lib/ui/home_page.dart` 已拆出分区栏 / 选集 / 顶栏 / 结果列表 / 播放器控制栏，
  但仍承担状态与布局编排（约 2900 行），播放器布局尚未拆

## 免责声明

- 本项目为**非官方**第三方客户端，与哔哩哔哩及其关联公司无任何关系，未获其授权或认可。
- 项目不包含哔哩哔哩的商标、Logo 或任何受版权保护的内容素材；视频、弹幕、评论的版权归原作者及平台所有。
- 仅供个人学习 Flutter 开发与网络协议研究，**请勿用于商业用途**。
- 使用者需自行拥有合法的哔哩哔哩账号并自行承担使用风险；本项目不提供任何内容破解、付费内容绕过或会员权益规避功能。
- 软件按「现状」提供，不附带任何明示或暗示的担保；因使用本软件产生的任何直接或间接损失，作者不承担责任。
- 若相关方认为本项目侵犯其权益，请联系删除。

## 贡献

欢迎提交 Issue 与 Pull Request，提交前请先阅读 [`CONTRIBUTING.md`](./CONTRIBUTING.md)。
安全问题请按 [`SECURITY.md`](./SECURITY.md) 私下报告，不要开公开 Issue。

## 许可证

本项目以 [GNU General Public License v3.0](./LICENSE) 发布。

你可以自由使用、修改和分发本项目，但如果分发修改后的版本，必须同样以 GPL-3.0 公开完整源码，并保留原始版权声明与改动说明。
