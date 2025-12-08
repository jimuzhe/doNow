import WidgetKit
import SwiftUI
import ActivityKit

@available(iOS 16.1, *)
struct DoNowActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoNowActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI - Shows when user long-presses
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        if let start = context.state.startTime, let end = context.state.endTime {
                           ProgressView(timerInterval: start...end, countsDown: false)
                                .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                .frame(width: 24, height: 24)
                        } else {
                           ProgressView(value: context.state.progress)
                                .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                .frame(width: 24, height: 24)
                        }
                        
                        if let end = context.state.endTime {
                            Text(timerInterval: Date()...end, countsDown: true)
                                .multilineTextAlignment(.center)
                                .monospacedDigit()
                                .font(.caption.bold())
                                .foregroundColor(.green)
                                .frame(width: 50)
                        } else {
                            Text("\(Int(context.state.progress * 100))%")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    // Empty for balance
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.currentStep)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    // Progress bar (no buttons for iOS 16 compatibility)
                    VStack(spacing: 8) {
                        if let start = context.state.startTime, let end = context.state.endTime {
                            ProgressView(timerInterval: start...end, countsDown: false)
                                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        } else {
                            ProgressView(value: context.state.progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        }
                        
                        Text("点击打开应用操作")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
            } compactLeading: {
                // Compact Leading - Progress indicator
                if let start = context.state.startTime, let end = context.state.endTime {
                   ProgressView(timerInterval: start...end, countsDown: false)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 16, height: 16)
                } else {
                   ProgressView(value: context.state.progress)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 16, height: 16)
                }
            } compactTrailing: {
                // Compact Trailing - Timer or Percentage
                if let end = context.state.endTime {
                    Text(timerInterval: Date()...end, countsDown: true)
                        .monospacedDigit()
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: 40)
                } else {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                }
            } minimal: {
                // Minimal - Just icon
                if let start = context.state.startTime, let end = context.state.endTime {
                     ProgressView(timerInterval: start...end, countsDown: false)
                        .progressViewStyle(CircularProgressViewStyle(tint: .green))
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "timer")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }
            .contentMargins(.horizontal, 4, for: .compactLeading)
            .contentMargins(.horizontal, 4, for: .compactTrailing)
        }
    }
}

// MARK: - Lock Screen View (No buttons for iOS 16 compatibility)
@available(iOS 16.1, *)
struct LockScreenView: View {
    let context: ActivityViewContext<DoNowActivityAttributes>
    
    var body: some View {
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
                
                if let end = context.state.endTime {
                    Text(timerInterval: Date()...end, countsDown: true)
                        .monospacedDigit()
                        .font(.caption.bold())
                        .foregroundColor(.green)
                } else {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
            }
            
            // Current Step
            Text(context.state.currentStep)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
            
            // Progress Bar
            if let start = context.state.startTime, let end = context.state.endTime {
                 ProgressView(timerInterval: start...end, countsDown: false)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
            } else {
                ProgressView(value: context.state.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
            }
            
            // Hint text (no buttons)
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
        endTime: Date().addingTimeInterval(1200)
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
