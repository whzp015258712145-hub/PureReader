import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var methodChannel: FlutterMethodChannel?
  var pendingFiles: [String] = []

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
        methodChannel = FlutterMethodChannel(name: "com.purereader.app/file_open", binaryMessenger: controller.engine.binaryMessenger)
        
        // 发送积压的文件
        for file in pendingFiles {
            methodChannel?.invokeMethod("onOpenFile", arguments: file)
        }
        pendingFiles.removeAll()
    }
    super.applicationDidFinishLaunching(notification)
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    for filename in filenames {
        print("SWIFT DEBUG: Open File \(filename)")
        if let channel = methodChannel {
            channel.invokeMethod("onOpenFile", arguments: filename)
        } else {
            pendingFiles.append(filename)
        }
    }
    super.application(sender, openFiles: filenames)
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
        print("SWIFT DEBUG: Open URL \(url)")
        if let channel = methodChannel {
            channel.invokeMethod("onOpenFile", arguments: url.path)
        } else {
            pendingFiles.append(url.path)
        }
    }
    super.application(application, open: urls)
  }
}
