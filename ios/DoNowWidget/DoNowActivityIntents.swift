import AppIntents
import ActivityKit
import Foundation

// MARK: - Complete Step Intent
@available(iOS 16.1, *)
struct CompleteStepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Step"
    static var description = IntentDescription("Mark current step as complete")
    
    func perform() async throws -> some IntentResult {
        // Store action in UserDefaults for Flutter to read
        let defaults = UserDefaults(suiteName: "group.com.donow.app")
        defaults?.set("complete", forKey: "lastAction")
        defaults?.set(Date().timeIntervalSince1970, forKey: "actionTimestamp")
        defaults?.synchronize()
        
        return .result()
    }
}

// MARK: - Cancel Task Intent
@available(iOS 16.1, *)
struct CancelTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Cancel Task"
    static var description = IntentDescription("Cancel the current task")
    
    func perform() async throws -> some IntentResult {
        // Store action in UserDefaults for Flutter to read
        let defaults = UserDefaults(suiteName: "group.com.donow.app")
        defaults?.set("cancel", forKey: "lastAction")
        defaults?.set(Date().timeIntervalSince1970, forKey: "actionTimestamp")
        defaults?.synchronize()
        
        return .result()
    }
}

// MARK: - Open App Intent (for tapping the Dynamic Island)
@available(iOS 16.1, *)
struct OpenAppIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open App"
    static var description = IntentDescription("Open the Do Now app")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
