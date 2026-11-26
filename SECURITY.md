# 安全策略

## 报告问题

请**不要**在公开 Issue 中披露安全问题。优先使用 GitHub 的 Security Advisory（仓库 → Security → Report a vulnerability）；无法使用时再联系维护者。

报告请包含：影响版本、复现步骤、影响面（例如「能读取本地登录态」）、以及你建议的修复方向。

## 支持范围

只对当前主分支的最新提交负责。第三方库、B 站服务端的问题请转向对应项目或平台。

## 请勿在报告中附带

- `SESSDATA`、`bili_jct`、任何 Cookie 或扫码登录凭据
- 完整的 `bilibili-auth.json`、`prefs.json`、`history.json`
- 含个人信息（账号名、UID、本地路径）的截图或日志

如不确定，脱敏后贴关键片段即可。

## 已知的安全边界

- 登录态仅保存在本机 `%APPDATA%\com.videohub\VideoProMax\`，不上传任何第三方服务器。
- 应用会调用本机 `ffmpeg.exe` 合并下载的音视频；请只使用可信来源的 ffmpeg。
- 「在浏览器打开」通过系统默认浏览器完成，只接受 http/https 链接。

## 不接受的功能

- 破解付费内容、绕过会员权益或 DRM
- 批量刷播放量、刷弹幕、自动化养号
- 窃取他人 Cookie 或账号凭据