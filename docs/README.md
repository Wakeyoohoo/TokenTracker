# TokenTracker

TokenTracker 是一款原生的 macOS 状态栏应用，用于聚合查询和统一展示各个 AI 平台的 API Token 用量和额度（支持 OpenAI, DeepSeek, MiniMax 等，并可通过可配置的插件系统接入任何自定义的 API 平台）。

## 核心功能介绍

1. **状态栏常驻**：点击顶部菜单栏的 `📊 TT` 图标快速查看各平台消耗情况。
2. **多平台支持**：内置主流模型提供商，显示：总花费、Tokens 消耗细分（Input/Output）、剩余额度和配额使用百分比进度条。
3. **安全存储**：所有的 API Key 均加密存储在 macOS 的系统 Keychain 中。
4. **自定义配置驱动 (Custom Provider)**：提供表单化的无代码配置功能，你可以自由添加任意未内置的第三方套壳、聚合 API，只需填写 URL 并设置 JSON 返回值解析路径即可。
5. **后台轮询与开机自启**：支持自定义设置数据刷新频率。

## 安装与编译说明

由于此项目为源码级交付并采用了新的 SwiftUI+AppKit 混合架构开发，请跟随下面简单的步骤自行编译应用：

### 环境要求
- macOS 14.0 或更高版本 (Sonoma+)
- Xcode 15 或更高版本

### 编译步骤

1. **打开项目**
   在终端进入项目根目录并在 Xcode 中打开项目：
   ```bash
   cd /Users/wakeyoo/workspace/ai-tools/TokenTracker
   open TokenTracker.xcodeproj
   ```

2. **配置签名 (Signing)**
   为了让 App 能够在你的电脑上运行并顺畅读取 Keychain：
   - 在 Xcode 左侧边栏点击工程文件 `TokenTracker` (带有蓝色图标那个)
   - 在主界面点击 `TokenTracker` Target
   - 选择顶部的 **Signing & Capabilities** 选项卡
   - 勾选 **Automatically manage signing**
   - 在 **Team** 下拉列表中，选择你自己的 Apple ID 或 Development Team。

3. **编译并运行 (Build and Run)**
   - 按下快捷键 `Cmd + R` (或者点击左上角的 `▶` 播放按钮)。
   - 首次运行如果弹出访问钥匙串 (Keychain) 权限申请，请选择**允许**。

### 开发构建

1. 构建
```bash
killall TokenTracker ; cd /Users/wakeyoo/workspace/ai-tools/TokenTracker && xcodebuild -project TokenTracker.xcodeproj -scheme TokenTracker -configuration Debug build 2>&1 | tail -20
```

2. 打开 Debug 产物
```bash
open /Users/wakeyoo/Library/Developer/Xcode/DerivedData/TokenTracker-fjxhpvrukxcmclgerzhuczgxfcbq/Build/Products/Debug/TokenTracker.app
```

### 将应用移动到应用程序文件夹 (可选)

如果你希望经常使用它，可以在编译成功后，将生成的 `TokenTracker.app` 移动到系统的“应用程序”目录：

1. 在 Xcode 左侧边栏的 `Products` 文件夹下，找到 `TokenTracker.app`
2. 右键点击它，选择 **Show in Finder**
3. 将 Finder 里高亮的 `TokenTracker.app` 拖入你的 `/Applications` 目录中。
4. 现在你可以通过 Spotlight (`Cmd + Space` 输入 TokenTracker) 或者启动台(Launchpad)随时打开它了。

## 使用指引

1. 启动应用后，点击屏幕右上角菜单栏出现的 `📊 TT` 图标。
2. 点击应用面板右下角的 **⚙ 齿轮图标** 打开设置面板（**注意：关闭设置面板不会退出程序，程序由于监控进程的需求，是在后台常驻的**）。
3. 在左侧的 **Providers** 列表中，找到你需要启用的平台，打开右上角的开关。
4. 填入对应的 `API Key`，点击 **测试连接**。若看到绿色的“已连接 ✓”，则说明配置成功。
5. 如需添加系统**未内置**的提供商（如第三方聚合 API 站），你可以点击左下角的 `+ 添加自定义`，跟随表单填写 URL 和字段映射。在 `General` 面板还可以查看到底层的自定义配置文件存储目录。

## 退出应用
当你需要关闭应用时：
1. 请点击菜单栏上的 `📊 TT` 图标打开下拉面板。
2. 点击右下角的 **电源图标 ⏻** 即可彻底退出应用和后台轮询服务。
