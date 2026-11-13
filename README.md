# FSYL TV

FSYL TV 是一个 Windows 单窗口桌面客户端，在同一个窗口内整合两个独立板块：

- **影视**：基于 [MoonTV](https://github.com/samqin123/MoonTV)（MIT）改造，本地 Node sidecar + WebView2 呈现。
- **动漫**：基于 [Kazumi](https://github.com/Predidit/Kazumi)（GPL-3.0）改造，保留其播放器、规则引擎与抓取逻辑。

两个板块的观看记录、收藏与播放器完全独立，数据全部保存在本机，不依赖任何自建服务器。

## 仓库结构

```
app/          Kazumi Flutter 工程（上游原样导入，后续品牌改造）
moonserver/   MoonTV Next.js 工程（上游原样导入，后续 sidecar 改造）
tools/        构建与打包脚本
docs/         设计与验收文档（后续阶段）
SPEC.md       运行时契约
CHANGELOG.md  对上游文件的每一处修改记录
LICENSE       GPL-3.0（本项目整体）
```

## 许可证

本项目整体以 **GNU General Public License v3.0** 发布，完整文本见 [LICENSE](LICENSE)。
其中 `moonserver/` 源自 MoonTV（MIT），其原始许可证见
[LICENSE-MOONTV-MIT](LICENSE-MOONTV-MIT)；第三方组件与上游仓库的固定版本见
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) 与 [VENDOR.md](VENDOR.md)。

本项目基于上述开源项目修改而来，所有上游版权声明与许可证文本均予保留。
完整源码随本仓库公开提供。

## 状态

开发中。当前进度与验收证据见 [PROGRESS.md](PROGRESS.md)；界面文案、构建方式与
已知问题将在后续阶段补全到本文件。
