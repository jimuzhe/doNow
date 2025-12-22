import AppIntents
import WidgetKit
import Foundation
import ActivityKit

// LiveActivityIntent requires iOS 17.0+ for interactive buttons in Dynamic Island
@available(iOS 17.0, *)
struct CompleteStepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Step"
    static var description = IntentDescription("Completes the current step of the active task.")

    func perform() async throws -> some IntentResult {
        // 1. Write pending action to App Group defaults
        // The app will check this when it returns to foreground to sync its internal state
        if let defaults = UserDefaults(suiteName: "group.com.donow.app") {
            defaults.set("complete", forKey: "pendingAction")
            
            // Also store a timestamp or increment a counter to ensure multiple clicks are caught
            let currentCount = defaults.integer(forKey: "completedStepsCount")
            defaults.set(currentCount + 1, forKey: "completedStepsCount")
            
            defaults.synchronize() // Force write
        }
        
        // 2. Update the Live Activity state IMMEDIATELY for visual feedback
        for activity in Activity<DoNowActivityAttributes>.activities {
            var state = activity.content.state
            
            if let steps = state.steps, !steps.isEmpty {
                let currentIndex = state.currentStepIndex
                if currentIndex < steps.count - 1 {
                    // Advance to next step
                    let nextIndex = currentIndex + 1
                    state.currentStepIndex = nextIndex
                    state.currentStep = steps[nextIndex].title
                    
                    // Update the timing: next step starts NOW
                    let now = Date()
                    var newSteps = steps
                    var currentEndTime = now
                    
                    // Adjust end times for all remaining steps based on new start time
                    for i in nextIndex..<steps.count {
                        currentEndTime = currentEndTime.addingTimeInterval(Double(steps[i].durationSeconds))
                        newSteps[i].endTime = currentEndTime
                    }
                    
                    state.steps = newSteps
                    state.startTime = now
                    state.endTime = newSteps[nextIndex].endTime
                    
                    // Update activity with new state
                    await activity.update(ActivityContent(state: state, staleDate: nil))
                } else {
                    // Last step completed - we could end it or show 100%
                    state.progress = 1.0
                    state.currentStepIndex = steps.count
                    await activity.update(ActivityContent(state: state, staleDate: nil))
                    
                    // Optional: End after a short delay or let the app handle it
                    // await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(now.addingTimeInterval(5)))
                }
            } else {
                // No schedule, just mark progress as complete
                state.progress = 1.0
                await activity.update(ActivityContent(state: state, staleDate: nil))
            }
        }
        
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
        
        // End the activity immediately
        for activity in Activity<DoNowActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        return .result()
    }
}
