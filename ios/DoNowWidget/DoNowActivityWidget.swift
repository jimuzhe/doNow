import WidgetKit
import SwiftUI
import ActivityKit

// Helper to get current step info based on time
@available(iOS 16.1, *)
struct DynamicStepInfo {
    let title: String
    let startTime: Date
    let endTime: Date
    let index: Int
    let totalSteps: Int
    
    var progress: Double {
        let now = Date()
        if now >= endTime { return 1.0 }
        if now <= startTime { return 0.0 }
        let total = endTime.timeIntervalSince(startTime)
        let elapsed = now.timeIntervalSince(startTime)
        return elapsed / total
    }
    
    static func from(state: DoNowActivityAttributes.ContentState) -> DynamicStepInfo? {
        guard let steps = state.steps, !steps.isEmpty else {
            // Fallback to current step if no schedule
            if let start = state.startTime, let end = state.endTime {
                return DynamicStepInfo(
                    title: state.currentStep,
                    startTime: start,
                    endTime: end,
                    index: state.currentStepIndex,
                    totalSteps: 1
                )
            }
            return nil
        }
        
        let now = Date()
        
        // Find current step based on time
        for (index, step) in steps.enumerated() {
            let stepStart = step.endTime.addingTimeInterval(-Double(step.durationSeconds))
            if now < step.endTime {
                return DynamicStepInfo(
                    title: step.title,
                    startTime: stepStart,
                    endTime: step.endTime,
                    index: index,
                    totalSteps: steps.count
                )
            }
        }
        
        // All done, show last step
        if let last = steps.last {
            let stepStart = last.endTime.addingTimeInterval(-Double(last.durationSeconds))
            return DynamicStepInfo(
                title: last.title,
                startTime: stepStart,
                endTime: last.endTime,
                index: steps.count - 1,
                totalSteps: steps.count
            )
        }
        
        return nil
    }
}

@available(iOS 16.1, *)
struct DoNowActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoNowActivityAttributes.self) { context in
            // Lock Screen / Banner UI - uses TimelineView for auto-refresh
            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                LockScreenView(context: context, currentDate: timeline.date)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI - Shows when user long-presses
                DynamicIslandExpandedRegion(.leading) {
                    TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                        DynamicLeadingView(state: context.state, currentDate: timeline.date)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    // Empty for balance
                }
                
                DynamicIslandExpandedRegion(.center) {
                    TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                        DynamicCenterView(state: context.state, taskTitle: context.attributes.taskTitle, currentDate: timeline.date)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    if #available(iOS 17.0, *) {
                        HStack {
                            // Cancel Button
                            Button(intent: CancelTaskIntent()) {
                                HStack {
                                    Image(systemName: "xmark")
                                    Text("Abort")
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            // Complete Button - Prominent
                            Button(intent: CompleteStepIntent()) {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Done")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .foregroundColor(.black)
                                .cornerRadius(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    } else {
                        // iOS 16 Compatibility
                        DynamicBottomFallbackView(state: context.state)
                    }
                }
                
            } compactLeading: {
                // Compact Leading - Just circular progress, no text inside
                TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                    DynamicCompactLeadingView(state: context.state, currentDate: timeline.date)
                }
            } compactTrailing: {
                // Compact Trailing - Timer text
                TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                    DynamicCompactTrailingView(state: context.state, currentDate: timeline.date)
                }
            } minimal: {
                // Minimal - Just progress circle
                TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                    DynamicMinimalView(state: context.state, currentDate: timeline.date)
                }
            }
            .contentMargins(.horizontal, 4, for: .compactLeading)
            .contentMargins(.horizontal, 4, for: .compactTrailing)
        }
    }
}

// MARK: - Subviews for Dynamic Island

@available(iOS 16.1, *)
struct DynamicLeadingView: View {
    let state: DoNowActivityAttributes.ContentState
    let currentDate: Date
    
    var body: some View {
        let stepInfo = DynamicStepInfo.from(state: state)
        
        HStack(spacing: 8) {
            // Circular progress - no text inside
            if let info = stepInfo {
                ProgressView(timerInterval: info.startTime...info.endTime, countsDown: false)
                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                    .frame(width: 28, height: 28)
            } else {
                ProgressView(value: state.progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                    .frame(width: 28, height: 28)
            }
        }
    }
}

@available(iOS 16.1, *)
struct DynamicCenterView: View {
    let state: DoNowActivityAttributes.ContentState
    let taskTitle: String
    let currentDate: Date
    
    var body: some View {
        let stepInfo = DynamicStepInfo.from(state: state)
        
        VStack(spacing: 4) {
            // Current step title (auto-calculates based on time)
            Text(stepInfo?.title ?? state.currentStep)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            HStack(spacing: 8) {
                // Step counter
                if let info = stepInfo, info.totalSteps > 1 {
                    Text("\(info.index + 1)/\(info.totalSteps)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                // Countdown timer
                if let info = stepInfo, info.endTime > currentDate {
                    Text(timerInterval: currentDate...info.endTime, countsDown: true)
                        .monospacedDigit()
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
            }
        }
    }
}

@available(iOS 16.1, *)
struct DynamicBottomFallbackView: View {
    let state: DoNowActivityAttributes.ContentState
    
    var body: some View {
        let stepInfo = DynamicStepInfo.from(state: state)
        
        VStack(spacing: 8) {
            if let info = stepInfo {
                ProgressView(timerInterval: info.startTime...info.endTime, countsDown: false)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
            } else {
                ProgressView(value: state.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
            }
            
            Text("点击打开应用操作")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

@available(iOS 16.1, *)
struct DynamicCompactLeadingView: View {
    let state: DoNowActivityAttributes.ContentState
    let currentDate: Date
    
    var body: some View {
        let stepInfo = DynamicStepInfo.from(state: state)
        
        // Just circular progress, no text
        if let info = stepInfo {
            ProgressView(timerInterval: info.startTime...info.endTime, countsDown: false)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .frame(width: 18, height: 18)
        } else {
            ProgressView(value: state.progress)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .frame(width: 18, height: 18)
        }
    }
}

@available(iOS 16.1, *)
struct DynamicCompactTrailingView: View {
    let state: DoNowActivityAttributes.ContentState
    let currentDate: Date
    
    var body: some View {
        let stepInfo = DynamicStepInfo.from(state: state)
        
        if let info = stepInfo, info.endTime > currentDate {
            Text(timerInterval: currentDate...info.endTime, countsDown: true)
                .monospacedDigit()
                .font(.caption2.bold())
                .foregroundColor(.white)
                .frame(maxWidth: 45)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        }
    }
}

@available(iOS 16.1, *)
struct DynamicMinimalView: View {
    let state: DoNowActivityAttributes.ContentState
    let currentDate: Date
    
    var body: some View {
        let stepInfo = DynamicStepInfo.from(state: state)
        
        // Just circular progress
        if let info = stepInfo {
            ProgressView(timerInterval: info.startTime...info.endTime, countsDown: false)
                .progressViewStyle(CircularProgressViewStyle(tint: .green))
                .frame(width: 22, height: 22)
        } else {
            ProgressView(value: state.progress)
                .progressViewStyle(CircularProgressViewStyle(tint: .green))
                .frame(width: 22, height: 22)
        }
    }
}

// MARK: - Lock Screen View
@available(iOS 16.1, *)
struct LockScreenView: View {
    let context: ActivityViewContext<DoNowActivityAttributes>
    let currentDate: Date
    
    var body: some View {
        let stepInfo = DynamicStepInfo.from(state: context.state)
        
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                
                Text(context.attributes.taskTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                if let info = stepInfo, info.endTime > currentDate {
                    Text(timerInterval: currentDate...info.endTime, countsDown: true)
                        .monospacedDigit()
                        .font(.caption.bold())
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            // Current Step with step number (auto-calculated)
            HStack {
                Text(stepInfo?.title ?? context.state.currentStep)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                
                if let info = stepInfo, info.totalSteps > 1 {
                    Spacer()
                    Text("\(info.index + 1)/\(info.totalSteps)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            
            // Progress Bar
            if let info = stepInfo {
                ProgressView(timerInterval: info.startTime...info.endTime, countsDown: false)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
            } else {
                ProgressView(value: context.state.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
            }
            
            // Hint text
            HStack {
                Spacer()
                Text("点击打开应用")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.9))
        .activitySystemActionForegroundColor(Color.white)
    }
}

// MARK: - Preview
@available(iOS 16.2, *)
struct DoNowActivityWidget_Previews: PreviewProvider {
    static let attributes = DoNowActivityAttributes(
        taskTitle: "完成项目报告",
        totalDuration: 60
    )
    static let contentState = DoNowActivityAttributes.ContentState(
        currentStep: "整理资料和数据",
        progress: 0.35,
        startTime: Date(),
        endTime: Date().addingTimeInterval(1200),
        steps: [
            StepInfo(title: "整理资料", durationSeconds: 600, endTime: Date().addingTimeInterval(600)),
            StepInfo(title: "撰写初稿", durationSeconds: 900, endTime: Date().addingTimeInterval(1500)),
            StepInfo(title: "校对修改", durationSeconds: 300, endTime: Date().addingTimeInterval(1800))
        ],
        currentStepIndex: 0
    )
    
    static var previews: some View {
        Group {
            attributes
                .previewContext(contentState, viewKind: .dynamicIsland(.compact))
                .previewDisplayName("Compact")
            
            attributes
                .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
                .previewDisplayName("Expanded")
            
            attributes
                .previewContext(contentState, viewKind: .dynamicIsland(.minimal))
                .previewDisplayName("Minimal")
            
            attributes
                .previewContext(contentState, viewKind: .content)
                .previewDisplayName("Lock Screen")
        }
    }
}
