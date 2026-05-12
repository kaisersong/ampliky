import Foundation

class RuleEngine {
    private let rules: [Rule]

    init(rules: [Rule]) {
        self.rules = rules.filter { $0.enabled }
    }

    func match(trigger: RuleTrigger) -> Rule? {
        rules.first { rule in
            matchTrigger(rule.trigger, against: trigger)
        }
    }

    private func matchTrigger(_ pattern: RuleTrigger, against event: RuleTrigger) -> Bool {
        switch (pattern, event) {
        case (.hotkey(let pKey), .hotkey(let eKey)):
            return pKey == eKey
        case (.wifi(let pSSID), .wifi(let eSSID)):
            return pSSID == eSSID
        case (.display(let pCount), .display(let eCount)):
            return pCount == eCount
        case (.time(let pFrom, let pTo), .time(let eFrom, _)):
            return eFrom >= pFrom && eFrom <= pTo
        default:
            return false
        }
    }
}
