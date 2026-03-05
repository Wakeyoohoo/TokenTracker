# TokenTracker

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/github/license/wakeyoo/TokenTracker" alt="License">
</p>

TokenTracker 是一款 macOS 菜单栏应用，用于聚合查询和展示各 AI 平台的 API Token 用量和额度。

## 功能特性

- **菜单栏常驻** - 点击顶部菜单栏图标快速查看各平台消耗情况
- **多平台支持** - 支持 OpenAI、DeepSeek、MiniMax、Anthropic、Gemini 等主流模型提供商
- **安全存储** - API Key 加密存储在 macOS Keychain 中
- **自定义 Provider** - 支持通过配置添加任意第三方 API
- **后台轮询** - 支持自定义刷新频率和开机自启

## 平台支持

| Provider | 支持状态 |
|----------|---------|
| OpenAI | ✅ |
| DeepSeek | ✅ |
| MiniMax | ✅ |
| Anthropic | ✅ |
| Gemini | ✅ |
| 自定义 API | ✅ |

## 环境要求

- macOS 14.0 (Sonoma) 或更高版本
- Xcode 15 或更高版本

## 快速开始

```bash
# 克隆项目
git clone https://github.com/wakeyoo/TokenTracker.git
cd TokenTracker

# 打开项目
open TokenTracker.xcodeproj
```

在 Xcode 中配置签名后，按 `Cmd + R` 运行。

详细编译说明请参考 [编译指南](docs/README.md)。

## 使用说明

1. 启动应用后，点击菜单栏的 📊 图标
2. 点击齿轮图标进入设置
3. 启用需要的平台并填入 API Key
4. 点击"测试连接"验证配置

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件
