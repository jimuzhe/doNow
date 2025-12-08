import ActivityKit
import SwiftUI

// This must match the data structure sent from Flutter
struct DoNowActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state updated via Flutter
        var currentStep: String
        var progress: Double // 0.0 to 1.0 (Legacy/Fallback)
        var startTime: Date?
        var endTime: Date?
    }

    // Static data passed at start
    var taskTitle: String
    var totalDuration: Int // minutes
}

// MARK: - Live Activity Model Extension
// This helps the live_activities Flutter package to work properly
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
        
        var startTime: Date? = nil
        if let startTimestamp = dict["startTime"] as? Double {
            startTime = Date(timeIntervalSince1970: startTimestamp)
        }
        
        var endTime: Date? = nil
        if let endTimestamp = dict["endTime"] as? Double {
            endTime = Date(timeIntervalSince1970: endTimestamp)
        }
        
        return DoNowActivityAttributes.ContentState(
            currentStep: currentStep, 
            progress: progress,
            startTime: startTime,
            endTime: endTime
        )
    }
}
