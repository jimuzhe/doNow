import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    logToDocuments(message: "App launching...")
    
    do {
        GeneratedPluginRegistrant.register(with: self)
        logToDocuments(message: "Plugins registered")
    } catch {
        logToDocuments(message: "Error registering plugins: \(error)")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  func logToDocuments(message: String) {
    DispatchQueue.global().async {
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let logFile = documentsDirectory.appendingPathComponent("startup_log.txt")
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
