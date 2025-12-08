import AppIntents
import WidgetKit
import Foundation

@available(iOS 16.0, *)
struct CompleteStepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Step"
    static var description = IntentDescription("Completes the current step of the active task.")

    func perform() async throws -> some IntentResult {
        // 1. Write pending action to App Group defaults
        if let defaults = UserDefaults(suiteName: "group.com.donow.app") {
            defaults.set("complete", forKey: "pendingAction")
            defaults.synchronize() // Force write
        }
        
        // 2. Open App to process it
        return .result(opensIntent: OpenURLIntent(URL(string: "donow://action")!))
    }
}

@available(iOS 16.0, *)
struct CancelTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Cancel Task"
    static var description = IntentDescription("Cancels the active task.")

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: "group.com.donow.app") {
            defaults.set("cancel", forKey: "pendingAction")
            defaults.synchronize()
        }
        return .result(opensIntent: OpenURLIntent(URL(string: "donow://action")!))
    }
}
