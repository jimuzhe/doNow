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
        }
    }
}

// MARK: - Custom Circle Progress (No Text Inside)

@available(iOS 16.1, *)
struct CircleProgressView: View {
    let progress: Double
    let tint: Color
    let lineWidth: CGFloat
    
    init(progress: Double, tint: Color = .green, lineWidth: CGFloat = 3) {
        self.progress = min(max(progress, 0), 1)
        self.tint = tint
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(tint.opacity(0.2), lineWidth: lineWidth)
            
            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: progress)
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
            // Circular progress - no text inside (custom view)
            CircleProgressView(
                progress: stepInfo?.progress ?? state.progress,
                tint: .green,
                lineWidth: 3
            )
            .frame(width: 28, height: 28)
        }
    }
}

@available(iOS 16.1, *)
struct DynamicCenterView: View {
    let state: DoNowActivityAttributes.ContentState
    let taskTitle: String
    let currentDate: Date
    
    var body: some View {
        VStack(spacing: 4) {
            // Auto-advancing step title
            AutoAdvancingStepTextView(state: state, currentDate: currentDate)
            
            // Step counter and countdown
            AutoAdvancingStepCounterView(state: state, currentDate: currentDate)
        }
    }
}

// MARK: - Auto Advancing Step Title View
// Uses ZStack with opacity to switch between steps automatically
@available(iOS 16.1, *)
struct AutoAdvancingStepTextView: View {
    let state: DoNowActivityAttributes.ContentState
    let currentDate: Date
    
    var body: some View {
        if let steps = state.steps, !steps.isEmpty {
            // Use ZStack with multiple Text views, only one visible at a time
            ZStack {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    let stepStart = step.endTime.addingTimeInterval(-Double(step.durationSeconds))
                    let isCurrentStep = currentDate >= stepStart && currentDate < step.endTime
                    let isPastAllSteps = index == steps.count - 1 && currentDate >= step.endTime
                    
                    Text(step.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .opacity(isCurrentStep || isPastAllSteps ? 1 : 0)
                }
            }
        } else {
            // Fallback to static step
            Text(state.currentStep)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

// MARK: - Auto Advancing Step Counter View
@available(iOS 16.1, *)
struct AutoAdvancingStepCounterView: View {
    let state: DoNowActivityAttributes.ContentState
    let currentDate: Date
    
    var body: some View {
        if let steps = state.steps, !steps.isEmpty {
            HStack(spacing: 8) {
                // Step counter - ZStack approach
                ZStack {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        let stepStart = step.endTime.addingTimeInterval(-Double(step.durationSeconds))
                        let isCurrentStep = currentDate >= stepStart && currentDate < step.endTime
                        let isPastAllSteps = index == steps.count - 1 && currentDate >= step.endTime
                        
                        if steps.count > 1 {
                            Text("\(index + 1)/\(steps.count)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .opacity(isCurrentStep || isPastAllSteps ? 1 : 0)
                        }
                    }
                }
                
                // Countdown timer - use the first step that hasn't ended yet
                ZStack {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        if step.endTime > currentDate {
                            let stepStart = step.endTime.addingTimeInterval(-Double(step.durationSeconds))
                            let isCurrentStep = currentDate >= stepStart
                            
                            if isCurrentStep {
                                Text(timerInterval: currentDate...step.endTime, countsDown: true)
                                    .monospacedDigit()
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
        } else if let endTime = state.endTime, endTime > currentDate {
            // Fallback countdown
            Text(timerInterval: currentDate...endTime, countsDown: true)
                .monospacedDigit()
                .font(.caption.bold())
                .foregroundColor(.green)
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
        let progress = stepInfo?.progress ?? state.progress
        
        // Use HStack with Spacer to push content away from edge
        HStack(spacing: 0) {
            Spacer()
                .frame(width: 8)
            
            // Use native ProgressView for better iOS 16 compatibility
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 14, height: 14)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

@available(iOS 16.1, *)
struct DynamicCompactTrailingView: View {
    let state: DoNowActivityAttributes.ContentState
    let currentDate: Date
    
    var body: some View {
        if let steps = state.steps, !steps.isEmpty {
            // Use ZStack approach for auto-advancing countdown
            ZStack {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    if step.endTime > currentDate {
                        let stepStart = step.endTime.addingTimeInterval(-Double(step.durationSeconds))
                        let isCurrentStep = currentDate >= stepStart
                        
                        if isCurrentStep {
                            Text(timerInterval: currentDate...step.endTime, countsDown: true)
                                .monospacedDigit()
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: 45)
                        }
                    }
                }
                
                // Show checkmark if all steps completed
                if let lastStep = steps.last, currentDate >= lastStep.endTime {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        } else {
            // Fallback
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
}

@available(iOS 16.1, *)
struct DynamicMinimalView: View {
    let state: DoNowActivityAttributes.ContentState
    let currentDate: Date
    
    var body: some View {
        let stepInfo = DynamicStepInfo.from(state: state)
        
        // Just circular progress (custom view)
        CircleProgressView(
            progress: stepInfo?.progress ?? state.progress,
            tint: .green,
            lineWidth: 2.5
        )
        .frame(width: 22, height: 22)
    }
}

// MARK: - Lock Screen View
@available(iOS 16.1, *)
struct LockScreenView: View {
    let context: ActivityViewContext<DoNowActivityAttributes>
    let currentDate: Date
    
    var body: some View {
        let steps = context.state.steps
        
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
                
                // Auto-advancing countdown timer
                if let steps = steps, !steps.isEmpty {
                    ZStack {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            if step.endTime > currentDate {
                                let stepStart = step.endTime.addingTimeInterval(-Double(step.durationSeconds))
                                let isCurrentStep = currentDate >= stepStart
                                
                                if isCurrentStep {
                                    Text(timerInterval: currentDate...step.endTime, countsDown: true)
                                        .monospacedDigit()
                                        .font(.caption.bold())
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        if let lastStep = steps.last, currentDate >= lastStep.endTime {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                } else if let endTime = context.state.endTime, endTime > currentDate {
                    Text(timerInterval: currentDate...endTime, countsDown: true)
                        .monospacedDigit()
                        .font(.caption.bold())
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            // Current Step with step number (auto-advancing)
            HStack {
                // Auto-advancing step title
                if let steps = steps, !steps.isEmpty {
                    ZStack(alignment: .leading) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            let stepStart = step.endTime.addingTimeInterval(-Double(step.durationSeconds))
                            let isCurrentStep = currentDate >= stepStart && currentDate < step.endTime
                            let isPastAllSteps = index == steps.count - 1 && currentDate >= step.endTime
                            
                            Text(step.title)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(2)
                                .opacity(isCurrentStep || isPastAllSteps ? 1 : 0)
                        }
                    }
                } else {
                    Text(context.state.currentStep)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                }
                
                // Step counter (auto-advancing)
                if let steps = steps, steps.count > 1 {
                    Spacer()
                    ZStack {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            let stepStart = step.endTime.addingTimeInterval(-Double(step.durationSeconds))
                            let isCurrentStep = currentDate >= stepStart && currentDate < step.endTime
                            let isPastAllSteps = index == steps.count - 1 && currentDate >= step.endTime
                            
                            Text("\(index + 1)/\(steps.count)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(8)
                                .opacity(isCurrentStep || isPastAllSteps ? 1 : 0)
                        }
                    }
                }
            }
            
            // Progress Bar (auto-advancing)
            if let steps = steps, !steps.isEmpty {
                ZStack {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        let stepStart = step.endTime.addingTimeInterval(-Double(step.durationSeconds))
                        let isCurrentStep = currentDate >= stepStart && currentDate < step.endTime
                        
                        if isCurrentStep {
                            ProgressView(timerInterval: stepStart...step.endTime, countsDown: false)
                                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        }
                    }
                    
                    // Show full progress if all done
                    if let lastStep = steps.last, currentDate >= lastStep.endTime {
                        ProgressView(value: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    }
                }
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
