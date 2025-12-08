import AppIntents
import WidgetKit
import Foundation

// LiveActivityIntent requires iOS 17.0+ for interactive buttons in Dynamic Island
@available(iOS 17.0, *)
struct CompleteStepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Step"
    static var description = IntentDescription("Completes the current step of the active task.")

    func perform() async throws -> some IntentResult {
        // Write pending action to App Group defaults
        if let defaults = UserDefaults(suiteName: "group.com.donow.app") {
            defaults.set("complete", forKey: "pendingAction")
            defaults.synchronize() // Force write
        }
        
        // Just return result - the app will check pendingAction when it resumes
        // Cannot use OpenURLIntent as it requires iOS 18+
        return .result()
    }
}

@available(iOS 17.0, *)
struct CancelTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Cancel Task"
    static var description = IntentDescription("Cancels the active task.")

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: "group.com.donow.app") {
            defaults.set("cancel", forKey: "pendingAction")
            defaults.synchronize()
        }
        
        // Just return result - the app will check pendingAction when it resumes
        return .result()
    }
}
