# 贡献指南

感谢愿意帮忙改进 VideoHub。提交前请花两分钟读完下面几条，能省掉很多来回。

## 开发环境

```bash
flutter pub get
flutter analyze lib
flutter build windows --release
```

- Flutter：Dart SDK `^3.14.0`（本项目在 3.50.1 上验证）
- 平台：目前只做 Windows 桌面
- `flutter build windows --release` 前请确认 `video_hub_flutter.exe` 没在运行，否则会报 `MSB3073`

## 提交之前

1. 先开 Issue 说明要解决的问题，避免白做。较大的改动（新增页面、改数据结构）请先讨论。
2. 跑一遍 `flutter analyze lib`，不要留下 error 或 warning。
3. 改完自己构建并启动验证一次，PR 描述里写清验证方式。
4. 保持改动聚焦：一个 PR 只做一件事，不要顺手重构无关文件。

## 代码约定

- 风格遵循 `analysis_options.yaml`，注释用中文，函数级注释说明「为什么」而不只是「做什么」。
- 新增 B 站接口时，先在 `SPEC.md` 里补上接口路径、所需签名 / Referer、返回字段要点，再写代码。
- 界面文案、字号、配色尽量沿用现有风格，避免单独引入新的设计语言。

## 不要提交这些

- `build/` 等构建产物、`*.exe`、`ffmpeg.exe`
- `bilibili-auth.json`、`prefs.json` 等本机登录态与配置（`.gitignore` 已覆盖）
- 任何真实账号 Cookie、SESSDATA、`bili_jct`

如果误提交了登录态，请立刻作废该账号的登录（哔哩哔哩 App 内退出全部设备）并说明情况。

## 不接受的功能

- 破解付费 / 大会员内容，绕过付费墙或 DRM
- 批量刷播放量、刷弹幕、自动化养号等违反平台规则的功能
- 内置任何平台商标、Logo 或受版权保护的内容素材

## 提交 PR

```
fix: 修复收起搜索栏后无法滚动
feat: UP 主空间支持合集分页
docs: 补充 WBI 签名说明
```

PR 描述请包含：改动点、影响范围、验证方式、相关 Issue 编号。

## 许可证

本项目以 GPL-3.0 发布。提交代码即表示你同意以同一许可证授权你的贡献。
