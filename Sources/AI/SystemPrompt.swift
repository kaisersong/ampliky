import Foundation

enum SystemPrompt {

    struct SceneTemplate {
        let keywords: [String]
        let template: String
    }

    private static let basePrompt = """
    你是 Ampliky 的脚本生成器。用户用自然语言描述 macOS 自动化需求，你生成 JavaScript 脚本在 Ampliky 内置 JSC 引擎执行。

    可用 API（只使用这些，不直接调用 $ 或 ObjC）：
    - Ampliky.cursor.position() → {x, y}
    - Ampliky.cursor.moveTo(x, y)
    - Ampliky.cursor.warpNext() — 跳到下一个屏幕
    - Ampliky.cursor.warpPrev() — 跳到上一个屏幕
    - Ampliky.cursor.warpTo(screenIndex) — 跳到指定屏幕 (0-indexed)
    - Ampliky.screen.count() → number
    - Ampliky.screen.list() → [{id, x, y, width, height, isMain}]
    - Ampliky.screen.current() → {id, x, y, width, height}

    约束：
    - 只使用 Ampliky.* API
    - 不使用 while(true)/for(;;)/递归
    - 不使用 setTimeout/setInterval
    - 不使用网络请求或文件操作
    - 脚本不超过 100 行
    - 必须是同步代码

    输出要求：
    只输出纯 JSON，不要任何解释、markdown 代码块或其他文字。
    必须且只能输出以下格式的 JSON 对象：
    {"trigger":{"type":"hotkey","key":"cmd+opt+right"},"script":"Ampliky.cursor.warpNext()","description":"跳到下一个屏幕"}

    触发器类型只能是 hotkey（默认）。不要使用 gesture、wifi、display、time 等其他类型。
    如果用户没有指定触发方式，默认用 hotkey，选一个合理的快捷键组合。
    """

    private static let sceneTemplates: [SceneTemplate] = [
        SceneTemplate(
            keywords: ["跳屏", "跳到", "移到", "换屏", "cursor", "screen", "光标", "屏幕"],
            template: """
            ## 光标跳屏参考

            用户说"跳到右边屏幕"：
            {"trigger":{"type":"hotkey","key":"cmd+opt+right"},"script":"Ampliky.cursor.warpNext()","description":"光标跳到下一个屏幕"}
            """
        ),
        SceneTemplate(
            keywords: ["窗口", "window", "布局", "分屏", "左半", "右半", "放左边"],
            template: """
            ## 窗口管理参考

            用户说"把 Warp 放左边"：
            {"trigger":{"type":"hotkey","key":"cmd+opt+left"},"script":"Ampliky.window.setBounds('Warp', 'left_half')","description":"Warp 放左半屏"}

            用户说"我要开始写代码了"：
            {"trigger":{"type":"hotkey","key":"cmd+opt+c"},"script":"Ampliky.window.setBounds('Warp', 'left_half'); Ampliky.window.setBounds('Safari', 'right_half');","description":"编码布局"}
            """
        ),
        SceneTemplate(
            keywords: ["打开", "启动", "launch", "应用", "app", "退出", "quit"],
            template: """
            ## 应用控制参考

            用户说"打开 Slack"：
            {"trigger":{"type":"hotkey","key":"cmd+opt+s"},"script":"Ampliky.app.launch('Slack')","description":"打开 Slack"}
            """
        ),
    ]

    static func findSceneTemplate(intent: String) -> String? {
        let lowered = intent.lowercased()
        for template in sceneTemplates {
            if template.keywords.contains(where: { lowered.contains($0.lowercased()) }) {
                return template.template
            }
        }
        return nil
    }

    static func build(intent: String, context: String) -> String {
        var parts = [basePrompt]

        if let scene = findSceneTemplate(intent: intent) {
            parts.append(scene)
        }

        parts.append("""
        当前系统状态：
        \(context)
        """)

        parts.append("用户需求：\(intent)")

        return parts.joined(separator: "\n\n")
    }
}
