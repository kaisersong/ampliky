# Ampliky

> AI 原生的 macOS 自动化引擎。用自然语言描述需求，Ampliky 生成可执行脚本并在本地零延迟运行。

[English](README.md) | 简体中文

---

## 概述

Ampliky 让你无需学习脚本语法，只需告诉它你想做什么，它就会将你的意图编译成可执行脚本，本地缓存，触发时瞬间执行。

**核心理念**：LLM 是编译器，自然语言是源码，JavaScript 是编译产物。编译一次，永久离线运行。

---

## 功能

### AI 指令生成
- 用自然语言描述自动化需求
- LLM 将自然语言编译为可执行 JavaScript
- 脚本本地缓存——运行时零 LLM 调用

### 触发方式
- **键盘快捷键** — 全局快捷键，如 `Cmd+Opt+Up`
- **触控板手势** — 三指点击、滑动
- **上下文触发** — WiFi 变化、屏幕数变化、时间触发

### 内置 API
- `Ampliky.cursor.warpNext()` — 光标跳到下一个屏幕
- `Ampliky.cursor.warpPrev()` — 光标跳到上一个屏幕
- `Ampliky.cursor.moveTo(x, y)` — 光标移动到坐标
- `Ampliky.app.launch(name)` — 启动应用
- `Ampliky.system.clipboard()` — 读写剪贴板

### 命令行接口

```bash
# 直接在 Ampliky 的 JSC 引擎中执行 JavaScript
ampliky run 'Ampliky.cursor.warpNext()'

# 按名称执行动作
ampliky exec '{"name":"teleportCursor","params":{"to":"next_screen"}}'

# 管理规则
ampliky rule list
ampliky rule remove <规则ID>

# 获取上下文
ampliky context
```

### AI Agent 使用指南

Ampliky 专为 AI Agent 集成设计。Agent 可通过两种接口控制你的 Mac：

**1. CLI 模式** — 适合简单的一次性命令：

```bash
# 读取屏幕信息
ampliky context

# 执行 JavaScript 表达式
ampliky run 'Ampliky.cursor.warpNext()'

# 执行动作
ampliky exec '{"name":"cursorPosition","params":{}}'
```

**2. Socket 模式** — 适合批量操作和实时交互：

```bash
# 通过 Unix socket 连接 (JSON-RPC 2.0)
echo '{"jsonrpc":"2.0","method":"context","params":{},"id":1}' | nc -U ~/.ampliky/ampliky.sock -w 1
```

**可用 RPC 方法：**

| 方法 | 参数 | 返回 | 描述 |
|------|------|------|------|
| `run` | `{"script": "..."}` | `{success, output}` | 执行 JavaScript |
| `exec` | `{"name": "...", "params": {...}}` | `{success, ...}` | 按名称执行动作 |
| `context` | `{}` | `{screens: N}` | 获取当前上下文 |
| `rule.list` | `{}` | `{rules: [...]}` | 列出所有规则 |
| `rule.remove` | `{"id": "..."}` | `{removed: true}` | 删除规则 |

**`exec` 可用动作：**

| 名称 | 参数 | 描述 |
|------|------|------|
| `teleportCursor` | `{"to": "next_screen\|"prev_screen\|"center"}` | 跳转光标 |
| `screenCount` | `{}` | 获取屏幕数量 |
| `cursorPosition` | `{}` | 获取光标位置 |

**AI Agent 示例工作流：**

```python
# Python 示例：AI Agent 通过 socket 控制 Ampliky
import socket, json, os

def amplify_call(method, params=None, req_id=1):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(os.path.expanduser("~/.ampliky/ampliky.sock"))
    request = {"jsonrpc": "2.0", "method": method, "params": params or {}, "id": req_id}
    sock.sendall(json.dumps(request).encode())
    response = sock.recv(4096).decode()
    sock.close()
    return json.loads(response)

# 获取屏幕数量
ctx = amplify_call("context")
print(f"屏幕数: {ctx['result']['screens']}")

# 光标跳到下一个屏幕
result = amplify_call("exec", {"name": "teleportCursor", "params": {"to": "next_screen"}})
print(f"成功: {result['result']['success']}")
```

---

## 安装

### 从源码构建

```bash
git clone https://github.com/kaisersong/ampliky
cd ampliky
xcodegen generate
open Ampliky.xcodeproj
```

### 系统要求
- macOS 14.0+
- Xcode 16.0+
- Swift 5

---

## 设置

### 权限

Ampliky 需要两项权限：

1. **输入监控** — 用于全局键盘快捷键
2. **辅助功能** — 用于窗口管理

首次启动时，Ampliky 会提示你在系统设置中授予这些权限。

---

## 使用

### 创建快捷指令

1. 点击菜单栏 Ampliky 图标
2. 选择"新建快捷指令"
3. 用自然语言描述你的自动化需求
4. 查看生成的触发器和脚本
5. 保存

### 编辑快捷指令

1. 打开快捷指令列表
2. 双击任意指令进行编辑
3. 修改触发器、脚本或名称
4. 保存更改

### 管理快捷指令

- **启用/禁用** — 在指令列表中切换复选框
- **删除** — 选中指令后点击"删除"
- **调试模式** — 从菜单栏启用，查看状态叠加层

---

## 架构

```
触发层                规则引擎             脚本执行器
─────────             ────────             ────────
键盘快捷键    ──►     匹配触发器   ──►     JSC 执行
触控板手势    ──►     加载脚本     ──►     反馈 Toast
WiFi/屏幕/时间──►     执行动作     ──►     记录日志
```

### 组件

| 组件 | 职责 |
|------|------|
| `HotkeyTrigger` | 全局键盘快捷键检测 |
| `GestureTrigger` | 触控板手势识别 |
| `RuleEngine` | 触发器匹配与规则分发 |
| `JSCRunner` | 进程内 JavaScript 执行 |
| `ConfigStore` | JSON 配置持久化 |
| `SocketServer` | JSON-RPC 2.0 Unix socket 服务 |

---

## 开发

### 项目结构

```
ampliky/
├── Sources/
│   ├── App/               # AppDelegate, Info.plist
│   ├── Core/              # RuleEngine, ConfigStore, Logger
│   ├── Triggers/          # HotkeyTrigger, GestureTrigger
│   ├── Actions/           # CursorAction, AppAction
│   ├── ScriptEngine/      # JSCRunner
│   ├── AI/                # SystemPrompt, LLMClient
│   ├── AgentHook/         # SocketServer, CLI
│   └── UI/                # MenuBar, Windows
├── Tests/
│   └── AmplikyTests/
└── Resources/
```

### Debug 构建

Debug 构建自动启用调试模式，每次构建重置权限：

```bash
xcodegen generate
xcodebuild -project Ampliky.xcodeproj -scheme Ampliky -configuration Debug build
```

---

## 许可证

MIT
