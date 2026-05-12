import Foundation

class SelfHealer {
    let maxRetries: Int
    private(set) var currentAttempt: Int = 0

    init(maxRetries: Int = 3) {
        self.maxRetries = maxRetries
    }

    func canRetry() -> Bool {
        currentAttempt < maxRetries
    }

    func incrementAttempt() {
        currentAttempt += 1
    }

    func reset() {
        currentAttempt = 0
    }

    static func buildFixPrompt(originalIntent: String, failedScript: String, errorMessage: String) -> String {
        """
        你之前为 Ampliky 生成的脚本执行失败了。

        用户原始意图：\(originalIntent)

        失败的脚本：
        ```javascript
        \(failedScript)
        ```

        错误信息：\(errorMessage)

        请修复脚本。注意：
        - 只使用 Ampliky.* API（不要自己造函数名）
        - 检查 API 名称拼写
        - 返回完整的修复后 JSON（包含 trigger, script, description）
        """
    }
}
