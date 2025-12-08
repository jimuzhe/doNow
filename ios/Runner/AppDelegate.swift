import Flutter
import UIKit
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    private var liveActivityChannel: FlutterMethodChannel?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        logToDocuments(message: "App launching...")
        
        // Register plugins
        GeneratedPluginRegistrant.register(with: self)
        logToDocuments(message: "Plugins registered")
        
        // Setup MethodChannel for Live Activities
        if let controller = window?.rootViewController as? FlutterViewController {
            liveActivityChannel = FlutterMethodChannel(
                name: "com.donow.app/live_activity",
                binaryMessenger: controller.binaryMessenger
            )
            
            liveActivityChannel?.setMethodCallHandler { [weak self] (call, result) in
                self?.handleMethodCall(call: call, result: result)
            }
            logToDocuments(message: "Live Activity channel registered")
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startActivity":
            if let args = call.arguments as? [String: Any] {
                startLiveActivity(args: args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
            
        case "updateActivity":
            if let args = call.arguments as? [String: Any] {
                updateLiveActivity(args: args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
            
        case "endActivity":
            endLiveActivity(result: result)
            
        case "isSupported":
            checkLiveActivitySupport(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Live Activity Methods
    
    private func startLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
        guard #available(iOS 16.1, *) else {
            logToDocuments(message: "Live Activities not supported on this iOS version")
            result(FlutterError(code: "UNSUPPORTED", message: "iOS 16.1+ required", details: nil))
            return
        }
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logToDocuments(message: "Live Activities are disabled by user")
            result(FlutterError(code: "DISABLED", message: "Live Activities disabled", details: nil))
            return
        }
        
        let taskTitle = args["taskTitle"] as? String ?? "Task"
        let currentStep = args["currentStep"] as? String ?? "Starting..."
        let progress = args["progress"] as? Double ?? 0.0
        let totalDuration = args["totalDuration"] as? Int ?? 60
        
        logToDocuments(message: "Starting Live Activity: \(taskTitle)")
        
        let attributes = DoNowActivityAttributes(
            taskTitle: taskTitle,
            totalDuration: totalDuration
        )
        
        let initialState = DoNowActivityAttributes.ContentState(
            currentStep: currentStep,
            progress: progress
        )
        
        do {
            // End any existing activities first
            for activity in Activity<DoNowActivityAttributes>.activities {
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            
            // Start new activity
            let activity = try Activity<DoNowActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            
            logToDocuments(message: "Live Activity started with ID: \(activity.id)")
            result(activity.id)
            
        } catch {
            logToDocuments(message: "Failed to start Live Activity: \(error.localizedDescription)")
            result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    private func updateLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
        guard #available(iOS 16.1, *) else {
            result(FlutterError(code: "UNSUPPORTED", message: "iOS 16.1+ required", details: nil))
            return
        }
        
        let currentStep = args["currentStep"] as? String ?? ""
        let progress = args["progress"] as? Double ?? 0.0
        
        logToDocuments(message: "Updating Live Activity: \(currentStep) - \(Int(progress * 100))%")
        
        let updatedState = DoNowActivityAttributes.ContentState(
            currentStep: currentStep,
            progress: progress
        )
        
        Task {
            for activity in Activity<DoNowActivityAttributes>.activities {
                await activity.update(
                    ActivityContent(state: updatedState, staleDate: nil)
                )
            }
            
            DispatchQueue.main.async {
                result(true)
            }
        }
    }
    
    private func endLiveActivity(result: @escaping FlutterResult) {
        guard #available(iOS 16.1, *) else {
            result(FlutterError(code: "UNSUPPORTED", message: "iOS 16.1+ required", details: nil))
            return
        }
        
        logToDocuments(message: "Ending Live Activity")
        
        Task {
            for activity in Activity<DoNowActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            
            DispatchQueue.main.async {
                result(true)
            }
        }
    }
    
    private func checkLiveActivitySupport(result: @escaping FlutterResult) {
        if #available(iOS 16.1, *) {
            let isEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
            logToDocuments(message: "Live Activities supported: \(isEnabled)")
            result(isEnabled)
        } else {
            logToDocuments(message: "Live Activities not supported (iOS < 16.1)")
            result(false)
        }
    }
    
    // MARK: - Logging
    
    func logToDocuments(message: String) {
        DispatchQueue.global().async {
            let fileManager = FileManager.default
            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let logFile = documentsDirectory.appendingPathComponent("live_activity_log.txt")
                let logText = "\(Date()): \(message)\n"
                
                if let data = logText.data(using: .utf8) {
                    if fileManager.fileExists(atPath: logFile.path) {
                        if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                            fileHandle.seekToEndOfFile()
                            fileHandle.write(data)
                            fileHandle.closeFile()
                        }
                    } else {
                        try? data.write(to: logFile)
                    }
                }
            }
        }
    }
}
