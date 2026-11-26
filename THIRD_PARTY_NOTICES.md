# 第三方组件与许可证

本项目以 GPL-3.0 发布。下表列出运行时依赖及其许可证；分发二进制时请同时满足各自的许可义务（尤其是 GPL 组件的源码可得要求）。

## 运行时依赖

| 组件 | 版本 | 许可证 |
| --- | --- | --- |
| Flutter SDK / Dart | 3.50.1 / 3.14 | BSD-3-Clause |
| media_kit | ^1.2.6 | MIT |
| media_kit_video | ^2.0.1 | MIT |
| media_kit_libs_windows_video | ^1.0.11 | MIT（其打包的 libmpv 见下） |
| libmpv（libmpv-2.dll） | 随 media_kit 提供 | GPL-2.0-or-later（默认构建；mpv 亦提供 LGPL-2.1-or-later 构建） |
| dio | ^5.11.1 | MIT |
| crypto | ^3.0.8 | BSD-3-Clause（Dart 项目） |
| archive | ^4.7.1 | MIT |
| qr_flutter | ^4.1.0 | BSD-3-Clause |
| path_provider | ^2.1.6 | BSD-3-Clause（Flutter 项目） |
| cupertino_icons | ^1.0.8 | MIT |
| material_ui | ^1.1.0 | BSD-3-Clause（Flutter 项目） |

## 可选组件（不随仓库分发）

| 组件 | 版本 | 许可证 | 说明 |
| --- | --- | --- | --- |
| ffmpeg | 7.1.1 essentials（gyan.dev 构建） | GPL-3.0（构建参数含 `--enable-gpl --enable-version3`） | 仅下载合并功能需要，由 `scripts/fetch-ffmpeg.ps1` 下载 |

## GPL 义务提示

- 分发包含 GPL 组件的二进制包时，必须同时提供对应组件的完整源码，或给出有效的源码获取方式。
- 修改本项目的代码再分发时，需同样以 GPL-3.0 公开完整源码，并保留原始版权声明与改动说明。
- 如果只想分发 MIT/BSD 部分，请不要把 GPL 组件（libmpv、ffmpeg）打进包内，改为让用户自行安装。

## 商标

「哔哩哔哩」「bilibili」等名称与标识归其权利人所有。本项目为第三方非官方客户端，不使用其 Logo 或商标素材，仅以文字形式说明兼容对象。