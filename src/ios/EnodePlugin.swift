import Foundation
import UIKit
import LinkKit

@objc(EnodePlugin)
class EnodePlugin: CDVPlugin {

    private var handler: Handler?

    @objc(openLinkUI:)
    func openLinkUI(command: CDVInvokedUrlCommand) {
        guard let linkToken = command.argument(at: 0) as? String else {
            send(error: "Invalid arguments", callbackId: command.callbackId)
            return
        }
        let themeMode = command.argument(at: 1) as? String ?? "system"
        presentLinkUI(linkToken: linkToken, themeMode: themeMode, callbackId: command.callbackId)
    }

    private func presentLinkUI(linkToken: String, themeMode: String, callbackId: String) {
        guard let viewController = self.viewController else {
            send(error: "No view controller available to present Link UI", callbackId: callbackId)
            return
        }

        // Set on the window, not the view controller - matching Enode's own demo, which
        // sets tintColor on self.window (SceneDelegate), not on a view controller. A
        // window-level override cascades to everything drawn in it regardless of which
        // internal view controller LinkKit ends up presenting; a view-controller-level
        // override only cascades to that object's actual descendants.
        let window = viewController.view.window
        let previousStyle = window?.overrideUserInterfaceStyle
        window?.overrideUserInterfaceStyle = userInterfaceStyle(for: themeMode)

        // Previously set once in pluginInitialize(), matching Enode's own launch-time
        // demo pattern - but at that point in the Cordova lifecycle the view may not yet
        // be attached to a window, silently no-oping the assignment via optional
        // chaining. Moved here to match where overrideUserInterfaceStyle (above) is
        // confirmed to actually take effect: immediately before presenting, when the
        // window is guaranteed to be live.
        let previousTintColor = window?.tintColor
        window?.tintColor = UIColor(red: 0x4A / 255, green: 0x00 / 255, blue: 0x91 / 255, alpha: 1)

        // Match Android's presentation: LinkKit's activity there uses a plain (non-dialog)
        // NoActionBar theme, so it renders full screen rather than the SDK's default sheet.
        //
        // Uses the (LinkResultCode, HumanReadableMessage?) completion overload rather than
        // the (LinkResult) one - LinkResultCode is String-backed, giving a stable machine-
        // readable code alongside the message, matching Android's errorCode/message pair.
        let handler = Handler(linkToken: linkToken, presentationStyle: .fullScreen) { [weak self] resultCode, message in
            guard let self = self else { return }
            self.handler = nil
            if let previousStyle = previousStyle {
                window?.overrideUserInterfaceStyle = previousStyle
            }
            window?.tintColor = previousTintColor
            self.handle(resultCode, message: message, callbackId: callbackId)
        }
        self.handler = handler
        handler.present(from: viewController)
    }

    private func userInterfaceStyle(for themeMode: String) -> UIUserInterfaceStyle {
        switch themeMode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return .unspecified
        }
    }

    private func handle(_ code: LinkResultCode, message: String?, callbackId: String) {
        switch code {
        case .success:
            send(success: callbackId)
        case .cancelledByUser, .dismissedViaDismissFunction:
            sendCancelled(callbackId: callbackId)
        case .earlyExitRequestedFromFrontend:
            // The SDK's own webview reached an "early exit" state (e.g. an unsupported
            // vehicle/scope combination) rather than the user explicitly tapping cancel or
            // a hard backend failure. Mapped to `cancelled` since linking did not complete -
            // this is a judgment call given O11's 3-state contract (success/cancelled/error);
            // revisit if O11 ever needs to distinguish this from a plain user cancel.
            sendCancelled(callbackId: callbackId)
        case .missingLinkToken:
            send(error: message ?? "Missing link token", code: code.rawValue, callbackId: callbackId)
        case .malformedLinkToken:
            send(error: message ?? "Malformed link token", code: code.rawValue, callbackId: callbackId)
        case .backendError:
            send(error: message ?? "Backend error", code: code.rawValue, callbackId: callbackId)
        case .unknown:
            send(error: message ?? "Unknown LinkKit error", code: code.rawValue, callbackId: callbackId)
        @unknown default:
            // LinkResultCode is a resilient (library-evolution) enum, so future SDK versions
            // can add cases without this being a compile error. Fail safe as a generic error
            // rather than silently mis-mapping an unrecognized code to something else.
            send(error: message ?? "Unknown LinkKit result", code: code.rawValue, callbackId: callbackId)
        }
    }

    private func send(success callbackId: String) {
        let payload: [String: Any] = ["status": "success"]
        let result = CDVPluginResult(status: .ok, messageAs: payload)
        commandDelegate.send(result, callbackId: callbackId)
    }

    private func sendCancelled(callbackId: String) {
        let payload: [String: Any] = ["status": "cancelled"]
        let result = CDVPluginResult(status: .ok, messageAs: payload)
        commandDelegate.send(result, callbackId: callbackId)
    }

    private func send(error message: String, callbackId: String) {
        let payload: [String: Any] = ["status": "error", "message": message]
        let result = CDVPluginResult(status: .error, messageAs: payload)
        commandDelegate.send(result, callbackId: callbackId)
    }

    private func send(error message: String, code: String, callbackId: String) {
        let payload: [String: Any] = ["status": "error", "code": code, "message": message]
        let result = CDVPluginResult(status: .error, messageAs: payload)
        commandDelegate.send(result, callbackId: callbackId)
    }
}
