# Ampliky

> AI-native macOS automation engine. Describe what you want in natural language, Ampliky generates executable scripts and runs them locally with zero latency.

English | [简体中文](README.zh-CN.md)

---

## Overview

Ampliky replaces the need to learn scripting syntax with natural language input. Tell Ampliky what you want to do, it compiles your intent into an executable script, caches it locally, and executes it instantly when triggered.

**Core concept:** LLM is the compiler, natural language is the source code, JavaScript is the compiled output. Compile once, run forever offline.

---

## Features

### AI Command Generation
- Describe automation needs in plain language
- LLM compiles natural language into executable JavaScript
- Scripts cached locally — zero LLM calls at runtime

### Trigger Types
- **Keyboard shortcuts** — Global hotkeys like `Cmd+Opt+Up`
- **Trackpad gestures** — Three-finger tap, swipes
- **Context triggers** — WiFi changes, display count changes, time-based

### Built-in API
- `Ampliky.cursor.warpNext()` — Jump cursor to next screen
- `Ampliky.cursor.warpPrev()` — Jump cursor to previous screen
- `Ampliky.cursor.moveTo(x, y)` — Move cursor to coordinates
- `Ampliky.window.leftHalf()` — Snap focused window to left half
- `Ampliky.window.rightHalf()` — Snap focused window to right half
- `Ampliky.window.maximize()` — Maximize focused window
- `Ampliky.window.moveToNextScreen()` — Move focused window to next screen (centered)
- `Ampliky.window.moveToPrevScreen()` — Move focused window to previous screen (centered)
- `Ampliky.window.moveToScreen(index)` — Move focused window to specific screen (centered)
- `Ampliky.app.launch(name)` — Launch an application
- `Ampliky.system.clipboard()` — Read/write clipboard
- `Ampliky.system.toggleMute()` — Toggle system mute
- `Ampliky.system.lockScreen()` — Lock screen

### CLI Interface

```bash
# Execute JavaScript directly in Ampliky's JSC engine
ampliky run 'Ampliky.cursor.warpNext()'

# Execute action by name
ampliky exec '{"name":"teleportCursor","params":{"to":"next_screen"}}'

# Manage rules
ampliky rule list
ampliky rule remove <rule-id>

# Get context
ampliky context
```

### AI Agent Usage

Ampliky is designed for AI agent integration. Agents can control your Mac through two interfaces:

**1. CLI Mode** — Best for simple, one-off commands:

```bash
# Read screen info
ampliky context

# Execute a JavaScript expression
ampliky run 'Ampliky.cursor.warpNext()'

# Execute an action
ampliky exec '{"name":"cursorPosition","params":{}}'
```

**2. Socket Mode** — Best for batch operations and real-time interaction:

```bash
# Connect via Unix socket (JSON-RPC 2.0)
echo '{"jsonrpc":"2.0","method":"context","params":{},"id":1}' | nc -U ~/.ampliky/ampliky.sock -w 1
```

**Available RPC Methods:**

| Method | Params | Returns | Description |
|--------|--------|---------|-------------|
| `run` | `{"script": "..."}` | `{success, output}` | Execute JavaScript |
| `exec` | `{"name": "...", "params": {...}}` | `{success, ...}` | Execute action by name |
| `context` | `{}` | `{screens: N}` | Get current context |
| `rule.list` | `{}` | `{rules: [...]}` | List all rules |
| `rule.remove` | `{"id": "..."}` | `{removed: true}` | Remove a rule |

**Built-in Actions for `exec`:**

| Name | Params | Description |
|------|--------|-------------|
| `teleportCursor` | `{"to": "next_screen\|"prev_screen\|"center"}` | Jump cursor |
| `screenCount` | `{}` | Get screen count |
| `cursorPosition` | `{}` | Get cursor position |

**Example AI Agent Workflow:**

```python
# Python example: AI agent controlling Ampliky via socket
import socket, json

def amplify_call(method, params=None, req_id=1):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(os.path.expanduser("~/.ampliky/ampliky.sock"))
    request = {"jsonrpc": "2.0", "method": method, "params": params or {}, "id": req_id}
    sock.sendall(json.dumps(request).encode())
    response = sock.recv(4096).decode()
    sock.close()
    return json.loads(response)

# Get screen count
ctx = amplify_call("context")
print(f"Screens: {ctx['result']['screens']}")

# Jump cursor to next screen
result = amplify_call("exec", {"name": "teleportCursor", "params": {"to": "next_screen"}})
print(f"Success: {result['result']['success']}")
```

---

## Install

### Build from Source

```bash
git clone https://github.com/kaisersong/ampliky
cd ampliky
xcodegen generate
open Ampliky.xcodeproj
```

### Requirements
- macOS 14.0+
- Xcode 16.0+
- Swift 5

---

## Setup

### Permissions

Ampliky requires two permissions:

1. **Input Monitoring** — For global keyboard shortcuts
2. **Accessibility** — For window management

On first launch, Ampliky will prompt you to grant these permissions in System Settings.

---

## Usage

### Creating Shortcuts

1. Click the Ampliky menubar icon
2. Select "New Shortcut"
3. Describe your automation in natural language
4. Review the generated trigger and script
5. Save

### Editing Shortcuts

1. Open the shortcut list
2. Double-click any shortcut to edit
3. Modify trigger, script, or name
4. Save changes

### Managing Shortcuts

- **Enable/Disable** — Toggle the checkbox in the shortcut list
- **Delete** — Select a shortcut and click "Delete"
- **Debug Mode** — Enable from menubar to see a status overlay

---

## Architecture

```
Trigger Layer          Rule Engine          Script Runner
─────────────          ───────────          ─────────────
Keyboard hotkeys   ──►  Match trigger   ──►  JSC execution
Trackpad gestures  ──►  Load script     ──►  Feedback toast
WiFi/display/time  ──►  Execute action  ──►  Log event
```

### Components

| Component | Responsibility |
|-----------|---------------|
| `HotkeyTrigger` | Global keyboard shortcut detection |
| `GestureTrigger` | Trackpad gesture recognition |
| `RuleEngine` | Trigger matching and rule dispatch |
| `JSCRunner` | In-process JavaScript execution |
| `ConfigStore` | JSON-based configuration persistence |
| `SocketServer` | JSON-RPC 2.0 Unix socket server |

---

## Development

### Project Structure

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

### Debug Build

Debug builds automatically enable debug mode and reset permissions on each build:

```bash
xcodegen generate
xcodebuild -project Ampliky.xcodeproj -scheme Ampliky -configuration Debug build
```

---

## License

MIT
