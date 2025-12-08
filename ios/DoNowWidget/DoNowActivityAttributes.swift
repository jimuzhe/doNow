import ActivityKit
import SwiftUI

// Step info for schedule
struct StepInfo: Codable, Hashable {
    var title: String
    var durationSeconds: Int
    var endTime: Date
}

// This must match the data structure sent from Flutter
struct DoNowActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state updated via Flutter
        var currentStep: String
        var progress: Double // 0.0 to 1.0 (Legacy/Fallback)
        var startTime: Date?
        var endTime: Date?
        
        // Full step schedule for auto-advance
        var steps: [StepInfo]?
        var currentStepIndex: Int
    }

    // Static data passed at start
    var taskTitle: String
    var totalDuration: Int // minutes
}

// MARK: - Live Activity Model Extension
extension DoNowActivityAttributes {
    static func createFromDictionary(_ dict: [String: Any]) -> DoNowActivityAttributes? {
        guard let taskTitle = dict["taskTitle"] as? String,
              let totalDuration = dict["totalDuration"] as? Int else {
            return nil
        }
        return DoNowActivityAttributes(taskTitle: taskTitle, totalDuration: totalDuration)
    }
}

extension DoNowActivityAttributes.ContentState {
    static func createFromDictionary(_ dict: [String: Any]) -> DoNowActivityAttributes.ContentState? {
        let currentStep = dict["currentStep"] as? String ?? "..."
        let progress = dict["progress"] as? Double ?? 0.0
        let currentStepIndex = dict["currentStepIndex"] as? Int ?? 0
        
        var startTime: Date? = nil
        if let startTimestamp = dict["startTime"] as? Double {
            startTime = Date(timeIntervalSince1970: startTimestamp)
        }
        
        var endTime: Date? = nil
        if let endTimestamp = dict["endTime"] as? Double {
            endTime = Date(timeIntervalSince1970: endTimestamp)
        }
        
        // Parse steps array
        var steps: [StepInfo]? = nil
        if let stepsArray = dict["steps"] as? [[String: Any]] {
            steps = stepsArray.compactMap { stepDict -> StepInfo? in
                guard let title = stepDict["title"] as? String,
                      let durationSeconds = stepDict["durationSeconds"] as? Int,
                      let endTimeStamp = stepDict["endTime"] as? Double else {
                    return nil
                }
                return StepInfo(
                    title: title, 
                    durationSeconds: durationSeconds,
                    endTime: Date(timeIntervalSince1970: endTimeStamp)
                )
            }
        }
        
        return DoNowActivityAttributes.ContentState(
            currentStep: currentStep, 
            progress: progress,
            startTime: startTime,
            endTime: endTime,
            steps: steps,
            currentStepIndex: currentStepIndex
        )
    }
    
    /// Calculate the current step based on the schedule and current time
    func getCurrentStepInfo() -> (step: StepInfo, index: Int, progress: Double)? {
        guard let steps = steps, !steps.isEmpty else { return nil }
        
        let now = Date()
        
        // Find the current step based on time
        for (index, step) in steps.enumerated() {
            if now < step.endTime {
                // This is the current step
                let stepStart = step.endTime.addingTimeInterval(-Double(step.durationSeconds))
                let elapsed = now.timeIntervalSince(stepStart)
                let progress = max(0, min(1, elapsed / Double(step.durationSeconds)))
                return (step, index, progress)
            }
        }
        
        // All steps completed, return last step
        if let lastStep = steps.last {
            return (lastStep, steps.count - 1, 1.0)
        }
        
        return nil
    }
}
