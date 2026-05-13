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
- `Ampliky.app.launch(name)` — Launch an application
- `Ampliky.system.clipboard()` — Read/write clipboard

### CLI Interface
```bash
ampliky run '{"name":"teleportCursor","params":{"to":"next_screen"}}'
ampliky rule list
ampliky context
```

### Agent Hook
External agents can control Ampliky via Unix Domain Socket (JSON-RPC 2.0), enabling AI assistants to manipulate your Mac without writing AppleScript.

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
