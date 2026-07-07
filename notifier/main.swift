// main.swift — a tiny bundled macOS app that posts a silent notification with a
// custom icon (the app's own bundle icon) and, when clicked, brings a target
// application to the front. Built on the modern UserNotifications framework, so
// unlike `osascript` it isn't stamped with the Script Editor identity.
//
//   Post:  Notifier <title> <subtitle> <body> [target-bundle-id]
//   Click: macOS relaunches this app with no args and delivers the tap to the
//          delegate, which activates <target-bundle-id> (e.g. com.googlecode.iterm2).
//
// It has no persistent process: it posts (or handles a click) and exits.
import AppKit
import UserNotifications

final class Delegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self   // set before anything, so a pending click is delivered

        let args = Array(CommandLine.arguments.dropFirst())
        if args.count >= 3 {
            // Post mode. Ask permission the first time, then deliver silently.
            center.requestAuthorization(options: [.alert]) { _, _ in
                let content = UNMutableNotificationContent()
                content.title = args[0]
                content.subtitle = args[1]
                content.body = args[2]
                if args.count >= 4 { content.userInfo = ["target": args[3]] }
                // no content.sound -> silent
                let req = UNNotificationRequest(identifier: UUID().uuidString,
                                                content: content, trigger: nil)
                center.add(req) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { NSApp.terminate(nil) }
                }
            }
        } else {
            // Launched by a click (no args). Give the delegate a moment to fire.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { NSApp.terminate(nil) }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
           let target = response.notification.request.content.userInfo["target"] as? String,
           !target.isEmpty {
            activate(bundleId: target)
        }
        completionHandler()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
    }

    private func activate(bundleId: String) {
        // Prefer focusing an already-running instance — this just brings its
        // existing windows forward. Using NSWorkspace.openApplication instead
        // sends a reopen event, which Electron apps (VS Code) answer by spawning
        // a brand-new window. Only fall back to launching if it isn't running.
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            app.activate(options: [.activateAllWindows])
            return
        }
        let ws = NSWorkspace.shared
        guard let url = ws.urlForApplication(withBundleIdentifier: bundleId) else { return }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        ws.openApplication(at: url, configuration: cfg, completionHandler: nil)
    }
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon, never steals focus
app.run()
