# TokenTracker — macOS Menu Bar App 完成总结

我已经为你完整开发了 **TokenTracker** macOS 状态栏应用，成功编译并启动。

## 已实现的主要特性

1. **原生 SwiftUI 菜单栏应用**：使用 `MenuBarExtra` 构建，系统级驻留，非常轻量。
2. **多平台用量监控**：
   - 🟢 **OpenAI**: 基于 Admin API 自动查询 Token 用量和花费。
   - 🔵 **DeepSeek**: 自动查询账户余额。
   - 🟣 **MiniMax (海螺)**: 自动查询 Coding Plan 余额。
   - 🟠 **Anthropic / Gemini**: 暂时提供占位（由于官方无公开用量查询 API，建议目前用手动模式记录或等官方开放 API 后填入）。
3. **配置驱动的插件式架构 (Core Engine)**：
   - **完全无代码扩展**：你现在可以通过 Settings 里的 **Add Custom Provider** 表单，填入任何 AI 平台的 API URL 即可动态添加新平台支持，系统会使用底层的 `CustomProvider` 通用 HTTP 引擎来查询余额。
   - **JSON 配置文件**：配置文件保存在 `~/.config/tokentracker/providers/` 目录，启动时自动加载。
4. **精美的仪表盘 UI**：
   - 顶部显示总花费/Token 使用量，下拉展示各自平台详情。
   - **进度条、百分比、剩余余额**：对于返回余额的 API（如 DeepSeek，MiniMax），自动计算额度占用比率。
   - 模型细分展开展示（OpenAI）。
5. **后台定时轮询**：
   - 可在 Settings 中将更新间隔设置为 1分钟/5分钟/15分钟等。
6. **安全存储**：
   - 所有的 API Key 均存储在 macOS Keychain 中的安全空间。
   
## 如何使用应用

1. 寻找屏幕顶部右上角的菜单栏，这里应该有一个类似柱状图图表图标 `📊 TT`。
2. 点击图标将弹出仪表盘弹窗。如果你没有启用任何平台，它会提示你去进行设置。
3. 点击右下角的 **⚙ Settings** 齿轮图标。
4. **测试预置平台**：在侧边栏选择 OpenAI 或 DeepSeek 等，打开开关 `✓`，填入你的 API Key，点击 **Test Connection**。
5. **测试添加新平台**：点击左下角的 `+ Add Custom Provider`：填入新的支持 OpenAI 兼容格式或自建套壳中转 API 的查询参数（响应通常是 JSON，填写 JSON key path 取值即可关联解析）。

## 代码结构概览

所有的项目文件储存在 `/Users/wakeyoo/workspace/ai-tools/TokenTracker/TokenTracker/`

- `Models/UsageData.swift` 及 `ProviderConfig.swift`: 描述了系统流转的数据实体。
- `Storage/` 下面实现了 Keychain 和 JSON Config 管理方案。
- `Providers/` 包括了统一的 `UsageProvider` protocol，以及所有硬编码内置支持的提供商逻辑。最重要的文件是 **`CustomProvider.swift`**（动态表单加载器引擎）。
- `TokenTracker.xcodeproj`: 我为了兼容菜单栏原生体验，生成了完整的 Xcode 项目属性文件。
- `Info.plist`: 中设置了 `LSUIElement = true`，应用运行不会再 Dock 栏弹出图标，仅留存状态栏。

## 后续建议

如果你发现某些自建的 API 聚合商或者一些新的模型通过 JSON 格式返回额度不同，你可以充分利用 Add Custom Provider 界面的 `JSON Key Path`（比如填写 `data.available_balance`）自动映射剩余额度。
