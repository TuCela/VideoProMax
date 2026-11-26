# 接口与约定 — video-hub-flutter

> 任何接口 / 字段 / 数据模型变更，先在这里升版本并写明，再改代码。

## 当前版本
- **v0.3**（2026-11-25：补充播放链路约定；新增 AGENTS.md 交接文档）

## 模块边界
| 模块 | 路径 |
| --- | --- |
| 数据层 / 模型 / BiliClient | `lib/bili/` 中数据、模型、API 相关文件 |
| UI / 页面 / 交互 | `lib/ui/`、页面组件 |
| 构建与验证 | `flutter build windows --release` |

## B 站接口备忘（实测记录）

以下结论均来自实际抓包验证，可作为二次开发参考。

### 需要登录态的接口
| 接口 | 说明 |
| --- | --- |
| `x/space/wbi/acc/info` | UP 主资料。需 WBI 签名 + 登录 Cookie，未登录返回 `-352` 风控 |
| `x/space/wbi/arc/search` | UP 主投稿列表。同样需要 WBI 签名 + 登录 Cookie |
| `x/web-interface/card` | 关注 / 粉丝数。注意 `following` 字段是 **bool**（表示是否已关注），不能强转 `num`，否则解析抛异常 |

### 无需签名但需正确 Referer
| 接口 | Referer | 说明 |
| --- | --- | --- |
| `x/polymer/web-dynamic/v1/feed/space` | 空间动态页 | UP 主动态流，返回 `items` + `offset` + `has_more` |
| `x/polymer/web-space/home/seasons_series` | 空间 `lists` 页 | UP 主合集与列表，返回 `items_lists.seasons_list` 与 `items_lists.series_list` |

### 已失效接口（不要再接）
- `x/polymer/space/...`：返回 404
- `x/series/series`：返回 `-400`

### WBI 签名
1. 请求 `x/web-interface/nav` 取 `wbi_img.img_url` 与 `sub_url`，各取文件名（不含扩展名）拼接。
2. 按固定 64 位乱序表重排后截取前 32 位，得到 `mixin_key`。
3. 参数按 key 排序、URL 编码后拼接，末尾追加 `mixin_key`，取其 MD5 作为 `w_rid`，同时带上 `wts`。

## 播放链路约定

| 项 | 约定 |
| --- | --- |
| 音视频 | B 站 DASH 分离：视频 `open(Media(videoUrl))`，音频用 mpv `audio-add <url> select` 挂载 |
| 请求头 | mpv 需全局 `http-header-fields`（Referer / UA / Cookie）。`audio-add` 不继承 Media 的 headers，缺失会静默失败，表现为「视频在播但没声音」 |
| 音量 | 存 `prefs.volume`，起播前 `setVolume`；`mute` 由 mpv 状态同步到控制栏 |
| 弹幕 | 独立 cid 拉取，通过 `DanmakuBridge` 单例驱动渲染层 |

## 变更记录
| 版本 | 时间 | 变更 | 影响 |
| --- | --- | --- | --- |
| v0.1 | 项目初期 | 建立文档 | 无 |
| v0.2 | 开源整理 | 脱敏，补充 WBI 签名步骤与失效接口说明 | 无代码影响 |
| v0.3 | 2026-11-25 | 补充播放链路约定（全局请求头 / 音频挂载）；新增 `AGENTS.md` 交接文档 | 无接口变更 |
