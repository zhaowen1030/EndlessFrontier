# 无尽前沿 · Endless Frontier

一个面向 [arXiv](https://arxiv.org/) 的原生 macOS 科学前沿学习助手。用 Swift + SwiftUI 构建，把论文浏览、双语翻译、本地 AI 学科报告和跨学科知识图谱放在同一个桌面应用里。

> 非 arXiv、康奈尔大学或 Anthropic 的官方产品。论文元数据与 PDF 来自 arXiv.org，版权归原作者所有。

![无尽前沿核心功能演示](docs/demo.gif)

*核心功能演示：知识图谱 · 中英对照 · AI 学科探索 · 下载论文 · PDF 版式双语阅读*

## 下载与安装

**无尽前沿 1.0.0（macOS 通用版）**

⬇️ **[下载 EndlessFrontier-1.0.0-macOS.zip](https://github.com/zhaowen1030/EndlessFrontier/releases/download/v1.0.0/EndlessFrontier-1.0.0-macOS.zip)** · 约 5.1 MB

### 系统要求

- **macOS 15.0 或更高版本**（推荐 macOS 26 Tahoe）
- **Apple Silicon 或 Intel Mac**（应用为通用二进制）
- 需要网络访问 arXiv，以及所配置的大模型 API
- 无需安装额外运行时，应用已包含全部依赖

### 安装

1. 下载并解压 `EndlessFrontier-1.0.0-macOS.zip`。
2. 将 `无尽前沿.app` 拖入「应用程序」文件夹。
3. 首次打开：应用为 ad-hoc 签名、未经过 Apple 公证。如系统提示无法验证开发者，请右键点击应用 →「打开」，或执行：
   ```bash
   xattr -dr com.apple.quarantine "/Applications/无尽前沿.app"
   ```
4. 打开应用后，在「设置 → 模型连接」中配置 Claude API 或 OpenAI 兼容模型。API Key 只保存在本机钥匙串。

## 构建说明

本仓库只提交源代码、Xcode 工程与资源文件，不包含本机构建产物或用户数据。请在本地构建并自行签名：

```bash
xcodebuild -project EndlessFrontier.xcodeproj \
  -scheme EndlessFrontier \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
```

构建后的应用位于 `build/Build/Products/Release/`。若要直接在 Finder 中运行，可自行 ad-hoc 签名；应用未经过 Apple 公证。

## 功能

- **完整 arXiv 学科分类**：155 个活跃学科，保留英文原名并显示中文译名，按 8 个学科群与子档案组织，支持英/中/分类代码搜索。
- **最新论文流**：直接调用 arXiv Atom API，支持最新提交、最近更新、相关度排序，按分类搜索、分页加载与刷新。
- **中英对照**：论文标题与摘要自动翻译为简体中文，英文在上、中文在下；翻译结果按 arXiv ID 缓存，避免重复计费。
- **PDF 下载**：一键从 arXiv 下载论文原文件，保存到 `~/Downloads/无尽前沿论文`，支持打开和在访达中显示。
- **本地收藏**：每张论文卡片都可收藏/取消收藏；侧边栏「收藏论文」按收藏时间倒序汇总全部收藏，数据只保存在本机。
- **下载论文列表**：仅收录已完整下载的 PDF，按完成下载时间倒序展示；可直接进入 PDF 双语阅读器。
- **PDF 版式双语阅读**：本地论文手动翻译，可只翻译当前页或「翻译全文」逐页处理，已完成的页面自动跳过。翻译按原始 PDF 的段落、分栏与坐标重排：英文文本替换为中文，图表、表格与公式保留原位；纯公式行和变量名不翻译，长句自动换行；跨页维护统一术语表，右侧同时显示术语对照与关键词汇（音标、词性、释义、例句）。支持原文 / 译文 / 双语 / 竖向分屏 / 横向分屏五种模式：双语模式按英文一句、中文一句交替显示并保留段落分组；竖向分屏为上下布局，横向分屏为左右布局，两种分屏与关键词汇栏均可拖拽调整比例；可切换 PDF 宽度/高度适应。仅译文模式可导出保留原始版面的译文 PDF，未翻译页面保留原文。译文、版面块、术语与词汇按页缓存在本机，完成后不会重复调用模型。此前下载过但尚无下载记录的 PDF 会自动从文件名识别 arXiv ID 并恢复元数据。
- **AI 知识树**：在学科页的「知识树」标签中手动构建顶向下的双语知识树；每个知识点可继续手动 AI 深入展开（概念定义、相关知识、核心人物、应用场景）。知识树与节点内容自动保存在本地，可重新生成；现有知识图谱的学科结点也提供知识树入口。
- **AI 学科探索（手动触发）**：连接 Claude API 或 OpenAI 兼容模型，生成结构化双语学科报告：
  - 发展历史
  - 未解难题
  - 前沿进展
  - 关键成果与真实应用场景
  - 关键人物及贡献
  - 与其他学科的交叉关系
  - 关键名词解释
  - 核心公式/方程（KaTeX 离线渲染）
- **自动保存，不重复生成**：报告生成一次后写入本地，重新打开直接读取；只有用户明确点击并确认「重新生成」才会覆盖。
- **文本底色标记**：点击顶部导航栏的「划词标色」后选择报告正文，可使用黄/绿/蓝/粉/橙五种系统底色进行标记；标记仅保存在本机，可再次选中修改或清除。正常阅读时使用轻量 SwiftUI 文本渲染，保证滚动流畅。报告重新生成时，因正文变化，底色会自动重置。
- **双语交叉知识图谱**：34 个种子学科节点、45 条精选关系，并在生成 AI 报告后自动吸收报告中的跨学科关系和新节点。节点可点击，右侧检查器可直接进入 AI 探索；支持拖拽、缩放、适应窗口与节点搜索。
- **隐私与本地优先**：API Key 存放在 macOS 钥匙串；报告、翻译缓存和 PDF 均保存在本机。论文浏览与下载不经过任何第三方服务器。

## 开发要求

- Xcode 16+ / Swift 5.9+（本项目在 Xcode 26.3 构建通过）
- macOS 15.0+ 开发环境

## 构建与运行

仓库包含可直接打开的 `EndlessFrontier.xcodeproj`。

```bash
open EndlessFrontier.xcodeproj
```

在 Xcode 中选择 `EndlessFrontier` scheme 运行即可。仓库内的 Xcode 项目已经生成；只有增删源文件或修改 `project.yml` 后才需要执行 `xcodegen generate`。

命令行构建：

```bash
xcodebuild -project EndlessFrontier.xcodeproj \
  -scheme EndlessFrontier \
  -configuration Debug \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
```

如需在 Finder 中直接启动，建议先 ad-hoc 签名：

```bash
codesign --force --deep --sign - build/Build/Products/Debug/EndlessFrontier.app
open build/Build/Products/Debug/EndlessFrontier.app
```

项目由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 的 `project.yml` 生成。修改/新增源文件后可以重新生成：

```bash
xcodegen generate
```

## 配置模型

打开「设置 → 模型连接」：

1. 选择 **Claude API** 或 **OpenAI 兼容接口**。
2. 填写 API Key（保存到钥匙串）与模型名称。
3. Claude API 默认模型为 `claude-opus-5-5`；可切换到 `claude-sonnet-5-5`、`claude-haiku-5-5` 或自定义模型。
4. 使用 OpenAI 兼容接口时填写完整 Base URL，例如：
   - `https://api.openai.com/v1`
   - `https://api.deepseek.com/v1`
   - `https://api.moonshot.cn/v1`
   - `http://localhost:11434/v1`（Ollama；已允许本地网络）
5. 点击「测试连接」。

也支持从环境变量自动读取凭据（便于开发或托管场景）：

- `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_BASE_URL`
- `OPENAI_API_KEY`

应用内保存的钥匙串密钥优先于环境变量。

### 翻译策略

「设置 → 通用与翻译」中可选择：

- **自动选择**（默认）：有模型时用大模型；没有可用模型或调用失败时尝试 Apple 系统翻译。
- **仅使用大模型**
- **仅使用系统翻译**：首次使用可能触发 macOS 下载英语→简体中文语言包。
- **关闭**

论文翻译按批次流式请求，结果即时写入缓存并逐批出现在列表中。

## AI 探索的设计

AI 探索严格手动触发，不会在浏览分类时自动生成。生成使用带严格事实校准指令的双语结构化 Prompt，要求模型：

- 不编造论文、年份、奖项、人物履历或公式；
- 区分共识、争论与推测；
- 只从 arXiv 分类目录中选择交叉学科 ID；
- 用等量的英文与中文学术内容呈现。

每次请求最多生成 30K tokens，以流式方式接收。生成期间可以离开当前分类，生成会继续在后台运行；完成后自动保存。成功后 JSON 报告保存到：

```
~/Library/Application Support/EndlessFrontier/Reports/<category>.json
```

若模型输出不完整或 JSON 无法解析，应用会保留诊断信息：

```
~/Library/Application Support/EndlessFrontier/Logs/last-generation-error.txt
```

报告 UI 同时提供章节导航、中英文并列排版、人物卡片、术语网格和公式渲染。

## 数据位置

| 数据 | 路径 |
| --- | --- |
| AI 报告 | `~/Library/Application Support/EndlessFrontier/Reports` |
| 文本底色标记 | `~/Library/Application Support/EndlessFrontier/Annotations/<category>.json` |
| AI 知识树 | `~/Library/Application Support/EndlessFrontier/KnowledgeTrees/<category>.json` |
| 下载记录 | `~/Library/Application Support/EndlessFrontier/downloaded-papers.json` |
| PDF 双语阅读缓存 | `~/Library/Application Support/EndlessFrontier/Reader/<paper>.json` |
| 收藏论文 | `~/Library/Application Support/EndlessFrontier/favorites.json` |
| 翻译缓存 | `~/Library/Application Support/EndlessFrontier/Cache/translations.json` |
| 诊断日志 | `~/Library/Application Support/EndlessFrontier/Logs` |
| 下载的 PDF | `~/Downloads/无尽前沿论文` |
| API 密钥 | macOS 钥匙串（service: `com.vince.EndlessFrontier.credentials`） |

「设置 → 数据与存储」可以打开这些目录、清除翻译缓存、删除全部报告或下载文件。

## 技术结构

```
EndlessFrontier/
├── App/              应用入口、依赖装配、全局导航状态
├── Models/           arXiv 分类、论文、AI 报告、知识图谱
├── Services/         arXiv API、LLM 客户端、报告存储、翻译、下载、钥匙串
├── ViewModels/       分类论文流、AI 探索生成状态
├── Views/            侧边栏、论文列表、AI 报告、知识图谱、设置、公式渲染
├── Utilities/        主题、路径、JSON 提取、DEBUG 截图工具
└── Resources/        AppIcon、离线 KaTeX 资源
```

- 网络：`URLSession` async/await，Anthropic SSE 与 OpenAI SSE 分别解析。
- 并发：UI 与缓存写入位于 `@MainActor`；arXiv 请求通过 actor 限速（≈1.15s/请求）。
- 公式：KaTeX 0.16.11 资源本地打包，使用 `WKWebView` 渲染，无网络依赖。
- 知识图谱：SwiftUI Canvas + 确定性力导向布局 + 卡片碰撞松弛，初始适应窗口；报告中的关系以虚线增量加入。

## 已知限制

- arXiv API 有使用频率限制，应用会做退避与请求间隔；大量刷新仍可能触发 429。
- AI 学科报告基于模型训练知识，不联网检索最新论文，可能滞后或包含错误；请以原始文献与权威综述为准，尤其核对人物、年份与公式。
- 翻译、报告生成都会消耗所选模型服务的额度。
- 系统翻译依赖 macOS 已安装的语言资源；首次可能需下载。
- PDF 版式翻译使用启发式版面分析：同一行中夹有公式时，为保证公式原样，该行会保留英文；图注、表格等复杂元素的识别可能不完全准确，可切换到原文或分屏模式核对。
- 旧版逐句译文不含版面与坐标数据，需要重新翻译一次才能生成保留原始版式的译文。
- 应用未做 Apple 公证（notarization）。分发时请自行签名与公证。

## 第三方资源

- 论文元数据与 PDF：[arXiv.org](https://arxiv.org/)
- 公式渲染：[KaTeX](https://github.com/KaTeX/KaTeX)，MIT License，许可证随资源包含在 `EndlessFrontier/Resources/KaTeX/LICENSE`
- 界面全部使用系统字体与 SwiftUI，无其他运行时依赖

## 已验证

- `xcodebuild` 的 Debug 与 Release 配置均可成功构建（Xcode 26.3 / macOS 26）。
- 真实 arXiv Atom API 的论文拉取、分类搜索、排序与分页。
- 中英双语论文标题与摘要、翻译缓存持久化。
- 从 arXiv 下载 PDF 到本地（已实测 40MB+ 文件）。
- 使用 OpenAI 兼容接口真实生成 AI 学科报告，JSON 解析、报告保存、重启后直接读取、图谱自动补充新节点与关系。
- KaTeX 离线公式渲染、浅色/深色界面、报告章节导航与正文划词标记本地持久化。
- 设置页的模型配置、Keychain 密钥保存状态、数据目录管理与清理入口。

## 键盘快捷键

| 快捷键 | 功能 |
| --- | --- |
| `⌘ F` | 聚焦侧边栏学科搜索 |
| `⌘ ⇧ G` | 打开知识图谱 |
| `⌘ ⇧ E` | AI 探索当前学科 |
| `⌘ R` | 刷新当前分类论文 |
| `⌘ ,` | 设置 |
